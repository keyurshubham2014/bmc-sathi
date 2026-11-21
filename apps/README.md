# BMC Sathi · Roads

Independent prototype. Not an official BMC product. All data is synthetic.

Follows each rupee of Mumbai's monsoon road spend: complaint → issue → work order → road → outcome.
Rules decide what is flagged; Claude only explains figures the rules have already computed.

## Run it

Needs Docker, Node 20 and Flutter 3.47.

```bash
# 1. Database (Postgres 17 on port 5440)
docker compose up -d

# 2. API (port 4000)
cd apps/api
cp .env.example .env          # optional: paste ANTHROPIC_API_KEY to enable Ask
npm install
npm run db:setup              # schema, rule views, demo users, load CSVs, group complaints, verify
npm run dev

# 3. Web app (port 5173)
cd apps/web
flutter run -d web-server --web-port 5173 --web-hostname localhost
```

Open http://localhost:5173 and tap a demo account: ward officer (Ward E), city auditor, or citizen.
The password is `DEMO_PASSWORD` in `apps/api/.env`.

`npm run db:setup` is safe to rerun. For a clean slate: `npx prisma migrate reset`, then `npm run db:setup`.
`npm test` (API, 31 tests) and `flutter test` (web) check the rules against the planted anomalies.

## Demo path (about 4 minutes)

1. **Auditor → Overview.** ₹13.43 cr spent, six wards over budget, Ward E at 119%.
2. **Ward E → Money trail.** Spend by contractor, method and week; every number opens the jobs behind it.
3. **Flags → Possible double billing.** Two jobs side by side: same road, work, contractor and area, days apart, no complaint. Record a decision.
4. **Contractors.** Speed, durability and cost against similar jobs (same work, method, rain and ward type). No rank.
5. **Ward → Plan.** Open issues ranked by risk, with a method, a cost and the line where the budget runs out. Expand one to see how its score is made up.
6. **Settings.** Change a risk weight; the plan re-ranks at once.
7. **Ward officer → New record.** Enter a bill at twice the rate card; it is flagged on save. Remove it afterwards.
8. **Trail.** Search a complaint id or road and follow it end to end.

## Where things are

| | |
|---|---|
| `apps/api/prisma/views.sql` | Every audit, scorecard and plan rule, as SQL views. Thresholds and weights live in the `setting` table |
| `apps/api/src/pipeline/` | `load` (CSV → tables), `enrich` and `group` (complaints → located issues), `social` (posts → issues), `summarise` (written summaries), `verify` (reference counts) |
| `apps/api/src/modules/` | One file per API area: wards, flags, contractors, trail, intake, settings, ask |
| `apps/web/lib/features/` | One folder per screen |
| `docs/` | PRD, tech spec, task plan, design brief |

## Real data

Replace the CSVs in `data/` with real exports in the same columns (see `DATA_DICTIONARY.md`) and run
`npm run db:setup`. Nothing in the rules refers to a specific ward, contractor or date. To move to Neon,
change `DATABASE_URL` and `DIRECT_URL`.

## Known limits

- Without `ANTHROPIC_API_KEY`, complaint text is read by rules only (category as reported, a default severity
  per category), Ask reports that it is not set up, and no summaries or social-post labels are written.
- With a key, Claude translates complaints, corrects the category and reads severity; its output was
  spot-checked, not measured against a labelled set.
- Summaries are written by `npm run db:summarise`, which is not part of `db:setup`. A summary whose figures have
  since changed is marked as written before recent changes.
- Fallback for the demo: dump and restore steps are in the root README under Development.
