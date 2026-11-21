# Requirements Registry — BMC Sathi

**Last Updated:** 2026-11-21
**Total Requirements:** 67 — **Covered:** 64 — **Uncovered:** 0 — **Deferred:** 3

ID prefixes: `REQ-F` functional · `REQ-D` data · `REQ-N` non-functional · `REQ-S` security · `REQ-O` operational

Sources are sections of `docs/PRD-bmc-sathi.md` or anchors in `docs/tech-spec/`.

## Functional

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-F-001 | Ward page shows budget, spend and remaining or overspent amount | PRD §5 F1 | P0 | TASK-03 |
| REQ-F-002 | Ward spend is broken down by contractor, by repair method and by week | PRD §5 F1 | P0 | TASK-03 |
| REQ-F-003 | Ward page shows three money-at-question tiles: re-opened spend, DLP spend, open-flag amount | PRD §5 F1 | P0 | TASK-03 |
| REQ-F-004 | City view shows 24 wards on a map shaded by spend against budget beside a sortable table | 02-frontend-spec.md#52-city-view-city | P0 | TASK-03 |
| REQ-F-005 | Every figure and bar on the ward page opens the work orders behind it | PRD §5 F1 | P0 | TASK-03 |
| REQ-F-006 | Over-billed flag: cost above overbill_ratio times expected cost | 04-database-design.md#52-flags | P0 | TASK-01 |
| REQ-F-007 | Possible double-billing flag: unlinked work order repeating an earlier job on same road, type, contractor and area within the window | 04-database-design.md#52-flags | P0 | TASK-01 |
| REQ-F-008 | Billed-under-DLP flag as its own type | 04-database-design.md#52-flags | P0 | TASK-01 |
| REQ-F-009 | Watch tier between the watch and flag ratios, which cannot take a decision | 04-database-design.md#52-flags | P1 | TASK-01 |
| REQ-F-010 | Flag queue with tabs per type, counts, amount at stake, filters and sort | 02-frontend-spec.md#54-flag-queue-flags | P0 | TASK-03 |
| REQ-F-011 | Flag detail shows type-specific evidence, including two work orders side by side for double billing | 02-frontend-spec.md#55-flag-detail | P0 | TASK-03 |
| REQ-F-012 | Ward officer or auditor records a decision with a note, and it persists | PRD §5 F2 | P0 | TASK-03 |
| REQ-F-013 | Contractor scorecard shows speed, durability and cost against similar jobs with a band and context | PRD §5 F3 | P0 | TASK-05 |
| REQ-F-014 | Ward scorecard uses the same three measures | PRD §5 F3 | P1 | TASK-05 |
| REQ-F-015 | Contractors are listed in name order with no rank, grade or performance sort | PRD §3 | P0 | TASK-05 |
| REQ-F-016 | Each scorecard measure links to the work orders behind it | PRD §5 F3 | P0 | TASK-05 |
| REQ-F-017 | Next-rupee plan ranks a ward's open issues by risk score with score parts and reasons | PRD §5 F4 | P0 | TASK-05 |
| REQ-F-018 | Plan recommends a repair method and shows the alternative with cost and re-open rate | 04-database-design.md#55-next-rupee-plan | P0 | TASK-05 |
| REQ-F-019 | Plan shows estimated and cumulative cost, a budget line, and an overspent-ward heading | PRD §5 F4 | P0 | TASK-05 |
| REQ-F-020 | Auditor edits thresholds and risk weights; weights must sum to 100; changes re-rank the plan | 03-backend-spec.md#settings | P1 | TASK-05 |
| REQ-F-021 | Pipeline enriches complaints with corrected category, severity and English text using Claude, resumably | 03-backend-spec.md#enrich | P0 | TASK-04 |
| REQ-F-022 | Pipeline runs in a rules-only mode when no Claude key is present | 03-backend-spec.md#enrich | P0 | TASK-04 |
| REQ-F-023 | Each complaint's ward and road are resolved from work order, GPS, road name or gazetteer | 04-database-design.md#6-pipeline-derived-data | P0 | TASK-04 |
| REQ-F-024 | Complaints are grouped into issues with states fixed, fixed_reopened, open, out_of_scope | 04-database-design.md#6-pipeline-derived-data | P0 | TASK-04 |
| REQ-F-025 | Social posts are labelled and attached to issues as supporting evidence only | PRD §6 | P2 | TASK-04 |
| REQ-F-026 | Search finds complaints, work orders, roads and localities | 03-backend-spec.md#trail-and-search-f5 | P0 | TASK-04 |
| REQ-F-027 | Trail view shows complaints, issue, work order, road and outcome as five stages | 02-frontend-spec.md#58-trail-trail-trail | P0 | TASK-04 |
| REQ-F-028 | Ask answers a question in its own language from a fetched fact pack and lists its sources | 03-backend-spec.md#7-ask | P0 | TASK-06 |
| REQ-F-029 | An Ask failure shows a plain message and leaves the rest of the app working | PRD §5 F6 | P0 | TASK-06 |
| REQ-F-030 | Ward officer adds a work order and sees any flags it raises immediately | PRD §5 F7 | P0 | TASK-06 |
| REQ-F-031 | Ward officer adds a complaint, which joins or creates an issue by rules | PRD §5 F7 | P1 | TASK-06 |
| REQ-F-032 | Work orders entered through intake can be deleted to reset the demo | 03-backend-spec.md#intake-f7 | P1 | TASK-06 |
| REQ-F-033 | Ward and contractor summaries are stored in English and Marathi and marked stale when figures change | 04-database-design.md#summary | P1 | TASK-06 |
| REQ-F-034 | Three demo accounts sign in and land on their role's home | 02-frontend-spec.md#3-routes | P0 | TASK-02 |
| REQ-F-035 | Responsive shell: rail or bottom bar, header with synthetic-data tag and independent-prototype line | 02-frontend-spec.md#4-layout | P0 | TASK-02 |
| REQ-F-036 | Theme mode light, dark or system, switched from the header and saved | 02-frontend-spec.md#8-theme | P0 | TASK-02 |
| REQ-F-037 | English and Marathi toggle, saved; all strings come from string files | 02-frontend-spec.md#9-language | P0 | TASK-02 |
| REQ-F-038 | Navigation items and routes differ by role | 02-frontend-spec.md#3-routes | P0 | TASK-02 |

## Data

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-D-001 | Raw tables mirror the 15 files with keys, types and indexes | 04-database-design.md#3-raw-tables | P0 | TASK-01 |
| REQ-D-002 | work_order_complaint and road_proximity are filled at load | 04-database-design.md#3-raw-tables | P0 | TASK-01 |
| REQ-D-003 | Derived and application tables exist: complaint_enriched, issue, social_post_label, summary, flag_decision, setting, app_user | 04-database-design.md#4-derived-and-application-tables | P0 | TASK-01 |
| REQ-D-004 | Views v_work_order, v_flag, v_ward_money, v_ward_spend_breakdown | 04-database-design.md#5-views | P0 | TASK-01 |
| REQ-D-005 | Views v_stratum_rate and v_scorecard with leave-one-out expected rates and bands | 04-database-design.md#54-scorecards | P0 | TASK-05 |
| REQ-D-006 | Views v_method_durability, v_open_issue_risk, v_plan | 04-database-design.md#55-next-rupee-plan | P0 | TASK-05 |
| REQ-D-007 | Seed of setting defaults and three users | 04-database-design.md#7-migrations-and-load | P0 | TASK-01 |
| REQ-D-008 | Load is rerunnable and does not touch decisions, users or settings | 04-database-design.md#7-migrations-and-load | P0 | TASK-01 |

## Non-Functional

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-N-001 | verify script asserts the reference counts and exits non-zero on mismatch | 01-project-overview.md#8-testing | P0 | TASK-01 |
| REQ-N-002 | API reads return in under 500 ms | 01-project-overview.md#9-performance-targets | P1 | TASK-03 |
| REQ-N-003 | Contrast test passes for every token pair in both themes | 02-frontend-spec.md#8-theme | P1 | TASK-02 |
| REQ-N-004 | Every list has loading, empty and error states | 02-frontend-spec.md#11-loading-empty-and-error-states | P0 | TASK-02 |
| REQ-N-005 | Keyboard reachable, labelled controls, no colour-only meaning | 02-frontend-spec.md#10-accessibility | P1 | TASK-02 |
| REQ-N-006 | Complaint pipeline is batched and finishes in under 15 minutes | 01-project-overview.md#9-performance-targets | P1 | TASK-04 |
| REQ-N-007 | Money is shown in Indian grouping with lakh and crore and tabular numerals | 02-frontend-spec.md#6-shared-widgets | P0 | TASK-02 |

## Security

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-S-001 | Passwords are bcrypt hashes; sessions are JWTs valid 12 hours | 03-backend-spec.md#3-authentication-and-roles | P0 | TASK-02 |
| REQ-S-002 | Role and ward scope are enforced by middleware on every route | 03-backend-spec.md#3-authentication-and-roles | P0 | TASK-02 |
| REQ-S-003 | Every route validates input with Zod and errors share one shape | 03-backend-spec.md#5-errors | P0 | TASK-02 |
| REQ-S-004 | Citizen role never receives complainant_id, decision notes or decided_by, nor the flag queue | 03-backend-spec.md#3-authentication-and-roles | P0 | TASK-03 |
| REQ-S-005 | Secrets live in an uncommitted environment file; the Claude key stays on the server | 01-project-overview.md#7-security | P0 | TASK-01 |
| REQ-S-006 | Ask is limited to 10 requests a minute and 500 characters, and the model has no tools | 03-backend-spec.md#7-ask | P0 | TASK-06 |
| REQ-S-007 | CORS allows only the configured web origin | 03-backend-spec.md#8-non-functional | P1 | TASK-02 |

## Operational

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-O-001 | Postgres 17 runs locally in Docker; DATABASE_URL switches the target | 01-project-overview.md#6-environments-and-configuration | P0 | TASK-01 |
| REQ-O-002 | Repository layout apps/api and apps/web as specified | 01-project-overview.md#5-repository-layout | P0 | TASK-01 |
| REQ-O-003 | A database dump exists and the demo script has been run end to end | PRD §10 | P0 | TASK-06 |
| REQ-O-004 | API refuses to start without a database connection and the v_flag view | 03-backend-spec.md#8-non-functional | P1 | TASK-02 |

## Deferred / Out of Scope

| Req ID | Requirement | Source | Reason | Decided by |
|---|---|---|---|---|
| REQ-F-039 | Hindi interface labels | PRD §3 | Non-goal for this build | Owner, 2026-11-21 |
| REQ-O-005 | Neon cloud database | 01-project-overview.md#4-technology | Local Postgres in Docker for now; same schema, switch by DATABASE_URL | Owner, 2026-11-21 |
| REQ-O-006 | Public deployment of API and web app | 01-project-overview.md#6-environments-and-configuration | Runs on the demo laptop | Owner, 2026-11-21 |
