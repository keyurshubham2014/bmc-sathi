# TASK-06: Ask, Intake, Summaries and Demo Readiness

| Field | Value |
|---|---|
| Task ID | TASK-06 |
| Status | In Progress |
| Priority | P0 |
| Size | M (about 1.5 hours) |
| Depends On | TASK-04, TASK-05 |
| Blocks | None |
| Requirement IDs | REQ-F-028, REQ-F-029, REQ-F-030, REQ-F-031, REQ-F-032, REQ-F-033, REQ-S-006, REQ-O-003 |
| Primary Spec Refs | 03-backend-spec.md#7-ask, 03-backend-spec.md#intake-f7, 03-backend-spec.md#summarise |
| Last Updated | 2026-11-21 |

## 1. Objective

Add the live parts of the demo and make it safe to present: a new work order that raises a flag on the spot, Ask in the user's language, stored bilingual summaries, and a rehearsed run with a database dump to fall back on.

## 2. Scope

### In Scope
- Intake API and screen for work orders and complaints; delete for intake work orders
- Ask API (Sonnet 5.5) with fact packs per scope, rate limit, timeout; Ask panel
- `summarise` script and summary display with stale marker on ward and scorecard pages
- Database dump and restore instructions; README run steps
- Full demo script run

### Out of Scope
- Claude parsing of intake complaints (owner chose rules only)
- Deployment (deferred, REQ-O-006)

## 3. Prerequisites

- TASK-04 and TASK-05 complete
- `ANTHROPIC_API_KEY` in `.env` for Ask and `summarise`. Without it, intake and demo readiness complete and Ask shows its unavailable state

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-04 | Provides gazetteer matching and `issue` for intake complaints and the trail fact pack |
| TASK-05 | Provides scorecards and plan, which summaries and Ask fact packs read |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-028 | Ask answers a question in its own language from a fetched fact pack and lists its sources | 03-backend-spec.md#7-ask |
| REQ-F-029 | An Ask failure shows a plain message and leaves the rest of the app working | PRD §5 F6 |
| REQ-F-030 | Ward officer adds a work order and sees any flags it raises immediately | PRD §5 F7 |
| REQ-F-031 | Ward officer adds a complaint, which joins or creates an issue by rules | PRD §5 F7 |
| REQ-F-032 | Work orders entered through intake can be deleted to reset the demo | 03-backend-spec.md#intake-f7 |
| REQ-F-033 | Ward and contractor summaries are stored in English and Marathi and marked stale when figures change | 04-database-design.md#summary |
| REQ-S-006 | Ask is limited to 10 requests a minute and 500 characters, and the model has no tools | 03-backend-spec.md#7-ask |
| REQ-O-003 | A database dump exists and the demo script has been run end to end | PRD §10 |

### 5.2 Data Contracts

Intake inserts `work_order` and `complaint` with `source = 'intake'`; work orders get null `sla_met` and `reopened_within_30d`. Intake complaints write `complaint_enriched` by rules and join an open issue on the same road and category or create one. `summarise` writes `summary` rows with `facts_hash`. Questions and answers are not stored.

### 5.3 API Contracts

`POST /intake/work-orders`, `POST /intake/complaints`, `DELETE /intake/work-orders/:id` (intake rows only) — ward officer, own ward. `POST /ask` (question up to 500 chars, `scope_type`, `scope_id`) returns `answer`, `sources`, `lang`; 429 past 10 a minute; 502 `assistant_unavailable` on failure or 20 s timeout. Ward and contractor detail responses gain `summary` with `stale`.

### 5.4 UI Surfaces & States

New record: two tabs; live expected cost and ratio on the work order form; field-level validation; submit disabled while saving; result card listing flags raised with links. Ask panel: field, send, answer with source links, in-flight and unavailable states. Summary block with `Written before recent changes` when stale and a neutral placeholder when none exists.

### 5.5 Permissions & Roles

Intake: ward officer, own ward only. Ask: all roles; the fact pack is built with the caller's role, so citizens' packs exclude hidden fields. Summaries: all roles.

### 5.6 Assumptions

- ASSUMPTION: the fact pack for a ward includes the top 10 plan rows and 20 most recent work orders — bounds the prompt — answers about older jobs point to the trail instead.
- ASSUMPTION: source ids returned by the model are dropped unless they appear in the fact pack — prevents invented references.
- ASSUMPTION: Claude request parameters are confirmed against the current Anthropic SDK documentation when this is built.

## 6. Implementation Steps

1. Add intake service and routes with validation (road in ward, method fits work type) and the flag re-read after insert.
2. Add the delete route restricted to `source = 'intake'`.
3. Build the new-record screen and result cards; invalidate providers per 02-frontend-spec.md §7.
4. Add fact-pack builders for ward, contractor and issue scopes.
5. Add the Ask route: rules prompt, model call, source filtering, rate limit, timeout, error mapping.
6. Build the Ask panel and attach it to the ward page, scorecards and trail.
7. Write `summarise`: fact sheets from the views, one call per subject for both languages, `facts_hash`.
8. Return summaries with `stale` from ward and contractor detail; render them.
9. Add `en` and `mr` strings.
10. Write a dump of the database to a file outside git; document restore and the `DATABASE_URL` switch in the README.
11. Run the eight demo steps twice, once in each theme; delete the intake work order afterwards; fix what breaks.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — A copied job raises a flag live
- **Given** the Ward E officer and an existing Ward E work order
- **When** they submit a new work order with the same road, work type, contractor and area, dated two days later, with no complaint
- **Then** the result card shows a possible double-billing flag, the flag queue count rises by one, and Ward E's spend rises by the cost

**AC-2** — Intake is validated and scoped
- **Given** the Ward E officer
- **When** they submit a work order for a road in another ward, or a method that does not fit the work type
- **Then** the API returns 400 or 403 and the form shows the reason at the field

**AC-3** — Demo reset
- **Given** an intake work order
- **When** it is deleted
- **Then** its flag and spend disappear; deleting an imported work order is refused

**AC-4** — Intake complaint joins an issue
- **Given** an open issue on a known road and category
- **When** the officer adds a complaint with that locality and category
- **Then** the result card shows it joined that issue and the issue's complaint count rose

**AC-5** — Ask answers in the question's language
- **Given** a citizen on a ward page with the Claude key set
- **When** they ask in Marathi how much the ward spent
- **Then** the answer is in Marathi, gives the figure shown on the page, and lists source ids that open

**AC-6** — Ask stays inside its facts
- **Given** a question the fact pack cannot answer
- **When** it is asked
- **Then** the answer says the data does not contain it and suggests a screen

**AC-7** — Ask fails safely
- **Given** no Claude key, or the network is off
- **When** a question is sent
- **Then** the panel shows the unavailable message and every other screen still works

**AC-8** — Ask is rate limited
- **Given** a signed-in user
- **When** they send an eleventh question within a minute
- **Then** the API returns 429

**AC-9** — Summaries are stored and marked stale
- **Given** `summarise` has run
- **When** a ward page is opened in English and Marathi, then a work order is added to that ward
- **Then** the summary appears in each language, and after the addition it is marked as written before recent changes

**AC-10** — Fallback works
- **Given** the dump restored into a second database
- **When** `DATABASE_URL` is pointed at it and the API restarted
- **Then** `verify` passes and the app runs

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
- [ ] Scripts are safe to rerun

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Integration | Intake flag raise, validation, scope, delete (AC-1, AC-2, AC-3, AC-4); Ask rate limit and failure mapping with the model call stubbed (AC-7, AC-8) | `apps/api/test/intake.test.ts`, `ask.test.ts` |
| Manual | AC-5, AC-6, AC-9 with the key; AC-10; full demo script twice | browser and terminal |

## 9. Deliverables

- Four API routes plus summary fields
- `summarise` script and stored summaries
- New-record screen, Ask panel, summary blocks
- Database dump, README run and fallback steps
- Rehearsed demo

## 10. Files Expected to Change

An estimate at module level, not a constraint.

- `apps/api/src/modules/intake/`, `modules/ask/` (new)
- `apps/api/src/pipeline/summarise.ts`, `lib/claude.ts` (new and modified)
- `apps/api/src/modules/wards/`, `modules/contractors/` (modified)
- `apps/web/lib/features/intake/`, `features/ask/` (new)
- `README.md`, string files (modified)

## 11. Related Documentation

- `docs/tech-spec/03-backend-spec.md#intake-f7` — intake behaviour
- `docs/tech-spec/03-backend-spec.md#7-ask` — fact packs, rules, limits
- `docs/tech-spec/03-backend-spec.md#summarise` — summary rules
- `docs/tech-spec/02-frontend-spec.md#7-state` — what to invalidate after a write
- `../PRD-bmc-sathi.md` — §10 demo script

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Claude key not available by demo time | No Ask, no summaries | Both degrade to visible placeholder states; the other seven demo steps do not need Claude |
| Venue network fails | Ask fails on stage | Database is local; rehearse step 8 with a fallback line |
| Intake row left in the data | Counts drift from 45 | Delete route and a reset step in the README |

## 13. Progress Status

**Current status:** In Progress

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
