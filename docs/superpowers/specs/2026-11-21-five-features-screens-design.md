# Screens for the five features: design

**Date:** 2026-11-21 · **Size:** a project (three screens, two languages) · **Data:** `docs/api-new-fields.md`

## Intent

The five features exist in the API and nowhere on screen. Put each figure where a reader already looks for that subject, using only components of the Works design in `design/`.

## Goals

- Scorecards say whose time a late job used, and what failed fixes cost again.
- The plan shows what flagged money would fund, without moving the real budget line.
- A decided flag offers a draft letter.

## Non-goals

- No new navigation items, routes or charts. No new shared components unless an existing one cannot carry the content.
- No change to how existing figures look or read.

## Anti-goals (from `design/DESIGN.md` and the feature designs)

- No ranking, grade or ordering of contractors. A band below similar jobs is never red.
- No blame wording: "waited before it was assigned", never "ward office delay"; "followed by another job", never "redone by".
- Recoverable money is never added to the remaining-budget figure.
- Amber stays for unreviewed flags, red for overspend or confirmed problems only.

## Approaches

| Approach | Trade-off | Outcome |
|---|---|---|
| Add rows and lines to the existing cards and list | Smallest change; reads in place; no new layout to test | **Chosen** |
| New "Delays" and "Recovery" tabs on the ward page | Room to breathe, but hides the figures from where the misleading ones sit | Rejected |
| A separate card per new measure | Clear, but five cards in a row does not fit laptop width | Rejected for contractors; one extra card kept for wards |

## Design

**Backend addition.** `scorecard()` returns `late: { expired_before_assignment, too_little_time_left, had_time }`, counts of the subject's missed jobs by cause, so the screen needs no extra requests.

**Speed card** (contractor and ward). *Decided: fair figure on top.*
- Band chip and headline come from `speed_fair`: "92% on time", unit line "when there was enough time left", "of 113 jobs", compare bars against similar jobs. `too_few` behaves as today.
- Below the bars: "All jobs: 39% on time · 118 of 303", opening the late jobs list as today.
- "Waited before assignment: 76 h (similar jobs 38 h)". Plain text for a contractor, no chip, no colour.
- "Late jobs, by what happened" with three count rows, each opening its work order list (`expired_before_assignment`, `too_little_time_left`, `had_time`). Rows with a count of 0 are still shown.

**Time to assign card** (ward scorecard only): headline hours from `assign_wait`, band chip, compare bars (ward against similar jobs, scaled to the larger of the two), job count.

**Durability card:** two more count rows: "Spent on fixes that re-opened" (opens `reopened`), and "Followed by another job: N jobs · ₹X" (opens `followed_up`) with a grey line "M of those went to another contractor".

**Targets note** (below the measures, when `unreachable_targets` is not empty): a panel "Targets shorter than the work takes", one row per work type and target: "Open or broken manhole · target 24 h · typically 82 h once assigned · 13 jobs".

**Plan.** *Decided: two lines.*
- A strip above the list: "In flags for this ward: ₹45.3 L possible (DLP ₹39.6 L · billing ₹5.7 L) · ₹0 confirmed". Hidden when both totals are 0.
- The existing budget line is untouched.
- A second `BudgetLine`, "If confirmed flags are recovered", after the last item with `within_recovered`, shown only when `confirmed_total > 0` and it would sit below the real line.
- A third, "If every open flag were recovered", after the last item with `within_possible`, shown when `possible_total > 0` and it would sit below the previous line. If every item is within it, it goes at the end of the list.
- Each plan card with `road_jobs > 1`: "35 jobs on this road this season · ₹30.5 L so far".

**Flag detail.** When the flag's decision is `confirmed` or `needs_explanation`: an outlined "Draft a letter" button. It posts to `/flags/draft` (DLP: the work order's `road_id`; otherwise the flag's `contractor_id` and `ward_code`; `lang` from the app's language) and shows the result in the detail panel: the body as selectable plain text, a Copy button, and one grey line: "Written by Claude from the evidence" or "Standard template" plus, when Marathi was asked for and English came back, "Marathi is unavailable just now". A failed request shows the existing error line.

**Strings.** Every label in English and Marathi in `core/strings.dart`. The Marathi is written by the builder and has not been read by a Marathi speaker; it is marked for review in the commit message.

**Tests.** API: the `late` counts add up to missed jobs with a complaint. Web: the positions of the two new plan lines are a pure function with a test (confirmed nothing; line below the real one; all items funded; overspent ward); existing tests keep passing; `flutter analyze` clean.

## Left to the builder

- Exact Dart structure, and whether the new rows share a helper.
- Wording within the anti-goals.
