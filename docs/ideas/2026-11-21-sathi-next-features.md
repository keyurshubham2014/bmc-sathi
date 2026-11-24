# BMC Sathi, five features from the data: brief

**Date:** 2026-11-21 · **Mode:** Refine · **Depth:** Standard
**Verdict:** Go

## In one line
Five additions that say what the data shows and the app does not yet: missed deadlines mostly belong to the ward office, flagged money would fund the backlog, failed fixes are paid for twice, a few roads take half the spend, and a confirmed flag should end in a document someone can send.

## The problem
BMC Sathi already covers all six starter ideas. Read-only queries on the loaded database (2,499 work orders, 6,501 complaints) found five things no screen says. All figures below are evidence from those queries, on synthetic data.

1. **The speed band blames the wrong party.** All eight contractors take 41 to 44 hours on average once a job is assigned, and are on time 89 to 93% when enough time was left. Their on-time rates differ (39% to 62%) because jobs reach them late: Mahalaxmi's jobs waited 76 hours before assignment, Sahyadri's 22. Of 1,235 missed SLAs, 441 had expired before assignment, 690 had less time left than the work typically takes, and 104 had enough time and were still late. Today's scorecard marks Mahalaxmi and Arabian Sea "well below" on speed.
2. **Some targets cannot be met.** Manhole and cave-in targets are 24 to 48 hours; the typical time from assignment to done is 83 to 86 hours. No miss on those work types happened with enough time left.
3. **Audit and plan are not joined.** Flags hold ₹3.48 cr (DLP ₹2.62 cr, over-billing excess ₹0.60 cr, double billing ₹0.26 cr). The 660 open issues cost ₹2.59 cr. Ward budgets fund 332 of them; counting flagged money inside each ward funds 646. Ward L goes from 0 of 54 to 54, Ward E from 0 of 26 to 26.
4. **Failed fixes are paid for twice.** 611 re-opened jobs cost ₹3.07 cr. 336 were followed by another job on the same road and work type within 30 days, costing ₹1.34 cr; only 44 of those went to the same contractor.
5. **Spend is concentrated.** 50 roads with 15 or more jobs took ₹6.41 cr (48%) and hold 239 of the 660 open issues. Kurla Andheri Road: 35 jobs, ₹30.5 L, under DLP.

Checked and found to carry no signal: work outside `active_wards` (about 80% of jobs), timestamp order, ward and road mismatches, stored `sla_met` against a recomputed value (1 mismatch in 2,454), complaints linked to two work orders (none).

## Who it's for
- **Primary:** the hackathon judges, scoring on the five rubric lines.
- **Secondary:** a ward officer or auditor who has to act on a flag.
- **Not for:** moving budget between wards, or ranking contractors. Both stay out, as the PRD says.

## The idea, refined
Came in as "analyse the data and find features that add real value against the rubric". It became five features in three groups. Keyur kept all five.

| | Feature | What it does | Rubric line |
|---|---|---|---|
| B | Whose delay was it | Contractor speed band is based on jobs assigned with enough time left. The raw on-time figure and the average wait before assignment stay visible. Ward scorecards get a new "time to assign" measure. Work types whose target is shorter than the typical work time carry a note saying so. | Fair Accountability |
| A | Recover and reinvest | The plan keeps its real "budget runs out here" line and gains a second "if recovered" line. Confirmed flags move it; open flags appear as an "up to" figure. DLP money is shown as its own share. Recovery stays inside the ward. | Budget Smarts, Audit |
| C | Redo bill | Under durability on the contractor scorecard: rupees spent on fixes that re-opened, and rupees paid for the follow-up jobs, each opening its work orders. | Fair Accountability |
| D | Stop-patching | One line on a plan item: "14th job on this road this season, ₹21 L so far". | Budget Smarts |
| E | Action pack | Once a flag is Confirmed or Needs explanation, a button drafts one document per group: one road for DLP, one contractor in one ward for billing. Claude writes it in English and Marathi from the evidence rows; a fixed template fills in if the call fails. Copy as text. | Usable + Demo |

What changed during the session:
- B started as an extra and became a correction, once the per-contractor numbers showed the current band is misleading.
- C lost its plan integration. It stays on the scorecard.
- D lost any savings claim. The rate card has no resurfacing price.
- E moved from one letter per flag to one per group, since 493 DLP letters are unusable.

## Options considered
| Option | Why considered | Outcome |
|---|---|---|
| Count all open flags as recoverable | Biggest headline from the first screen | Rejected: counts money nobody has reviewed |
| Add recoverable money to remaining budget | One line, simpler screen | Rejected: states unrecovered money as available |
| Leave DLP out of the recoverable figure | DLP flags may exceed the answer key | Rejected: shown as its own share instead |
| Keep today's speed band, add the split as context | Safest against the answer key | Rejected: Mahalaxmi would still read "well below" |
| Leave unreachable-target jobs out quietly | Cleaner numbers | Rejected: hides a finding |
| Use redo cost to suggest contractors in the plan | Strongest budget link | Rejected: a ranking in all but name |
| Ward list or separate screen for repeat-spend roads | More visible | Rejected: one line on plan items is enough |
| Template-only or Claude-only drafts | Less code either way | Rejected: Claude with a template fallback |
| Contractors outside `active_wards` as a flag | Looked like an audit signal | Rejected: about 80% of jobs, so noise |
| Accidents on roads with a pending issue | "Cost of delay" story | Not taken further: busy roads nearly always have a pending issue, so the link is weak |

## Scope
**Build order:** B, A, C, D, E.

1. **B.** A view for the delay split per work order; speed band on the adjusted basis; "time to assign" on ward scorecards; the unreachable-target note. `db:verify` expects 72 ward scorecard rows and will need 96; the API tests change with it.
2. **A.** Recoverable amount per ward in `v_plan` (confirmed, and open as "up to"), split into billing and DLP; second line on the plan screen.
3. **C.** Two rupee figures under durability, with work order lists.
4. **D.** Job count and season spend for the road on each plan item.
5. **E.** One route that groups flags and drafts through `askJson`, plus the template fallback and a copy button.

**Cut, and why:** contractor suggestions in the plan (no-ranking rule); resurfacing savings (no price in the data); PDF output (no package, not needed); per-flag letters (unusable at 493); a ward "paid twice" tile (scorecard carries it).

**Later:** a ward list of repeat-spend roads; real DLP contractor per road once the data has it.

## Challenges and how they landed
| # | Challenge | Tag | Outcome |
|---|---|---|---|
| 1 | A narrow tool beats a platform; seven features exist and each addition can break the demo | [SERIOUS] | Overruled: Keyur kept all five. Softened by the build order and by reusing existing views. See Risks. |
| 2 | Recoverable money is not recovered money | [SERIOUS] | Changed the idea: real budget line stays, second line labelled "if recovered" |
| 3 | DLP is ₹2.62 cr of ₹3.48 cr and may exceed the answer key | [SERIOUS] | Changed the idea: DLP shown as its own share |
| 4 | The answer key may expect "Mahalaxmi is slow" | [SERIOUS] | Still open. The data dictionary defines `assigned_at` as when BMC assigned the job, and the raw on-time figure stays on screen. |
| 5 | Redo cost in the plan breaks the no-ranking rule in spirit | [SERIOUS] | Changed the idea: scorecard only |
| 6 | No resurfacing price, so any saving for D would be invented | [FATAL for costing] | Changed the idea: D makes no savings claim |
| 7 | A drafted notice can look like an official BMC document | [SERIOUS] | Proposed: headed "Draft for review", no letterhead, blank signature. Not explicitly decided. |
| 8 | E needs Claude live on venue Wi-Fi | [SERIOUS] | Changed the idea: template fallback |
| 9 | The DLP draft cannot name who is liable | [SERIOUS] | Proposed: address it to the roads department to identify the DLP contractor. Not explicitly decided. |
| 10 | "Redone" is inferred from a second job on the same road | [MINOR] | Holds up: counted only for jobs already marked re-opened; wording is "followed by another job" |
| 11 | Busy roads get more jobs anyway | [MINOR] | Holds up: D is worded as repeat spend, no contractor attached |
| 12 | Letter drafting is a familiar Claude demo | [MINOR] | Holds up if every draft lists its work order ids |

## Risks and red flags
1. **Scope.** Five features on top of seven, built against a demo. Keyur chose all five. If time runs short, the order gives the cut line: stop after A.
2. **Answer key and B.** If judges score speed against a key that treats late assignment as contractor slowness, the adjusted band will disagree with it. The raw figure stays visible as cover.
3. **The "enough time left" rule is not pinned down.** The numbers here use the median assigned-to-done time per work type. A different cut-off moves the 441, 690 and 104 split.
4. **`ui-refresh` is unmerged and stays that way** on Keyur's instruction. B, A, C and D all touch the plan and scorecard screens it changes.
   Checked at 15:24 on 2026-11-21: a second session has this folder on a new `design-overhaul` branch (no commits yet) with an unpacked design handoff in `design/` covering 23 screens, including the scorecard, plan and flag detail screens. `ui-refresh` has its first four tasks committed (tokens, components, charts, navigation) and no file activity in the last 30 minutes. Neither design includes these five features.
5. **Checks will fail until updated.** `db:verify` and `api.test.ts` hold fixed scorecard row counts.

## Feasibility
Read: `README.md`, `DATA_DICTIONARY.md`, `docs/CHALLENGE.md`, `STARTER_IDEAS.md`, `docs/PRD-bmc-sathi.md`, `apps/api/prisma/views.sql`, `apps/api/src/pipeline/verify.ts`, and the exports of `modules/ask.ts`, `modules/flags.ts` and `lib/claude.ts`. Queries ran read-only against the local `sathi` database.

No new tables are needed. B is one view and a change to `v_scorecard`. A is a join in `v_plan` on `v_flag`. C and D are aggregates over `work_order`. E reuses `askJson` and the flag evidence JSON. No effort estimate was agreed in the session.

## How we'll know it worked
- No contractor's speed band differs from "similar" for a reason that traces to assignment wait.
- In Ward L, confirming flags in the demo moves the "if recovered" line down the plan.
- `npm run db:verify` and `npm test` pass with updated counts.

## Decisions made
- Keep all five features: Keyur's call.
- A: confirmed flags move the line, open flags shown as possible.
- A: second line, real budget line unchanged.
- A: DLP included, shown as its own share.
- D: one line on plan items.
- B: speed band based on jobs with enough time left.
- B: "time to assign" as a new ward scorecard measure.
- B: say plainly when a target is shorter than the typical work time.
- C: rupees on the scorecard only.
- E: one draft per group.
- E: Claude with a fixed-template fallback.
- Build order B, A, C, D, E.
- Do not merge `ui-refresh`. This replaced an earlier answer to merge it first.

## Open questions
- Where does the screen work go with `ui-refresh` unmerged: on main, inside that branch, or API and views only for now? Keyur.
- The exact "enough time left" cut-off for B. Decide in design.
- How much build time is left. The answer given was "everything", read as room for all five.
- Draft heading, signature and addressee for E (challenges 7 and 9). Decide in design.

## Verdict
**Go.** Every feature rests on a measured pattern, reuses views that exist, and lands on a named rubric line. B matters most because it fixes a band the app currently gets wrong. The verdict would change to Rethink for C, D and E if less than about two hours remain, in which case build B and A and narrate the rest.

## Next step
Settle where the screen work goes, then design B with `superpowers:brainstorming`.
