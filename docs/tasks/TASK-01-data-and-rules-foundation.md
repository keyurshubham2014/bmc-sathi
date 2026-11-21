# TASK-01: Data and Rules Foundation

| Field | Value |
|---|---|
| Task ID | TASK-01 |
| Status | Complete |
| Priority | P0 |
| Size | M (about 1.5 hours) |
| Depends On | None |
| Blocks | TASK-02 |
| Requirement IDs | REQ-F-006, REQ-F-007, REQ-F-008, REQ-F-009, REQ-D-001, REQ-D-002, REQ-D-003, REQ-D-004, REQ-D-007, REQ-D-008, REQ-N-001, REQ-S-005, REQ-O-001, REQ-O-002 |
| Primary Spec Refs | 04-database-design.md#3-raw-tables, 04-database-design.md#52-flags, 01-project-overview.md#8-testing |
| Last Updated | 2026-11-21 |

## 1. Objective

Stand up the repository, a local Postgres 17, every table, the money and flag views, and the loader. At the end, one command reproduces the reference figures (Rs 13.43 crore; 109 over-billed, 45 double-billing, 493 DLP flags) from the supplied files. This is the part of the product the judges score first.

## 2. Scope

### In Scope
- `apps/api` project: Node 20, TypeScript, Express 5, Prisma 6, Zod, tsx; `.env.example` and git-ignored `.env`
- `docker-compose.yml` with Postgres 17 and a named volume
- Prisma models and migration for all raw, derived and application tables
- One raw SQL migration creating `v_work_order`, `v_flag`, `v_ward_money`, `v_ward_spend_breakdown`
- Seed for `setting` defaults and three `app_user` rows
- `load` script for the 15 files, including `work_order_complaint` and `road_proximity`
- `verify` script

### Out of Scope
- Scorecard and plan views (TASK-05)
- Filling `complaint_enriched` and `issue` (TASK-04)
- HTTP server and routes (TASK-02)
- Neon (deferred, REQ-O-005)

## 3. Prerequisites

- Docker running
- Node 20 and npm
- The 15 files in `data/`

## 4. Dependencies

Not applicable — this is the first task.

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-006 | Over-billed flag: cost above overbill_ratio times expected cost | 04-database-design.md#52-flags |
| REQ-F-007 | Possible double-billing flag: unlinked work order repeating an earlier job on same road, type, contractor and area within the window | 04-database-design.md#52-flags |
| REQ-F-008 | Billed-under-DLP flag as its own type | 04-database-design.md#52-flags |
| REQ-F-009 | Watch tier between the watch and flag ratios, which cannot take a decision | 04-database-design.md#52-flags |
| REQ-D-001 | Raw tables mirror the 15 files with keys, types and indexes | 04-database-design.md#3-raw-tables |
| REQ-D-002 | work_order_complaint and road_proximity are filled at load | 04-database-design.md#3-raw-tables |
| REQ-D-003 | Derived and application tables exist: complaint_enriched, issue, social_post_label, summary, flag_decision, setting, app_user | 04-database-design.md#4-derived-and-application-tables |
| REQ-D-004 | Views v_work_order, v_flag, v_ward_money, v_ward_spend_breakdown | 04-database-design.md#5-views |
| REQ-D-007 | Seed of setting defaults and three users | 04-database-design.md#7-migrations-and-load |
| REQ-D-008 | Load is rerunnable and does not touch decisions, users or settings | 04-database-design.md#7-migrations-and-load |
| REQ-N-001 | verify script asserts the reference counts and exits non-zero on mismatch | 01-project-overview.md#8-testing |
| REQ-S-005 | Secrets live in an uncommitted environment file; the Claude key stays on the server | 01-project-overview.md#7-security |
| REQ-O-001 | Postgres 17 runs locally in Docker; DATABASE_URL switches the target | 01-project-overview.md#6-environments-and-configuration |
| REQ-O-002 | Repository layout apps/api and apps/web as specified | 01-project-overview.md#5-repository-layout |

### 5.2 Data Contracts

Creates every table in 04-database-design.md §3 and §4. Type changes from the files: Y/N to boolean, blanks to null, money to integer. Adds `source` (default `import`) to `work_order` and `complaint`. Drops `contractor_name` from `work_order`. `road_proximity` is computed in the loader with point-to-segment distance against `hotspot_radius_m`. Flag identity is `(flag_type, work_order_id)`.

### 5.3 API Contracts

Not applicable — this task exposes no HTTP routes. Its interface is three npm scripts: `db:load`, `db:verify`, and Prisma's migrate and seed.

### 5.4 UI Surfaces & States

Not applicable — no screens in this task.

### 5.5 Permissions & Roles

Not applicable — no user-facing access. Seeded users: `officer.e` (ward_officer, Ward E), `auditor`, `citizen`; passwords from the environment file, stored as bcrypt hashes.

### 5.6 Assumptions

- ASSUMPTION: rain band uses the higher of the two stations on the completion date — one date per job keeps peer groups simple — bands shift slightly if assignment date is preferred.
- ASSUMPTION: a work order with several flag types counts once, at its largest amount, in `open_flag_amount` — avoids double counting — totals rise if summed per flag.
- ASSUMPTION: views are plain, not materialised — 2,499 rows — revisit above a few hundred thousand.

## 6. Implementation Steps

1. Initialise git, `.gitignore` (node_modules, .env, build output), root README pointing at `docs/`.
2. Add `docker-compose.yml` for Postgres 17; start it; put `DATABASE_URL` and `DIRECT_URL` in `.env`.
3. Scaffold `apps/api` with TypeScript, tsx and Prisma.
4. Write Prisma models for the raw tables with keys and indexes from 04 §3.
5. Write Prisma models for the derived and application tables from 04 §4; run the first migration.
6. Write the SQL migration for `v_work_order`, then `v_flag` (three flag queries plus watch tier, joined to `flag_decision`), `v_ward_money`, `v_ward_spend_breakdown`. Read thresholds from `setting`.
7. Write the seed: all `setting` defaults from 04 §4 and the three users.
8. Write `load`: parse each file, convert types, truncate and insert raw tables in dependency order, split `linked_complaint_ids`, compute `road_proximity`.
9. Write `verify`: assert row counts per table, city spend, flag counts per type and tier, six wards over budget.
10. Run migrate, seed, load, verify; fix until verify passes.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Reference figures reproduced
- **Given** a fresh database after migrate, seed and load
- **When** `verify` runs
- **Then** it reports 2,499 work orders, city spend of Rs 13.43 crore (within Rs 1 lakh), 109 overbilled, 45 duplicate, 493 dlp, 5 watch, and exits 0

**AC-2** — Normal variation is not flagged
- **Given** the loaded database
- **When** `v_flag` is queried for tier `flag` and type `overbilled`
- **Then** no row has a cost ratio at or below 1.5, and no `duplicate` row has a linked complaint

**AC-3** — Thresholds are settings
- **Given** `overbill_ratio` is changed from 1.5 to 2.0 in `setting`
- **When** `v_flag` is read again
- **Then** the overbilled count falls with no migration or restart

**AC-4** — Load is rerunnable
- **Given** a `flag_decision` row exists
- **When** `load` is run a second time
- **Then** raw row counts are unchanged and the decision row is still present

**AC-5** — Verify fails loudly
- **Given** one work order is deleted by hand
- **When** `verify` runs
- **Then** it names the mismatched figure and exits non-zero

### 7.2 Non-Functional Checklist

- [x] No hardcoded thresholds, URLs or secrets; settings table and environment file only
- [x] Scripts are safe to rerun
- [x] Logging: one line per request with user id; no bodies, tokens or keys

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Script | `verify` proves AC-1, AC-2, AC-5 | `apps/api/src/pipeline/verify.ts` |
| Manual | Change a setting and re-query (AC-3); rerun load after inserting a decision (AC-4) | psql in the container |

## 9. Deliverables

- Running Postgres 17 container
- Prisma schema, two migrations, seed
- `load` and `verify` scripts
- `.env.example`

## 10. Files Expected to Change

An estimate at module level, not a constraint.

- `docker-compose.yml`, `.gitignore`, `README.md` (new)
- `apps/api/package.json`, `tsconfig.json` (new)
- `apps/api/prisma/` schema, migrations, seed (new)
- `apps/api/src/pipeline/load.ts`, `verify.ts`, `src/lib/db.ts`, `src/lib/geo.ts` (new)

## 11. Related Documentation

- `docs/tech-spec/04-database-design.md#3-raw-tables` — keys and indexes
- `docs/tech-spec/04-database-design.md#4-derived-and-application-tables` — column lists and setting defaults
- `docs/tech-spec/04-database-design.md#5-views` — view definitions
- `../../DATA_DICTIONARY.md` — source columns

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Duplicate rule matches more or fewer than 45 | Audit accuracy | Compare against the 45 unlinked work orders; all must match and nothing else |
| CSV quoting or Devanagari breaks the parser | Load fails | Use a real CSV parser with UTF-8; never split on commas |
| Prisma cannot model views | Build friction | Views live only in SQL migrations and are read with raw queries |

## 13. Progress Status

**Current status:** Complete

| Date | Progress | Commit |
|---|---|---|
| 2026-11-21 | Verified: verify passes on the main and the restored database, reference counts reproduced, load and views rerunnable, thresholds read from settings. | see git log |

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
