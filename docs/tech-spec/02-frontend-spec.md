# Frontend Specification

**Project:** BMC Sathi (Module 1: Roads)
**Version:** 1.0
**Last Updated:** 2026-11-21
**Status:** Draft

## Related Documents

- [00 Master Index](./00-master-index.md): entry point and reading order
- [01 Project Overview & Architecture](./01-project-overview.md): system shape, configuration, testing
- [03 Backend Specification](./03-backend-spec.md): the routes each screen calls
- [04 Database Design](./04-database-design.md): what the figures mean
- [PRD](../PRD-bmc-sathi.md): features, roles, design character, demo script

---

## 1. Overview

A Flutter app built for the web and shown in Chrome on a projector. It reflows to phone width. Three roles share six screens; the role decides the starting screen, the data scope and which actions are shown.

| Package | Use |
|---|---|
| flutter_riverpod | State |
| go_router | Routing and role redirects |
| dio | API client |
| flutter_map | Ward and road map, drawn from bundled GeoJSON |
| shared_preferences | Theme mode, language, session token |
| intl + flutter_localizations | Indian number formats, dates, English and Marathi strings |
| material_symbols_icons | Icons |

No chart package. Bars are drawn with sized boxes, which covers every chart in the PRD.

## 2. Structure

| Folder | Contents |
|---|---|
| `lib/core/theme` | Colour tokens, typography, spacing, theme-mode controller |
| `lib/core/l10n` | String files for `en` and `mr`, language controller |
| `lib/core/api` | Dio client, auth interceptor, error mapping |
| `lib/core/format` | Rupee, percentage, date and "x times rate card" formatters |
| `lib/core/widgets` | Shared widgets (§6) |
| `lib/features/auth` | Sign-in |
| `lib/features/shell` | Navigation rail or bottom bar, header |
| `lib/features/overview` | City view and ward money trail |
| `lib/features/flags` | Queue and flag detail |
| `lib/features/contractors` | List and scorecard |
| `lib/features/plan` | Next-rupee plan |
| `lib/features/trail` | Search and trail view |
| `lib/features/ask` | Ask panel |
| `lib/features/intake` | New work order and new complaint forms |
| `lib/features/settings` | Rule settings (auditor) |

## 3. Routes

| Path | Screen | Roles | Notes |
|---|---|---|---|
| `/login` | Sign-in | all | Shows the three demo accounts as one-tap cards under the form |
| `/city` | City view | auditor (home), others allowed | |
| `/ward/:code` | Ward money trail | all | Home for ward officer (own ward) and citizen (chosen ward) |
| `/ward/:code/plan` | Next-rupee plan | all | |
| `/ward/:code/scorecard` | Ward scorecard | all | |
| `/flags` | Flag queue | ward officer, auditor | Officer is filtered to own ward |
| `/flags/:type/:workOrderId` | Flag detail | ward officer, auditor | Opens as a side panel on wide screens |
| `/contractors` | Contractor list | all | |
| `/contractors/:id` | Contractor scorecard | all | |
| `/trail` | Search | all | |
| `/trail/issue/:id`, `/trail/work-order/:id` | Trail view | all | |
| `/intake` | New record | ward officer | |
| `/settings` | Rule settings | auditor | |

Redirects: no token goes to `/login`; a signed-in user at `/` goes to their home; a role opening a route it may not use goes to its home.

## 4. Layout

| Width | Name | Navigation | Content |
|---|---|---|---|
| 1200 px and above | Wide | Left rail with labels | Two columns; detail opens as a right-hand panel 420 px wide |
| 720 to 1199 px | Medium | Left rail, icons only | One column; detail opens as a full-height sheet |
| Below 720 px | Narrow | Bottom bar | One column; detail is its own page; tables become stacked cards |

**Header, always visible:** product name "BMC Sathi · Roads", the ward selector (where relevant), a "Synthetic data" tag, language toggle (EN / मराठी), theme toggle, account menu. The login screen and account menu carry the line "Independent prototype. Not an official BMC product."

**Navigation items:** Overview, Flags, Contractors, Plan, Trail. Flags is hidden for citizens. New record appears for ward officers; Settings for auditors.

## 5. Screens

### 5.1 Sign-in
Username and password, plus three cards (Ward officer · Ward E, Auditor, Citizen) that fill the form and sign in. Errors appear under the form.

### 5.2 City view (`/city`)

```
[ City totals: budget · spent · in open flags · re-opened spend ]

+---------------------------+  +----------------------------------+
|                           |  | Ward   Budget  Spent   %    Flags|
|   Map of 24 wards,        |  | E      ₹..     ₹..    119%   12  |
|   shaded by spend / budget|  | R/C    ₹..     ₹..    114%    9  |
|                           |  | L      ₹..     ₹..    110%   14  |
+---------------------------+  +----------------------------------+
```

- Map: ward polygons from the bundled GeoJSON, no background tiles, so it needs no network. Shading has five steps from under 80% to over 110%, with a legend. Each ward shows its code.
- Selecting a ward on the map highlights its table row and the reverse. Opening it goes to the ward page.
- The table sorts by any column. Default sort is spend as a share of budget, highest first.

### 5.3 Ward money trail (`/ward/:code`)

```
Ward E · Byculla, Mazgaon          [ Money trail | Plan | Scorecard ]

Budget ₹..   Spent ₹..   Over by ₹.. (119%)      ▓▓▓▓▓▓▓▓▓▓▓▓░ 

[ Re-opened in 30 days ]  [ Billed under DLP ]  [ In open flags ]
[ ₹..  · n jobs        ]  [ ₹..  · n jobs    ]  [ ₹..  · n flags]

Spend by  ( Contractor | Method | Week )
Sahyadri Infra     ▓▓▓▓▓▓▓▓▓▓  ₹..   n jobs
...

Summary (written from these figures)                     [ Ask ]
"Ward E spent ..."
```

- Every figure and every bar opens the list of work orders behind it, in the detail panel.
- Each work order row opens its trail.
- The budget bar turns to the error colour only past 100%, with the words "Over by".
- Citizens see the same page without the Flags link; the "In open flags" tile shows count and amount only.

### 5.4 Flag queue (`/flags`)

- Tabs: Over-billed, Possible double billing, Recover under DLP, Watch. Each tab shows its count and amount at stake.
- Filters: ward (auditor), contractor, decision state. Default shows open flags, largest amount first.
- Row: work order id, road, contractor, amount at stake, one-line reason, decision chip.
- A header strip shows "n open · ₹x at stake · n decided".

### 5.5 Flag detail

| Flag type | Evidence shown |
|---|---|
| Over-billed | Method, area, rate, expected cost, billed cost, ratio as "2.3 times the rate card", and a small strip showing where this job sits against the normal range (0.77x to 1.3x) |
| Possible double billing | The two work orders side by side with matching fields marked: road, work type, contractor, area, days apart; the second marked "no complaint linked" |
| Recover under DLP | Road, last resurfaced date, DLP status, billed cost, and the line "Liable party is the road's original contractor, which this data does not name" |

Below the evidence: links to the work order's trail and the contractor's scorecard, then the decision control (Confirmed, Needs explanation, Not an issue) with a note field and Save. The current decision, who made it and when are shown above the control. Watch-tier rows show evidence and no decision control.

### 5.6 Contractor list and scorecard

- List: eight cards in name order with jobs, spend and wards worked. No sorting by performance and no rank numbers.
- Scorecard: three measure cards (Speed, Durability, Cost), each with the observed figure, "similar jobs" figure, a band label, a two-bar comparison, and a context line ("n of these jobs were in heavy-rain weeks, n in low-lying wards"). A band of "too few jobs to say" replaces the comparison when it applies.
- Under each measure, a link to the work orders behind it.
- A "How this is compared" expander explains peer groups in three sentences.
- The stored summary, then Ask.

### 5.7 Next-rupee plan (`/ward/:code/plan`)

- Header: remaining budget, or "Over budget by ₹x: everything below needs additional funds".
- Ranked cards. Each shows rank, road and segment, category, complaint count, risk score, reason chips, recommended method with estimated cost, and the alternative with its cost and re-open rate where one exists.
- Expanding a card shows the six score parts as bars with their points, and a link to the issue's trail.
- A full-width divider, "Budget runs out here", sits between the last affordable item and the next. Items below it show the shortfall.
- A footer line states the count and total cost of items within budget.

### 5.8 Trail (`/trail`, `/trail/...`)

- Search box with results grouped by type.
- Trail view is a vertical timeline with five stages: **Complaints** → **Issue** → **Work order** → **Road** → **Outcome**.
  - Complaints: each with channel, date, original text and, when not English, the translation beneath it marked "Translated". Reported category is shown struck through when it was corrected.
  - Issue: category, severity (marked "estimated"), complaint count, related social posts collapsed.
  - Work order: contractor, method, dates, cost against expected cost, engineer remark as recorded.
  - Road: type, surface, last resurfaced, DLP status.
  - Outcome: SLA met or missed with hours; held or re-opened; any flags with links.
- An open issue shows "Never fixed" at the work order stage and its plan rank.
- A work order with no complaints shows "No complaint linked" at the first stage.

### 5.9 Ask

A panel opened from the ward page, scorecards and trail. One text field, a send button and the answer beneath with its source ids as links. It holds only the current answer. On failure: "The assistant is not available. The figures on this page are unaffected."

### 5.10 New record (`/intake`)

Two forms on tabs.

- **Work order:** road (searchable, own ward), work type, method (filtered by work type), contractor, area, cost, dates, linked complaint ids (optional). The expected cost and ratio update as the user types. After saving, a result card shows any flags raised, with a link to each.
- **Complaint:** description, category, locality, channel. After saving, the result card shows the issue it joined or created.

### 5.11 Rule settings (`/settings`)

A table of settings with description, value and Save per row. The six risk weights show their running total and cannot be saved unless it is 100.

## 6. Shared widgets

| Widget | Purpose |
|---|---|
| `MoneyText` | Rupee amounts in Indian grouping with lakh and crore, tabular numerals |
| `StatTile` | Label, figure, sub-line; tappable |
| `BandChip` | Scorecard band with label and icon |
| `DecisionChip` | Flag decision state |
| `CompareBars` | Two horizontal bars: this subject and similar jobs |
| `BarList` | Labelled horizontal bars for breakdowns |
| `WorkOrderTable` | Sortable table that becomes stacked cards when narrow |
| `DetailPanel` | Right-hand panel, sheet or page depending on width |
| `EmptyState`, `ErrorState`, `LoadingSkeleton` | The three non-data states, used by every list |
| `SyntheticTag` | The header tag |

## 7. State

- One Riverpod provider per API read, keyed by its parameters (ward code, filters, language). Screens watch providers and render loading, error or data.
- `sessionProvider` holds the token and user, restored from storage at start. A 401 response clears it and returns to sign-in.
- `themeModeProvider` and `localeProvider` are persisted, following Saarthee's `ThemeModeController`.
- **After a write**, the affected providers are invalidated so figures refresh:

| Write | Invalidates |
|---|---|
| Flag decision | Flag list, flag summary, ward money |
| New work order | Ward list, ward money and breakdowns, flag list and summary, contractor scorecard |
| New complaint | Ward plan |
| Setting change | Everything |

## 8. Theme

- All colours come from one theme extension, `SathiColors`, with a light and a dark instance. Screens read colours only through it; no raw colour values in feature code.
- Token names and starting values are in PRD §9. Additional tokens needed: `border`, `borderStrong`, `surfaceAlt`, `onPrimary`, `primaryContainer`, `errorTint`, `successTint`, `infoTint`, `focusRing`, and a five-step `mapScale` for ward shading that reads in both themes.
- Theme mode is light, dark or system, default system, saved per device and switched from the header without a reload.
- A unit test computes contrast for every text-on-background pair in both themes and fails below 4.5:1 for body text or 3:1 for large text and chip borders. Values are adjusted until it passes.
- Typography: one family covering Latin and Devanagari, bundled with the app so it does not load from the network. Sizes: 12 label, 14 body, 16 emphasis, 20 section, 28 headline figure. Figures use tabular numerals.
- Spacing on a 4 px grid. Card corners 8 px. Elevation is replaced by 1 px borders, which hold up better on a projector.
- Motion is limited to the detail panel sliding in and bars growing on first paint, both under 200 ms and disabled when the system asks for reduced motion.

## 9. Language

- Every visible string comes from the string files; none are written in widgets.
- English and Marathi are complete for navigation, labels, band names, flag reason templates, plan reason chips, decisions, errors and empty states.
- Flag reasons and plan reasons are templates filled from API fields, for example "Billed {ratio} times the rate card for {method}".
- Numbers and dates follow the selected language's conventions; rupee amounts keep Western digits in both, for readability on a projector.
- Data values (road names, contractor names, complaint text) are shown as stored.
- Layouts are checked with Marathi selected: labels wrap to two lines before they truncate.

## 10. Accessibility

- Colour never carries meaning alone: every band, flag, decision and map step has a text label or pattern.
- All actions reachable by keyboard, in visual order, with a visible focus ring.
- Tables expose header and cell semantics; the map has an equivalent table beside it.
- Minimum target size 44 px on narrow layouts.

## 11. Loading, empty and error states

| State | Behaviour |
|---|---|
| Loading | Skeleton of the final layout; no spinners over blank pages |
| Empty | A sentence saying what is empty and why ("No open flags in this ward") |
| Error | Plain message, a Retry button, and the request id for server errors |
| Stale summary | The summary is shown with "Written before recent changes" |
| Not allowed | Redirect to the role's home with a brief notice |

## Decisions & Assumptions

| # | Decision/Assumption | Rationale | Status | Date |
|---|---|---|---|---|
| 1 | Flutter web as the only build target | Chosen by the owner: web on projector, responsive | Confirmed | 2026-11-21 |
| 2 | English and Marathi | Chosen by the owner | Confirmed | 2026-11-21 |
| 3 | Map without background tiles | No network dependency; ward shapes are approximations anyway | Assumed | 2026-11-21 |
| 4 | No chart package | Every chart is a bar; fewer dependencies | Assumed | 2026-11-21 |
| 5 | Contractor list in name order with no performance sort | PRD anti-goal: no ranking | Confirmed | 2026-11-21 |
| 6 | Citizen does not see the flag queue | See [03](./03-backend-spec.md) decision 3 | Assumed | 2026-11-21 |
| 7 | Rupee amounts keep Western digits in Marathi | Readability for a mixed audience | Assumed | 2026-11-21 |
| 8 | Font bundled with the app | Works without network | Assumed | 2026-11-21 |
| 9 | Demo account cards on the sign-in screen | Saves typing on stage while keeping a real login | Assumed | 2026-11-21 |

## Version History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-11-21 | Keyur Patel with Claude | Initial draft |
