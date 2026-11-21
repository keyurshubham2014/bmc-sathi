# TASK-04: Complaints to Issues and the Trail

| Field | Value |
|---|---|
| Task ID | TASK-04 |
| Status | In Review |
| Priority | P0 |
| Size | M (about 1.5 hours) |
| Depends On | TASK-02 |
| Blocks | TASK-05, TASK-06 |
| Requirement IDs | REQ-F-021, REQ-F-022, REQ-F-023, REQ-F-024, REQ-F-025, REQ-F-026, REQ-F-027, REQ-N-006 |
| Primary Spec Refs | 03-backend-spec.md#6-pipeline, 04-database-design.md#6-pipeline-derived-data, 02-frontend-spec.md#58-trail-trail-trail |
| Last Updated | 2026-11-21 |

## 1. Objective

Turn 6,501 complaints into located, de-duplicated issues and let anyone follow one item from complaint to outcome. The pipeline works with no Claude key now and improves when the key is added.

## 2. Scope

### In Scope
- `enrich` script: Claude mode (Haiku 5.5, batches of 25, 5 in parallel, structured output, resumable) and `--no-claude` rules-only mode; chosen automatically when no key is set
- `group` script: resolve ward and road, build `issue`, set `issue_id`
- Social post labelling inside `enrich` (Claude mode only)
- API: `/search`, `/trail/issue/:id`, `/trail/complaint/:id`, `/trail/work-order/:id`
- Search screen and trail view with five stages and all variants
- Trail links from TASK-03 work-order rows now open the trail

### Out of Scope
- `summarise` script and Ask (TASK-06)
- Plan rank shown on an open issue appears once TASK-05 lands
- Intake of new complaints (TASK-06)

## 3. Prerequisites

- TASK-02 complete
- Optional: `ANTHROPIC_API_KEY` in `.env`. Without it the task completes in rules-only mode and AC-2 is verified later

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Provides the API skeleton, auth and the shell the trail screens sit in |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-021 | Pipeline enriches complaints with corrected category, severity and English text using Claude, resumably | 03-backend-spec.md#enrich |
| REQ-F-022 | Pipeline runs in a rules-only mode when no Claude key is present | 03-backend-spec.md#enrich |
| REQ-F-023 | Each complaint's ward and road are resolved from work order, GPS, road name or gazetteer | 04-database-design.md#6-pipeline-derived-data |
| REQ-F-024 | Complaints are grouped into issues with states fixed, fixed_reopened, open, out_of_scope | 04-database-design.md#6-pipeline-derived-data |
| REQ-F-025 | Social posts are labelled and attached to issues as supporting evidence only | PRD §6 |
| REQ-F-026 | Search finds complaints, work orders, roads and localities | 03-backend-spec.md#trail-and-search-f5 |
| REQ-F-027 | Trail view shows complaints, issue, work order, road and outcome as five stages | 02-frontend-spec.md#58-trail-trail-trail |
| REQ-N-006 | Complaint pipeline is batched and finishes in under 15 minutes | 01-project-overview.md#9-performance-targets |

### 5.2 Data Contracts

Fills `complaint_enriched`, `issue`, `social_post_label`. Road resolution order and grouping rules exactly as 04-database-design.md §6. Rules-only values: `category_clean` = reported category (`Road related` and `Other` become `Pothole`); severity default per category (cave-in 5, open manhole 5, waterlogging 4, choked drain 3, pothole 3, paver blocks 2); `text_en` = original; `model` null.

### 5.3 API Contracts

`GET /search?q=` (3+ chars; up to 20 results with type and trail target). `GET /trail/issue/:id`, `/trail/complaint/:id` (resolves to its issue), `/trail/work-order/:id` (returns work order, road, contractor and flags alone when it has no issue). Citizen responses omit `complainant_id`.

### 5.4 UI Surfaces & States

Search with grouped results and an empty state for no matches. Trail timeline: Complaints, Issue, Work order, Road, Outcome. Variants: fixed; fixed and re-opened; never fixed; no complaint linked. Non-English complaints show original text with the translation beneath marked `Translated` (Claude mode only). Corrected categories show the reported one struck through. Severity is labelled `estimated`.

### 5.5 Permissions & Roles

Search and trail: all roles, read-only.

### 5.6 Assumptions

- ASSUMPTION: severity defaults per category in rules-only mode as listed above — keeps the plan working without Claude — ranks shift once Claude severities replace them.
- ASSUMPTION: issues split when 7 days pass between complaints on the same road and category — matches the duplicate window — fewer, larger issues if widened.
- ASSUMPTION: Claude request parameters and structured output are confirmed against the current Anthropic SDK documentation when this is built — SDK details change.

## 6. Implementation Steps

1. Write gazetteer matching (name and aliases, case-insensitive, Devanagari) and nearest-segment distance in `src/lib/geo.ts`.
2. Write `enrich --no-claude`: fill `complaint_enriched` with rule values for rows that have none.
3. Write `group`: resolve ward and road per 04 §6; build issues for linked sets, open groups, duplicates and out-of-scope; write `issue_id`.
4. Run both; add issue counts and a no-orphan check to `verify`.
5. Write `enrich` Claude mode: batching, concurrency, schema check, one retry, skip list, resume. Label social posts in the same run. Guard on the key.
6. Add trail service and routes; add search across complaint id, work order id, road name, locality.
7. Build the search screen.
8. Build the trail view with five stages and the four variants.
9. Point TASK-03 work-order rows at the trail route.
10. Add `en` and `mr` strings.
11. If the key is present, run Claude-mode `enrich` then `group` again and spot-check ten Marathi and Hindi complaints.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Rules-only pipeline completes
- **Given** no Claude key in the environment
- **When** `enrich` then `group` run
- **Then** every complaint has a `complaint_enriched` row, every open or in-progress complaint with a resolvable location belongs to an issue, and both scripts exit 0

**AC-2** — Claude mode enriches and resumes
- **Given** a Claude key and an `enrich` run interrupted part-way
- **When** `enrich` is run again
- **Then** only complaints without Claude fields are sent, and non-English complaints end with an English `text_en` and a `model` value

**AC-3** — Missing wards are filled
- **Given** the 457 complaints with no ward code
- **When** `group` has run
- **Then** each has `ward_code_resolved` unless its location source is `none`

**AC-4** — Complaint leads to its work order
- **Given** a resolved complaint id typed into search
- **When** its result is opened
- **Then** the trail shows that complaint, its issue, the linked work order with cost against expected cost, the road with DLP status, and the outcome

**AC-5** — Never-fixed issue
- **Given** an open issue
- **When** its trail is opened
- **Then** the work order stage reads `Never fixed` and the outcome stage shows days open

**AC-6** — Unlinked work order
- **Given** one of the 45 double-billing work orders
- **When** its trail is opened
- **Then** the complaints stage reads `No complaint linked` and the flag is listed with a link

**AC-7** — Search handles no match
- **Given** a query that matches nothing
- **When** search runs
- **Then** an empty state says so and nothing errors

### 7.2 Non-Functional Checklist

- [ ] Validation: every input validated server-side with Zod; forms show field-level messages
- [ ] Error states: every failure path shows a message with Retry; no blank screens
- [ ] Loading states: every async surface shows a skeleton
- [ ] Empty states: every list says what is empty and why
- [ ] Authorization: role and ward checked server-side on every route this task adds
- [ ] Logging: one line per request with user id; no bodies, tokens or keys
- [ ] Accessibility: keyboard reachable, labelled, visible focus, text label beside every colour cue
- [ ] Responsive: checked at 1280, 900 and 390 px wide
- [ ] Follows the layering and widget patterns from earlier tasks
- [ ] Every new string exists in English and Marathi string files
- [ ] Scripts are safe to rerun

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Script | `verify` additions prove AC-1 and AC-3 | `apps/api/src/pipeline/verify.ts` |
| Integration | Trail for a linked complaint, an open issue and an unlinked work order (AC-4, AC-5, AC-6) | `apps/api/test/trail.test.ts` |
| Manual | AC-2 when the key is available; AC-7; demo step 4 with a Marathi complaint | terminal and browser |

## 9. Deliverables

- `enrich` and `group` scripts
- Populated `complaint_enriched`, `issue`
- Four API routes
- Search and trail screens

## 10. Files Expected to Change

An estimate at module level, not a constraint.

- `apps/api/src/pipeline/enrich.ts`, `group.ts`, `verify.ts` (new and modified)
- `apps/api/src/lib/geo.ts`, `lib/claude.ts` (new and modified)
- `apps/api/src/modules/trail/` (new)
- `apps/web/lib/features/trail/` (new)
- string files (modified)

## 11. Related Documentation

- `docs/tech-spec/03-backend-spec.md#enrich` — batching, schema, fallback
- `docs/tech-spec/04-database-design.md#6-pipeline-derived-data` — resolution and grouping rules
- `docs/tech-spec/03-backend-spec.md#trail-and-search-f5` — routes
- `docs/tech-spec/02-frontend-spec.md#58-trail-trail-trail` — stages and variants

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Claude key arrives late | No translations in the demo | Rules-only mode is complete on its own; Claude mode is one rerun |
| Claude run is slow or rate-limited | Pipeline not done by demo | Resume support; lower concurrency; run on the 200-row sample first |
| Nearest-road matching puts complaints on the wrong segment | Odd plan items | Prefer the work order's road, then a named road; show location source on the trail |

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
