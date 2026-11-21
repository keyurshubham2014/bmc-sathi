# BMC Sathi · Roads

Follow each rupee of Mumbai's monsoon road spend, from complaint to repair to outcome.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Note:** Independent prototype, not an official BMC product. All data in this repository is synthetic.

![City overview: budget, spend, open flags and wards over budget](docs/screenshots/overview.jpg)

## Table of contents

- [About](#about)
- [Getting started](#getting-started)
- [Usage](#usage)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Database](#database)
- [API reference](#api-reference)
- [Development](#development)
- [Known limits](#known-limits)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [Acknowledgments](#acknowledgments)

---

## About

BMC Sathi was built for the "Follow the Rupee: Mumbai Monsoon Roads" challenge at Claude Impact Lab Mumbai.
It loads a season of road-repair records and answers three questions: where did the money go, who did
the work well, and where should the next rupee be spent.

Rules written in SQL decide what is flagged. Claude reads complaint text and explains figures the rules
have already computed; it does not decide what is flagged.

**Features**

- **Money trail.** Budget against spend for 24 wards, broken down by contractor, repair method and week. Every figure opens the work orders behind it.
- **Audit flags.** Over-billing against the rate card, possible double billing, and repairs billed on roads still under defect liability. Each flag shows its evidence and takes a recorded decision.
- **Scorecards.** Speed, durability and cost for each contractor and ward, compared with similar jobs (same work type, repair method, rain band and ward type). No ranking.
- **Next-rupee plan.** Open issues ranked by a risk score with a visible breakdown, a recommended repair method, an estimated cost and the point where the ward's budget runs out.
- **Trail.** Search a complaint id, work order id, road or locality and follow it: complaints, issue, work order, road, outcome, with matching social media posts.
- **New records.** A ward officer adds a work order or complaint; the same rules apply on save.
- **Ask and summaries.** Plain-language answers and short summaries, in English and Marathi, written by Claude from the figures on the page.
- **Three roles** (ward officer, auditor, citizen), English and Marathi, light and dark themes.

**Tech stack**

| Layer | Technology |
|---|---|
| Web app | Flutter (Dart SDK ^3.13.1), flutter_riverpod 3.5, go_router 18.1, dio 5.11, intl 0.20, flutter_map 8.3 |
| API | Node.js, Express 5.3, TypeScript 7.0, Zod 4.6 |
| Data | PostgreSQL 17 (Docker), Prisma 6.19 |
| AI | @anthropic-ai/sdk 1.12 (`claude-haiku-5-5` for the pipeline, `claude-sonnet-5-5` for Ask and summaries) |
| Tests | Vitest 4.1 with supertest (API), flutter_test (web) |

---

## Getting started

### Prerequisites

- Docker, for the Postgres 17 container
- Node.js. No version is pinned in `package.json`; the project was built and tested on Node 20.20.
- Flutter. Built and tested on Flutter 3.47.1 (stable).
- Optional: an Anthropic API key, for the Claude features

### Install and run

1. Start the database. It listens on host port 5440.

   ```bash
   docker compose up -d
   ```

2. Configure and prepare the API.

   ```bash
   cd apps/api
   cp .env.example .env    # then set JWT_SECRET and DEMO_PASSWORD; add ANTHROPIC_API_KEY if you have one
   npm install
   npm run db:setup        # schema, rule views, demo users, CSV load, complaint grouping, checks
   ```

3. Start the API on port 4000.

   ```bash
   npm run dev
   ```

4. In a second terminal, start the web app on port 5173.

   ```bash
   cd apps/web
   flutter run -d web-server --web-port 5173 --web-hostname localhost
   ```

5. Open http://localhost:5173 and tap a demo account.

### Environment variables

API, in `apps/api/.env`:

| Variable | Required | Description | Example |
|---|---|---|---|
| `DATABASE_URL` | Yes | Postgres connection used by Prisma | `postgresql://sathi:sathi@127.0.0.1:5440/sathi` |
| `DIRECT_URL` | Yes | Direct (unpooled) connection used for migrations | `postgresql://sathi:sathi@127.0.0.1:5440/sathi` |
| `JWT_SECRET` | Yes | Signs sign-in tokens. The API does not start without it | a long random string |
| `DEMO_PASSWORD` | No | Password given to the three seeded demo accounts by `npm run db:seed` | see `.env.example` |
| `ANTHROPIC_API_KEY` | No | Enables Ask, summaries and Claude's reading of complaints and social posts. Without it the pipeline runs on rules only | `sk-ant-...` |
| `PORT` | No | API port. Defaults to `4000` | `4000` |
| `WEB_ORIGIN` | No | Origin allowed by CORS. Defaults to `http://localhost:5173` | `http://localhost:5173` |

Web app, passed at build time with `--dart-define`:

| Variable | Required | Description | Example |
|---|---|---|---|
| `API_BASE` | No | Base URL of the API. Defaults to `http://localhost:4000/api/v1` | `http://localhost:4000/api/v1` |
| `DEMO_PASSWORD` | No | Password the demo-account buttons send. Must match the API's value | same as the API |

```bash
# Only needed if you changed the defaults
flutter run -d web-server --web-port 5173 --web-hostname localhost \
  --dart-define=API_BASE=http://localhost:4000/api/v1 --dart-define=DEMO_PASSWORD=your-password
```

---

## Usage

### Demo accounts

| Username | Role | Sees |
|---|---|---|
| `officer.e` | Ward officer, Ward E | Ward E only, its flag queue, and the New record screen |
| `auditor` | City auditor | All wards, all flags, and rule settings |
| `citizen` | Citizen | Money trail, scorecards, plan and trail; flag totals but not the flag queue |

### A walk through the app

1. **Overview** (auditor): city totals, the ward map and the wards over budget. Tap a ward to select it, tap again to open it.
2. **Ward → Money trail**: spend by contractor, method and week. Each figure opens its work orders.

   ![Ward money trail with a written summary](docs/screenshots/ward-money-trail.jpg)

3. **Flags → Possible double billing**: two jobs side by side, with the fields that match. Record a decision.

   ![Double-billing evidence: two jobs on the same road, three days apart](docs/screenshots/flag-evidence.jpg)

4. **Contractors**: three measures against similar jobs.

   ![Contractor scorecard](docs/screenshots/scorecard.jpg)

5. **Ward → Plan**: ranked open issues. Expand one to see how its risk score is made up.

   ![Next-rupee plan with a score breakdown](docs/screenshots/plan.jpg)

6. **Settings** (auditor): change a threshold or risk weight. Flags, scorecards and the plan update at once.
7. **New record** (ward officer): enter a work order billed well above the rate card; it is flagged on save.
8. **Trail**: search a complaint id, work order id, road or locality.

   ![Trail: translated complaints, the issue and matching social posts](docs/screenshots/trail.jpg)

### Pipeline commands

Run from `apps/api`. `npm run db:setup` runs all of these except `db:summarise`.

```bash
npm run db:load        # load the CSVs in data/ (skips rows already loaded)
npm run db:enrich      # read complaints: rules first, then Claude if a key is set
npm run db:group       # locate complaints and group them into issues
npm run db:social      # label social posts with Claude and match them to issues
npm run db:summarise   # write ward and contractor summaries (needs a key)
npm run db:verify      # check counts against the dataset's known anomalies
```

`db:enrich`, `db:social` and `db:summarise` call the Claude API and cost money when a key is set.
`db:enrich` and `db:social` accept `--no-claude` to stay on rules only.

---

## Architecture

```mermaid
flowchart LR
  CSV[data/*.csv] --> L[load]
  L --> DB[(PostgreSQL)]
  DB --> E[enrich] --> G[group] --> S[social] --> SM[summarise]
  E & G & S & SM --> DB
  C[Claude API] -. reads text, writes summaries .-> E & S & SM
  DB --> V[SQL views: flags, scorecards, plan]
  V --> API[Express API]
  API --> WEB[Flutter web app]
  WEB -- new records, decisions, settings --> API --> DB
  API -. Ask .-> C
```

The pipeline runs once and stores what it learns. The audit rules are SQL views, so a new work order, a
recorded decision or a changed setting takes effect on the next read without re-running anything.

---

## Project structure

```
.
├── apps/
│   ├── api/
│   │   ├── prisma/
│   │   │   ├── schema.prisma      # tables
│   │   │   ├── migrations/        # initial migration
│   │   │   ├── views.sql          # every audit, scorecard and plan rule
│   │   │   └── seed.ts            # rule settings and demo users
│   │   ├── src/
│   │   │   ├── pipeline/          # load, enrich, group, social, summarise, verify
│   │   │   ├── modules/           # one router per API area
│   │   │   ├── middleware/        # sign-in and role checks
│   │   │   ├── lib/               # db client, errors, geometry, shared rules, Claude helper
│   │   │   ├── app.ts             # Express app
│   │   │   └── server.ts          # entry point
│   │   └── test/api.test.ts       # API tests against the loaded database
│   └── web/
│       ├── lib/
│       │   ├── core/              # theme, strings (EN/MR), session, formatting, shared widgets
│       │   ├── features/          # one folder per screen
│       │   ├── router.dart        # routes and role redirects
│       │   └── main.dart
│       └── test/core_test.dart
├── data/                          # synthetic CSVs and GeoJSON
├── docs/                          # PRD, tech spec, task plan, design brief, screenshots
├── docker-compose.yml             # Postgres 17
└── DATA_DICTIONARY.md             # column reference for data/
```

---

## Database

Tables are defined in `apps/api/prisma/schema.prisma`.

| Group | Tables |
|---|---|
| Loaded from CSV | `ward`, `locality`, `road`, `traffic`, `flood_hotspot`, `facility`, `accident`, `rainfall_daily`, `tide`, `rate_card`, `contractor`, `complaint`, `social_post`, `work_order` |
| Derived by the pipeline | `work_order_complaint`, `road_proximity`, `complaint_enriched`, `issue`, `social_post_label`, `summary` |
| Written by the app | `flag_decision`, `setting`, `app_user` |

Rules live in `apps/api/prisma/views.sql`, which is safe to re-run with `npm run db:views`:

| View | What it gives |
|---|---|
| `v_work_order` | Each work order with its expected cost, cost ratio, road details and rain band |
| `v_flag` | Over-billed, watch, duplicate and DLP flags, joined to any recorded decision |
| `v_ward_money`, `v_ward_spend_breakdown` | Budget against spend, and spend by contractor, method and week |
| `v_scorecard` | Speed, durability and cost for contractors and wards against similar jobs |
| `v_method_durability` | Re-open rate of each repair method, by road type |
| `v_open_issue_risk`, `v_plan` | Risk score for each open issue, and the ranked plan with method, cost and budget line |

Thresholds and risk weights are rows in `setting`, read by the views through the `cfg(key)` function.

---

## API reference

Base path `/api/v1`. Every route except `POST /auth/login` needs `Authorization: Bearer <token>`.

| Method | Path | Description | Auth |
|---|---|---|---|
| POST | `/auth/login` | Sign in; returns a token and the user | Public |
| GET | `/auth/me` | The signed-in user | Any role |
| GET | `/wards` | Money row for every ward | Any role |
| GET | `/wards/:code` | One ward's money, amounts in question and flag counts | Any role; a ward officer only for their ward |

<details>
<summary>All routes</summary>

| Method | Path | Description | Auth |
|---|---|---|---|
| GET | `/wards/:code/breakdown` | Spend by contractor, method or week | Any role |
| GET | `/wards/:code/work-orders` | Work orders in a ward, with filters and paging | Any role |
| GET | `/wards/:code/scorecard` | The ward's three measures | Any role |
| GET | `/wards/:code/plan` | Ranked open issues with method, cost and budget line | Any role |
| GET | `/flags` | Flag queue, by type and decision state | Ward officer, auditor |
| GET | `/flags/summary` | Count and amount at stake by type and decision | Any role |
| GET | `/flags/:type/:workOrderId` | One flag with its evidence | Ward officer, auditor |
| PUT | `/flags/:type/:workOrderId/decision` | Record a decision | Ward officer, auditor |
| GET | `/contractors` | Contractors in name order | Any role |
| GET | `/contractors/:id` | One contractor with its scorecard | Any role |
| GET | `/contractors/:id/work-orders` | That contractor's work orders | Any role |
| GET | `/trail/search?q=` | Complaints, work orders and issues matching a term | Any role |
| GET | `/trail/issue/:id` | The trail for an issue | Any role |
| GET | `/trail/complaint/:id` | The trail for the issue a complaint belongs to | Any role |
| GET | `/trail/work-order/:id` | The trail for a work order | Any role |
| GET | `/intake/options` | Roads, methods, contractors and categories for the forms | Ward officer |
| POST | `/intake/work-orders` | Add a work order; returns any flags it raises | Ward officer |
| DELETE | `/intake/work-orders/:id` | Remove a work order added through intake | Ward officer |
| POST | `/intake/complaints` | Add a complaint; returns its issue and plan rank | Ward officer |
| GET | `/settings` | Rule thresholds and risk weights | Auditor |
| PUT | `/settings` | Change settings; the six risk weights must total 100 | Auditor |
| POST | `/ask` | Ask a question about one ward, contractor or issue. Limited to 10 a minute per user | Any role |
| GET | `/ask/summary` | The stored summary for a ward or contractor, with `stale` set when its figures have since changed | Any role |

</details>

**Example**

```bash
curl -s http://localhost:4000/api/v1/auth/login \
  -H 'content-type: application/json' \
  -d '{"username":"auditor","password":"<DEMO_PASSWORD>"}'
```

```json
{
  "token": "<jwt>",
  "user": { "user_id": 2, "username": "auditor", "display_name": "City Auditor", "role": "auditor", "ward_code": null }
}
```

**Errors** are returned as JSON with a `code`:

| Status | Code |
|---|---|
| 400 | `validation_failed` |
| 401 | `not_signed_in` |
| 403 | `not_allowed` |
| 404 | `not_found` |
| 409 | `conflict` |
| 429 | `too_many_requests` |
| 502 | `assistant_unavailable` |
| 500 | `server_error` |

---

## Development

API scripts, from `apps/api`:

| Script | What it does |
|---|---|
| `npm run dev` | Start the API with reload on change |
| `npm test` | Run the API tests. They need the database loaded by `db:setup` |
| `npm run db:setup` | Migrate, create views, seed, load, enrich, group, match social posts, verify |
| `npm run db:migrate` | Apply Prisma migrations |
| `npm run db:views` | Recreate the rule views |
| `npm run db:seed` | Write rule settings and demo users |

The pipeline scripts are listed under [Usage](#pipeline-commands).

Web app, from `apps/web`:

```bash
flutter test       # unit tests: money formatting, strings, theme contrast
flutter analyze    # static analysis, configured in analysis_options.yaml
```

To start from an empty database: `npx prisma migrate reset` in `apps/api`, then `npm run db:setup`.

### Database dump and restore

A dump lets you bring back a loaded database without re-running the pipeline. `*.dump` files are ignored by git.

```bash
# Save
mkdir -p backup
docker exec bmc-sathi-db pg_dump -U sathi -Fc sathi > backup/sathi.dump

# Restore into a second database
docker exec bmc-sathi-db psql -U sathi -d postgres -c "create database sathi_fallback"
docker exec -i bmc-sathi-db pg_restore -U sathi -d sathi_fallback < backup/sathi.dump
```

To use the restored copy, change the database name at the end of `DATABASE_URL` and `DIRECT_URL` in `apps/api/.env` to `sathi_fallback` and restart the API.

---

## Known limits

- Scores and matches depend on the synthetic dataset; none of it has been run on real BMC data.
- Claude's reading of complaints (translation, category, severity) and its matching of social posts were spot-checked, not measured against a labelled set.
- `npm run db:summarise` is not part of `db:setup`. Summaries are not rewritten automatically when figures change; the page marks them as written before recent changes until it is run again.
- The Ask rate limit (10 questions a minute per user) is kept in the API's memory, so it resets on restart and is not shared between instances.
- There is no deployment configuration; only the local Docker database is set up.
- The API has no linter configured, and no CI runs the tests.
- The overview map uses real BMC ward boundaries (`apps/web/assets/geo/wards.geojson`) over OpenStreetMap's public tile server, so it needs a network connection, and that server is not meant for heavy use. Everything plotted on it (spend, flags) is synthetic. `data/wards.geojson` is the challenge's simplified file and is no longer drawn.

---

## Contributing

Contributions are welcome. Open an issue to discuss a change, or send a pull request with tests for any rule you change.

## License

[MIT](LICENSE)

## Contact

Keyur Patel · [github.com/keyurshubham2014](https://github.com/keyurshubham2014)

## Acknowledgments

Thanks to Claude Impact Lab Mumbai for the "Follow the Rupee: Mumbai Monsoon Roads" challenge and its synthetic dataset. The original brief is in [docs/CHALLENGE.md](docs/CHALLENGE.md).

Ward boundaries are from OpenCity, via [bharatlas.com](https://bharatlas.com/view/wards_mumbai), under CC0. Map tiles are © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors.
