# Recover and reinvest, Redo bill, Repeat spend: design

**Date:** 2026-11-21 · **Size:** small change, backend only · **Brief:** `docs/ideas/2026-11-21-sathi-next-features.md` (features A, C, D)

## Intent

Three figures the data supports and no screen shows: how far flagged money would fund a ward's plan, what failed fixes cost a second time, and how often the same road is patched. Each must open the work orders behind it.

## Goals

- **A.** The plan data says, per ward and per item, what recovered money would fund, without changing the real budget line.
- **C.** A scorecard carries rupees spent on fixes that re-opened and rupees spent on the jobs that followed them.
- **D.** Each plan item carries how many jobs its road has had this season and what they cost.

## Non-goals

- No screen changes (screens are being redone on `design-overhaul`).
- No moving budget between wards. Recovery counts only in the ward where the flag is.
- No savings claim for D. The rate card has no resurfacing price.
- No contractor suggestion in the plan.

## Anti-goals

- Recoverable money never appears as available money. `remaining` and `within_budget` keep their meaning and values.
- No ranking or ordering of contractors by redo cost.
- "Followed by another job", never "redone by": the follow-up is inferred from road, work type and date.

## Constraints

- Same worktree (`.worktrees/whose-delay`, branch `whose-delay`) and database copy (`sathi_b`) as feature B. Nothing is merged and the live `sathi` database is not touched.
- Existing columns of `v_plan`, `v_ward_money` and `v_scorecard` keep their names and values. `db:verify` and all 38 API tests keep passing.

## Approaches

| Approach | Trade-off | Outcome |
|---|---|---|
| New columns and one small view per feature, returned by the existing plan and scorecard routes | Additive; no new routes; screens pick fields up when ready | **Chosen.** It is how B was built and Keyur asked for the three together. |
| New routes per feature (`/recoverable`, `/redo`) | Cleaner separation, but three more calls per screen and more tests | Rejected |
| Compute in the API in TypeScript | Easier arithmetic, but rules would leave `views.sql`, where every other rule lives | Rejected |

## Design

### A. Recover and reinvest

**View `v_ward_recoverable`** (one row per ward). A flagged work order counts once, at its largest amount at stake, under the flag type that carries that amount (the convention `v_ward_money` already uses). Watch items never count.

| Column | Meaning |
|---|---|
| `confirmed_billing`, `confirmed_dlp`, `confirmed_total` | Flags with decision `confirmed` |
| `possible_billing`, `possible_dlp`, `possible_total` | Flags with decision `open` or `needs_explanation` |

Flags decided `not_an_issue` count nowhere. *Decided: confirmed moves the line, open shown as possible, DLP as its own share.*

**`v_plan` gains two columns per item:**
- `within_recovered`: `cumulative_cost <= ward_remaining + confirmed_total`
- `within_possible`: `cumulative_cost <= ward_remaining + confirmed_total + possible_total`

Recovered money pays off any overspend first, because `ward_remaining` is negative for an overspent ward. *My call: it is the honest arithmetic.* On today's data that funds 640 of 660 open issues if everything were recovered (the brief said 646, which ignored overspend), and 417 on billing flags alone. Ward L goes from 0 of 54 to 54; Ward E from 0 of 26 to 26.

**`GET /wards/:code/plan`** returns the two columns on each item and a `recoverable` object holding the ward's row. Citizens get the totals and shares but no per-flag rows, which matches what `/flags/summary` already gives them.

### C. Redo bill

**View `v_followup`** (one row per re-opened work order): `work_order_id`, `contractor_id`, `ward_code`, `cost_inr`, and the first later job on the same road and work type assigned within 30 days of its completion: `followup_work_order_id`, `followup_cost`, `followup_contractor_id`, all null when there is none. The 30 days matches `reopened_within_30d` and is not a setting.

**`scorecard()` returns `redo`:** `reopened_jobs`, `reopened_spend`, `followup_jobs`, `followup_spend` (each follow-up job counted once even if it follows two failed jobs), `followup_by_other` (follow-ups done by a different contractor; for a ward scorecard, always the count where the contractor changed). *Decided: rupees on the scorecard only.* Ward scorecards get the same object because `scorecard()` is shared. *My call.*

**Work order filter `followed_up`:** re-opened jobs that have a follow-up. The existing `reopened` filter covers the first figure.

### D. Repeat spend

**`v_plan` gains two columns per item:** `road_jobs` (work orders on that road this season, all work types) and `road_spend` (their total cost). Both 0 when the issue has no road. The plan route returns them. *Decided: one line on plan items; wording is the screen's job.*

### Checks

- `db:verify`: 24 rows in `v_ward_recoverable`; with no decisions recorded and no intake rows, city `possible_total` is 33,467,546 and `confirmed_total` is 0; plan items within possible budget 640; `v_followup` has 611 rows, 336 with a follow-up.
- API tests: confirming one flag in Ward E raises `recoverable.confirmed_total` by that flag's amount and lowers `possible_total` by the same, then is undone; `within_budget` values do not change; a plan item's `road_jobs` equals the work order count for its road; CT04's `redo.reopened_jobs` is 116 and its `followed_up` filter total equals `redo.followup_jobs` counted per failed job.

## Left to the builder

- Whether `followup_jobs` counts failed jobs with a follow-up or distinct follow-up jobs: return both if they differ, named `followed_up_jobs` and `followup_jobs`.
- Index or query shape for the follow-up lookup, as long as the plan route stays under a second.
