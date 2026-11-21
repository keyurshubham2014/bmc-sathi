// New records typed in by a ward officer. They go through the same live rules as imported data:
// a new work order is flagged (or not) by v_flag the moment it is saved.
import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, parse } from "../lib/errors";
import { nearestRoad } from "../lib/geo";
import { cleanCategory, mentionedRoad, SEVERITY } from "../lib/rules";
import { requireRole } from "../middleware/auth";

export const intake = Router().use(requireRole("ward_officer"));

const methodsByWorkType = () => db.$queryRaw<{ work_type: string; repair_method: string; unit: string; standard_rate_inr: number }[]>`
  SELECT DISTINCT w.work_type, w.repair_method, rc.unit, rc.standard_rate_inr
  FROM work_order w JOIN rate_card rc USING (repair_method) WHERE w.source = 'import' ORDER BY 1, 2`;

/** What the forms need: this ward's roads, the methods allowed per work type, and contractors. */
intake.get("/options", async (req, res) => {
  const [roads, methods, contractors] = await Promise.all([
    db.road.findMany({ where: { ward_code: req.user.ward_code! }, select: { road_id: true, road_name: true, segment_no: true }, orderBy: [{ road_name: "asc" }, { segment_no: "asc" }] }),
    methodsByWorkType(),
    db.contractor.findMany({ select: { contractor_id: true, contractor_name: true }, orderBy: { contractor_name: "asc" } }),
  ]);
  res.json({ roads, methods, contractors, categories: Object.keys(SEVERITY) });
});

const nextId = async (table: "work_order" | "complaint", prefix: string) => {
  const [{ n }] = await db.$queryRawUnsafe<{ n: number }[]>(`SELECT COUNT(*)::int n FROM ${table} WHERE source = 'intake'`);
  return `${prefix}${String(n + 1).padStart(4, "0")}`;
};

intake.post("/work-orders", async (req, res) => {
  const b = parse(z.object({
    road_id: z.string(), work_type: z.string(), repair_method: z.string(), contractor_id: z.string(),
    area_sqm: z.number().positive().max(10_000), cost_inr: z.number().int().positive().max(100_000_000),
    assigned_at: z.coerce.date().optional(), completed_at: z.coerce.date().optional(),
  }), req.body);
  const road = await db.road.findUnique({ where: { road_id: b.road_id } });
  if (!road || road.ward_code !== req.user.ward_code) throw new AppError("not_allowed", "This road is outside your ward.");
  if (!(await methodsByWorkType()).some((m) => m.work_type === b.work_type && m.repair_method === b.repair_method))
    throw new AppError("validation_failed", "This repair method is not used for this work type.", [{ field: "repair_method", message: "Does not fit the work type" }]);
  if (!(await db.contractor.findUnique({ where: { contractor_id: b.contractor_id } })))
    throw new AppError("validation_failed", "No such contractor.", [{ field: "contractor_id", message: "Unknown" }]);
  // Default to the data's own latest moment, so the duplicate window is measured against real neighbours.
  const assigned_at = b.assigned_at ?? (await db.$queryRaw<{ t: Date }[]>`SELECT MAX(assigned_at) + interval '1 minute' AS t FROM work_order`)[0].t;
  if (b.completed_at && b.completed_at < assigned_at)
    throw new AppError("validation_failed", "Completion cannot be before assignment.", [{ field: "completed_at", message: "Before assigned_at" }]);

  const work_order_id = await nextId("work_order", "WO25-N");
  await db.work_order.create({ data: { ...b, assigned_at, work_order_id, ward_code: road.ward_code, source: "intake" } });
  const [work_order] = await db.$queryRaw<any[]>`SELECT * FROM v_work_order WHERE work_order_id = ${work_order_id}`;
  const flags = await db.$queryRaw`SELECT flag_type, tier, amount_at_stake FROM v_flag WHERE work_order_id = ${work_order_id}`;
  res.status(201).json({ work_order, flags });
});

// Lets the demo be reset. Imported rows cannot be deleted.
intake.delete("/work-orders/:id", async (req, res) => {
  const { count } = await db.work_order.deleteMany({ where: { work_order_id: req.params.id, source: "intake", ward_code: req.user.ward_code! } });
  if (!count) throw new AppError("not_found", "No such intake work order in your ward.");
  res.status(204).end();
});

intake.post("/complaints", async (req, res) => {
  const b = parse(z.object({
    description: z.string().trim().min(5).max(1000), category_reported: z.string().max(80),
    locality_text: z.string().trim().max(120).optional(), channel: z.string().max(40).default("Ward Office Walk-in"),
  }), req.body);
  const ward = req.user.ward_code!;
  const roads = await db.road.findMany({ where: { ward_code: ward } });
  // Place it: a road named in the text, else the road nearest the named locality, else no road.
  const place = b.locality_text
    ? (await db.$queryRaw<{ lat: number; lon: number }[]>`
        SELECT lat, lon FROM locality WHERE ward_code = ${ward}
          AND (${b.locality_text} ILIKE '%' || locality || '%' OR locality ILIKE '%' || ${b.locality_text} || '%' OR aliases ILIKE '%' || ${b.locality_text} || '%') LIMIT 1`)[0]
    : undefined;
  const named = mentionedRoad(`${b.description} ${b.locality_text ?? ""}`, [...new Set(roads.map((r) => r.road_name))].sort((x, y) => y.length - x.length));
  const candidates = named ? roads.filter((r) => r.road_name === named) : place ? roads : [];
  const road = candidates.length ? (place ? nearestRoad(place.lat, place.lon, candidates)!.road : candidates[0]) : null;
  const category = cleanCategory(b.category_reported);
  const severity = SEVERITY[category];

  const complaint_id = await nextId("complaint", "BMC25-N");
  const result = await db.$transaction(async (tx) => {
    // "Now" is the data's own latest moment, so a 2025 dataset does not gain a year of days-open.
    const [{ t }] = await tx.$queryRaw<{ t: Date }[]>`SELECT MAX(received_at) + interval '1 minute' AS t FROM complaint`;
    const complaint = await tx.complaint.create({
      data: { complaint_id, received_at: t, channel: b.channel, category_reported: b.category_reported, description: b.description,
        locality_text: b.locality_text, ward_code: ward, status: "Open", source: "intake" },
      omit: { complainant_id: true },
    });
    const open = road ? await tx.issue.findFirst({ where: { state: "open", road_id: road.road_id, category } }) : null;
    const issue = open
      ? await tx.issue.update({ where: { issue_id: open.issue_id }, data: { complaint_count: { increment: 1 }, last_reported_at: t, severity: Math.max(open.severity, severity) } })
      : await tx.issue.create({ data: { ward_code: ward, road_id: road?.road_id, category, severity, first_reported_at: t, last_reported_at: t, complaint_count: 1, state: "open" } });
    await tx.complaint_enriched.create({
      data: { complaint_id, category_clean: category, severity, text_en: b.description, road_name_mentioned: named, ward_code_resolved: ward,
        road_id_resolved: road?.road_id, lat_resolved: place?.lat, lon_resolved: place?.lon, location_source: road || place ? "locality" : "none", issue_id: issue.issue_id },
    });
    return { complaint, issue, joined_existing: !!open };
  });
  const [plan] = await db.$queryRaw<any[]>`SELECT rank, risk_score FROM v_plan WHERE issue_id = ${result.issue.issue_id}`;
  res.status(201).json({ ...result, road: road && { road_id: road.road_id, road_name: road.road_name, segment_no: road.segment_no }, plan: plan ?? null });
});
