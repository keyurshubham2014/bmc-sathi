# Whose delay was it: design

**Date:** 2026-11-21 · **Size:** small change, backend only · **Brief:** `docs/ideas/2026-11-21-sathi-next-features.md` (feature B)

## Intent

The contractor speed band today compares on-time rates that differ mainly because jobs reach contractors late. All eight contractors take 41 to 44 hours once assigned and are on time 89 to 93% when enough time was left; the wait before assignment runs from 22 to 76 hours. The scorecard should say whose delay it was, with the work orders behind it.

## Goals

- A speed figure for contractors and wards that counts only jobs assigned with enough time left.
- The wait before assignment as its own measure, banded for wards.
- A plain statement when a work type's target is shorter than the work typically takes.

## Non-goals

- No screen changes. Screens are being redone on `design-overhaul` by another session and will read the new data later.
- No change to the existing `speed`, `durability` or `cost` rows, or to any flag.
- Summaries are not re-run.

## Anti-goals

- No ranking or ordering of contractors or wards by any of the new figures.
- No blame wording. The data says when a job was assigned, not why it was late.

## Constraints

- Work happens in a separate git worktree on a new branch from `main`. Nothing is committed to `main`, `design-overhaul` or `ui-refresh`.
- The loaded `sathi` database is shared with the running app and the other session. Development and tests use a restored copy (`sathi_b`, made with the dump and restore steps in the README), so the shared views do not change until Keyur says so. *My call.*
- `npm run db:verify` and `npm test` must pass on the copy, with their expected counts updated.

## Approaches

| Approach | Trade-off | Outcome |
|---|---|---|
| New measures beside the old one | Additive; nothing breaks; the old band stays on current screens until they switch | **Chosen by Keyur** |
| Replace `speed` in place | Fixed everywhere at once, but current screens would show the new figure under the old label | Rejected |
| Extra columns on the existing rows | Fewer rows, but every reader of the view changes | Rejected |

## Design

**Setting.** `fair_chance_pct`, default 0.5: the percentile of assigned-to-done hours, per work type, that the time left at assignment must cover. Seeded in `prisma/seed.ts`; editable through the existing settings route. *Decided: median, as a setting.*

**View `v_work_order_delay`** (new, one row per work order with a linked complaint):
`first_complaint_at`, `hours_to_assign` (first complaint to assignment), `hours_to_do` (assignment to done), `typical_hours` (the `fair_chance_pct` percentile of `hours_to_do` for that work type), `fair_chance` (target hours minus `hours_to_assign` is at least `typical_hours`), and `miss_cause` for missed jobs: `expired_before_assignment`, `too_little_time_left` or `had_time`. Work orders with no linked complaint have no start of clock and are left out.

**`v_scorecard` gains two measures** for every contractor and ward, using the same "similar jobs" groups as today (work type, method, rain band, ward type, the subject's own jobs left out):

| Measure | observed | expected | n | band |
|---|---|---|---|---|
| `speed_fair` | share on time among `fair_chance` jobs | same share for similar jobs | fair-chance jobs | existing `band()`; `too_few` under `band_min_jobs` |
| `assign_wait` | average `hours_to_assign` | average for similar jobs | jobs with a complaint | wards: banded, fewer hours is better. Contractors: `context`, never a band, because contractors do not assign their own jobs |

Result: 5 rows per subject, so 40 contractor rows and 120 ward rows.

**Unreachable targets.** `scorecard()` returns `unreachable_targets`: for the subject's jobs, each work type and target where the target is shorter than `typical_hours`, with the target, the typical hours and the job count. *My call on the shape.*

**Work orders behind the figures.** `listWorkOrders` gains filters `fair_chance` and `miss_cause=<value>`, so each new figure opens its rows like the existing ones.

**Summary prompt.** `pipeline/summarise.ts` learns the two measures in one sentence each. Existing summaries become stale through the existing facts hash and are not re-run. *Decided.*

**Checks.** `db:verify`: contractor scorecard rows go from 24 to 40 and ward rows from 72 to 120; plus a check that the three miss causes add up to the missed jobs with a complaint (1,235 on imported data: 441, 690, 104). `api.test.ts`: the ward measure list becomes five names; new tests pin that CT03's `speed_fair` band is `similar`, that a contractor's `assign_wait` band is `context`, and that Ward L's `assign_wait` is banded below similar jobs.

## Left to the builder

- The test statistic for the `assign_wait` band (a mean of hours, not a share). Any standard choice that respects `band_z`, `band_z_strong` and `band_min_jobs`.
- Whether `v_work_order_delay` is read by `v_scorecard` directly or through `v_work_order`.
