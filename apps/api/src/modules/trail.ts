import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, parse } from "../lib/errors";

export const trail = Router();

// complainant_id is never selected, so no role can receive it.
const complaintsOf = (issueId: number) => db.$queryRaw<any[]>`
  SELECT c.complaint_id, c.received_at, c.channel, c.category_reported, c.description, c.language, c.locality_text,
         c.photo_description, c.upvotes, c.status, c.resolved_at, e.category_clean, e.severity, e.text_en,
         e.location_source, (e.model IS NOT NULL) AS read_by_claude
  FROM complaint c JOIN complaint_enriched e USING (complaint_id)
  WHERE e.issue_id = ${issueId} ORDER BY c.received_at`;

async function workOrderPart(workOrderId: string | null) {
  if (!workOrderId) return { work_order: null, flags: [] };
  const [wo] = await db.$queryRaw<any[]>`SELECT * FROM v_work_order WHERE work_order_id = ${workOrderId}`;
  const flags = await db.$queryRaw`SELECT flag_type, tier, amount_at_stake, decision FROM v_flag WHERE work_order_id = ${workOrderId}`;
  return { work_order: wo ?? null, flags };
}

async function issueTrail(issueId: number, highlight?: string) {
  const issue = await db.issue.findUnique({ where: { issue_id: issueId } });
  if (!issue) throw new AppError("not_found", "No such issue.");
  const [complaints, part, road, plan, social] = await Promise.all([
    complaintsOf(issueId),
    workOrderPart(issue.work_order_id),
    issue.road_id ? db.road.findUnique({ where: { road_id: issue.road_id } }) : null,
    issue.state === "open"
      ? db.$queryRaw<any[]>`SELECT rank, risk_score, recommended_method, estimated_cost, within_budget, days_open FROM v_plan WHERE issue_id = ${issueId}`
      : [],
    db.$queryRaw`SELECT s.post_id, s.posted_at, s.source, s.text, l.text_en FROM social_post_label l JOIN social_post s USING (post_id) WHERE l.issue_id = ${issueId}`,
  ]);
  return { issue, complaints, ...part, road, plan: plan[0] ?? null, social_posts: social, highlight: highlight ?? null };
}

trail.get("/search", async (req, res) => {
  const { q } = parse(z.object({ q: z.string().trim().min(3).max(80) }), req.query);
  const like = `%${q}%`;
  const [complaints, workOrders, issues] = await Promise.all([
    db.$queryRaw`SELECT complaint_id AS id, locality_text, status, received_at FROM complaint WHERE complaint_id ILIKE ${like} ORDER BY complaint_id LIMIT 6`,
    db.$queryRaw`SELECT work_order_id AS id, road_name, work_type, contractor_name FROM v_work_order WHERE work_order_id ILIKE ${like} ORDER BY work_order_id LIMIT 6`,
    // Road and locality names lead to the issues there, open ones first.
    db.$queryRaw`
      SELECT i.issue_id AS id, i.category, i.state, i.ward_code, i.complaint_count, r.road_name, i.last_reported_at
      FROM issue i LEFT JOIN road r USING (road_id)
      WHERE i.state <> 'out_of_scope' AND (r.road_name ILIKE ${like} OR EXISTS (
        SELECT 1 FROM complaint_enriched e JOIN complaint c USING (complaint_id)
        WHERE e.issue_id = i.issue_id AND c.locality_text ILIKE ${like}))
      ORDER BY (i.state = 'open') DESC, i.complaint_count DESC LIMIT 12`,
  ]);
  res.json({ complaints, work_orders: workOrders, issues });
});

trail.get("/issue/:id", async (req, res) => {
  res.json(await issueTrail(parse(z.coerce.number().int(), req.params.id)));
});

trail.get("/complaint/:id", async (req, res) => {
  const e = await db.complaint_enriched.findUnique({ where: { complaint_id: req.params.id } });
  if (!e) throw new AppError("not_found", "No such complaint.");
  if (!e.issue_id) throw new AppError("not_found", "This complaint could not be placed in any ward.");
  res.json(await issueTrail(e.issue_id, e.complaint_id));
});

trail.get("/work-order/:id", async (req, res) => {
  const issue = await db.issue.findUnique({ where: { work_order_id: req.params.id } });
  if (issue) return void res.json(await issueTrail(issue.issue_id));
  // No complaint was ever linked: show the job, its road and its flags alone.
  const part = await workOrderPart(req.params.id);
  if (!part.work_order) throw new AppError("not_found", "No such work order.");
  const road = await db.road.findUnique({ where: { road_id: part.work_order.road_id } });
  res.json({ issue: null, complaints: [], ...part, road, plan: null, social_posts: [], highlight: null });
});
