# Recover, Redo, Repeat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add to the plan and scorecard data: what recovered flag money would fund, what failed fixes cost a second time, and how often each road is patched.

**Architecture:** Two new SQL views (`v_ward_recoverable`, `v_followup`) and four new columns at the end of `v_plan`. The existing plan and scorecard routes return the new fields; the work order list gains one filter.

**Tech Stack:** PostgreSQL 17 views, Node 20, Express 5, TypeScript, Zod, Prisma raw queries, vitest + supertest.

**Spec:** `docs/superpowers/specs/2026-11-21-recover-redo-repeat-design.md`

## Global Constraints

- Worktree `.worktrees/whose-delay`, branch `whose-delay`, database copy `sathi_b`. Never commit to `main`, `design-overhaul` or `ui-refresh`; never write to the `sathi` database.
- Backend only. No file under `apps/web/` changes.
- Existing columns of `v_plan`, `v_ward_money` and `v_scorecard` keep their names and values; new `v_plan` columns go at the end. `remaining` and `within_budget` are untouched.
- New views are added to the `DROP VIEW` line and created after the views they read.
- No ranking or ordering by any new figure. No Claude calls.
- Each task ends with `npx tsc --noEmit && npm run db:views && npm run db:verify && npm test` in `apps/api`, then a commit.

## Review Focus

1. **A work order with both a DLP flag and a billing flag** counts once in `v_ward_recoverable`, at the larger amount, under that amount's type. Pinned in Task 1.
2. **A flag decided `not_an_issue`** counts in neither confirmed nor possible; `needs_explanation` counts as possible. Pinned in Task 1.
3. **A ward with no flags at all** still has a `v_ward_recoverable` row of zeros, so the plan route never returns a null `recoverable`. Pinned in Task 1.
4. **An issue with no road** gets `road_jobs = 0` and `road_spend = 0`, not null. Pinned in Task 2.
5. **One follow-up job that follows two failed jobs** is counted once in `followup_spend`. Pinned in Task 3.

---

### Task 1: Recover and reinvest (A)

**Files:** Modify `apps/api/prisma/views.sql`, `apps/api/src/modules/wards.ts` (plan route), `apps/api/src/pipeline/verify.ts`. Test: `apps/api/test/api.test.ts`.

**Interfaces:**
- Produces view `v_ward_recoverable(ward_code, confirmed_billing, confirmed_dlp, confirmed_total, possible_billing, possible_dlp, possible_total)`, all bigint, one row per ward, zeros when none. Per work order: largest `amount_at_stake` among its `tier = 'flag'` rows, typed `dlp` when that row's `flag_type` is `dlp`, else `billing`. Bucket by that row's decision: `confirmed` → confirmed; `open` or `needs_explanation` → possible; `not_an_issue` → none. If a work order's flags carry different decisions, each flag is bucketed by its own decision before taking the largest per bucket.
- Produces on `v_plan`: `within_recovered` (bool) and `within_possible` (bool) as the spec defines.
- Produces on `GET /wards/:code/plan`: the two columns on each item, and `recoverable` (the ward's row).

- [ ] **Step 1: Write failing checks** in `verify.ts`: `v_ward_recoverable` has 24 rows; inside a guard for "no intake rows and no flag decisions": sum of `possible_total` is 33467546, sum of `confirmed_total` is 0, plan rows with `within_possible` is 640. Always: zero rows where `confirmed_total <> confirmed_billing + confirmed_dlp` or `possible_total <> possible_billing + possible_dlp`; zero plan rows where `within_budget AND NOT within_recovered` in wards with `ward_remaining >= 0`.
- [ ] **Step 2: Write failing tests:**

```ts
it("moves recoverable money from possible to confirmed when a flag is confirmed", async () => {
  const plan = async () => (await api().get("/api/v1/wards/E/plan").set(as("auditor"))).body;
  const before = await plan();
  const flag = (await api().get("/api/v1/flags?type=overbilled&ward=E&decision=open&limit=1").set(as("auditor"))).body.items[0];
  // use the query names the existing flag tests use
  await api().put(`/api/v1/flags/overbilled/${flag.work_order_id}/decision`).set(as("auditor")).send({ decision: "confirmed" });
  try {
    const after = await plan();
    const moved = after.recoverable.confirmed_total - before.recoverable.confirmed_total;
    expect(moved).toBeGreaterThan(0);
    expect(before.recoverable.possible_total - after.recoverable.possible_total).toBe(moved);
    expect(after.items.map((i: any) => i.within_budget)).toEqual(before.items.map((i: any) => i.within_budget));
    expect(after.ward.remaining).toBe(before.ward.remaining);
  } finally {
    await db.flag_decision.deleteMany({ where: { flag_type: "overbilled", work_order_id: flag.work_order_id } });
  }
});
it("does not count a dismissed flag as recoverable", async () => { /* same shape with decision "not_an_issue": possible_total drops, confirmed_total unchanged */ });
it("gives every ward a recoverable row and the citizen only totals", async () => {
  const r = (await api().get("/api/v1/wards/E/plan").set(as("citizen"))).body;
  expect(Object.keys(r.recoverable).sort()).toEqual(["confirmed_billing", "confirmed_dlp", "confirmed_total", "possible_billing", "possible_dlp", "possible_total", "ward_code"]);
});
```

- [ ] **Step 3:** Run `npm run db:verify` and `npm test`; expect failures on the missing view and fields.
- [ ] **Step 4:** Implement the view, the two `v_plan` columns and the route fields.
- [ ] **Step 5:** Full check from Global Constraints. Commit `feat(api): recoverable flag money against the ward plan`.

### Task 2: Repeat spend (D)

**Files:** Modify `apps/api/prisma/views.sql` (`v_plan`), `apps/api/src/modules/wards.ts` (plan route). Test: `apps/api/test/api.test.ts`.

**Interfaces:** Produces on `v_plan` and the plan route: `road_jobs` (int) and `road_spend` (bigint): count and total cost of all work orders on the item's `road_id`; 0 when `road_id` is null.

- [ ] **Step 1: Write the failing test:** for Ward L's plan, take the first item with a `road_id`; `road_jobs` equals `total` and `road_spend` equals `total_cost` from `GET /wards/L/work-orders` narrowed to that road by a direct `db.work_order.aggregate` on `road_id`. Also: every item has non-null `road_jobs` and `road_spend`.
- [ ] **Step 2:** Run; expect `undefined`.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Full check. Commit `feat(api): jobs and spend on a plan item's road this season`.

### Task 3: Redo bill (C)

**Files:** Modify `apps/api/prisma/views.sql`, `apps/api/src/modules/contractors.ts` (`scorecard()`), `apps/api/src/modules/wards.ts` (`workOrderQuery`, `listWorkOrders`), `apps/api/src/pipeline/verify.ts`. Test: `apps/api/test/api.test.ts`.

**Interfaces:**
- Produces view `v_followup(work_order_id, contractor_id, ward_code, cost_inr, followup_work_order_id, followup_cost, followup_contractor_id)`: one row per work order with `reopened_within_30d`; the follow-up is the earliest work order on the same `road_id` and `work_type` with `assigned_at` after this job's `completed_at` and within 30 days of it; nulls when none.
- Produces on `scorecard()`: `redo: { reopened_jobs, reopened_spend, followed_up_jobs, followup_jobs, followup_spend, followup_by_other }`. `followed_up_jobs` counts failed jobs with a follow-up; `followup_jobs` and `followup_spend` count each distinct follow-up job once; `followup_by_other` counts failed jobs whose follow-up went to a different contractor.
- Produces filter value `followed_up` on `workOrderQuery.filter`.

- [ ] **Step 1: Write failing checks** in `verify.ts` (inside the no-intake guard): `v_followup` rows 611; rows with a follow-up 336.
- [ ] **Step 2: Write failing tests:**

```ts
it("counts what failed fixes cost a second time", async () => {
  const s = (await api().get("/api/v1/contractors/CT04").set(as("citizen"))).body.scorecard;
  expect(s.redo.reopened_jobs).toBe(116);
  expect(s.redo.followed_up_jobs).toBe(70);
  expect(s.redo.followup_jobs).toBeLessThanOrEqual(s.redo.followed_up_jobs);
  expect(s.redo.followup_by_other).toBeLessThanOrEqual(s.redo.followed_up_jobs);
  const jobs = await api().get("/api/v1/contractors/CT04/work-orders?filter=followed_up&limit=1").set(as("citizen"));
  expect(jobs.body.total).toBe(s.redo.followed_up_jobs);
  const reopened = await api().get("/api/v1/contractors/CT04/work-orders?filter=reopened&limit=1").set(as("citizen"));
  expect(Number(reopened.body.total_cost)).toBe(Number(s.redo.reopened_spend));
});
it("counts a follow-up job once even when it follows two failed jobs", async () => {
  const [row] = await db.$queryRaw<any[]>`SELECT COUNT(followup_work_order_id)::int AS links, COUNT(DISTINCT followup_work_order_id)::int AS jobs FROM v_followup WHERE ward_code = 'L'`;
  const s = (await api().get("/api/v1/wards/L/scorecard").set(as("citizen"))).body.scorecard;
  expect(s.redo.followed_up_jobs).toBe(row.links);
  expect(s.redo.followup_jobs).toBe(row.jobs);
});
```

- [ ] **Step 3:** Run; expect failures.
- [ ] **Step 4:** Implement.
- [ ] **Step 5:** Full check. Commit `feat(api): cost of re-opened fixes and the jobs that followed them`.
