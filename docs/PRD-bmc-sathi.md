# BMC Sathi (BMC साथी): Product Requirements

**Module 1: Roads. "Follow the Rupee" for Mumbai monsoon road repairs.**
Version 1.0 · 21 November 2026 · Owner: Keyur Patel · Status: draft for approval

> Independent prototype. Not an official BMC product. All data is synthetic and every contractor is fictional.

---

## 1. Summary

BMC Sathi is a ward-level accountability and budgeting tool. For any ward it answers three questions:

1. **Where did the money go?** Budget, spend, and the share spent on work that failed or should not have been billed.
2. **Did the fix last?** Re-opened repairs, by contractor, method and road.
3. **Where should the next rupee go?** Open issues ranked by risk, with a method and a cost.

Roads is the first module. The name, navigation and data model leave room for other departments (drains, solid waste, water) without renaming or restructuring.

**Build window:** 6 to 10 hours, demoed the same day on a projector.

## 2. Users and roles

Three seeded demo accounts. The role is carried in the session and enforced by the API.

| Role | Starts at | Can do |
|---|---|---|
| **Ward officer** (Assistant Commissioner, ward engineer) | Their own ward | See the ward's money trail, review flags and record decisions, read the next-rupee plan, add a work order or complaint |
| **City auditor** (head office, vigilance) | All 24 wards | Compare wards and contractors, work the city-wide flag queue, record decisions |
| **Citizen / corporator** | A ward they choose | Read the ward summary and contractor scorecards in plain language, look up a complaint, ask a question. Read-only |

All three roles use the same six screens. They differ in the starting screen, the scope of data and whether actions are enabled.

## 3. Goals, non-goals, anti-goals

**Goals**

- Flag real billing problems and nothing else, with the evidence beside every flag.
- Describe contractor and ward performance against comparable work, never against a raw average.
- Rank open issues for each ward's remaining budget, with a reason for every position.
- Let anyone follow one item end to end: complaint → issue → work order → road → contractor.
- Run on real BMC data by reloading the tables, with no code change to the rules.

**Non-goals for this build**

- Citizen complaint filing with photos (Saarthee's job, not this tool's).
- Real authentication (SSO, OTP), user management, or audit logs beyond flag decisions.
- Moving budget between wards.
- Native phone builds. The web build reflows to phone width.
- Hindi interface labels. Complaints and questions in Hindi are still understood.

**Anti-goals: the product has failed if it does any of these**

- Shows a single grade, rank or league table for contractors.
- Flags a job without linking the rows that justify it.
- Uses accusatory words (fraud, scam, corrupt). Flags say what the data shows and what to check.
- Lets Claude decide a flag or a score. Rules decide; Claude explains.
- Uses the BMC crest or implies BMC endorsement.

## 4. How the rubric maps to features

| Criterion | Weight | Feature that earns it |
|---|---:|---|
| Audit accuracy | 25% | F2 Audit flags |
| Fair accountability | 20% | F3 Scorecards |
| Budget recommendation | 20% | F4 Next-rupee plan |
| Connects the trail | 15% | F5 Trail view, issue pipeline (§6) |
| Usable by a real person | 10% | Roles, flag decisions, plain language, Marathi |
| Demo and clarity | 10% | Live intake (F7), demo script (§10) |

## 5. Features

### F1. Ward money trail

For one ward: budget, spend to date, and remaining or overspent amount. Spend broken down by contractor, by repair method and by week. Three "money at question" tiles: spent on fixes that re-opened within 30 days, billed on roads under DLP, and held in open flags.

- A city view shows all 24 wards on a map shaded by spend against budget, with a sortable table beside it.
- Claude writes a summary of about 120 words per ward in English and Marathi, stored at pipeline time, built only from the ward's computed figures.

*Done when:* every figure on the ward page can be tapped to list the work orders behind it, and the totals match the raw data (city total ₹13.43 crore).

### F2. Audit flags

Each flag has a type, the rupees at stake, a one-line reason, the evidence rows and a decision state.

| Flag type | Rule | Found in the supplied data |
|---|---|---|
| **Over-billed** | Cost is more than 1.5 times the expected cost (area × rate for per-sqm methods, the flat rate for per-job methods) | 109 jobs. Normal jobs sit between 0.77x and 1.3x; only 5 fall between 1.3x and 1.5x |
| **Possible double billing** | A work order with no linked complaint that repeats an earlier job on the same road, same work type, same contractor and same area (within 5%), within 7 days | 45 jobs. All 45 unlinked work orders match this pattern |
| **Billed under DLP** | A paid work order on a road with `under_dlp = Y` | 493 jobs, ₹2.62 crore |

Rules that keep normal variation out:

- Jobs between 1.3x and 1.5x of the rate card appear as "watch", not as flags.
- 621 other pairs of jobs repeat on the same road within 7 days but have complaints linked. These are repeat work, not double billing, and are not flagged.
- Missed SLAs and re-opened repairs are **performance signals**, shown on scorecards and the ward page. They are not billing flags: half of all jobs missed SLA, so flagging them would bury the real problems.
- DLP flags are a separate tab titled "Recover under DLP". The wording names the road's original contractor as liable, not the contractor who did the repair, because the dataset does not say they are the same.
- Thresholds (1.5x, 7 days, 5%) are stored as settings, not written into the rules, so they can be tuned for real data.

**Decisions.** A ward officer or auditor opens a flag and records one of: *Confirmed*, *Needs explanation*, *Not an issue*, with a note. The queue shows open flags first, with rupees at stake. Decisions are stored with user and time.

*Done when:* the flag counts above are reproduced exactly, every flag opens to its evidence (for double billing, both work orders side by side), and a decision persists after reload.

### F3. Contractor and ward scorecards

Three measures, each compared with similar jobs. No overall grade and no ranking.

```
Mahalaxmi Civil Contractors (synthetic)
303 jobs · ₹1.62 cr · 24 wards

SPEED       39% on time
            similar jobs: 47%          [ below ]

DURABILITY  38% re-opened within 30 days
            similar jobs: 24%          [ well below ]

COST        1.08x rate card (typical job)
            42 jobs above 1.5x         [ review ]

> See the 42 jobs    > See re-opened jobs
```

- **Similar jobs** means the same work type and repair method, in the same rain band (rainfall on the days of the job: dry, moderate, heavy) and the same ward type (low-lying index at or above 0.6, or below). The contractor's own jobs are left out of their comparison.
- Each measure gets a band: well above, above, similar, below, well below. A band other than "similar" is shown only when the gap is larger than chance would explain for that number of jobs; otherwise it reads "similar" or "too few jobs to say".
- Under each measure is the context: how many of the jobs were in heavy-rain weeks and low-lying wards.
- Claude writes a summary under 120 words in English and Marathi from the computed measures. It must name one thing to improve and must not make accusations.
- A ward scorecard uses the same three measures for the work done in that ward.

Findings that shaped this design:

- Rain and low-lying wards shift results only slightly in this dataset (re-opens 24% to 27%; SLA misses 47% in normal wards against 53% in low-lying ones). The adjustment is kept because real data will differ, and showing it is what makes the comparison fair.
- `engineer_remark` carries no signal. "Rain delayed work" jobs miss SLA at the same rate as the rest (53% against 50%). Remarks are shown as recorded but are not used in any score.

*Done when:* all 8 contractors and 24 wards have a scorecard, every measure links to its work orders, and no screen sorts contractors by a combined score.

### F4. Next-rupee plan

For one ward: open issues ranked by risk, each with a recommended method, an estimated cost and its reasons. A line marks where the remaining budget runs out. An overspent ward sees the same list headed "needs additional budget".

```
Ward L · ₹4.2 L left of ₹61 L

1  LBS Marg seg 3 · Road cave-in
   Risk 92 · ambulance route to a hospital,
   2 pothole accidents, bus route
   Method: Excavation and PQC patch · est ₹1.8 L

2  Kurla Depot Rd · Pothole cluster (14 complaints)
   Risk 81 · flood hotspot, 11k vehicles/hr
   Method: Hot mix patch · est ₹0.9 L
   (cold mix re-opens 35% on busy roads)

------ budget runs out here ------

3  ...  est ₹1.1 L   (needs ₹0.6 L more)
```
*(Illustrative figures.)*

**Risk score, 0 to 100.** A weighted sum, with weights stored as settings and the contribution of each part shown on the item:

| Part | Source |
|---|---|
| Severity (1 to 5) | Work type, plus Claude's reading of the description and photo description |
| Demand | Number of complaints in the issue, upvotes, days open |
| Flood exposure | Flood hotspot within range, tide-sensitive flag, ward low-lying index |
| Traffic | Peak-hour vehicles, bus routes, two-wheeler share |
| Safety record | Accidents on that road caused by potholes, waterlogging or uneven surface, weighted by severity |
| Critical access | Road is an ambulance entry road for a hospital, or has a school on it |

**Method.** Five of the six work types have one method, so the choice only matters for potholes and waterlogging. For potholes, measured re-open rates are cold mix 32%, mastic 26%, hot mix 23%. Cold mix is still the cheaper option per square metre even after counting redone work (₹1,800 × 1.32 against ₹2,600 × 1.23). The rule is therefore:

- High-risk roads (highway or arterial, ambulance route, bus route, or risk at or above a set level): recommend the method with the lowest measured re-open rate for that road type and surface. On highways this is hot mix (10% against 37% for cold mix).
- Other roads: recommend the method with the lowest expected cost including redone work.
- Always show both costs and the re-open rate used, so the officer can overrule it.

*Done when:* all 24 wards have a ranked list, every item shows its reasons and score parts, the cumulative cost and budget line are correct, and changing a weight changes the order.

### F5. Trail view

One screen for one item, reachable from anywhere: complaints (with original text and a translation), the cleaned issue they belong to, the work orders that addressed it, the road (surface, last resurfaced, DLP), the contractor, the cost against the rate card, whether SLA was met and whether it re-opened. Issues with no work order are marked "never fixed".

Searchable by complaint id, work order id, road name or locality. This is also the citizen's "what happened to my complaint" screen.

*Done when:* a complaint id leads to its work order and back, and an open issue shows its place in the next-rupee plan.

### F6. Ask

A question box on the ward page and the trail view. Claude answers in the language of the question (English, Marathi, Hindi or Hinglish) using only facts fetched from the database for that ward, complaint or contractor, and lists the record ids it used. If the data does not contain the answer, it says so.

This is the only feature that calls Claude while the app is running. If the call fails, the box shows a plain error and the rest of the app is unaffected.

### F7. Live intake

A form for a ward officer to add a work order or a complaint. On save, the same rules run: a new work order that copies an existing job appears in the flag queue at once, and the ward spend and contractor scorecard update. A new complaint is located by locality and attached to an existing open issue or starts a new one, using rules only (no Claude call).

## 6. From complaints to issues

Runs once in the pipeline, over all 6,501 complaints and 650 social posts.

1. **Locate.** Use GPS where present (58% of complaints). Otherwise match `locality_text` against the gazetteer and its aliases, including Devanagari. Fill the 457 missing ward codes from the location.
2. **Read.** Claude processes complaints in batches and returns, for each one: the corrected category (about 18% are wrong or vague), a severity from 1 to 5, the road or landmark named, and an English translation. Results are stored; the original text is always kept and shown.
3. **Group.** Complaints of the same category on the same road or within a set distance, inside a time window, become one issue. The 1,014 complaints BMC already marked duplicate are checked against this grouping.
4. **Link.** An issue is linked to a work order through `linked_complaint_ids`. Issues with no link, and still open, feed the next-rupee plan (896 complaints are open or in progress).
5. **Social posts.** Claude marks each post as a road issue, thanks, sarcasm or noise. Posts about road issues are attached to issues as supporting evidence only. They never create a flag or change a score.

Complaints forwarded to other agencies or rejected as not BMC roads are kept in the trail but left out of the plan.

## 7. Approaches considered

| Approach | Trade-off | Decision |
|---|---|---|
| **A. Pipeline once, thin API** | Repeatable numbers and fast screens, but nothing reacts to new data | Used for Claude's complaint clean-up and written summaries |
| **B. Rules computed live in the database** | Always current, reacts to new rows; cannot include Claude's slow work | Used for flags, scorecards and rankings |
| **C. Claude does the auditing** | Quick to start; results vary between runs and miss rows at this volume | Rejected. Audit accuracy is the largest criterion |

**Chosen: A and B together.** The pipeline loads the files and stores what Claude produces. Flags, scores and rankings are database views over the raw tables, so they recalculate on every read and respond to new records.

## 8. Technical decisions already made

For the technical specification to build on:

- **Frontend:** Flutter, web build as the demo target, responsive from projector width down to phone width.
- **Backend:** Node.js with Express and TypeScript, matching Saarthee.
- **Database:** PostgreSQL on Neon. Audit rules, scorecards and risk ranking are SQL views. Thresholds and weights live in a settings table.
- **Claude:** used in the pipeline (complaint reading, social post sorting, summaries in two languages) and in one live endpoint (Ask). The API key stays on the server.
- **Auth:** three seeded accounts, session token, role checked on every API route. Marked for replacement.
- **Libraries to carry over from Saarthee:** Riverpod, go_router, dio, flutter_map, shared_preferences, intl.

*My calls, open to change in the tech spec:* SQL views over materialised tables (2,499 work orders is small enough); PostGIS only if nearest-road matching needs it; hosting for the API and web build.

## 9. Design and theme

**Character.** A public ledger: calm, dense, numerical. It should look like something a ward office would leave open all day, not a consumer app.

**Layout.** Wide screens get a left rail (Overview, Flags, Contractors, Plan, Trail), a map-and-table main area and a detail panel on the right. Below tablet width the rail becomes a bottom bar and panels become full screens.

**Theme control.** Light, dark and system, saved per device, with the same structure as Saarthee: one set of semantic colour tokens exposed as a Flutter theme extension, screens never use raw colours, and a test checks contrast for every text and background pair.

Starting palette, to be contrast-tested:

| Token | Light | Dark | Used for |
|---|---|---|---|
| primary | `#123A6B` | `#8DB4F0` | Navigation, links, primary buttons |
| accent | `#0E7C86` | `#5CC6CF` | Charts, selected states (monsoon teal) |
| background | `#F4F6F9` | `#0E1520` | Page |
| surface | `#FFFFFF` | `#172131` | Cards, tables |
| textPrimary | `#14202E` | `#E6ECF4` | Body text |
| textSecondary | `#4A5868` | `#A3B1C2` | Labels |
| flag / flagTint | `#9A5B00` / `#FFF4E0` | `#F2B84B` / `#3A2C0E` | Audit flags, "watch" |
| error / success / info | `#B3261E` / `#1A7340` / `#1F5FAE` | lighter equivalents | Status only |

Rules:

- Colour never carries meaning alone. Every band and flag has a text label.
- Red is for confirmed problems and overspend only. Unreviewed flags are amber.
- Money uses Indian grouping and lakh/crore (₹1.62 cr, ₹4.2 L), with tabular numerals so columns align.
- One typeface that covers Latin and Devanagari at equal weight (Mukta or Noto Sans with Noto Sans Devanagari).
- English and Marathi toggle in the header, saved per device. Layouts must hold Marathi labels, which run longer.
- A "Synthetic data" tag is always visible in the header.
- Keyboard focus is visible and tables are usable without a mouse.

## 10. Demo script (about 4 minutes)

1. Sign in as **auditor**. City map: 24 wards, six over budget. Ward E is at 119%.
2. Open Ward E. Money trail, and the three "money at question" tiles.
3. Open a **double-billing flag**. Two work orders side by side: same road, same area, same contractor, 2 days apart, no complaint on the second. Record "Needs explanation".
4. Follow the first work order's **trail** back to its complaints, one in Marathi with its translation.
5. Open the contractor's **scorecard**. Three measures against similar jobs, no grade.
6. Sign in as **ward officer**. **Next-rupee plan** with the budget line and the reasons on the top item.
7. **Live intake:** add a work order that copies an existing job. The flag appears and the ward spend moves.
8. Switch to **Marathi** and to **dark theme**. Ask a question in Marathi as a citizen.

## 11. Build order and what to cut

| Order | Work | Hours |
|---|---|---:|
| 1 | Load 15 files into Neon; flag, scorecard and ranking views; check counts against §5 | 1.5 |
| 2 | API routes and seeded login | 1.0 |
| 3 | Flutter shell, theme tokens, language toggle, navigation | 1.0 |
| 4 | City and ward money trail (F1), flags with decisions (F2) | 1.5 |
| 5 | Scorecards (F3), next-rupee plan (F4) | 1.5 |
| 6 | Complaint pipeline with Claude (§6), trail view (F5). Start the pipeline run during step 3 | 1.5 |
| 7 | Ask (F6), live intake (F7), stored summaries | 1.0 |
| 8 | Demo rehearsal and fixes | 0.5 |

Total 9.5 hours, at the top of the window. **Cut in this order if time runs short:** social posts, Marathi summaries (keep Marathi labels), live intake for complaints (keep work orders), ward scorecards (keep contractor), dark theme polish.

## 12. Running on real BMC data

- Column names follow the supplied dictionary; real exports need a mapping step into the same tables.
- Thresholds and weights are settings. On real data, the over-billing threshold should be set from the observed spread of cost against rate card, not kept at 1.5x.
- Real complaints carry personal details. Only the anonymised complainant id is stored and shown.
- The DLP rule needs the original contractor per road to name who is liable. The supplied data does not have it.
- Ward boundaries here are approximations. Real boundaries replace the GeoJSON file.

## 13. Risks and open questions

| Risk or question | Handling |
|---|---|
| The judges' answer key is not published, so flag rules are inferred from the data and starter ideas | Rules are settings; the "watch" tier and the separate DLP tab limit the damage if a threshold is off |
| 493 DLP flags may be more than the key expects | Kept in their own tab so they do not dilute the 154 billing flags |
| Claude run over 6,501 complaints may be slow or fail mid-way | Batched, resumable, results stored per complaint; rules-only grouping is the fallback |
| Venue network fails during the demo | Only Ask needs Claude live. Neon needs a connection, so keep a local Postgres copy ready |
| The name contains "BMC" | No crest, and the "independent prototype" line stays in the header and login screen |
| Severity for open issues is not in the data | Inferred from work type and Claude's reading; shown as an estimate |
