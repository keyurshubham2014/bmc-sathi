import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, parse } from "../lib/errors";
import { requireRole } from "../middleware/auth";

export const settings = Router().use(requireRole("auditor"));

const WEIGHTS = ["w_severity", "w_access", "w_safety", "w_traffic", "w_flood", "w_demand"];

settings.get("/", async (_req, res) => res.json({ items: await db.setting.findMany({ orderBy: { key: "asc" } }) }));

/** Saves one or more settings together, so the six risk weights can change and still total 100. */
settings.put("/", async (req, res) => {
  const { values } = parse(z.object({ values: z.record(z.string(), z.number().min(0).max(1000)) }), req.body);
  const current = Object.fromEntries((await db.setting.findMany()).map((s) => [s.key, s.value]));
  const unknown = Object.keys(values).filter((k) => !(k in current));
  if (unknown.length) throw new AppError("validation_failed", `Unknown setting: ${unknown.join(", ")}`);
  const next = { ...current, ...values };
  const total = WEIGHTS.reduce((s, k) => s + next[k], 0);
  if (Math.abs(total - 100) > 0.001)
    throw new AppError("validation_failed", `The six risk weights must total 100. They total ${total}.`, [{ field: "weights", message: `Total is ${total}` }]);
  if (next.overbill_watch_ratio >= next.overbill_ratio)
    throw new AppError("validation_failed", "The watch line must be below the flag line.", [{ field: "overbill_watch_ratio", message: "Must be below overbill_ratio" }]);
  await db.$transaction(Object.entries(values).map(([key, value]) => db.setting.update({ where: { key }, data: { value } })));
  res.json({ items: await db.setting.findMany({ orderBy: { key: "asc" } }) });
});
