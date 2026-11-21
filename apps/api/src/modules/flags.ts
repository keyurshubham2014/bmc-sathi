import { Prisma } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, paging, parse } from "../lib/errors";
import { requireRole, wardScope } from "../middleware/auth";

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
