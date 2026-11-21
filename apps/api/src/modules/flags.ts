import { Prisma } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, paging, parse } from "../lib/errors";
import { askJson, SONNET } from "../lib/claude";
import { config } from "../config";
import { requireRole, wardScope } from "../middleware/auth";
import { rateLimit } from "./ask";

// Unreviewed flags name contractors, so the queue is for officers and auditors only.
export const flags = Router().use(requireRole("ward_officer", "auditor"));

const FLAG_TYPE = z.enum(["overbilled", "duplicate", "dlp"]);

flags.get("/", async (req, res) => {
  const q = parse(z.object({
    type: FLAG_TYPE.optional(), ward_code: z.string().optional(), contractor_id: z.string().optional(),
    decision: z.enum(["open", "confirmed", "needs_explanation", "not_an_issue"]).optional(),
    tier: z.enum(["flag", "watch"]).default("flag"), sort: z.enum(["amount", "date"]).default("amount"),
    ...paging,
  }), req.query);
  const ward = wardScope(req.user, q.ward_code);
  const where = [Prisma.sql`f.tier = ${q.tier}`];
  if (q.type) where.push(Prisma.sql`f.flag_type = ${q.type}`);
  if (ward) where.push(Prisma.sql`f.ward_code = ${ward}`);
  if (q.contractor_id) where.push(Prisma.sql`f.contractor_id = ${q.contractor_id}`);
  if (q.decision) where.push(Prisma.sql`f.decision = ${q.decision}`);
  const cond = Prisma.join(where, " AND ");
  const order = q.sort === "date" ? Prisma.sql`w.assigned_at DESC` : Prisma.sql`f.amount_at_stake DESC`;
  const [items, totals] = await Promise.all([
    db.$queryRaw`SELECT f.*, w.road_name, w.contractor_name, w.work_type, w.repair_method, w.cost_inr, w.assigned_at
      FROM v_flag f JOIN v_work_order w ON w.work_order_id = f.work_order_id
      WHERE ${cond} ORDER BY ${order}, f.work_order_id LIMIT ${q.limit} OFFSET ${q.offset}`,
    db.$queryRaw<any[]>`SELECT COUNT(*)::int AS total FROM v_flag f WHERE ${cond}`,
  ]);
  res.json({ items, total: totals[0].total });
});

flags.get("/summary", async (req, res) => {
  const q = parse(z.object({ ward_code: z.string().optional() }), req.query);
  const ward = wardScope(req.user, q.ward_code);
  const scope = ward ? Prisma.sql`AND ward_code = ${ward}` : Prisma.empty;
  res.json({ items: await db.$queryRaw`
    SELECT flag_type, tier, decision, COUNT(*)::int AS count, SUM(amount_at_stake)::bigint AS amount
    FROM v_flag WHERE true ${scope} GROUP BY flag_type, tier, decision ORDER BY flag_type, tier, decision` });
});

async function findFlag(type: string, workOrderId: string) {
  const rows = await db.$queryRaw<any[]>`SELECT * FROM v_flag WHERE flag_type = ${type} AND work_order_id = ${workOrderId}
    ORDER BY tier LIMIT 1`;
  if (!rows.length) throw new AppError("not_found", "No such flag.");
  return rows[0];
}
const workOrder = async (id: string) =>
  (await db.$queryRaw<any[]>`SELECT * FROM v_work_order WHERE work_order_id = ${id}`)[0] ?? null;

flags.get("/:type/:workOrderId", async (req, res) => {
  const type = parse(FLAG_TYPE, req.params.type);
  const flag = await findFlag(type, req.params.workOrderId);
  wardScope(req.user, flag.ward_code);
  const decided = flag.decided_by ? await db.app_user.findUnique({ where: { user_id: flag.decided_by } }) : null;
  res.json({
    flag: { ...flag, decided_by_name: decided?.display_name ?? null },
    work_order: await workOrder(flag.work_order_id),
    earlier_work_order: type === "duplicate" ? await workOrder(flag.evidence.earlier_work_order_id) : null,
  });
});

flags.put("/:type/:workOrderId/decision", async (req, res) => {
  const type = parse(FLAG_TYPE, req.params.type);
  const body = parse(z.object({
    decision: z.enum(["confirmed", "needs_explanation", "not_an_issue"]),
    note: z.string().trim().max(500).optional(),
  }), req.body);
  const flag = await findFlag(type, req.params.workOrderId);
  wardScope(req.user, flag.ward_code);
  if (flag.tier !== "flag") throw new AppError("conflict", "A watch item cannot take a decision.");
  const data = { decision: body.decision, note: body.note ?? null, decided_by: req.user.user_id, decided_at: new Date() };
  await db.flag_decision.upsert({
    where: { flag_type_work_order_id: { flag_type: type, work_order_id: flag.work_order_id } },
    update: data, create: { flag_type: type, work_order_id: flag.work_order_id, ...data },
  });
  res.json({ flag: await findFlag(type, flag.work_order_id) });
});

// ---------- action pack: one draft document for a group of decided flags ----------

const HEADER = "DRAFT FOR REVIEW. Independent prototype, synthetic data. Not an official BMC document.";
const SIGN = "Prepared by: ____________    Date: ____________";
const MAX_JOBS = 60;
const rupees = (n: number) => `₹${Math.round(n).toLocaleString("en-IN")}`;
const day = (d: Date) => new Date(d).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "Asia/Kolkata" });

/** A written draft is used only if it names every job and accuses no one; otherwise the template is. */
export const acceptable = (body: string, ids: string[]) =>
  ids.every((id) => body.includes(id)) && !/\b(fraud|scam|corrupt|theft|criminal)/i.test(body);

function reason(r: any): string {
  const e = r.evidence;
  if (r.flag_type === "overbilled") return `billed ${e.ratio} times the rate card (expected about ${rupees(e.expected_cost)})`;
  if (r.flag_type === "duplicate") return `repeats ${e.earlier_work_order_id} on the same road ${e.days_apart} days earlier, with no complaint linked`;
  return `the road was last resurfaced on ${day(e.last_resurfaced)} and is under its defect liability period`;
}

const WRITER = `You draft a short official letter for a Mumbai ward office from the JSON facts given. An officer will review and edit it before use.
For kind "dlp": address the Roads Department; ask it to identify the contractor liable under the defect liability period for the road and to recover the listed amounts. Do not name a liable contractor: the records do not say who it is.
For kind "billing": address the contractor named in the facts; ask for a written explanation of each listed job within 7 days. A flag is a reason to ask, not a finding.
List every job on its own line with its work order id exactly as given, its date, what was billed, the amount in question and the reason from the facts. Include the officer's note where there is one.
Do not accuse anyone, do not use words such as fraud, scam, corrupt, theft or criminal, and add no fact that is not in the JSON. Do not write a total, a heading line about drafts, or a signature: those are added afterwards.
Plain sentences, under 250 words besides the job list. Write in the language named in "lang" ("en" English, "mr" Marathi in Devanagari), keeping ids, names and amounts as given.`;
const Written = z.object({ title: z.string(), body: z.string() });

flags.post("/draft", async (req, res) => {
  const b = parse(z.discriminatedUnion("kind", [
    z.object({ kind: z.literal("dlp"), road_id: z.string().min(1).max(20), lang: z.enum(["en", "mr"]).default("en"), plain: z.boolean().default(false) }),
    z.object({ kind: z.literal("billing"), contractor_id: z.string().min(1).max(20), ward_code: z.string().min(1).max(10), lang: z.enum(["en", "mr"]).default("en"), plain: z.boolean().default(false) }),
  ]), req.body);

  let scope: Prisma.Sql, to: string, subject: string;
  if (b.kind === "dlp") {
    const road = await db.road.findUnique({ where: { road_id: b.road_id } });
    if (!road) throw new AppError("not_found", "No such road.");
    wardScope(req.user, road.ward_code);
    scope = Prisma.sql`f.flag_type = 'dlp' AND w.road_id = ${b.road_id}`;
    to = "The Roads Department";
    subject = `Repairs billed on ${road.road_name} (${road.road_id}, Ward ${road.ward_code}) while under its defect liability period`;
  } else {
    wardScope(req.user, b.ward_code);
    const contractor = await db.contractor.findUnique({ where: { contractor_id: b.contractor_id } });
    if (!contractor) throw new AppError("not_found", "No such contractor.");
    scope = Prisma.sql`f.flag_type <> 'dlp' AND f.contractor_id = ${b.contractor_id} AND f.ward_code = ${b.ward_code}`;
    to = contractor.contractor_name;
    subject = `Request for explanation: billing on jobs in Ward ${b.ward_code}`;
  }
  const rows = await db.$queryRaw<any[]>`
    SELECT f.flag_type, f.work_order_id, f.amount_at_stake, f.decision, f.note, f.evidence,
           w.assigned_at, w.road_name, w.work_type, w.repair_method, w.cost_inr
    FROM v_flag f JOIN v_work_order w ON w.work_order_id = f.work_order_id
    WHERE f.tier = 'flag' AND f.decision IN ('confirmed', 'needs_explanation') AND ${scope}
    ORDER BY f.amount_at_stake DESC, f.work_order_id`;
  if (!rows.length) throw new AppError("conflict", "No decided flags in this group yet.");

  // A job with two flags is listed for both reasons and counted once, at its larger amount.
  const perJob = new Map<string, number>();
  for (const r of rows) perJob.set(r.work_order_id, Math.max(perJob.get(r.work_order_id) ?? 0, r.amount_at_stake));
  const ids = [...perJob.keys()].slice(0, MAX_JOBS);
  const listed = rows.filter((r) => ids.includes(r.work_order_id));
  const total = ids.reduce((s, id) => s + perJob.get(id)!, 0);
  const left_out = perJob.size - ids.length;

  const jobs = listed.map((r) => ({
    work_order_id: r.work_order_id, date: day(r.assigned_at), road: r.road_name, work: `${r.work_type}, ${r.repair_method}`,
    billed: rupees(r.cost_inr), amount_in_question: rupees(r.amount_at_stake), reason: reason(r),
    decision: r.decision === "confirmed" ? "Confirmed" : "Needs explanation", note: r.note,
  }));
  const totalLine = `Total in question: ${rupees(total)} across ${ids.length} job${ids.length === 1 ? "" : "s"}.`
    + (left_out ? ` ${left_out} smaller job${left_out === 1 ? " is" : "s are"} not listed here.` : "");
  const wrap = (body: string) => `${HEADER}\n\n${body.trim()}\n\n${totalLine}\n\n${SIGN}`;

  const ask = b.kind === "dlp"
    ? "Please identify the contractor liable under the defect liability period for this road and recover the amounts below, or tell this office why they are not recoverable."
    : "Please explain each of the jobs below in writing within 7 days. A flag is a reason to ask, not a finding.";
  const template = wrap([`To: ${to}`, `Subject: ${subject}`, "", ask, "",
    ...jobs.map((j, i) => `${i + 1}. ${j.work_order_id} · ${j.date} · ${j.road} · ${j.work} · billed ${j.billed} · ${j.reason} · amount in question ${j.amount_in_question} · ${j.decision}${j.note ? `. Note: ${j.note}` : ""}`),
  ].join("\n"));
  const out = { work_order_ids: ids, total_amount: total, left_out };

  if (!b.plain && config.anthropicKey) {
    rateLimit(req.user.user_id);
    try {
      // shortcut: askJson has no timeout of its own, so the wait is capped here; give it a client timeout if drafts are ever queued.
      const written = await Promise.race([
        askJson(SONNET, WRITER, JSON.stringify({ kind: b.kind, lang: b.lang, to, subject, jobs }), Written),
        new Promise<never>((_, no) => setTimeout(() => no(new Error("timed out")), 20_000)),
      ]);
      if (acceptable(written.body, ids))
        return res.json({ draft: { title: written.title, body: wrap(written.body) }, source: "claude", lang: b.lang, ...out });
    } catch { /* fall through to the template: the officer always gets a draft */ }
  }
  res.json({ draft: { title: subject, body: template }, source: "template", lang: "en", ...out });
});
