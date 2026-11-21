# Whose Delay Was It Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every contractor and ward scorecard a speed figure that counts only jobs assigned with enough time left, the wait before assignment as its own measure, and a list of targets shorter than the work takes.

**Architecture:** One new SQL view (`v_work_order_delay`) splits each job's clock into time before and after assignment. `v_scorecard` gains two measures built on it. The API passes them through its existing keyed `measures` object; the work order list gains two filters.

**Tech Stack:** PostgreSQL 17 views, Node 20, Express 5, TypeScript, Zod, Prisma raw queries, vitest + supertest.

**Spec:** `docs/superpowers/specs/2026-11-21-whose-delay-design.md`

## Global Constraints

- Work in a new git worktree `.worktrees/whose-delay` on branch `whose-delay`, created from `main`. Never commit to `main`, `design-overhaul` or `ui-refresh`. Do not touch the main folder's checked-out branch.
- Backend only. No file under `apps/web/` changes.
- Database: a copy named `sathi_b` in the `bmc-sathi-db` container, restored from a dump of `sathi`. The worktree's `apps/api/.env` is a copy of the main folder's with `sathi_b` at the end of `DATABASE_URL` and `DIRECT_URL`. Never run `db:views`, `db:seed` or tests against `sathi`.
- Existing `speed`, `durability` and `cost` rows of `v_scorecard` keep their values. All existing flag counts in `db:verify` stay as they are.
- No ranking or ordering by the new figures. No blame wording in any string.
- No Claude calls: do not run `db:summarise`, `db:enrich` or `db:social`.
- Each task ends with `npx tsc --noEmit && npm run db:views && npm run db:verify && npm test` in the worktree's `apps/api`, then a commit on `whose-delay`.

## Review Focus

1. **A work order with no linked complaint** (the 45 double-billing jobs, or an intake job) has no start of clock: it must be absent from `v_work_order_delay` and must not turn any scorecard figure into null or an error. Pinned in Task 1.
2. **A job assigned before its first complaint was logged** must count as a wait of 0 hours, not a negative wait. Pinned in Task 1.
3. **A subject with fewer than `band_min_jobs` fair-chance jobs, or none,** gets `speed_fair` band `too_few` and no division error. Pinned in Task 2.
4. **`fair_chance_pct` set outside 0 to 1** through `PUT /settings` must be rejected with 400, because the view would fail on every read. Pinned in Task 1.
5. **Intake rows added during a demo** shift the typical hours slightly: reference counts in `db:verify` for the new view apply only while no intake rows exist, as the existing "wards over budget" check does. Pinned in Task 1.

---

### Task 1: Database copy, delay view and setting

**Files:**
- Modify: `apps/api/prisma/views.sql` (add `v_work_order_delay` to the `DROP VIEW` line and create it after `v_work_order`)
- Modify: `apps/api/prisma/seed.ts` (one setting)
- Modify: `apps/api/src/modules/settings.ts` (range check)
- Modify: `apps/api/src/pipeline/verify.ts`
- Test: `apps/api/test/api.test.ts`

**Interfaces:**
- Produces setting `fair_chance_pct`, default `0.5`, description "Share of similar jobs whose assigned-to-done time must fit in the time left for a job to count as having enough time".
- Produces view `v_work_order_delay` with columns: `work_order_id`, `ward_code`, `contractor_id`, `work_type`, `repair_method`, `rain_band`, `ward_type`, `sla_hours`, `sla_met`, `first_complaint_at`, `hours_to_assign` (float8, never below 0), `hours_to_do` (float8), `typical_hours` (float8: `percentile_cont(cfg('fair_chance_pct'))` of `hours_to_do` within `work_type`), `fair_chance` (bool: `sla_hours - hours_to_assign >= typical_hours`), `miss_cause` (text, null when `sla_met`: `expired_before_assignment` when `hours_to_assign >= sla_hours`, else `too_little_time_left` when not `fair_chance`, else `had_time`). One row per work order that has at least one row in `work_order_complaint`.

- [ ] **Step 1:** Create the worktree and the database copy. Use superpowers:using-git-worktrees for the worktree. Then dump `sathi` and restore into `sathi_b` with the commands in the README's "Database dump and restore" section (database name `sathi_b`), copy `apps/api/.env` from the main folder with both URLs pointing at `sathi_b`, and run `npm install` in the worktree's `apps/api`. Run `npm run db:verify && npm test`; expect `all checks passed` and 31 tests passing before any change.
- [ ] **Step 2: Write the failing checks** in `verify.ts`, inside the existing "no intake rows" guard:

```ts
check("delay rows = work orders with a complaint", await one(`SELECT COUNT(*) n FROM v_work_order_delay`), 2454);
check("misses: expired before assignment", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE miss_cause='expired_before_assignment'`), 441);
check("misses: too little time left", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE miss_cause='too_little_time_left'`), 690);
check("misses: had time", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE miss_cause='had_time'`), 104);
```

and outside the guard:

```ts
check("missed jobs with no cause", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE NOT sla_met AND miss_cause IS NULL`), 0);
check("negative waits", await one(`SELECT COUNT(*) n FROM v_work_order_delay WHERE hours_to_assign < 0`), 0);
check("delay rows without a complaint", await one(`SELECT COUNT(*) n FROM v_work_order_delay d WHERE NOT EXISTS (SELECT 1 FROM work_order_complaint l WHERE l.work_order_id = d.work_order_id)`), 0);
```

- [ ] **Step 3: Write the failing test** in `api.test.ts`:

```ts
it("rejects a fair-chance share outside 0 to 1", async () => {
  const r = await api().put("/api/v1/settings").set(as("auditor")).send({ fair_chance_pct: 1.5 });
  expect(r.status).toBe(400);
});
```

(Match the request body shape the existing settings tests use.)
- [ ] **Step 4:** Run `npm run db:verify`; expect failures naming the new view. Run `npm test`; expect the new test to fail.
- [ ] **Step 5:** Add the setting, the view and the range check. If the reference counts differ by a few because of the boundary (`>=` against `>`), keep the definitions in Interfaces above and correct the expected numbers, noting the change in the commit message.
- [ ] **Step 6:** `npx tsc --noEmit && npm run db:seed && npm run db:views && npm run db:verify && npm test`. Commit `feat(api): delay view splitting each job's clock at assignment`.

### Task 2: Scorecard measures and unreachable targets

**Files:**
- Modify: `apps/api/prisma/views.sql` (`v_scorecard`, `band` helper if needed)
- Modify: `apps/api/src/modules/contractors.ts` (`scorecard()`)
- Modify: `apps/api/src/pipeline/verify.ts`
- Test: `apps/api/test/api.test.ts`

**Interfaces:**
- Consumes: `v_work_order_delay` from Task 1.
- Produces two more `measure` values in `v_scorecard`, same columns as existing rows, same "similar jobs" groups (work type, method, rain band, ward type; subject's own jobs left out; the existing wide fallback):
  - `speed_fair`: `observed` = share with `sla_met` among `fair_chance` jobs; `expected` = that share for similar jobs; `n` = fair-chance jobs; `band` from the existing `band()`.
  - `assign_wait`: `observed` = average `hours_to_assign`; `expected` = average for similar jobs; `n` = jobs in the delay view; `band` for `subject_type = 'ward'` from a z on the difference of means (fewer hours is better, so positive z means better), using `band_z`, `band_z_strong`, `band_min_jobs`; for `subject_type = 'contractor'` the literal `'context'`.
- Produces on `scorecard()`'s return value: `unreachable_targets: { work_type: string; sla_hours: number; typical_hours: number; jobs: number }[]`, one entry per work type and target among the subject's jobs where `sla_hours < typical_hours`, ordered by `work_type`, `sla_hours`. Empty array when none.

- [ ] **Step 1: Write failing tests** in the `scorecards` block; change the existing ward assertion to five names:

```ts
expect(Object.keys(s.measures).sort()).toEqual(["assign_wait", "cost", "durability", "speed", "speed_fair"]);

it("judges speed only on jobs that had enough time", async () => {
  const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
  expect(s.measures.speed.band).toBe("well_below");            // unchanged
  expect(s.measures.speed_fair.band).toBe("similar");
  expect(s.measures.speed_fair.observed).toBeGreaterThan(0.85);
  expect(s.measures.assign_wait.band).toBe("context");
  expect(s.measures.assign_wait.observed).toBeGreaterThan(70);
});
it("holds a ward to its time to assign", async () => {
  const s = (await api().get("/api/v1/wards/L/scorecard").set(as("citizen"))).body.scorecard;
  expect(s.measures.assign_wait.observed).toBeGreaterThan(s.measures.assign_wait.expected);
  expect(["below", "well_below"]).toContain(s.measures.assign_wait.band);
});
it("names targets shorter than the work takes", async () => {
  const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
  const types = s.unreachable_targets.map((t: any) => t.work_type);
  expect(types).toContain("Road cave-in");
  expect(types).toContain("Open or broken manhole");
  expect(types).not.toContain("Broken paver blocks");
  for (const t of s.unreachable_targets) expect(t.sla_hours).toBeLessThan(t.typical_hours);
});
it("shows too few jobs, not a band, for a small ward", async () => {
  const s = (await api().get("/api/v1/wards/C/scorecard").set(as("citizen"))).body.scorecard;
  expect(s.measures.speed_fair.band).toBe("too_few");
});
```

- [ ] **Step 2:** In `verify.ts` change the scorecard row counts to 40 (contractor) and 120 (ward). Run `npm run db:verify && npm test`; expect failures.
- [ ] **Step 3:** Implement the two measures and `unreachable_targets`.
- [ ] **Step 4:** `npx tsc --noEmit && npm run db:views && npm run db:verify && npm test`. Confirm by query that the three original measures are unchanged for CT03 and ward L against `sathi`. Commit `feat(api): fair speed and time-to-assign measures on scorecards`.

### Task 3: Work orders behind the figures, and the summary prompt

**Files:**
- Modify: `apps/api/src/modules/wards.ts` (`workOrderQuery`, `listWorkOrders`)
- Modify: `apps/api/src/pipeline/summarise.ts` (`SYSTEM`)
- Test: `apps/api/test/api.test.ts`

**Interfaces:**
- Consumes: `v_work_order_delay`.
- Produces on `workOrderQuery.filter`: four more values, `fair_chance`, `expired_before_assignment`, `too_little_time_left`, `had_time`. The first lists jobs with `fair_chance`; the others list jobs with that `miss_cause`.

- [ ] **Step 1: Write the failing test:**

```ts
it("opens the jobs behind the fair speed figure", async () => {
  const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
  const fair = await api().get("/api/v1/contractors/CT03/work-orders?filter=fair_chance&limit=1").set(as("citizen"));
  expect(fair.body.total).toBe(s.measures.speed_fair.n);
  const late = await api().get("/api/v1/contractors/CT03/work-orders?filter=had_time&limit=1").set(as("citizen"));
  expect(late.body.total).toBe(Math.round(s.measures.speed_fair.n * (1 - s.measures.speed_fair.observed)));
});
```

- [ ] **Step 2:** Run; expect 400 `validation_failed`.
- [ ] **Step 3:** Implement the filters. Add two sentences to `SYSTEM` after the speed sentence: "The speed_fair figure is the share completed on time among jobs that were assigned with enough time left; prefer it to the speed figure when describing a contractor. The assign_wait figure is the average hours a job waited before it was assigned; it describes the ward office, never the contractor."
- [ ] **Step 4:** `npx tsc --noEmit && npm run db:verify && npm test`. Commit `feat(api): work order filters for delay causes; summary prompt knows the new measures`.
