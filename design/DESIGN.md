# BMC Sathi · Roads — design handoff ("Works" system)

Approved visual design for Module 1 (Roads). Light theme, desktop width (1440). Every screen is a static, standalone HTML file with inline styles and inline SVG, plus a PNG render. **The HTML files are the source of truth**: copy markup, sizes, colours and SVG from them. Do not restyle.

## What is in this folder
- `screens/*.html` — one file per screen. Open in a browser. Inline styles on every element; the only external resource is the Google Fonts link.
- `screens/png/*.png` — the same screens rendered at 1440 wide, for quick visual comparison.
- `tokens.css` — the design tokens as CSS variables (colours, radii, type, spacing, hatches).
- `CLAUDE_CODE_PROMPT.md` — a prompt to paste into Claude Code.
- `screens/00-foundations-and-components.html` — every chip, button, field, bar, table and state, with names.

## Screen map
| File | Route | What it is |
|---|---|---|
| `screens/01-sign-in.html` | `/login` | Sign in (no shell) |
| `screens/02-city-view.html` | `/city` | City view, auditor home |
| `screens/03-ward-money-trail.html` | `/ward/:code` | Ward money trail (default ward tab) |
| `screens/04-ward-roads-overview.html` | `/ward/:code (optional 'Roads' section or tab)` | Ward overview with road cards. Design extra, not in the spec: use if time allows |
| `screens/06-flag-detail-double-billing.html` | `/flags/double-billing/WO25-02461` | Queue + detail panel: possible double billing (the demo flag) |
| `screens/07-flag-detail-over-billed.html` | `/flags/over-billed/:workOrderId` | Queue + detail panel: over-billed, range strip |
| `screens/08-flag-detail-dlp.html` | `/flags/dlp/:workOrderId` | Queue + detail panel: recover under DLP |
| `screens/09-flag-detail-watch.html` | `/flags/watch/:workOrderId` | Queue + detail panel: watch, no decision form |
| `screens/10-contractors.html` | `/contractors` | Contractor list, A to Z, no ranking |
| `screens/11-contractor-scorecard.html` | `/contractors/:id` | Contractor scorecard, three measures |
| `screens/12-ward-scorecard-too-few.html` | `/ward/:code/scorecard` | Ward scorecard, 'too few jobs' state |
| `screens/13-plan-within-budget.html` | `/ward/:code/plan` | Next-rupee plan, within budget (Ward B) |
| `screens/14-plan-overspent.html` | `/ward/:code/plan` | Next-rupee plan, overspent (Ward E) |
| `screens/15-trail-search.html` | `/trail` | Trail search with results |
| `screens/16-trail-fixed.html` | `/trail/work-order/WO25-00008` | Trail: fixed, held, SLA missed |
| `screens/17-trail-reopened.html` | `/trail/work-order/WO25-00056` | Trail: re-opened, open DLP flag |
| `screens/18-trail-never-fixed.html` | `/trail/issue/:id` | Trail: never fixed |
| `screens/19-trail-no-complaint.html` | `/trail/work-order/WO25-02461` | Trail: no complaint linked |
| `screens/20-ask-panel.html` | `(panel on any page)` | Ask panel open on the ward money trail |
| `screens/21-new-record-work-order.html` | `/intake` | New record, work order tab, saved state |
| `screens/22-new-record-complaint.html` | `/intake` | New record, complaint tab, saved state |
| `screens/23-rule-settings.html` | `/settings` | Rule settings, auditor only |
| `screens/00-foundations-and-components.html` | `(reference)` | Tokens, icons and every component with states |

Not designed yet: dark theme, phone width (390 px) and Marathi versions. For the demo, ship light theme at desktop width. The language toggle and the "Dark mode" switch exist in the UI; wire them only if time allows.

## The app shell (same on every screen except sign-in)
- Page ground `--ground`; one rounded app shell (`--shell`, radius 22) holding a 232 px sidebar and the content column.
- **Sidebar:** logo mark + "BMC Sathi" + "Roads"; search field with "Ctrl K"; tiny caps group labels ("Main menu", "Support"); nav items with thin stroke icons; the selected item is a white raised pill with teal icon and label; Flags carries a dark count badge; a ward group ("Ward E overview") expands to Money trail, Plan, Scorecard with a tree line; bottom info card "Independent prototype / Not an official BMC product. All data is synthetic."; Settings; Dark mode switch.
- **Top bar:** page title or breadcrumb (with ward selector chevron on ward pages); dashed "Synthetic data" tag (always visible); "EN | मराठी" segmented toggle; account button (initials, name, role); at most one primary button.
- **Role differences:** ward officer "R. Kulkarni" sees New record and Flags badge 12; city auditor "A. Deshmukh" sees "City overview", "Wards", Flags badge 74 and "Rule settings" (see `02-city-view.html`, `23-rule-settings.html`). Citizens see no Flags item and no flag queue.
- **Detail panel:** 440 px white panel on the right of the content, full height, with a close button; the page narrows, no dimming (see the flag detail and Ask screens).

## Components to build once and reuse
Names follow the foundations board.
- **Panel** (white, radius 16, 1 px `--line`, faint shadow) and **card** (grey `--inset`, radius 12, with an inset white sub-card).
- **Stat block:** small icon + grey label, 26 to 28 px numeral (weight 600), grey sub-line; stats in a row are divided by thin vertical rules.
- **Buttons:** 34 px tall, radius 10. Primary = solid teal, white text. Outlined = white with `--line` border. Quiet = teal text link with arrow. One primary per screen.
- **Status pill** (white, dot + label: "No DLP", "Under DLP", "Bus route") and **amber flag pill** ("4 open flags").
- **Decision chip:** Open (empty circle, amber, dashed border) · Needs explanation (question icon, amber, solid) · Confirmed (alert icon, red on red tint) · Not an issue (check, neutral) · Watch (eye, grey).
- **Band chip (scorecards):** Well above / Above (teal tint, up arrows) · Similar / Typical (neutral) · Below / Well below (neutral with stronger border, down arrows, **never red**) · Too few jobs to say (dashed) · Review (amber flag).
- **Bars:** progress bar with pale hatched remainder; budget bar = teal to 100% then **hatched red overspend**; compare bars = solid teal ("This contractor") vs grey hatched ("Similar jobs").
- **Range strip** (over-billed and watch): 0x to 2.0x scale with labelled zones "normal 0.77x to 1.3x", "watch 1.3x to 1.5x", "flag above 1.5x" and a pin "this job".
- **Stepper / trail:** five stages (Complaints, Issue, Work order, Road, Outcome). Filled teal check = has a record; hollow dashed node = nothing recorded ("No complaint linked", "Never fixed"); amber node = open flag.
- **Evidence pair:** two columns (Earlier job / Second job) with a centre column of "Matches" / "Differs" tags per row.
- **Budget line (plan):** full-width dashed divider with a centred white label "Budget runs out here" (or "Budget already used up" at the top for an overspent ward).
- **Table:** real `<table>`, 36 px header in tiny caps, 46 px+ rows, figures right-aligned in tabular numerals, sort arrow on the sorted header.
- **Form fields:** label above, 44 px inputs, radius 10, helper text 12 px grey, error = red border + icon + message; focus = 2 px teal ring with 2 px offset.
- **Illustrations:** axonometric road slabs (concrete, asphalt, paver blocks) with teal pins, and the schematic 24-ward map. They are inline SVG in the screen files: copy them as they are, do not redraw.

## Rules that must hold (product anti-goals)
1. No contractor grade, rank, league table, star or combined score. Contractor list is A to Z. A spend breakdown sorted by amount is allowed and is captioned "not a ranking".
2. No accusatory words anywhere, including generated text: never fraud, scam, corrupt, cheat, theft, steal. Use "possible", "billed", "check", "needs explanation".
3. Every flag shows its evidence on the same screen.
4. Colour meaning is fixed: **amber** = unreviewed flag or watch; **red** = overspend or confirmed problem only; **teal** = selection, actions, neutral data. Never colour alone: always a word plus an icon or hatch.
5. "Synthetic data" tag in the top bar on every screen, including sign-in. "Independent prototype. Not an official BMC product." on sign-in and in the sidebar card.
6. No BMC crest, logo, seal or emblem.
7. Generated summaries are labelled "Summary (written from these figures)"; assistant answers "Answer from the data" with source ids. Claude writes text, never decisions.
8. Data values are shown as stored: contractor names keep "(synthetic)"; ids, road names and complaint text are not cleaned up or translated.
9. Money: ₹, Indian grouping; crore to two decimals ("₹1.30 cr"), lakh to one ("₹63.2 L"); table cells under ₹1 lakh in full digits ("₹64,531", "₹1,02,000"). Tabular numerals; numeric columns right-aligned.
10. Smallest text 11 px (tiny caps labels only). Text contrast 4.5:1. Real buttons, links, tables and labelled inputs. Keyboard focus ring on every control.

## Figures in the mockups
Real (from the supplied data): city totals, ward budgets and spend, contractor job counts and spend, the work orders and complaints quoted from the brief (WO25-00008, WO25-00014, WO25-00056, WO25-01323, WO25-02461, BMC25-001879, BMC25-000022 and their details).
Illustrative (replace with real data from the API): the three "money in question" amounts, per-contractor and weekly spend for Ward E, road-level figures, most flag-queue rows, risk scores and plan costs, scorecard context counts, 14 of the 24 ward percentages on the city map, "Last updated: 3 Aug 2025".
