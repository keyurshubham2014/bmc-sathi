# New API fields for the screens

Branch `whose-delay`. The scorecard, plan and flag detail screens on this branch already use these fields. Everything here is additive: no existing field changed name, meaning or value. Examples are real responses from the loaded synthetic data. Base path `/api/v1`.

Why each figure exists is in `docs/ideas/2026-11-21-sathi-next-features.md`. The rules are in `apps/api/prisma/views.sql`.

## 1. Scorecard: `GET /contractors/:id` and `GET /wards/:code/scorecard`

`scorecard.measures` now has five keys. `speed`, `durability` and `cost` are unchanged.

| Key | observed | expected | n | band |
|---|---|---|---|---|
| `speed_fair` | Share on time among jobs assigned with enough time left | Same share for similar jobs | Jobs that had enough time | `well_above`, `above`, `similar`, `below`, `well_below`, `too_few` |
| `assign_wait` | Average hours from first complaint to assignment | Average for similar jobs | Jobs with a linked complaint | Wards: same bands, fewer hours is better. Contractors: always `context` |

Mahalaxmi (CT03):

```json
"speed":       { "observed": 0.39, "expected": 0.55, "n": 303, "band": "well_below" },
"speed_fair":  { "observed": 0.92, "expected": 0.93, "n": 113, "band": "similar" },
"assign_wait": { "observed": 76.1, "expected": 38.1, "n": 293, "band": "context" }
```

Ward L:

```json
"speed_fair":  { "observed": 0.87, "expected": 0.91, "n": 76,  "band": "similar" },
"assign_wait": { "observed": 62.6, "expected": 42.5, "n": 228, "band": "well_below" }
```

Screen rules:

- Show `speed` and `speed_fair` together for a contractor. Suggested labels: "On time, all jobs" and "On time, when there was enough time left".
- `assign_wait` is hours, not a share. A contractor's value is context: never draw it as a band, a dot on a range, or a colour.
- Word `assign_wait` as time, not fault: "jobs waited N hours before they were assigned". The data says when a job was assigned, not why or by whom. Do not write "ward office delay".
- `too_few` shows "not enough jobs to compare", as for the other measures.
- "Enough time left" means the target hours minus the wait covers what half of such jobs take once assigned. The share is the setting `fair_chance_pct` (0 to 1, default 0.5), editable on the Settings screen like the others.

**`scorecard.unreachable_targets`**: targets shorter than such work typically takes once assigned. Empty array when none.

```json
[ { "work_type": "Choked drain / nullah overflow", "sla_hours": 48, "typical_hours": 79.3, "jobs": 8 },
  { "work_type": "Open or broken manhole",         "sla_hours": 24, "typical_hours": 82.4, "jobs": 13 },
  { "work_type": "Road cave-in",                   "sla_hours": 24, "typical_hours": 83.9, "jobs": 9 },
  { "work_type": "Waterlogging",                   "sla_hours": 24, "typical_hours": 31.3, "jobs": 12 } ]
```

Suggested line: "13 manhole jobs had a 24-hour target; such work typically takes 82 hours once assigned." The list is wider than manholes and cave-ins: drains at 48 and 72 hours and waterlogging at 24 hours are in it too.

**`scorecard.late`**: the subject's missed jobs by cause, matching the three filters in section 2.

```json
{ "expired_before_assignment": 101, "too_little_time_left": 69, "had_time": 9 }
```

**`scorecard.redo`**: what re-opened fixes cost, and what the jobs that followed them cost.

```json
{ "reopened_jobs": 114, "reopened_spend": 5127412,
  "followed_up_jobs": 63, "followup_jobs": 63, "followup_spend": 2277869, "followup_by_other": 53 }
```

| Field | Meaning |
|---|---|
| `reopened_jobs`, `reopened_spend` | Jobs marked re-opened within 30 days, and what they cost |
| `followed_up_jobs` | Of those, how many were followed by another job on the same road and work type within 30 days |
| `followup_jobs`, `followup_spend` | The follow-up jobs themselves, each counted once, and their cost |
| `followup_by_other` | Failed jobs whose follow-up went to a different contractor |

Screen rules: say "followed by another job", never "redone by". The link is inferred from road, work type and date. No ordering of contractors by any of these.

## 2. Work orders behind the figures: `filter=` on `/contractors/:id/work-orders` and `/wards/:code/work-orders`

Five new values, used like the existing ones (`reopened`, `dlp`, and so on):

| Value | Lists |
|---|---|
| `fair_chance` | Jobs assigned with enough time left. `total` equals `speed_fair.n` |
| `expired_before_assignment` | Missed jobs whose target had already passed when they were assigned |
| `too_little_time_left` | Missed jobs assigned with less time left than such work typically takes |
| `had_time` | Missed jobs that had enough time |
| `followed_up` | Re-opened jobs followed by another job. `total` equals `redo.followed_up_jobs` |

CT03's 179 missed jobs with a complaint split 101 / 69 / 9 across the three causes. A stacked strip of the three, each part opening its list, tells the story in one line.

## 3. Plan: `GET /wards/:code/plan`

**New top-level `recoverable`** (all roles; totals only, no flag rows):

```json
"recoverable": { "ward_code": "L",
  "confirmed_billing": 0,      "confirmed_dlp": 0,       "confirmed_total": 0,
  "possible_billing": 574145,  "possible_dlp": 3959357,  "possible_total": 4533502 }
```

- `confirmed_*`: flags decided Confirmed. `possible_*`: flags still open or marked Needs explanation. Dismissed flags count nowhere.
- A job with two flags counts once. `billing` is over-billing excess and double billing; `dlp` is repairs billed on roads under defect liability.

**New on each item:**

| Field | Meaning |
|---|---|
| `within_recovered` | Funded if the confirmed amount came back |
| `within_possible` | Funded if confirmed and possible both came back |
| `road_jobs`, `road_spend` | Every loaded job on the item's road, any work type, and its total cost. 0 when the issue has no road |

Ward L, first item:

```json
{ "rank": 1, "road_name": "Kurla Andheri Road", "estimated_cost": 180000, "cumulative_cost": 180000,
  "within_budget": false, "within_recovered": false, "within_possible": true,
  "road_jobs": 35, "road_spend": 3052667 }
```

Screen rules:

- Keep the existing "budget runs out here" line where `within_budget` stops. It does not move.
- Draw a second line where `within_recovered` stops, labelled "if confirmed flags are recovered". Optionally a third, lighter, where `within_possible` stops: "if every open flag were recovered".
- Recovered money pays off overspend first. Ward L is ₹11.4 L over budget, so the first ₹11.4 L recovered funds nothing new.
- Never add these amounts to the remaining-budget figure. It is money not yet in hand.
- Show the DLP share on its own. The data does not name who is liable for a DLP road.
- Suggested item line: "35 jobs on this road this season, ₹30.5 L so far". No savings claim: there is no resurfacing price in the data.

City-wide today: budgets fund 332 of 660 open issues; 640 if every flag were recovered; 426 on billing flags alone.

## 4. Action pack: `POST /flags/draft`

Ward officers (own ward) and auditors. One draft for a group of flags decided Confirmed or Needs explanation.

```json
{ "kind": "dlp", "road_id": "RD0220", "lang": "en" }
{ "kind": "billing", "contractor_id": "CT03", "ward_code": "K/W", "lang": "mr" }
```

Add `"plain": true` to get the fixed template without calling Claude.

Response:

```json
{ "draft": { "title": "...", "body": "DRAFT FOR REVIEW. ...\n\nTo: The Roads Department\n..." },
  "source": "template", "lang": "en",
  "work_order_ids": ["WO25-02068", "WO25-00020"], "total_amount": 392774, "left_out": 0 }
```

| Status | When |
|---|---|
| 200 | A draft. `source` is `claude` or `template` |
| 409 `conflict` | No decided flags in the group yet |
| 403 | A citizen, or an officer outside their ward |
| 404 | Unknown road or contractor |
| 429 | More than 10 Claude drafts or Ask questions a minute for this user |

Screen rules:

- Offer the button on a flag once it is Confirmed or Needs explanation. For a DLP flag send the flag's `road_id`; for an over-billing or double-billing flag send its `contractor_id` and `ward_code`.
- Show `body` as plain text with a copy button. Line breaks are `\n`.
- When `source` is `template` and Marathi was asked for, `lang` comes back `en`: say the Marathi version is unavailable just now.
- When `left_out` is above 0, the body already says how many smaller jobs are not listed.
- Calls can take up to 20 seconds before the template is returned; show progress.
- The Claude path was tried once in the running app (a DLP draft for RD0220, 21 Nov 2026) and returned a draft that passed the check.

## 5. Settings: `GET` and `PUT /settings`

One new key, `fair_chance_pct`, range 0 to 1. A value outside the range returns 400.

## Before this reaches the live database

- Run `npm run db:seed` (adds the setting) and `npm run db:views`.
- All stored ward and contractor summaries will read as written before recent changes until `npm run db:summarise` is run again, because the facts behind them now include the new figures.
