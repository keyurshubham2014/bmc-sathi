// Ask: Claude explains, in plain words, figures the rules have already computed.
// It is given the facts for one ward, contractor or issue and nothing else, and decides nothing.
import Anthropic from "@anthropic-ai/sdk";
import { Router } from "express";
import { z } from "zod";
import { config } from "../config";
import { db } from "../lib/db";
import { AppError, parse } from "../lib/errors";
import { wardScope } from "../middleware/auth";
import { scorecard } from "./contractors";

export const ask = Router();

const SYSTEM = `You answer questions for Mumbai ward staff, auditors and citizens about road repair spending.
Answer only from the JSON facts in the user message. If the facts do not answer the question, say so in one sentence.
The audit rules have already decided what is flagged; explain their results, do not make new accusations. A flag is a reason to look, not proof of wrongdoing.
Rates in the facts are fractions: say them as percentages. Give rupee amounts in lakh or crore. Name the record ids (work order, complaint, issue) you relied on.
Keep the answer under 120 words, in plain sentences with no headings or lists.`;

/** The facts Claude may use. Exported so a test can check them without calling Claude. */
export async function factsFor(scope_type: "ward" | "contractor" | "issue", scope_id: string, canSeeFlags: boolean) {
  if (scope_type === "ward") {
    const [money] = await db.$queryRaw<any[]>`SELECT * FROM v_ward_money WHERE ward_code = ${scope_id}`;
    if (!money) throw new AppError("not_found", "No such ward.");
    const [by_contractor, flags, plan, recent] = await Promise.all([
      db.$queryRaw`SELECT contractor_name, COUNT(*)::int jobs, SUM(cost_inr)::int spend, SUM(reopened_within_30d::int)::int reopened FROM v_work_order WHERE ward_code = ${scope_id} GROUP BY 1 ORDER BY 3 DESC`,
      db.$queryRaw`SELECT flag_type, tier, COUNT(*)::int flags, SUM(amount_at_stake)::int amount_at_stake FROM v_flag WHERE ward_code = ${scope_id} GROUP BY 1, 2`,
      db.$queryRaw`SELECT rank, issue_id, road_name, category, risk_score, recommended_method, estimated_cost, within_budget, complaint_count FROM v_plan WHERE ward_code = ${scope_id} ORDER BY rank LIMIT 10`,
      canSeeFlags
        ? db.$queryRaw`SELECT work_order_id, road_name, work_type, repair_method, contractor_name, cost_inr, expected_cost, cost_ratio, assigned_at, sla_met, reopened_within_30d FROM v_work_order WHERE ward_code = ${scope_id} ORDER BY assigned_at DESC LIMIT 20`
        : [],
    ]);
    return { ward: money, spend_by_contractor: by_contractor, flags, scorecard: await scorecard("ward", scope_id), top_of_plan: plan, recent_work_orders: recent };
  }
  if (scope_type === "contractor") {
    const contractor = await db.contractor.findUnique({ where: { contractor_id: scope_id } });
    if (!contractor) throw new AppError("not_found", "No such contractor.");
    const [by_ward, flags] = await Promise.all([
      db.$queryRaw`SELECT ward_code, COUNT(*)::int jobs, SUM(cost_inr)::int spend, SUM(reopened_within_30d::int)::int reopened FROM v_work_order WHERE contractor_id = ${scope_id} GROUP BY 1 ORDER BY 3 DESC`,
      db.$queryRaw`SELECT flag_type, tier, COUNT(*)::int flags, SUM(amount_at_stake)::int amount_at_stake FROM v_flag WHERE contractor_id = ${scope_id} GROUP BY 1, 2`,
    ]);
    return { contractor, scorecard_vs_similar_jobs: await scorecard("contractor", scope_id), jobs_by_ward: by_ward, flags };
  }
  const id = Number(scope_id);
  const issue = Number.isInteger(id) ? await db.issue.findUnique({ where: { issue_id: id } }) : null;
  if (!issue) throw new AppError("not_found", "No such issue.");
  const [complaints, wo, plan] = await Promise.all([
    db.$queryRaw`SELECT c.complaint_id, c.received_at, c.channel, c.description, c.status FROM complaint c JOIN complaint_enriched e USING (complaint_id) WHERE e.issue_id = ${id} ORDER BY 2 LIMIT 20`,
    issue.work_order_id ? db.$queryRaw`SELECT * FROM v_work_order WHERE work_order_id = ${issue.work_order_id}` : [],
    db.$queryRaw`SELECT rank, risk_score, pts_severity, pts_access, pts_safety, pts_traffic, pts_flood, pts_demand, recommended_method, estimated_cost, within_budget, days_open FROM v_plan WHERE issue_id = ${id}`,
  ]);
  return { issue, complaints, work_order: wo, plan };
}

ask.post("/", async (req, res) => {
  const b = parse(z.object({
    question: z.string().trim().min(3).max(500),
    scope_type: z.enum(["ward", "contractor", "issue"]),
    scope_id: z.string().min(1).max(20),
    lang: z.enum(["en", "mr"]).default("en"),
  }), req.body);
  if (b.scope_type === "ward") wardScope(req.user, b.scope_id);
  const facts = await factsFor(b.scope_type, b.scope_id, req.user.role !== "citizen");
  if (!config.anthropicKey) throw new AppError("assistant_unavailable", "Ask is not set up yet: add ANTHROPIC_API_KEY to apps/api/.env and restart the API.");

  const json = (_k: string, v: unknown) => (typeof v === "bigint" ? Number(v) : v);
  let response;
  try {
    response = await new Anthropic({ apiKey: config.anthropicKey, timeout: 25_000, maxRetries: 1 }).beta.messages.create({
      model: "claude-sonnet-5-5",
      max_tokens: 2000,
      output_config: { effort: "low" },
      // If a safety check declines, the API retries on its default fallback model.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: SYSTEM + (b.lang === "mr" ? "\nAnswer in Marathi." : "\nAnswer in English."),
      // The question is user input: it is kept apart from the facts and cannot change the rules above.
      messages: [{ role: "user", content: `<facts>\n${JSON.stringify(facts, json)}\n</facts>\n\n<question>\n${b.question}\n</question>` }],
    });
  } catch (e) {
    if (e instanceof Anthropic.AuthenticationError) throw new AppError("assistant_unavailable", "The Claude API key was rejected. Check ANTHROPIC_API_KEY.");
    if (e instanceof Anthropic.RateLimitError) throw new AppError("too_many_requests", "Ask is busy. Try again in a minute.");
    if (e instanceof Anthropic.APIError) throw new AppError("assistant_unavailable", "Ask could not get an answer just now. The figures on screen are unaffected.");
    throw e;
  }
  const answer = response.content.flatMap((blk) => (blk.type === "text" ? [blk.text] : [])).join("").trim();
  if (response.stop_reason === "refusal" || !answer) throw new AppError("assistant_unavailable", "Ask could not answer that question.");
  res.json({ answer, lang: b.lang, model: response.model });
});

// The stored summary for a ward or contractor, written by the summarise pipeline step. Null until it has run.
ask.get("/summary", async (req, res) => {
  const q = parse(z.object({ type: z.enum(["ward", "contractor"]), id: z.string().max(20), lang: z.enum(["en", "mr"]).default("en") }), req.query);
  const row = await db.summary.findUnique({ where: { subject_type_subject_id_lang: { subject_type: q.type, subject_id: q.id, lang: q.lang } } });
  res.json({ summary: row && { body: row.body, generated_at: row.generated_at } });
});
