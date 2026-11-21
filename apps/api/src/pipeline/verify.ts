// Checks that the loaded database reproduces the reference figures from the supplied data.
// Exits non-zero on any mismatch. Run after load and after any change to a view.
// Counts only imported rows, so demo records added through intake do not fail it.
import { db } from "../lib/db";

const failures: string[] = [];
function check(name: string, actual: number, expected: number, tolerance = 0) {
  const ok = Math.abs(actual - expected) <= tolerance;
  console.log(`${ok ? "ok  " : "FAIL"} ${name}: ${actual}${ok ? "" : ` (expected ${expected})`}`);
  if (!ok) failures.push(name);
}
const one = async (sql: string) => Number(((await db.$queryRawUnsafe(sql)) as any[])[0].n);

const imported = `work_order_id IN (SELECT work_order_id FROM work_order WHERE source = 'import')`;

check("wards", await one(`SELECT COUNT(*) n FROM ward`), 24);
check("contractors", await one(`SELECT COUNT(*) n FROM contractor`), 8);
check("roads", await one(`SELECT COUNT(*) n FROM road`), 291);
check("complaints", await one(`SELECT COUNT(*) n FROM complaint WHERE source = 'import'`), 6501);
check("work orders", await one(`SELECT COUNT(*) n FROM work_order WHERE source = 'import'`), 2499);
check("work orders with no rate", await one(`SELECT COUNT(*) n FROM v_work_order WHERE expected_cost IS NULL`), 0);
check("city spend (rupees)", await one(`SELECT SUM(cost_inr) n FROM work_order WHERE source = 'import'`), 134_300_000, 100_000);
check("flags: overbilled", await one(`SELECT COUNT(*) n FROM v_flag WHERE flag_type='overbilled' AND tier='flag' AND ${imported}`), 109);
check("flags: watch", await one(`SELECT COUNT(*) n FROM v_flag WHERE tier='watch' AND ${imported}`), 5);
check("flags: duplicate", await one(`SELECT COUNT(*) n FROM v_flag WHERE flag_type='duplicate' AND ${imported}`), 45);
check("flags: dlp", await one(`SELECT COUNT(*) n FROM v_flag WHERE flag_type='dlp' AND ${imported}`), 493);
check("overbilled at or below 1.5x", await one(`SELECT COUNT(*) n FROM v_flag WHERE flag_type='overbilled' AND tier='flag' AND (evidence->>'ratio')::numeric <= 1.5`), 0);
check("duplicates that have a complaint", await one(`SELECT COUNT(*) n FROM v_flag f JOIN work_order_complaint l USING (work_order_id) WHERE f.flag_type='duplicate'`), 0);
check("unlinked work orders not flagged duplicate", await one(`SELECT COUNT(*) n FROM v_work_order w WHERE NOT has_complaint AND source='import' AND NOT EXISTS (SELECT 1 FROM v_flag f WHERE f.flag_type='duplicate' AND f.work_order_id = w.work_order_id)`), 0);
check("ward money rows", await one(`SELECT COUNT(*) n FROM v_ward_money`), 24);
check("ward spend adds up to city spend", await one(`SELECT (SELECT SUM(spend) FROM v_ward_money) - (SELECT SUM(cost_inr) FROM work_order) n`), 0);
// Reference value holds only while no intake rows exist.
if ((await one(`SELECT COUNT(*) n FROM work_order WHERE source <> 'import'`)) === 0)
{
  check("wards over budget", await one(`SELECT COUNT(*) n FROM v_ward_money WHERE spend_share > 1`), 6);
  check("delay rows = work orders with a complaint", await one(`SELECT COUNT(*) n FROM v_work_order_delay`), 2454);
  check("misses: expired before assignment", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE miss_cause='expired_before_assignment'`), 441);
  check("misses: too little time left", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE miss_cause='too_little_time_left'`), 700);
  check("misses: had time", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE miss_cause='had_time'`), 94);
}
check("ward recoverable rows", await one(`SELECT COUNT(*) n FROM v_ward_recoverable`), 24);
check("recoverable shares that do not add up", await one(`SELECT COUNT(*) n FROM v_ward_recoverable WHERE confirmed_total <> confirmed_billing + confirmed_dlp OR possible_total <> possible_billing + possible_dlp`), 0);
check("funded items that recovery would unfund", await one(`SELECT COUNT(*) n FROM v_plan WHERE within_budget AND NOT (within_recovered AND within_possible)`), 0);
// Reference values hold only while nothing has been added or decided.
if ((await one(`SELECT (SELECT COUNT(*) FROM work_order WHERE source <> 'import') + (SELECT COUNT(*) FROM flag_decision) n`)) === 0) {
  check("recoverable if every flag were confirmed (rupees)", await one(`SELECT SUM(possible_total) n FROM v_ward_recoverable`), 33_467_546);
  check("recoverable already confirmed", await one(`SELECT SUM(confirmed_total) n FROM v_ward_recoverable`), 0);
  check("plan items funded if every flag were recovered", await one(`SELECT COUNT(*) n FROM v_plan WHERE within_possible`), 640);
}
check("missed jobs with no cause", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE NOT sla_met AND miss_cause IS NULL`), 0);
check("negative waits", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE hours_to_assign < 0`), 0);
check("delay rows without a complaint", await one(`SELECT COUNT(*) n FROM v_work_order_delay d WHERE NOT EXISTS (SELECT 1 FROM work_order_complaint l WHERE l.work_order_id = d.work_order_id)`), 0);

// After enrich and group have run.
if ((await one(`SELECT COUNT(*) n FROM issue`)) > 0) {
  check("complaints with no enrichment", await one(`SELECT COUNT(*) n FROM complaint c WHERE NOT EXISTS (SELECT 1 FROM complaint_enriched e WHERE e.complaint_id = c.complaint_id)`), 0);
  check("open complaints not in an issue", await one(`SELECT COUNT(*) n FROM complaint c JOIN complaint_enriched e USING (complaint_id) WHERE c.status IN ('Open','In Progress') AND e.issue_id IS NULL AND e.ward_code_resolved IS NOT NULL`), 0);
  check("complaints still without a ward", await one(`SELECT COUNT(*) n FROM complaint_enriched WHERE ward_code_resolved IS NULL AND location_source <> 'none'`), 0);
  check("contractor scorecard rows", await one(`SELECT COUNT(*) n FROM v_scorecard WHERE subject_type = 'contractor'`), 40);
  check("ward scorecard rows", await one(`SELECT COUNT(*) n FROM v_scorecard WHERE subject_type = 'ward'`), 120);
  check("wards with a plan", await one(`SELECT COUNT(DISTINCT ward_code) n FROM v_plan`), 24);
  check("plan rows with no method", await one(`SELECT COUNT(*) n FROM v_plan WHERE recommended_method IS NULL OR estimated_cost IS NULL`), 0);
}

await db.$disconnect();
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed: ${failures.join("; ")}`);
  process.exit(1);
}
console.log("\nall checks passed");
