# TASK-02: Sign-in and App Shell

| Field | Value |
|---|---|
| Task ID | TASK-02 |
| Status | Complete |
| Priority | P0 |
| Size | M (about 1.5 hours) |
| Depends On | TASK-01 |
| Blocks | TASK-03, TASK-04 |
| Requirement IDs | REQ-F-034, REQ-F-035, REQ-F-036, REQ-F-037, REQ-F-038, REQ-N-003, REQ-N-004, REQ-N-005, REQ-N-007, REQ-S-001, REQ-S-002, REQ-S-003, REQ-S-007, REQ-O-004 |
| Primary Spec Refs | 03-backend-spec.md#3-authentication-and-roles, 02-frontend-spec.md#4-layout, 02-frontend-spec.md#8-theme |
| Last Updated | 2026-11-21 |

## 1. Objective

Deliver the running API with login and role enforcement, and the Flutter web shell with navigation, theme control and the English and Marathi toggle. At the end, each of the three demo accounts signs in and lands on its own home with the right navigation.

## 2. Scope

### In Scope
- Express app: config, error handler, request logging, CORS, Zod `validate`, `requireRole`, `scopeWard`, startup check
- `POST /auth/login`, `GET /auth/me`, `GET /wards` (to prove an authenticated read)
- Flutter web project with Riverpod, go_router, dio, shared_preferences, intl
- `SathiColors` light and dark tokens, typography, bundled Latin + Devanagari font, theme-mode controller
- String files for `en` and `mr`; locale controller
- Shell: header, rail or bottom bar by width, role-based items, route guards and redirects
- Shared widgets: `MoneyText`, `StatTile`, `EmptyState`, `ErrorState`, `LoadingSkeleton`, `DetailPanel`, `SyntheticTag`
- Sign-in screen with three demo-account cards

### Out of Scope
- Feature screens (TASK-03 to TASK-06); routes render a titled placeholder using `EmptyState`
- Real single sign-on (later)

## 3. Prerequisites

- TASK-01 verify passing
- Flutter 3.47 with web enabled
- `JWT_SECRET` and `WEB_ORIGIN` in `.env`

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | Provides `app_user`, `ward` and the database connection |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-034 | Three demo accounts sign in and land on their role's home | 02-frontend-spec.md#3-routes |
| REQ-F-035 | Responsive shell: rail or bottom bar, header with synthetic-data tag and independent-prototype line | 02-frontend-spec.md#4-layout |
| REQ-F-036 | Theme mode light, dark or system, switched from the header and saved | 02-frontend-spec.md#8-theme |
| REQ-F-037 | English and Marathi toggle, saved; all strings come from string files | 02-frontend-spec.md#9-language |
| REQ-F-038 | Navigation items and routes differ by role | 02-frontend-spec.md#3-routes |
| REQ-N-003 | Contrast test passes for every token pair in both themes | 02-frontend-spec.md#8-theme |
| REQ-N-004 | Every list has loading, empty and error states | 02-frontend-spec.md#11-loading-empty-and-error-states |
| REQ-N-005 | Keyboard reachable, labelled controls, no colour-only meaning | 02-frontend-spec.md#10-accessibility |
| REQ-N-007 | Money is shown in Indian grouping with lakh and crore and tabular numerals | 02-frontend-spec.md#6-shared-widgets |
| REQ-S-001 | Passwords are bcrypt hashes; sessions are JWTs valid 12 hours | 03-backend-spec.md#3-authentication-and-roles |
| REQ-S-002 | Role and ward scope are enforced by middleware on every route | 03-backend-spec.md#3-authentication-and-roles |
| REQ-S-003 | Every route validates input with Zod and errors share one shape | 03-backend-spec.md#5-errors |
| REQ-S-007 | CORS allows only the configured web origin | 03-backend-spec.md#8-non-functional |
| REQ-O-004 | API refuses to start without a database connection and the v_flag view | 03-backend-spec.md#8-non-functional |

### 5.2 Data Contracts

Reads `app_user` and `v_ward_money`. No schema change.

### 5.3 API Contracts

`POST /api/v1/auth/login` — body `username`, `password` — returns `token`, `user`; 401 `not_signed_in` on bad credentials. `GET /api/v1/auth/me` — bearer — returns `user`. `GET /api/v1/wards` — bearer, any role — 24 ward money rows. Error shape and codes as in 03-backend-spec.md §5.

### 5.4 UI Surfaces & States

Sign-in: default, submitting (button disabled), error under the form. Shell at wide, medium and narrow widths per 02 §4. Header: product name, Synthetic data tag, EN/मराठी toggle, theme toggle, account menu with the independent-prototype line. Placeholder pages show loading, empty and error states through the shared widgets.

### 5.5 Permissions & Roles

Navigation: Overview, Contractors, Plan, Trail for all; Flags for ward officer and auditor; New record for ward officer; Settings for auditor. A role opening a route it may not use is redirected to its home with a notice. Home: auditor `/city`; ward officer `/ward/E`; citizen `/ward/:code` after choosing a ward (default E).

### 5.6 Assumptions

- ASSUMPTION: token is kept in shared_preferences — simplest on web for a demo — move to an http-only cookie before real use.
- ASSUMPTION: citizen's ward defaults to E and is changed from the header ward selector — avoids an extra onboarding screen.
- ASSUMPTION: font is Mukta, bundled — covers both scripts at matching weights — swap if contrast or legibility fails on the projector.

## 6. Implementation Steps

1. Build `app.ts` and `server.ts`: config loader, logger, CORS, JSON, error handler, startup check for DB and `v_flag`.
2. Add `validate`, `requireRole`, `scopeWard` middleware and the typed application error.
3. Add the auth module: login with bcrypt compare, JWT issue, `me`.
4. Add `GET /wards` in a wards module with a service reading `v_ward_money`.
5. Create the Flutter project under `apps/web`; add packages; set the API base URL as a build define.
6. Write `SathiColors` (light, dark), typography and spacing; write the contrast test and adjust values until it passes.
7. Add theme-mode and locale controllers persisted in shared_preferences.
8. Add `en` and `mr` string files with navigation, common actions, states and errors.
9. Build the dio client with auth interceptor and error mapping; build `sessionProvider`.
10. Build shared widgets listed in scope, including `MoneyText` with lakh and crore.
11. Build router with guards and the shell (rail, bottom bar, header).
12. Build the sign-in screen with demo-account cards.
13. Write the role test (API) and a formatter unit test; run all three accounts through sign-in at three widths.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Each role lands on its home
- **Given** the three seeded accounts
- **When** each signs in from the sign-in screen
- **Then** auditor sees the city route, ward officer sees Ward E, citizen sees a ward page, each with the navigation items listed for its role

**AC-2** — Wrong password
- **Given** a valid username and a wrong password
- **When** sign-in is submitted
- **Then** the API returns 401 `not_signed_in` and the form shows the translated message without clearing the username

**AC-3** — Role is enforced on the server
- **Given** a citizen token
- **When** it calls a route restricted to auditor
- **Then** the API returns 403 `not_allowed`

**AC-4** — Theme persists
- **Given** dark mode chosen from the header
- **When** the page is reloaded
- **Then** the app opens in dark mode

**AC-5** — Language persists
- **Given** Marathi chosen from the header
- **When** the page is reloaded
- **Then** navigation and headings are in Marathi and no label is truncated at 390 px

**AC-6** — Shell reflows
- **Given** a signed-in user
- **When** the window is resized from 1280 to 390 px
- **Then** the rail becomes icons-only below 1200 px and a bottom bar below 720 px

**AC-7** — Money format
- **Given** the values 16200000, 420000 and 9500
- **When** rendered by `MoneyText`
- **Then** they read ₹1.62 cr, ₹4.2 L and ₹9,500

### 7.2 Non-Functional Checklist

- [x] Validation: every input validated server-side with Zod; forms show field-level messages
- [x] Error states: every failure path shows a message with Retry; no blank screens
- [x] Loading states: every async surface shows a skeleton
- [x] Empty states: every list says what is empty and why
- [x] Authorization: role and ward checked server-side on every route this task adds
- [x] Logging: one line per request with user id; no bodies, tokens or keys
- [x] Accessibility: keyboard reachable, labelled, visible focus, text label beside every colour cue
- [x] Responsive: checked at 1280, 900 and 390 px wide
- [x] No hardcoded thresholds, URLs or secrets; settings table and environment file only
- [x] Every new string exists in English and Marathi string files

## 8. Validation & Testing

| Level | What to test | Where |
|---|---|---|
| Unit | Contrast for every token pair, both themes; `MoneyText` formatter (AC-7) | `apps/web/test/` |
| Integration | Login success and failure; role refusal (AC-2, AC-3) | `apps/api/test/auth.test.ts` |
| Manual | AC-1, AC-4, AC-5, AC-6 in Chrome at 1280, 900, 390 px | browser |

## 9. Deliverables

- Running API on port 4000 with auth
- Flutter web app with shell, theme, language, sign-in
- Shared widget set
- Contrast and role tests

## 10. Files Expected to Change

An estimate at module level, not a constraint.

- `apps/api/src/app.ts`, `server.ts`, `config/`, `middleware/`, `lib/errors.ts`, `modules/auth/`, `modules/wards/` (new)
- `apps/web/` project; `lib/core/{theme,l10n,api,format,widgets}`, `lib/features/{auth,shell}`, `lib/router/` (new)

## 11. Related Documentation

- `docs/tech-spec/03-backend-spec.md#3-authentication-and-roles` — role table
- `docs/tech-spec/03-backend-spec.md#5-errors` — error codes
- `docs/tech-spec/02-frontend-spec.md#3-routes` — routes and redirects
- `docs/tech-spec/02-frontend-spec.md#8-theme` — tokens and contrast rule
- `../PRD-bmc-sathi.md` — §9 palette values

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Palette fails contrast | Rework | Run the test before building screens; adjust token values, not screens |
| Devanagari font adds load time | Slow first paint | Bundle only two weights |
| CORS blocks the web app locally | Lost time | Set `WEB_ORIGIN` to the exact Flutter dev origin and run Flutter on a fixed port |

## 13. Progress Status

**Current status:** Complete

| Date | Progress | Commit |
|---|---|---|
| 2026-11-21 | Verified in the browser: all three roles land on their home, role redirects with a message, theme and language, keyboard focus, layout at 1512, 900 and 390 px. Fixed the header tag wrapping by letter at 390 px. | see git log |

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
