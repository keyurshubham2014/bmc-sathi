// Fills complaint_enriched for complaints that do not have a row yet, so an interrupted run resumes.
// Rules-only for now: category from what the citizen picked, a default severity per category, and
// the road name if the description mentions one. Claude mode (translation, corrected category,
// severity read from the text) plugs in here once ANTHROPIC_API_KEY is set.
import { db } from "../lib/db";
import { cleanCategory, mentionedRoad, SEVERITY } from "../lib/rules";

if (process.env.ANTHROPIC_API_KEY && !process.argv.includes("--no-claude"))
  console.log("note: Claude mode is not wired in yet; running rules-only.");
const roadNames = [...new Set((await db.road.findMany({ select: { road_name: true } })).map((r) => r.road_name))]
  .sort((a, b) => b.length - a.length);
const todo = await db.complaint.findMany({
  where: { enriched: null },
  select: { complaint_id: true, category_reported: true, description: true },
});
const rows = todo.map((c) => {
  const category_clean = cleanCategory(c.category_reported);
  return {
    complaint_id: c.complaint_id, category_clean, severity: SEVERITY[category_clean],
    text_en: c.description, road_name_mentioned: mentionedRoad(c.description, roadNames),
  };
});
for (let i = 0; i < rows.length; i += 1000) await db.complaint_enriched.createMany({ data: rows.slice(i, i + 1000) });
console.log(`enriched ${rows.length} complaints (rules-only)`);
await db.$disconnect();
