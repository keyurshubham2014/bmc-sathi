import { Prisma } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, paging, parse } from "../lib/errors";
import { scorecard } from "./contractors";

export const wards = Router();

async function wardMoney(code: string) {
  const rows = await db.$queryRaw<any[]>`SELECT * FROM v_ward_money WHERE ward_code = ${code}`;
  if (!rows.length) throw new AppError("not_found", "No such ward.");
  return rows[0];
}

wards.get("/", async (_req, res) => {
  res.json({ items: await db.$queryRaw`SELECT * FROM v_ward_money ORDER BY spend_share DESC` });
});

wards.get("/:code", async (req, res) => {
  const money = await wardMoney(req.params.code);
  const flags = await db.$queryRaw`
    SELECT flag_type, COUNT(*)::int AS count, SUM(amount_at_stake)::bigint AS amount,
           (COUNT(*) FILTER (WHERE decision = 'open'))::int AS open
    FROM v_flag WHERE ward_code = ${req.params.code} AND tier = 'flag' GROUP BY flag_type`;
  res.json({ ward: money, flags });
});

wards.get("/:code/breakdown", async (req, res) => {
  const { dimension } = parse(z.object({ dimension: z.enum(["contractor", "method", "week"]) }), req.query);
  await wardMoney(req.params.code);
  const order = dimension === "week" ? Prisma.sql`key` : Prisma.sql`spend DESC`;
  res.json({ items: await db.$queryRaw`
    SELECT key, label, spend, jobs FROM v_ward_spend_breakdown
    WHERE ward_code = ${req.params.code} AND dimension = ${dimension} ORDER BY ${order}` });
});

const MISS_CAUSES = ["expired_before_assignment", "too_little_time_left", "had_time"] as const;

/** The work orders behind any figure on a ward or contractor page. */
export const workOrderQuery = z.object({
  filter: z.enum(["all", "reopened", "dlp", "flagged", "sla_missed", "overbilled", "fair_chance", ...MISS_CAUSES]).default("all"),
  contractor_id: z.string().optional(),
  method: z.string().optional(),
  week: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  ...paging,
});

export async function listWorkOrders(scope: Prisma.Sql, q: z.infer<typeof workOrderQuery>) {
  const where = [scope];
  if (q.filter === "reopened") where.push(Prisma.sql`reopened_within_30d`);
  if (q.filter === "dlp") where.push(Prisma.sql`road_under_dlp`);
  if (q.filter === "sla_missed") where.push(Prisma.sql`sla_met = false`);
  if (q.filter === "overbilled") where.push(Prisma.sql`cost_ratio > cfg('overbill_ratio')`);
  if (q.filter === "flagged") where.push(Prisma.sql`work_order_id IN (SELECT work_order_id FROM v_flag WHERE tier = 'flag')`);
  if (q.filter === "fair_chance") where.push(Prisma.sql`work_order_id IN (SELECT work_order_id FROM v_work_order_delay WHERE fair_chance)`);
  if ((MISS_CAUSES as readonly string[]).includes(q.filter))
    where.push(Prisma.sql`work_order_id IN (SELECT work_order_id FROM v_work_order_delay WHERE miss_cause = ${q.filter})`);
  if (q.contractor_id) where.push(Prisma.sql`contractor_id = ${q.contractor_id}`);
  if (q.method) where.push(Prisma.sql`repair_method = ${q.method}`);
  if (q.week) where.push(Prisma.sql`date_trunc('week', COALESCE(completed_at, assigned_at))::date = ${q.week}::date`);
  const cond = Prisma.join(where, " AND ");
  const [items, totals] = await Promise.all([
    db.$queryRaw`SELECT work_order_id, ward_code, road_id, road_name, work_type, repair_method, contractor_id,
        contractor_name, assigned_at, completed_at, area_sqm, cost_inr, expected_cost, cost_ratio, sla_hours,
        sla_met, reopened_within_30d, road_under_dlp, has_complaint, source
      FROM v_work_order WHERE ${cond} ORDER BY cost_inr DESC LIMIT ${q.limit} OFFSET ${q.offset}`,
    db.$queryRaw<any[]>`SELECT COUNT(*)::int AS total, COALESCE(SUM(cost_inr), 0)::bigint AS total_cost FROM v_work_order WHERE ${cond}`,
  ]);
  return { items, ...totals[0] };
}

wards.get("/:code/work-orders", async (req, res) => {
  await wardMoney(req.params.code);
  res.json(await listWorkOrders(Prisma.sql`ward_code = ${req.params.code}`, parse(workOrderQuery, req.query)));
});

wards.get("/:code/scorecard", async (req, res) => {
  await wardMoney(req.params.code);
  res.json({ scorecard: await scorecard("ward", req.params.code) });
});

// The next-rupee plan: open issues ranked by risk, with a method, a cost and the budget line.
wards.get("/:code/plan", async (req, res) => {
  const ward = await wardMoney(req.params.code);
  const items = await db.$queryRaw`
    SELECT issue_id, rank, road_id, road_name, segment_no, road_type, category, severity, complaint_count, upvotes_total,
           days_open, accidents, hospital_entry_count, school_count, bus_route, near_hotspot_id, high_risk, risk_score,
           pts_severity, pts_access, pts_safety, pts_traffic, pts_flood, pts_demand, recommended_method,
           recommended_reopen_rate, estimated_cost, alt_method, alt_cost, alt_reopen_rate, cumulative_cost, within_budget,
           within_recovered, within_possible, road_jobs, road_spend
    FROM v_plan WHERE ward_code = ${req.params.code} ORDER BY rank`;
  const weights = await db.setting.findMany({ where: { key: { startsWith: "w_" } } });
  // Totals only: what flagged money would fund. The flag rows themselves stay behind the flags routes.
  const [recoverable] = await db.$queryRaw<any[]>`SELECT * FROM v_ward_recoverable WHERE ward_code = ${req.params.code}`;
  res.json({ ward, recoverable, items, weights: Object.fromEntries(weights.map((w) => [w.key, w.value])) });
});
