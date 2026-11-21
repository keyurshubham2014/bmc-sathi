import { Prisma } from "@prisma/client";
import { Router } from "express";
import { db } from "../lib/db";
import { AppError, parse } from "../lib/errors";
import { listWorkOrders, workOrderQuery } from "./wards";

export const contractors = Router();

/** The measures for one contractor or ward, keyed by measure. */
export async function scorecard(type: "contractor" | "ward", id: string) {
  const rows = await db.$queryRaw<any[]>`SELECT * FROM v_scorecard WHERE subject_type = ${type} AND subject_id = ${id}`;
  if (!rows.length) return null;
  const { jobs, spend, wards, heavy_rain_jobs, low_lying_jobs } = rows[0];
  // Targets shorter than such work typically takes once assigned: missed whoever does the job.
  const unreachable_targets = await db.$queryRaw`
    SELECT work_type, sla_hours, ROUND(MAX(typical_hours)::numeric, 1)::float8 AS typical_hours, COUNT(*)::int AS jobs
    FROM v_work_order_delay
    WHERE ${type === "contractor" ? Prisma.sql`contractor_id` : Prisma.sql`ward_code`} = ${id} AND sla_hours < typical_hours
    GROUP BY work_type, sla_hours ORDER BY work_type, sla_hours`;
  return {
    jobs, spend, wards, heavy_rain_jobs, low_lying_jobs, unreachable_targets,
    measures: Object.fromEntries(rows.map((r) => [r.measure, { observed: r.observed, expected: r.expected, n: r.n, band: r.band, flagged: r.flagged }])),
  };
}

// Name order only. No score-based ordering is offered anywhere.
contractors.get("/", async (_req, res) => {
  res.json({ items: await db.$queryRaw`
    SELECT c.contractor_id, c.contractor_name, c.empanelled_since, s.jobs, s.spend, s.wards
    FROM contractor c JOIN v_scorecard s ON s.subject_type = 'contractor' AND s.subject_id = c.contractor_id AND s.measure = 'cost'
    ORDER BY c.contractor_name` });
});

contractors.get("/:id", async (req, res) => {
  const contractor = await db.contractor.findUnique({ where: { contractor_id: req.params.id } });
  if (!contractor) throw new AppError("not_found", "No such contractor.");
  res.json({ contractor, scorecard: await scorecard("contractor", contractor.contractor_id) });
});

contractors.get("/:id/work-orders", async (req, res) => {
  res.json(await listWorkOrders(Prisma.sql`contractor_id = ${req.params.id}`, parse(workOrderQuery, req.query)));
});
