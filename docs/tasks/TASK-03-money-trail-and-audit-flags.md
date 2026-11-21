# TASK-03: Money Trail and Audit Flags

| Field | Value |
|---|---|
| Task ID | TASK-03 |
| Status | In Review |
| Priority | P0 |
| Size | L (about 2.0 hours) |
| Depends On | TASK-02 |
| Blocks | TASK-05 |
| Requirement IDs | REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-005, REQ-F-010, REQ-F-011, REQ-F-012, REQ-N-002, REQ-S-004 |
| Primary Spec Refs | 03-backend-spec.md#wards-and-money-trail-f1, 03-backend-spec.md#flags-f2, 02-frontend-spec.md#52-city-view-city, 02-frontend-spec.md#55-flag-detail |
| Last Updated | 2026-11-21 |

## 1. Objective

Deliver the city view, the ward money trail and the audit flag workflow end to end. An auditor can go from the city map to a ward, open a flag, see its evidence and record a decision that persists.

## 2. Scope

### In Scope
- API: ward detail, breakdown, ward work orders; flags list, summary, detail, decision
- City view: ward map from bundled GeoJSON with five-step shading and legend, sortable table, linked selection
- Ward page: budget bar, three money-at-question tiles, breakdown by contractor, method, week, drill-down to work orders
- Flag queue with four tabs, filters, header strip
- Flag detail with evidence per type and the decision control
- Widgets: `BarList`, `WorkOrderTable`, `DecisionChip`
- Bilingual flag reason templates

### Out of Scope
- Ward summary text and Ask button behaviour (TASK-06)
- Ward scorecard tab and plan tab content (TASK-05)
- Trail links resolve in TASK-04; until then they open the work order in the detail panel

## 3. Prerequisites

- TASK-02 complete
- `wards.geojson` copied into web assets

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Provides auth, the shell, the API client and shared widgets |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-001 | Ward page shows budget, spend and remaining or overspent amount | PRD §5 F1 |
| REQ-F-002 | Ward spend is broken down by contractor, by repair method and by week | PRD §5 F1 |
| REQ-F-003 | Ward page shows three money-at-question tiles: re-opened spend, DLP spend, open-flag amount | PRD §5 F1 |
| REQ-F-004 | City view shows 24 wards on a map shaded by spend against budget beside a sortable table | 02-frontend-spec.md#52-city-view-city |
| REQ-F-005 | Every figure and bar on the ward page opens the work orders behind it | PRD §5 F1 |
| REQ-F-010 | Flag queue with tabs per type, counts, amount at stake, filters and sort | 02-frontend-spec.md#54-flag-queue-flags |
| REQ-F-011 | Flag detail shows type-specific evidence, including two work orders side by side for double billing | 02-frontend-spec.md#55-flag-detail |
| REQ-F-012 | Ward officer or auditor records a decision with a note, and it persists | PRD §5 F2 |
| REQ-N-002 | API reads return in under 500 ms | 01-project-overview.md#9-performance-targets |
| REQ-S-004 | Citizen role never receives complainant_id, decision notes or decided_by, nor the flag queue | 03-backend-spec.md#3-authentication-and-roles |

### 5.2 Data Contracts

Reads `v_ward_money`, `v_ward_spend_breakdown`, `v_work_order`, `v_flag`. Writes `flag_decision` (upsert on `(flag_type, work_order_id)`), with `decided_by` from the token.

### 5.3 API Contracts

As specified in 03-backend-spec.md: `GET /wards/:code`, `/wards/:code/breakdown?dimension=`, `/wards/:code/work-orders?filter=`; `GET /flags`, `/flags/summary`, `/flags/:type/:workOrderId`; `PUT /flags/:type/:workOrderId/decision` (body `decision`, `note` up to 500 chars). Decision on a watch-tier row returns 409 `conflict`. Lists return `{ items, total }` with `limit` and `offset`.

### 5.4 UI Surfaces & States

City view, ward page, flag queue and flag detail as in 02-frontend-spec.md §5.2 to §5.5. States: loading skeletons; empty (`No open flags in this ward`); error with Retry; not-allowed redirect for citizens on `/flags`. Budget bar uses the error colour only above 100% and always with the words `Over by`. Unreviewed flags are amber; confirmed are red; each has a text label.

### 5.5 Permissions & Roles

Read wards: all roles. Flag queue and detail: ward officer (own ward only, forced by `scopeWard`) and auditor. Decisions: same two roles. Citizen: the open-flags tile shows count and amount only and is not a link; responses to citizens omit `note` and `decided_by`.

### 5.6 Assumptions

- ASSUMPTION: DLP evidence states that the liable party is the road's original contractor, which the data does not name — fairness — wording changes if a real export names them.
- ASSUMPTION: the map draws polygons with no tile layer — no network dependency — add tiles later if wanted.

## 6. Implementation Steps

1. Add wards service and routes for detail, breakdown and work orders with the `filter` options.
2. Add flags service and routes: list with filters and sort, summary, detail (second work order for duplicates), decision upsert.
3. Strip citizen-hidden fields in the services; add API tests for scope and stripping.
4. Add providers for wards, ward detail, breakdown, work orders, flags, flag summary, flag detail.
5. Build `WorkOrderTable` (table when wide, stacked cards when narrow), `BarList`, `DecisionChip`.
6. Build the city view: map with shading and legend, table, two-way selection.
7. Build the ward page: header tabs, budget bar, tiles, breakdown switcher, drill-down into `DetailPanel`.
8. Build the flag queue: tabs with counts and amounts, filters, header strip.
9. Build flag detail: three evidence layouts plus watch; links to contractor and work order.
10. Build the decision control; on save invalidate flag list, flag summary and ward money.
11. Add `en` and `mr` strings, including reason templates.
12. Walk demo steps 1 to 3 at three widths.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — City view matches the data
- **Given** an auditor on the city view
- **When** the table is sorted by spend share
- **Then** Ward E is first at 119% and exactly six wards show over 100%

**AC-2** — Figures drill down
- **Given** the Ward E page
- **When** the `Re-opened in 30 days` tile is opened
- **Then** the detail panel lists exactly the work orders whose costs sum to the tile's amount

**AC-3** — Breakdown switches
- **Given** the Ward E page
- **When** the breakdown is switched between contractor, method and week
- **Then** bars and totals change and each bar opens its work orders

**AC-4** — Flag counts match
- **Given** an auditor on the flag queue with no filters
- **When** each tab is opened
- **Then** the tabs show 109, 45, 493 and 5

**AC-5** — Double-billing evidence
- **Given** a possible double-billing flag
- **When** it is opened
- **Then** two work orders appear side by side with road, work type, contractor, area and days apart marked as matching, and the second marked `no complaint linked`

**AC-6** — Decision persists
- **Given** an open flag
- **When** the auditor saves `Needs explanation` with a note and reloads the page
- **Then** the flag shows that decision, the auditor's name and the time, and the open count has dropped by one

**AC-7** — Watch takes no decision
- **Given** a watch-tier row
- **When** it is opened
- **Then** evidence is shown and no decision control is offered; a direct API call returns 409

**AC-8** — Ward officer is scoped
- **Given** the Ward E officer
- **When** they open the flag queue or request another ward's flags through the API
- **Then** only Ward E flags are returned

**AC-9** — Citizen cannot see the queue
- **Given** a citizen
- **When** they open `/flags` or call `GET /flags`
- **Then** the app redirects to their home and the API returns 403

### 7.2 Non-Functional Checklist

- [ ] Validation: every input validated server-side with Zod; forms show field-level messages
- [ ] Error states: every failure path shows a message with Retry; no blank screens
- [ ] Loading states: every async surface shows a skeleton
- [ ] Empty states: every list says what is empty and why
- [ ] Authorization: role and ward checked server-side on every route this task adds
- [ ] Logging: one line per request with user id; no bodies, tokens or keys
- [ ] Accessibility: keyboard reachable, labelled, visible focus, text label beside every colour cue
- [ ] Responsive: checked at 1280, 900 and 390 px wide
- [ ] No hardcoded thresholds, URLs or secrets; settings table and environment file only
- [ ] Follows the layering and widget patterns from earlier tasks
- [ ] Every new string exists in English and Marathi string files

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Integration | Flag counts per tab (AC-4); decision upsert and reload (AC-6); 409 on watch (AC-7); ward scope (AC-8); citizen 403 and stripped fields (AC-9) | `apps/api/test/flags.test.ts` |
| Manual | AC-1, AC-2, AC-3, AC-5 and demo steps 1 to 3 at 1280, 900, 390 px; every read under 500 ms in the network panel | browser |

## 9. Deliverables

- Seven API routes
- City view, ward page, flag queue, flag detail
- Three shared widgets
- Flag API tests

## 10. Files Expected to Change

An estimate at module level, not a constraint.

- `apps/api/src/modules/wards/`, `modules/flags/` (new and modified)
- `apps/web/lib/features/overview/`, `features/flags/` (new)
- `apps/web/lib/core/widgets/` (modified)
- `apps/web/assets/geo/wards.geojson` (new)
- string files (modified)

## 11. Related Documentation

- `docs/tech-spec/03-backend-spec.md#wards-and-money-trail-f1` — ward routes
- `docs/tech-spec/03-backend-spec.md#flags-f2` — flag routes
- `docs/tech-spec/02-frontend-spec.md#5-screens` — screen content
- `docs/tech-spec/04-database-design.md#52-flags` — evidence fields

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| GeoJSON polygons render slowly or misaligned in flutter_map | City view late | Fall back to the table alone with shaded rows; the map is not scored |
| Drill-down totals disagree with tiles | Credibility | Both read the same view with the same filter; assert in the API test |
| This is the largest task | Overrun | Build flags before the map; the map is the first thing to simplify |

## 13. Progress Status

**Current status:** In Review

| Date | Progress | Commit |
|---|---|---|
| | | |

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Tests named in section 8 written and passing
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Validator passes
