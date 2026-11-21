# TASK-05: Scorecards and Next-Rupee Plan

| Field | Value |
|---|---|
| Task ID | TASK-05 |
| Status | Complete |
| Priority | P0 |
| Size | M (about 1.5 hours) |
| Depends On | TASK-03, TASK-04 |
| Blocks | TASK-06 |
| Requirement IDs | REQ-F-013, REQ-F-014, REQ-F-015, REQ-F-016, REQ-F-017, REQ-F-018, REQ-F-019, REQ-F-020, REQ-D-005, REQ-D-006 |
| Primary Spec Refs | 04-database-design.md#54-scorecards, 04-database-design.md#55-next-rupee-plan, 02-frontend-spec.md#57-next-rupee-plan-wardcodeplan |
| Last Updated | 2026-11-21 |

## 1. Objective

Deliver fair scorecards for contractors and wards, and the ranked next-rupee plan for every ward. These two features carry 40% of the judging weight between them.

## 2. Scope

### In Scope
- SQL migration: `v_stratum_rate`, `v_scorecard`, `v_method_durability`, `v_open_issue_risk`, `v_plan`
- API: contractors list, contractor detail, contractor work orders, ward scorecard, ward plan, settings read and update
- Contractor list and scorecard; ward scorecard tab
- Plan screen with expandable score parts and the budget line
- Settings screen for the auditor
- Widgets: `BandChip`, `CompareBars`
- Plan rank on the open-issue trail

### Out of Scope
- Stored summaries on scorecards (TASK-06)
- Ask (TASK-06)

## 3. Prerequisites

- TASK-03 and TASK-04 complete
- `issue` populated

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-03 | Provides `WorkOrderTable`, the ward page tabs and drill-down pattern |
| TASK-04 | Provides `issue`, which the plan ranks |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-013 | Contractor scorecard shows speed, durability and cost against similar jobs with a band and context | PRD §5 F3 |
| REQ-F-014 | Ward scorecard uses the same three measures | PRD §5 F3 |
| REQ-F-015 | Contractors are listed in name order with no rank, grade or performance sort | PRD §3 |
| REQ-F-016 | Each scorecard measure links to the work orders behind it | PRD §5 F3 |
| REQ-F-017 | Next-rupee plan ranks a ward's open issues by risk score with score parts and reasons | PRD §5 F4 |
| REQ-F-018 | Plan recommends a repair method and shows the alternative with cost and re-open rate | 04-database-design.md#55-next-rupee-plan |
| REQ-F-019 | Plan shows estimated and cumulative cost, a budget line, and an overspent-ward heading | PRD §5 F4 |
| REQ-F-020 | Auditor edits thresholds and risk weights; weights must sum to 100; changes re-rank the plan | 03-backend-spec.md#settings |
| REQ-D-005 | Views v_stratum_rate and v_scorecard with leave-one-out expected rates and bands | 04-database-design.md#54-scorecards |
| REQ-D-006 | Views v_method_durability, v_open_issue_risk, v_plan | 04-database-design.md#55-next-rupee-plan |

### 5.2 Data Contracts

New views only, per 04-database-design.md §5.4 and §5.5. Expected rates leave out the subject's own jobs; strata with fewer than 5 other jobs fall back to work type and method. Work orders with null `sla_met` or `reopened_within_30d` are left out of rates. `PUT /settings/:key` writes `setting`.

### 5.3 API Contracts

`GET /contractors` (name order), `/contractors/:id`, `/contractors/:id/work-orders?filter=`; `GET /wards/:code/scorecard`; `GET /wards/:code/plan`; `GET /settings`, `PUT /settings/:key` (auditor; range-checked; the six weights must sum to 100, otherwise 400).

### 5.4 UI Surfaces & States

Scorecard: three measure cards with observed figure, similar-jobs figure, `BandChip`, `CompareBars`, context line, link to work orders; `too few jobs to say` variant; `How this is compared` expander. Contractor list: cards in name order, no rank numbers. Plan: header (remaining budget or over-budget wording), ranked cards with reason chips, method and alternative, expandable six-part breakdown, `Budget runs out here` divider, footer total. Empty state when a ward has no open issues. Settings: table with running weight total.

### 5.5 Permissions & Roles

Scorecards and plan: all roles, read-only. Settings: auditor only; others are redirected and the API returns 403.

### 5.6 Assumptions

- ASSUMPTION: bands use |z| of 2 and 3 with a 30-job minimum — keeps small gaps unlabelled — more contractors read `similar` if raised.
- ASSUMPTION: risk weights 30/15/15/15/15/10 — severity first, then the brief's context factors — the order changes if the judges weight differently; adjustable on the settings screen.
- ASSUMPTION: estimated area for an open pothole issue is the ward's median for that work type — complaints carry no area.

## 6. Implementation Steps

1. Write the SQL migration for `v_stratum_rate` and `v_scorecard` for both subject types and three measures.
2. Check by hand against known figures: CT03 durability 38% observed, CT05 9%; both should band away from `similar`.
3. Write `v_method_durability`, `v_open_issue_risk` with one column per score part, and `v_plan` with method, costs, cumulative cost and `within_budget`.
4. Extend `verify`: 8 contractor and 24 ward scorecards; every ward has a plan row set or an explicit empty result; score parts sum to the score.
5. Add contractors, plan and settings services and routes.
6. Build `BandChip` and `CompareBars`.
7. Build contractor list and scorecard; add the ward scorecard tab.
8. Build the plan screen with expandable parts, the divider and the footer.
9. Build the settings screen; invalidate all providers on save.
10. Show plan rank on the open-issue trail.
11. Add `en` and `mr` strings including band names and reason chips.
12. Walk demo steps 5 and 6.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — All scorecards exist
- **Given** the loaded database
- **When** `verify` runs
- **Then** it finds three measures for each of 8 contractors and 24 wards

**AC-2** — Comparison is against similar jobs
- **Given** contractor CT03
- **When** its scorecard is opened
- **Then** durability shows about 38% re-opened against a lower similar-jobs figure with a below-range band, and the context line gives heavy-rain and low-lying job counts

**AC-3** — No ranking anywhere
- **Given** the contractor list
- **When** it is viewed in any role
- **Then** contractors are in name order with no rank, grade or sort-by-performance control

**AC-4** — Measures link to evidence
- **Given** a contractor's cost measure showing n jobs above 1.5 times
- **When** the link is opened
- **Then** exactly n work orders are listed

**AC-5** — Plan is ranked with reasons
- **Given** a ward with open issues and budget remaining
- **When** its plan is opened
- **Then** items are in descending risk score, each shows reasons, a method and an estimated cost, and expanding one shows six parts that sum to the score

**AC-6** — Budget line is correct
- **Given** that ward's plan
- **When** cumulative cost passes the remaining budget
- **Then** the divider sits immediately before the first item that does not fit, and the footer total equals the cost of items above it

**AC-7** — Overspent ward
- **Given** Ward E, which is over budget
- **When** its plan is opened
- **Then** the header reads that everything needs additional funds and no item is marked within budget

**AC-8** — High-risk roads get the durable method
- **Given** a pothole issue on a highway or arterial road
- **When** its plan row is read
- **Then** the recommended method is the one with the lowest re-open rate for that road type, and the cheaper alternative is shown with its re-open rate

**AC-9** — Weights re-rank
- **Given** the auditor raises `w_traffic` and lowers `w_severity` keeping the total at 100
- **When** the plan is reopened
- **Then** the order changes; and a save with a total other than 100 is refused

### 7.2 Non-Functional Checklist

- [x] Validation: every input validated server-side with Zod; forms show field-level messages
- [x] Error states: every failure path shows a message with Retry; no blank screens
- [x] Loading states: every async surface shows a skeleton
- [x] Empty states: every list says what is empty and why
- [x] Authorization: role and ward checked server-side on every route this task adds
- [x] Accessibility: keyboard reachable, labelled, visible focus, text label beside every colour cue
- [x] Responsive: checked at 1280, 900 and 390 px wide
- [x] No hardcoded thresholds, URLs or secrets; settings table and environment file only
- [x] Follows the layering and widget patterns from earlier tasks
- [x] Every new string exists in English and Marathi string files

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Script | `verify` additions prove AC-1 and the sum check in AC-5 | `apps/api/src/pipeline/verify.ts` |
| Integration | Plan ordering, cumulative cost and `within_budget` (AC-5, AC-6, AC-7); settings validation and role (AC-9) | `apps/api/test/plan.test.ts` |
| Manual | AC-2, AC-3, AC-4, AC-8 and demo steps 5 and 6 at three widths | browser |

## 9. Deliverables

- One SQL migration with five views
- Seven API routes
- Contractor list, scorecards, plan and settings screens
- Two shared widgets

## 10. Files Expected to Change

An estimate at module level, not a constraint.

- `apps/api/prisma/migrations/` (new)
- `apps/api/src/modules/contractors/`, `modules/plan/`, `modules/settings/` (new)
- `apps/web/lib/features/contractors/`, `features/plan/`, `features/settings/` (new)
- `apps/web/lib/features/overview/` ward tabs, `features/trail/` (modified)
- string files (modified)

## 11. Related Documentation

- `docs/tech-spec/04-database-design.md#54-scorecards` — peer groups, expected rate, bands
- `docs/tech-spec/04-database-design.md#55-next-rupee-plan` — score parts and method rule
- `docs/tech-spec/03-backend-spec.md#contractors-f3` — routes
- `docs/tech-spec/02-frontend-spec.md#56-contractor-list-and-scorecard` — scorecard layout
- `../PRD-bmc-sathi.md` — §3 anti-goals

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Leave-one-out SQL is slow or wrong | Scorecards late | Compute stratum totals once and subtract the subject's own counts; check two contractors by hand |
| Risk ranking differs from the answer key | Budget score | Weights are settings; reasons are visible; tune after seeing the top items for two wards |
| Few open issues resolve to a road | Thin plans | Fall back to ward-level factors when road is null and say so on the item |

## 13. Progress Status

**Current status:** Complete

| Date | Progress | Commit |
|---|---|---|
| 2026-11-21 | Verified in the browser: scorecards against similar jobs, no ranking, evidence links, plan with score parts and budget line, overspent ward. Changing weights in Settings re-scored the plan; weights restored. | see git log |

## 14. Completion Checklist

- [x] All implementation steps complete
- [x] All behavioral acceptance criteria verified in the running application
- [x] Non-functional checklist fully ticked
- [x] Tests named in section 8 written and passing
- [x] Frontend and backend integrated end to end (no mocked data left in place)
- [x] Error, loading, empty, and unauthorized states verified
- [x] Code reviewed against the patterns established in earlier tasks
- [x] Assumptions documented and, where possible, confirmed
- [x] Task file progress log and status updated
- [x] `00-task-summary.md` updated
- [x] Validator passes
