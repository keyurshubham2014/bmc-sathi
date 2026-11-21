# BMC Sathi (BMC साथी): Visual Design Brief, Module 1: Roads

Paste this whole document into the design tool, or paste one section at a time with the prompts in section 10. The document stands alone and needs no other files.

Conventions used below:
- **Proposed** marks a value or decision the source spec does not give. Treat it as a starting point, to be checked.
- **check** marks a Marathi rendering that a native reader should confirm.
- Figures marked **(illustrative)** are not from the data. Everything else is from the supplied synthetic dataset.
- Amounts use ₹, Indian grouping, lakh (L) and crore (cr). Digits are Western in both languages.

## Contents

1. Product, audience and design character
2. Hard rules
3. Design tokens (colour, type, spacing, shape, motion, contrast)
4. Layout system (three widths)
5. Component inventory
6. Screen specifications (14 screens)
7. Language: English and Marathi
8. Accessibility
9. Deliverables to produce
10. Ready-to-paste prompts
11. Assumptions and spec conflicts

---

## 1. Product, audience and design character

**What it is.** BMC Sathi is a ward-level accountability and budgeting tool for road repairs in Mumbai's municipal corporation. For any ward it answers three questions:

1. Where did the money go? Budget, spend, and the share spent on work that re-opened or should not have been billed.
2. Did the fix last? Re-opened repairs, by contractor, method and road.
3. Where should the next rupee go? Open issues ranked by risk, with a recommended method and cost.

It is an independent prototype. It is not an official BMC product. All data is synthetic and every contractor is fictional. It is shown full-screen on a projector in Chrome, and it must also reflow to phone width.

**Users.** One app with the same screens for every role. The role sets the starting screen, the data scope and which actions appear.

| Role | Starts at | Sees | Can do |
|---|---|---|---|
| Ward officer (ward engineer or Assistant Commissioner) | Own ward's money trail | Own ward's flag queue; any ward read-only | Decide own-ward flags; add a work order or complaint |
| City auditor (head office, vigilance) | City view | All 24 wards and all flags | Decide any flag; change rule settings |
| Citizen or corporator | Ward chooser, then the ward page | Ward money trail (no flag queue), contractor scorecards, complaint lookup | Read only; ask a question |

**Design character: a public ledger.** A ward office leaves this open all day. It should feel calm, dense and numerical, like a printed accounts register on a screen. It is not a consumer app.

- Tables, rules and figures do the work. Use 1 px lines, not shadows.
- No hero images, illustrations, gradients, decorative icons, emojis, or big rounded cards.
- Figures are large and tabular. Labels are small and plain.
- Colour is restrained. It signals status; it does not decorate.
- Dense, but never cramped. Body text is 14 px.
- Readable from the back of a room on the wide projector view.

---

## 2. Hard rules

These are product anti-goals and accessibility rules. Designs that break them are wrong.

1. **No contractor grade, rank or league table.** The contractor list is alphabetical, with no rank numbers and no sort by performance. Never combine the three measures into one score, badge, star or grade.
2. **No accusatory words** in UI text or generated copy: never "fraud", "scam", "corrupt", "cheat", "theft", "steal". Flags state what the data shows and what to check. Use words such as "possible", "billed", "check", "needs explanation".
3. **Every flag shows its evidence on the same screen.** No flag without the linked rows that justify it.
4. **Colour meaning is fixed.**
   - Amber = unreviewed flag or watch item.
   - Red = confirmed problem, or spend over budget. Nothing else.
   - Bands and neutral states never use red.
5. **Colour never carries meaning alone.** Every band, flag, decision and map step has a text label plus an icon or pattern.
6. **"Synthetic data" tag is always visible in the header**, on every screen, including sign-in.
7. **"Independent prototype. Not an official BMC product."** appears on the sign-in screen and in the account menu. It may also appear in a footer.
8. **No BMC crest, logo, seal or emblem**, and no imitation of one. The name appears as text only.
9. **Claude writes text, never decisions.** Generated summaries are labelled "Summary (written from these figures)". Assistant answers are labelled "Answer from the data" and list their source ids. No score or flag is presented as Claude's judgment.
10. **Data values are shown as stored.** Contractor names keep the "(synthetic)" suffix, for example "Mahalaxmi Civil Contractors (synthetic)". Road names, complaint text and ids are not translated or cleaned up.

---

## 3. Design tokens

### 3.1 Colour: semantic tokens

Every colour in the UI comes from these tokens. Screens never use raw hex values. Values marked "from spec" are fixed. Values marked "proposed" are new and must pass the contrast test in 3.5.

| Token | Light | Dark | Source | Use |
|---|---|---|---|---|
| `primary` | `#123A6B` | `#8DB4F0` | from spec | Navigation, links, primary buttons, selected rail item |
| `onPrimary` | `#FFFFFF` | `#0E1520` | proposed | Text and icons on `primary` |
| `primaryContainer` | `#DCE6F5` | `#1D3556` | proposed | Selected row or tab background |
| `accent` | `#0E7C86` | `#5CC6CF` | from spec | Charts, selected states, "monsoon teal" |
| `background` | `#F4F6F9` | `#0E1520` | from spec | Page |
| `surface` | `#FFFFFF` | `#172131` | from spec | Cards, tables, panels |
| `surfaceAlt` | `#EBEFF5` | `#1E2A3D` | proposed | Table header, zebra row, skeleton blocks, neutral chip fill |
| `border` | `#D5DCE6` | `#2A3749` | proposed | Dividers, card edges (decorative, 1 px) |
| `borderStrong` | `#8593A6` | `#64778F` | proposed | Input borders, chip borders, panel edge, budget line |
| `textPrimary` | `#14202E` | `#E6ECF4` | from spec | Body text, figures |
| `textSecondary` | `#4A5868` | `#A3B1C2` | from spec | Labels, sub-lines, captions |
| `flag` | `#9A5B00` | `#F2B84B` | from spec | Unreviewed flag and watch text and icon |
| `flagTint` | `#FFF4E0` | `#3A2C0E` | from spec | Background behind amber items |
| `error` | `#B3261E` | `#F28B82` | from spec (light), proposed (dark) | Confirmed problem and overspend only |
| `errorTint` | `#FBE9E7` | `#3A1E1E` | proposed | Background behind red items |
| `success` | `#1A7340` | `#6FD39A` | from spec (light), proposed (dark) | Status: "held", "SLA met" |
| `successTint` | `#E3F4EA` | `#14301F` | proposed | Background behind success items |
| `info` | `#1F5FAE` | `#8FBCF7` | from spec (light), proposed (dark) | Status: "Needs explanation" link, neutral notices |
| `infoTint` | `#E4EEF9` | `#15263D` | proposed | Background behind info notices |
| `focusRing` | `#123A6B` | `#8DB4F0` | proposed | 2 px keyboard focus ring with 2 px offset |

**Map scale.** Five steps, shaded by spend as a share of budget. Each step also has a text label and a pattern, so it reads without colour. Steps 4 and 5 are overspend, so they use the red family.

| Step | Range | Light fill | Dark fill | Label and pattern (proposed) | Label text, light / dark |
|---|---|---|---|---|---|
| 1 | under 80% | `#E3F1F2` | `#1B3A3F` | Plain fill | `#14202E` / `#E6ECF4` |
| 2 | 80 to 89% | `#A9D7DB` | `#24575D` | Plain fill | `#14202E` / `#E6ECF4` |
| 3 | 90 to 99% | `#5FAFB7` | `#276A71` | Plain fill | `#14202E` / `#E6ECF4` |
| 4 | 100 to 110% | `#F3C9BF` | `#5E2F28` | Diagonal hatch | `#14202E` / `#E6ECF4` |
| 5 | over 110% | `#D9826F` | `#8E3F34` | Cross hatch | `#14202E` / `#E6ECF4` |

Ward codes sit on each ward, 12 px, weight 600. Ward borders use `borderStrong`.

### 3.2 Typography

- **Family:** Mukta (proposed). One family covers Latin and Devanagari at equal weight. Bundle it with the app; do not load it from the network. Fallback if Marathi conjuncts or digits fail review: Noto Sans with Noto Sans Devanagari.
- **Sizes: only these five.**

| Role | Size | Weight (proposed) | Use |
|---|---|---|---|
| Label | 12 px | 600 | Column headers, chip text, map ward codes, captions |
| Body | 14 px | 400 | Table cells, reasons, summaries, descriptions |
| Emphasis | 16 px | 600 | Card titles, row titles, button text |
| Section | 20 px | 600 | Page and panel headings |
| Headline figure | 28 px | 700 | Tile figures, budget totals, scorecard figures |

- **Tabular numerals on every figure.** Use `font-variant-numeric: tabular-nums`. Right-align numeric columns so rupee amounts line up.
- **Line height (proposed):** 1.4 for English body; 1.6 for Marathi body, because matras need room; 1.2 for 28 px figures.
- **No all-caps.** Use sentence case in labels, in both languages.

### 3.3 Spacing, shape, borders, elevation

- **Spacing:** 4 px grid. Steps: 4, 8, 12, 16, 24, 32, 48.
- **Corners:** 8 px on cards, panels, chips, buttons and inputs. No pills.
- **Edges:** 1 px `border` lines. Use `borderStrong` for inputs and chips.
- **Elevation:** none. No shadows. The detail panel is marked by its 1 px left edge.
- **Page gutter:** 24 px at wide and medium widths; 16 px at narrow widths.
- **Focus:** 2 px `focusRing`, 2 px offset, on every interactive element.

### 3.4 Motion

Motion is limited to two things. Both run under 200 ms.

- The detail panel or sheet slides in from the right.
- Bars grow from zero on first paint.

Under reduced motion, both are off and the final state appears at once. Skeletons are static blocks in `surfaceAlt` with no shimmer.

### 3.5 Contrast requirements

- Body text: 4.5:1 minimum.
- Large text (20 px, or 16 px bold) and graphics: 3:1 minimum.
- Chip borders and input borders: 3:1 minimum against the surface.
- Proposed values above were hand-checked for the main pairs. For example: `textSecondary` on `surface` is about 7:1 in light and about 7.4:1 in dark; `flag` on `flagTint` is about 5:1 in light; dark `flag` on dark `flagTint` is about 7.6:1. The contrast unit test decides final values.

---

## 4. Layout system

Three widths. Design each screen at all three where the screen spec says so.

| Width | Name | Reference canvas | Navigation | Content | Detail |
|---|---|---|---|---|---|
| 1200 px and up | Wide | 1440 × 900 | Left rail with labels, 208 px (proposed) | Two columns: main area and optional right panel | Right-hand panel, 420 px wide |
| 720 to 1199 px | Medium | 1024 × 768 | Left rail, icons only, 72 px (proposed) | One column | Full-height sheet, 560 px wide, right-anchored, no dimming |
| Under 720 px | Narrow | 390 × 844 | Bottom bar, five items | One column; tables become stacked cards | Its own page with a back arrow in the header |

**Header (every width, always visible).** Left to right:
- Product name "BMC Sathi · Roads".
- Ward selector, where relevant (see the screen specs).
- "Synthetic data" tag.
- Language toggle: "EN | मराठी".
- Theme toggle.
- Account menu: name, role, ward, "Sign out", and the line "Independent prototype. Not an official BMC product."

Header height is 56 px at wide and medium. At narrow it becomes two rows (proposed): row 1 has the name on the left and the toggles and account on the right; row 2 has the ward selector and the synthetic tag. Marathi labels may wrap to two lines in the header; they must not truncate.

**Navigation items.**

| Item | Route | Roles | Notes |
|---|---|---|---|
| Overview | role home: `/city` for auditor, own ward for officer, chosen ward for citizen | all | |
| Flags | `/flags` | officer, auditor | Hidden for citizens |
| Contractors | `/contractors` | all | |
| Plan | `/ward/:code/plan` for the selected ward | all | Uses the selected ward (see section 11) |
| Trail | `/trail` | all | |
| New record | `/intake` | officer | At wide and medium, in the rail below a divider. At narrow, in the account menu |
| Settings | `/settings` | auditor | Same placement as New record |

**Wide (1200 px and up).** Rail on the left. Main area holds the page. Detail opens on the right at 420 px; the main area narrows to fit. Closing the detail returns the main area to full width. Escape closes the panel; focus returns to the element that opened it.

**Medium (720 to 1199 px).** Icon-only rail, with a visible text label on focus and a tooltip on hover. One column. Detail opens as a full-height sheet that covers the right side; the page behind stays visible at its edges.

**Narrow (under 720 px).** Bottom bar with five items: Overview, Flags, Contractors, Plan, Trail. Citizens see four items, without Flags. Detail is a full page with a back arrow. Tables become stacked cards: each row becomes a card, with the key figure first, then label and value pairs. All tap targets are at least 44 × 44 px.

**Layout for the map page at each width.** Wide: map and table side by side, map about 45% width. Medium: map on top at full width, 300 px tall; table below. Narrow: map on top at full width, 320 px tall; table below as stacked cards.

---

## 5. Component inventory

Each component lists its purpose, anatomy, variants, states and example. Examples use real figures where the data has them.

### 5.1 MoneyText
- **Purpose.** Every rupee amount. Indian grouping, lakh and crore, tabular numerals.
- **Anatomy.** Optional prefix word, the amount, optional suffix word. Example: "Over by ₹10.2 L".
- **Format rules (proposed).**
  - Headlines, tiles and summaries: "₹1.30 cr", "₹63.2 L". Crore to two decimals; lakh to one.
  - Table cells under ₹1 lakh: full digits with Indian grouping, such as "₹64,531" or "₹1,02,000".
  - Table cells at ₹1 lakh and above: lakh form, such as "₹1.02 L".
- **Variants.** Plain (`textPrimary`). Over budget (`error` colour, with the words "Over by" before it). Remaining (`textPrimary`, with "Left" before it). Estimate (followed by the word "est.").
- **States.** Loading shows a skeleton block the width of the figure. Missing shows an em dash and the empty-state wording in the nearest container.
- **Example.** "Budget ₹53.0 L · Spent ₹63.2 L · Over by ₹10.2 L (119%)".

### 5.2 StatTile
- **Purpose.** One headline figure with a label and a sub-line. Tappable when the figure has a list behind it.
- **Anatomy.** Label (12 px, `textSecondary`) on top. Figure (28 px, MoneyText or number). Sub-line (14 px): job count or flag count. Chevron on the right when tappable.
- **Variants.** Static. Tappable (hover shows an underline; focus shows the ring). Over (figure in `error` with the word "Over by" in the label).
- **States.** Loading (skeleton figure and sub-line). Empty ("No re-opened repairs in 30 days" as the sub-line, figure shows ₹0). Error (tile shows "Could not load" with Retry).
- **Example.** Label "Re-opened in 30 days". Figure "₹18.4 L" (illustrative). Sub-line "37 jobs" (illustrative).

### 5.3 BandChip
- **Purpose.** The scorecard band for one measure. Always shows a word and an icon.
- **Anatomy.** Icon, then text label. Chip is 8 px corners, 1 px border.
- **Variants (proposed; no red).**

| Band | Label (English) | Icon | Fill | Border |
|---|---|---|---|---|
| well above | Well above | double up arrow | `successTint` | `success` 1 px |
| above | Above | up arrow | `successTint` | `success` 1 px |
| similar | Similar | equals sign | `surfaceAlt` | `borderStrong` 1 px |
| below | Below | down arrow | `surfaceAlt` | `borderStrong` 2 px |
| well below | Well below | double down arrow | `surfaceAlt` | `textPrimary` 2 px |
| too few | Too few jobs to say | ellipsis | `surfaceAlt` | dashed `borderStrong` |
| review (cost) | Review | flag outline | `flagTint` | `flag` 1 px |
| typical (cost) | Typical | equals sign | `surfaceAlt` | `borderStrong` 1 px |

- **Durability sign.** For re-opens, "above" always means better. So "Well below" on durability means more re-opens than similar jobs. Add a plain sub-line under the chip: "More re-opens than similar jobs" (proposed).
- **States.** Loading (skeleton chip). Not applicable (no chip, the line "Not enough data" in its place).
- **Example.** "Below" with down arrow, on the speed measure of a contractor.

### 5.4 DecisionChip
- **Purpose.** The decision state of a flag.
- **Anatomy.** Icon, label, optional "by [name], [date]" line below in 12 px.
- **Variants (proposed).**

| State | Label (English) | Icon | Colour use |
|---|---|---|---|
| Open | Open | empty circle | `flag` text on `flagTint`, dashed border |
| Needs explanation | Needs explanation | question mark | `flag` text on `flagTint`, solid border |
| Confirmed | Confirmed | filled alert | `error` text on `errorTint` |
| Not an issue | Not an issue | check | `textPrimary` on `surfaceAlt` |
| Watch | Watch (no decision) | eye | `textSecondary` on `surfaceAlt` |

- **States.** Loading (skeleton). The chip itself has no error state.
- **Example.** "Open", on a possible double billing row.

### 5.5 CompareBars
- **Purpose.** Compare a subject with similar jobs. Two horizontal bars with labels and figures.
- **Anatomy.** Row 1: label "This contractor" (or "This ward"), bar, figure. Row 2: label "Similar jobs", bar, figure. Scale runs from 0 to 100% for rates, or 0 to 1.5x for cost ratios.
- **Variants.** Rate (percent). Ratio (for cost, bar 1 is the subject's median ratio; bar 2 is the rate card at 1.00x, labelled "Rate card").
- **Colour.** Subject bar uses `primary`. Comparison bar uses `textSecondary` outlined with a hatch fill, so it does not depend on colour alone.
- **States.** Loading (two skeleton bars). Too few jobs (the component is replaced by the BandChip's "Too few jobs to say" text).
- **Example.** Speed: "This contractor 39%", "Similar jobs 47%".

### 5.6 BarList
- **Purpose.** A labelled breakdown: spend by contractor, method or week.
- **Anatomy.** Each row: label (left, may wrap to two lines), bar (proportional to the largest row), figure (MoneyText), job count. Each row is a button that opens the work orders behind it in the detail panel.
- **Variants.** Sorted by amount, descending (the breakdown's natural order; not a performance sort). Week breakdown uses the week start date as label.
- **States.** Loading (rows as skeleton bars). Empty ("No work orders in this breakdown for this ward"). Error (ErrorState).
- **Example.** "Western Coast Asphalt Co (synthetic)" with a bar, "₹ (illustrative) 14.1 L", "41 jobs" (illustrative).

### 5.7 WorkOrderTable
- **Purpose.** The work orders behind any figure. Sortable on each column.
- **Columns (wide).** Work order id, road, work type, method, contractor, completed, cost, ratio (x rate card), SLA, re-opened, flags. Numbers right-aligned.
- **Column headers.** Real header cells with `aria-sort` set. Click a header to sort; click again to reverse.
- **Narrow.** Each row becomes a stacked card: work order id and road on top; cost and ratio in a row; SLA, re-opened and flag chips below.
- **States.** Loading (skeleton rows). Empty ("No work orders match this filter"). Error (ErrorState with Retry and request id).
- **Example row.** WO25-00008 · Bellasis Road · Choked drain / nullah overflow · Desilting and garbage removal · Western Coast Asphalt Co (synthetic) · 7 Jun 2025 · ₹88,502 · 1.26x · SLA missed · Not re-opened.

### 5.8 DetailPanel
- **Purpose.** Shows one item's detail beside the page without leaving it.
- **Anatomy.** Header row: title (20 px), subtitle (14 px), close button (44 px target). Body: scrollable content. Footer (only on flag detail): decision control.
- **Width behaviour.** Wide: right panel 420 px. Medium: full-height sheet 560 px. Narrow: full page with back arrow.
- **Variants.** Work-order list. Flag evidence. Score breakdown. Trail. Ask. Settings note.
- **States.** Loading (skeleton of the body). Error (ErrorState inside the panel). Not allowed (redirect with a notice; see 5.9).
- **Example.** Title "Work orders behind Re-opened in 30 days", subtitle "Ward E · 37 jobs (illustrative)".

### 5.9 EmptyState, ErrorState, LoadingSkeleton, and Not-allowed notice
- **EmptyState.** One sentence saying what is empty and why. Example: "No open flags in this ward." Optional link to clear the filter. Plain text, no illustration.
- **ErrorState.** Plain message, a Retry button, and for server errors the request id in 12 px text. Example: "The figures could not be loaded. Request id: 4f2a…". Retry is the first focusable element.
- **LoadingSkeleton.** A grey block in the shape of the final layout: same columns, same card heights. No spinners on blank pages. Static in reduced motion.
- **Not-allowed notice.** A toast at the top of the content: "You do not have access to that page. Showing your home page." Auto-dismisses after 6 seconds; can be closed.
- **Stale summary notice.** Inline above the summary: "Written before recent changes" in `info` with a refresh icon.

### 5.10 SyntheticTag
- **Purpose.** Shows the data is synthetic.
- **Anatomy.** Outlined tag, 12 px, 8 px corners, text "Synthetic data" (Marathi: "कृत्रिम माहिती").
- **Variants.** Header (always). Sign-in (also always).
- **States.** None. It is never hidden.

### 5.11 Navigation rail (wide and medium)
- **Anatomy.** Brand block at top: "BMC Sathi" in 16 px emphasis, "Roads" in 12 px. Then the nav items: icon and label (wide) or icon only (medium). Divider. Then New record and Settings where they apply. Item height 44 px.
- **States.** Default, hover (`surfaceAlt` fill), focused (ring), selected (`primaryContainer` fill with 2 px `primary` left edge), disabled (none; items are hidden by role).
- **Example.** Selected item: "Flags" with count "9 open" in 12 px.

### 5.12 Bottom bar (narrow)
- **Anatomy.** Five slots, each icon above label, 12 px labels. Slot is 44 px tall minimum.
- **States.** Default, selected (`primary` icon and label, with a 2 px top edge), focused (ring).
- **Marathi.** Labels may wrap to two lines within the slot. Do not truncate.

### 5.13 Header
- See section 4. Contents: name, ward selector, synthetic tag, language toggle, theme toggle, account menu.

### 5.14 Language toggle
- **Anatomy.** Segmented control with two options: "EN" and "मराठी". Selected option has `primaryContainer` fill and `primary` text.
- **States.** Default, selected, focused. Saved per device; switching does not reload the page.

### 5.15 Theme toggle
- **Anatomy.** Icon button (44 px target) that opens a small menu: Light, Dark, System. The current choice is marked with a check.
- **States.** Default, open, focused.

### 5.16 Account menu
- **Anatomy.** Button with the user's display name. Menu panel: name, role, ward (for officer), a divider, "Sign out", and the line "Independent prototype. Not an official BMC product." in 12 px `textSecondary`.
- **States.** Closed, open, focused.

### 5.17 Ward selector
- **Anatomy.** Select control showing "E · Byculla, Agripada, Mumbai Central". Options list all 24 wards by code and name.
- **Officer behaviour.** Own ward is marked "Your ward". Other wards are selectable for reading. Flags and New record are limited to the own ward (see 6.4 and 6.13).
- **Citizen behaviour.** Starts on the chosen ward. Can change ward.
- **States.** Default, open, focused, disabled while loading.

### 5.18 Tabs
- **Anatomy.** Row of tab labels; the selected tab has a 2 px `primary` underline and `primary` text. Count appears in 12 px after the label where relevant ("Over-billed 109").
- **Variants.** Ward page (Money trail, Plan, Scorecard). Flag queue (four tabs). New record (Work order, Complaint).
- **States.** Default, selected, focused. Keyboard arrows move between tabs.

### 5.19 Filter bar
- **Anatomy.** Row of selects and a clear button: Ward (auditor only), Contractor, Decision state. Each select shows its label above the value.
- **Narrow.** Filters collapse behind a "Filters" button that opens a full-page list.
- **States.** Default, filter active (count in a chip), focused.

### 5.20 ScoreParts (risk breakdown bars)
- **Purpose.** Shows the six parts of a risk score and how many points each adds.
- **Anatomy.** Six rows. Each: part name (14 px), bar (proportional to its weight), points "22 of 30" (12 px, right-aligned). Total at the bottom: "Risk 92 of 100".
- **Parts and weights.** Severity 30; Critical access 15; Safety record 15; Traffic 15; Flood exposure 15; Demand 10.
- **States.** Loading (six skeleton bars). Settings changed (a notice "Weights changed. Scores recalculated").

### 5.21 ReasonChip
- **Purpose.** A short reason for a plan position, or a flag reason.
- **Anatomy.** Icon, text. 8 px corners, 1 px `borderStrong`, `surfaceAlt` fill.
- **Plan reason examples.** "Ambulance route to a hospital"; "Bus route"; "Flood hotspot nearby"; "Tide-sensitive"; "2 pothole accidents"; "14 complaints"; "Heavy traffic"; "School on road".
- **Variants.** Neutral (most). Critical access (icon: cross, primary-coloured outline).
- **States.** Default, focused (if clickable).

### 5.22 TrailStage (timeline)
- **Purpose.** One stage of the trail view.
- **Anatomy.** Left: vertical rule (1 px `border`), node circle (filled when the stage has data; outlined when it does not). Right: stage name (16 px emphasis), then content.
- **Stages.** Complaints, Issue, Work order, Road, Outcome.
- **Variants.**
  - Filled: normal content.
  - Empty (never fixed): node outlined; text "Never fixed" in 16 px emphasis, with the plan rank line below.
  - Empty (no complaint): node outlined; text "No complaint linked".
  - Corrected field: reported value shown with strike-through, corrected value beside it, and a label "Corrected".
- **States.** Loading (skeleton of the stage). Error (ErrorState inside the stage).

### 5.23 EvidencePair (flag evidence comparison)
- **Purpose.** Two work orders side by side, with matching fields marked. Used for possible double billing.
- **Anatomy.** Two columns with the same row labels: road, work type, contractor, area, cost, assigned date, complaint link. Each row: value in each column. Matching rows get a "Matches" tag with a check icon, in `textPrimary` on `surfaceAlt`. Differing rows get "Differs" with a dash icon.
- **Bottom row.** "Days apart: 4 (within 7)". For the second work order, "No complaint linked" in `flag` text.
- **States.** Loading (two skeleton columns). Error (ErrorState).

### 5.24 BudgetLine (budget divider)
- **Purpose.** The point where the remaining budget runs out in the plan.
- **Anatomy.** Full-width row, 1 px dashed `borderStrong` line, with centred label "Budget runs out here" (14 px emphasis) and a second line "₹7.9 L left after item 2" (12 px).
- **Overspent variant.** Placed at the top, above item 1, reading "Budget already used up" and a second line "Over budget by ₹10.2 L".
- **States.** None; it is always present when the plan has items.

### 5.25 Map and map legend
- **Map.** Ward polygons from the bundled outline file. No background tiles. Each ward shows its code. Hover and focus show a tooltip with the ward name, budget, spend and percent. Selected ward has a 2 px `primary` outline.
- **Legend.** Five rows below the map, each with a swatch (with its pattern), the range text, and the wording: "under 80%", "80 to 89%", "90 to 99%", "100 to 110%", "over 110%". Title "Spend as share of budget".
- **Equivalent table.** The table beside the map is the accessible equivalent; selecting a row highlights the ward on the map and the reverse.
- **States.** Loading (grey outline shapes). Error (map replaced with ErrorState; the table still works).

### 5.26 Form fields
- **Text input.** Label above (14 px emphasis), input 44 px tall, 1 px `borderStrong`, 8 px corners. Helper text below in 12 px `textSecondary`. Error text below in `error` with an icon.
- **Money input.** ₹ prefix inside the field. Expected cost and ratio update below as the user types, in 12 px: "Expected ₹71,400 · Ratio 0.90x".
- **Select.** Same as text input, with a chevron.
- **Searchable select.** Text input with a list below; list items are 44 px tall.
- **Date input.** Native date control, format "2 Aug 2025".
- **Multi-select chips.** For linked complaint ids. Each chip shows the id with a remove button (44 px target).
- **Text area.** Five rows; character counter in 12 px ("412 of 500").
- **States.** Default, focused (ring), filled, error, disabled, read-only.

### 5.27 ResultCard
- **Purpose.** Confirms a save and shows what the save changed.
- **Anatomy.** Heading with icon ("Saved"); body lines; list of flags raised, each with a link; a link to the trail.
- **Variants.** Work order saved with no flag. Work order saved with flags raised. Complaint joined an existing issue. Complaint created a new issue.
- **States.** Saving (button shows "Saving…" and is disabled). Error (ErrorState with Retry, request id). Conflict (inline message "This work order id already exists").

### 5.28 Summary block
- **Purpose.** The stored, written summary for a ward or contractor.
- **Anatomy.** Heading "Summary (written from these figures)". Body text 14 px, up to 120 words. "Ask" button top right.
- **States.** Loading (three skeleton lines). Stale ("Written before recent changes" notice above the body). Missing ("No summary yet for this ward. The figures above are current.").

### 5.29 AskPanel
- **Purpose.** Ask one question about the ward, contractor or complaint in view. Opens in the DetailPanel.
- **Anatomy.** Heading "Ask about this ward" (or contractor, or complaint). Text field with 500-character counter. Send button. Answer area below: answer text, then "Sources" with record ids as links.
- **Holds only the current answer.** A new question replaces the old one.
- **States.** Idle (placeholder text: "Ask about these figures"). Sending (button disabled, "Sending…"). Answer. Error: "The assistant is not available. The figures on this page are unaffected." Rate limit: "Too many questions. Try again in a minute." (proposed).

### 5.30 SettingRow
- **Purpose.** One rule setting, in the settings table.
- **Anatomy.** Name (14 px emphasis), description (12 px `textSecondary`), value input, Save button (44 px). For risk weights: a running total "Total 100 of 100" line under the six rows.
- **States.** Default, changed (Save becomes active), saving, saved ("Saved" in `success` text for 3 seconds), error. Weights: Save disabled and the total in `error` text when the total is not 100.

### 5.31 Stacked card (narrow table row)
- **Purpose.** Replaces a table row below 720 px.
- **Anatomy.** Card with a title line (16 px emphasis), a second line (14 px), then two or three label and value pairs in a 2-column grid. Tappable as a whole, 44 px minimum height.

### 5.32 Lists and cards used by screens
- **Flag row.** Work order id (14 px emphasis), road, contractor, amount at stake (MoneyText), one-line reason (14 px), DecisionChip. Tappable.
- **Contractor card.** Name (16 px emphasis, with "(synthetic)" as stored), jobs, spend, wards worked, in a plain grid. No score, no rank, no band.
- **Plan card.** Rank number (20 px), road and segment (16 px emphasis), category and complaint count (14 px), risk score (16 px), ReasonChips, recommended method with estimated cost, alternative with cost and re-open rate. Expand control reveals ScoreParts and a trail link.
- **Search result row.** Type label (12 px), id or name (16 px emphasis), one line of context (14 px).

---

## 6. Screen specifications

Each screen lists who sees it, what differs by role, a text wireframe at wide and narrow widths, sample content and the states that apply. Wireframes are shape guides, not pixel specs.

### 6.1 Sign-in (`/login`)

- **Who.** Everyone, before sign-in.
- **Role differences.** None.
- **Purpose.** Sign in with a username and password, or tap one of three demo account cards that fill the form and sign in.

Wide (1440 × 900), centred column 420 px:

```
BMC Sathi · Roads                                  [Synthetic data]  EN | मराठी  [theme]

                 Sign in
                 Username  [______________]
                 Password  [______________]
                 [ Sign in ]
                 Error text appears here, under the form.

                 Demo accounts
                 [ Ward officer · Ward E ]
                 [ Auditor ]
                 [ Citizen ]

                 Independent prototype. Not an official BMC product.
```

Narrow (390 px): the same, single column, full width with 16 px gutters. Demo cards stack vertically, each 44 px or taller.

- **Sample content.** Error under the form: "Username or password is not right." (proposed). Card subtitles: "Your ward", "Head office", "Ward or corporator view".
- **States.** Loading (button shows "Signing in…"). Error (text under the form). Session expired ("Please sign in again.", shown above the form).
- **Notes.** No BMC crest. Synthetic tag and prototype line are always visible.

### 6.2 City view (`/city`)

- **Who.** Auditor (home). Officer and citizen may open it.
- **Role differences.** None beyond access; all roles see the same figures.
- **Purpose.** Shows all 24 wards on a map shaded by spend against budget, with a sortable table beside it.

Wide (1440 × 900):

```
Header: BMC Sathi · Roads   [Synthetic data]   EN | मराठी   [theme]   [account]
Rail: Overview | Flags | Contractors | Plan | Trail | Settings

City totals (four tiles across the top)
[ Budget ₹14.91 cr ] [ Spent ₹13.43 cr · 90% ] [ In open flags ₹ (illustrative) ] [ Re-opened spend ₹ (illustrative) ]

+---------------------------------+  +----------------------------------------------+
| MAP of 24 wards                 |  | Ward | Budget | Spent | % of budget | Flags  |
| shaded in five steps            |  | E    | 53.0 L | 63.2 L| 119%        | 12 (ill.) |
| legend below the map            |  | R/C  | 29.0 L | 33.1 L| 114%        |  9 (ill.) |
|                                 |  | L    | 1.19 cr| 1.30 cr| 110%       | 14 (ill.) |
+---------------------------------+  +----------------------------------------------+
```

Flags column values are illustrative. Budget and spend figures are from the data.

Narrow (390 px): totals as a 2 × 2 grid of tiles. Then the map (320 px tall). Then the table as stacked cards, each card: ward code and name, percent with BandChip-style text "Over by 19%", budget and spent, flags.

- **Sample rows (sorted by % of budget, descending, default).**

| Ward | Ward name | Budget | Spent | % |
|---|---|---|---|---|
| E | Byculla, Agripada, Mumbai Central | ₹53.0 L | ₹63.2 L | 119% |
| R/C | Borivali | ₹29.0 L | ₹33.1 L | 114% |
| L | Kurla | ₹1.19 cr | ₹1.30 cr | 110% |
| M/W | Chembur | ₹44.0 L | ₹46.9 L | 107% |
| A | Colaba, Fort, Churchgate | ₹16.0 L | ₹16.6 L | 103% |
| R/S | Kandivali | ₹66.0 L | ₹66.4 L | 101% |
| H/W | Bandra West, Khar West, Santacruz West | ₹43.0 L | ₹42.5 L | 99% |
| N | Ghatkopar, Vikhroli | ₹62.0 L | ₹60.0 L | 97% |

- **Interaction.** Selecting a ward on the map highlights its table row, and the reverse. Opening it goes to the ward page. Sorting: any column; default is spend as share of budget, highest first.
- **States.** Loading (grey map outline; table as skeleton rows). Empty (not expected; if no ward data: "No ward data is loaded yet."). Error (map replaced by ErrorState; table also ErrorState). Stale: not used on this page.
- **Over-budget signal.** Percent cells over 100% use the `error` colour and the word "Over by" in the adjacent column, so the signal does not depend on colour alone.

### 6.3 Ward money trail (`/ward/:code`)

- **Who.** Officer (own ward, home). Auditor (any ward). Citizen (chosen ward).
- **Role differences.**
  - Officer and auditor: flag counts link to the flag queue.
  - Citizen: no Flags link. The "In open flags" tile shows count and amount only, with no list link.
  - Citizen never sees complainant ids, decided-by names or flag notes.
- **Purpose.** Money for one ward: budget, spend, over or left; three money-at-question tiles; spend breakdowns; a summary.

Wide (1440 × 900), Ward E shown:

```
Header: [Ward E · Byculla, Agripada, Mumbai Central ▾]  [Synthetic data]  EN | मराठी  [theme]  [account]

Ward E · Byculla, Agripada, Mumbai Central          [ Money trail | Plan | Scorecard ]

Budget ₹53.0 L     Spent ₹63.2 L     Over by ₹10.2 L (119%)
[==========================================|====]  bar; past 100% in error colour

[ Re-opened in 30 days ]     [ Billed under DLP ]     [ In open flags ]
[ ₹ (illustrative) · n jobs ] [ ₹ (illustrative) · n jobs ] [ ₹ (illustrative) · n flags ]

Spend by:  ( Contractor | Method | Week )
Western Coast Asphalt Co (synthetic)   [=========]  ₹ (illustrative)  n jobs
Arabian Sea Engineering (synthetic)    [=======]    ₹ (illustrative)  n jobs
...

Summary (written from these figures)                                    [ Ask ]
"Ward E spent ₹63.2 L against a budget of ₹53.0 L..." (about 120 words)
```

Layout detail at wide: the three tiles sit in one row across the main area. Breakdown below the tiles, with BarList. Summary at the bottom. The budget bar is a single 8 px tall track; the fill stops at 100% with a marker; anything past 100% is drawn in `error`, with "Over by" text.

Narrow (390 px): budget as a stacked block; tiles in a single column; breakdown as BarList; summary at the bottom; Ask as a full-width button under the summary.

- **Sample content.** Ward E has 118 work orders in the data. Bellasis Road and Clare Road have the most work orders. Spend and tile figures on this screen other than the budget line are illustrative.
- **Tapping.** Every figure and every bar opens the work-order list in the DetailPanel. Each work-order row opens its trail.
- **Breakdown tabs.** Contractor, Method, Week. Each replaces the BarList.
- **States.**
  - Loading: skeleton of tiles and bars.
  - Empty: "No work orders in this ward yet." under the breakdown.
  - Error: ErrorState for the breakdown; the budget figures still show if they loaded.
  - Stale summary: "Written before recent changes" above the summary body.
  - Not allowed (e.g. officer opens another ward's Flags via a link): redirect with the notice.

### 6.4 Flag queue (`/flags`)

- **Who.** Officer (own ward only). Auditor (all wards). Citizen: not allowed.
- **Role differences.** Officer: ward filter is locked to own ward and is not shown. Auditor: ward filter is shown.
- **Purpose.** Work the open flags, largest amount first. Tabs by flag type.

Wide (1440 × 900):

```
Section: Flags
Header strip: 74 open · ₹ (illustrative) at stake · 12 decided (all three illustrative)

[ Over-billed 109 ]  [ Possible double billing 45 ]  [ Recover under DLP 493 · ₹2.62 cr ]  [ Watch 5 ]
Amounts shown per tab: over-billed, double billing and DLP tabs show amount at stake.

Filters: Ward ▾ (auditor only)   Contractor ▾   Decision ▾ (Open by default)

Work order  | Road                     | Contractor              | At stake   | Reason                                  | Decision
WO25-02461  | Dr Babasaheb Ambedkar Rd | Deccan Paving Solutions | ₹64,531    | Same road, area and contractor as WO25-01323, 4 days earlier | [Open]
...
```

Narrow (390 px): tabs become a horizontal scroll row with the four tabs (no hidden tabs; each tab 44 px tall); filters collapse behind a Filters button; rows become Flag rows (5.32).

- **Sample reasons (template-filled, English).**
  - Over-billed: "Billed 1.70 times the rate card for Dewatering pump deployed (illustrative)."
  - Double billing: "Same road, work type, contractor and area as WO25-01323, 4 days earlier. No complaint linked."
  - DLP: "Billed on Maulana Azad Road, which is under defect liability period."
- **Marathi reasons.** Templates in section 7.
- **Sorting.** Default: open first, then largest amount at stake. Other sorts: date.
- **States.** Loading (skeleton rows). Empty: "No open flags in this ward." (or "No flags in this tab."). Error (ErrorState with Retry). Not allowed for citizens (redirect notice).

### 6.5 Flag detail (`/flags/:type/:workOrderId`)

- **Who.** Officer (own ward) and auditor.
- **Role differences.** Officer: decision control enabled for own-ward flags only; other wards are read-only. Auditor: decision control enabled for all.
- **Purpose.** Show the evidence and record one decision.
- **Layout.** Wide: DetailPanel on the right, 420 px, with the flag queue behind. Medium: sheet. Narrow: its own page.

Common frame, top to bottom:
1. Title: flag type label. Subtitle: work order id, road.
2. Current decision (DecisionChip) with "by [name], [date]" below. If none: "Open. No decision recorded yet."
3. Evidence block (below).
4. Links: "Work order trail" and "Contractor scorecard".
5. Decision control: radio group (Confirmed, Needs explanation, Not an issue), note text area (500 characters), Save button.

Watch-tier rows show the frame with evidence, but **no decision control**. Replace it with the line: "Watch items show evidence only. No decision is recorded for them."

#### 6.5.1 Over-billed

Evidence (illustrative job, real structure):

```
Method                    Dewatering pump deployed (per job)
Area                      not used for per-job methods
Rate card                 ₹60,000 per job
Expected cost             ₹60,000
Billed cost               ₹1,02,000
Ratio                     1.70 times the rate card

Where this job sits against the normal range
0x ----------|---------|-----------|-------------|--------------------
            0.77x    1.0x        1.3x          1.5x
                 normal range   watch   flag
                                                 ^ this job at 1.70x
```

- The strip uses text labels under the markers, not colour alone: "normal 0.77x to 1.3x", "watch 1.3x to 1.5x", "flag above 1.5x".
- Reason line: "Billed 1.70 times the rate card for Dewatering pump deployed."
- Amount at stake: ₹42,000 (billed minus expected), in MoneyText.

#### 6.5.2 Possible double billing (the demo flag)

Evidence: EvidencePair with the two real work orders.

```
                        Earlier job                       Second job (flagged)
Work order              WO25-01323                        WO25-02461
Road                    Dr Babasaheb Ambedkar Road  Matches    Dr Babasaheb Ambedkar Road  Matches
                        (segment 2, RD0046)                     (segment 2, RD0046)
Work type               Broken paver blocks               Matches   Broken paver blocks          Matches
Method                  Paver blocks relaid                         Paver blocks relaid
Contractor              Deccan Paving Solutions (synthetic) Matches Deccan Paving Solutions (synthetic) Matches
Area                    23.8 sqm                          Matches   23.8 sqm                     Matches
Assigned                29 Jul 2025                                 2 Aug 2025
Days apart              4 days (within 7)
Linked complaints       BMC25-003431, BMC25-003432        ---        No complaint linked (flag)
Cost                    ₹62,186                                     ₹64,531
Amount at stake                                                     ₹64,531
```

- Ratio note under the pair: "Both jobs are within the rate card range (0.87x and 0.90x). The flag is about repeat work with no complaint, not about rate."
- Links: "Trail for WO25-02461" and "Trail for WO25-01323". "Contractor scorecard: Deccan Paving Solutions (synthetic)".
- Sample note (text in the field, for the screenshot): "Area matches the earlier job. Asked the contractor for the measurement sheet."
- Decision saved: DecisionChip shows "Needs explanation" with "by Ward E officer, 21 Nov 2026" (illustrative names).

Wide (1440 × 900): the flag queue remains on the left at reduced contrast? No. Keep the queue at full width behind; the panel is 420 px. The EvidencePair is two columns of 190 px each inside the panel; if that is too narrow, stack the two work orders as tabs labelled "Earlier job" and "Second job", with matches shown on the second.

Narrow (390 px): EvidencePair becomes two stacked blocks, "Earlier job" then "Second job", each with the matches list; matches are marked "Matches" text.

#### 6.5.3 Recover under DLP

Evidence (real road):

```
Road                      Maulana Azad Road (Main, Concrete (CC))
Last resurfaced           20 Apr 2024
DLP status                Under defect liability period
Work order                WO25-00014 · Drain desilting · Western Coast Asphalt Co (synthetic)
Billed cost               ₹85,657
Expected (rate card)      ₹90,000 per job (ratio 0.95x)
Liable party              "Liable party is the road's original contractor, which this data does not name."
```

- Reason line: "Billed on a road under its defect liability period."
- Watch the wording: the tab is "Recover under DLP". The liable party line is required, verbatim, in the evidence block.
- Amount at stake: ₹85,657.

#### 6.5.4 Watch (over-billed, 1.3x to 1.5x)

Frame and evidence as 6.5.1, with the strip showing 1.38x (illustrative) between the watch and flag markers. No decision control. Reason line: "Billed 1.38 times the rate card. Watch only, not a flag." The header shows the "Watch" DecisionChip with eye icon.

States for all flag detail screens:
- Loading: skeleton of the frame and evidence block.
- Error: ErrorState in the panel body with Retry.
- Conflict (decision on watch tier): "Watch items cannot take a decision."
- Saved: ResultCard-style confirmation line "Decision saved." for three seconds, then the chip updates.

### 6.6 Contractor list (`/contractors`)

- **Who.** Everyone.
- **Role differences.** None.
- **Purpose.** Eight contractor cards in name order. No sorting by performance; no rank numbers.

Wide (1440 × 900): two columns of cards, four rows. Each card: name, then a row of facts.

Narrow (390 px): one column of cards.

Card content (real figures, name order):

| Contractor | Jobs | Spend | Wards worked |
|---|---|---|---|
| Arabian Sea Engineering (synthetic) | 328 | ₹1.86 cr | 24 |
| Deccan Paving Solutions (synthetic) | 287 | ₹1.41 cr | 24 |
| Konkan Roadcon Pvt Ltd (synthetic) | 337 | ₹1.89 cr | 24 |
| Mahalaxmi Civil Contractors (synthetic) | 303 | ₹1.62 cr | 24 |
| Mithi Infra Projects (synthetic) | 319 | ₹1.71 cr | 24 |
| Sahyadri Infra Works (synthetic) | 337 | ₹1.72 cr | 24 |
| Shivneri Construction (synthetic) | 289 | ₹1.47 cr | 24 |
| Western Coast Asphalt Co (synthetic) | 299 | ₹1.75 cr | 24 |

These totals reconcile to 2,499 jobs and ₹13.43 cr. "Wards worked" shows 24 for every contractor, as the work-order data says (see section 11).

- **Card interaction.** The whole card opens the contractor scorecard. Focus ring on the card.
- **Anti-goal check.** No star, no badge, no colour on the card, no order other than name.
- **States.** Loading (eight skeleton cards). Empty: "No contractors are loaded yet." Error (ErrorState with Retry).

### 6.7 Contractor scorecard (`/contractors/:id`)

- **Who.** Everyone.
- **Role differences.** None. Citizens see the same page.
- **Purpose.** Three measures, each against similar jobs. No overall grade.

Wide (1440 × 900), Mahalaxmi Civil Contractors (synthetic):

```
Section: Mahalaxmi Civil Contractors (synthetic)
303 jobs · ₹1.62 cr · 24 wards                          [ Summary ] [ Ask ]

Summary (written from these figures)
"..." under 120 words. Names one thing to improve. No accusatory words.

+------------------------------------+ +------------------------------------+ +-----------------------------+
| SPEED                              | | DURABILITY                         | | COST                        |
| 39% on time                        | | 38% re-opened within 30 days       | | 1.08x rate card (typical)   |
| [ Below ]                          | | [ Well below ]                     | | [ Typical ]                 |
| This contractor  [=====]  39%      | | This contractor [========] 38%     | | Median job       [====] 1.08x |
| Similar jobs     [========] 47%   | | Similar jobs    [====] 24%         | | Rate card        [====] 1.00x|
| Context: n in heavy-rain weeks,    | | Context: n in heavy-rain weeks,    | | Context: n in low-lying wards |
|   n in low-lying wards             | |   n in low-lying wards             | | 42 jobs above 1.5x [Review] |
| > See work orders                  | | > See re-opened jobs               | | > See the 42 jobs           |
+------------------------------------+ +------------------------------------+ +-----------------------------+

> How this is compared (expander, closed by default)
```

Layout: three measure cards in a row at wide, each about one third of the main area. Medium: three cards stacked as a 2-column grid, the third spanning both columns. Narrow: single column of cards in the order Speed, Durability, Cost.

Measure card anatomy: title (12 px label, uppercase is not allowed, use sentence case "Speed"), the observed figure (28 px), a plain sub-line (14 px), BandChip, CompareBars, context line (12 px), link (44 px target).

- **Band copy rules.** Speed: "39% on time". Durability: "38% re-opened within 30 days". Cost: "1.08x rate card (typical job)" for median ratio.
- **Durability gloss.** Under the band: "More re-opens than similar jobs" (proposed, see 5.3).
- **Too few jobs.** When the subject has fewer jobs than the minimum (30), replace the CompareBars and band with "Too few jobs to say" and the observed figure only.
- **"How this is compared" expander.** Three sentences: "Similar jobs means the same work type and repair method, in the same rain band and ward type. A contractor's own jobs are left out of their comparison. A band other than similar appears only when the gap is larger than chance would explain for that many jobs."
- **Summary.** Under the cards, the Summary block (5.28). The AskPanel opens from the Ask button in the DetailPanel.
- **States.** Loading (three skeleton cards). Stale summary notice. Error (ErrorState inside each card, with Retry on that card only). Not allowed: none.

Narrow (390 px): summary first, then measure cards, then "How this is compared".

### 6.8 Ward scorecard (`/ward/:code/scorecard`)

- **Who.** Everyone, from the ward page tab.
- **Role differences.** None.
- **Purpose.** The same three measures, for one ward's work.
- **Sample.** Ward C (Kalbadevi, Bhuleshwar, Marine Lines) has 20 work orders in the data, under the minimum of 30. Every measure shows "Too few jobs to say".

Wide (1440 × 900):

```
Ward C · Kalbadevi, Bhuleshwar, Marine Lines                [ Money trail | Plan | Scorecard ]
20 jobs · ₹8.0 L spent · 89% of budget

Speed          Too few jobs to say     (observed: n% on time, illustrative)
Durability     Too few jobs to say     (observed: n% re-opened, illustrative)
Cost           Too few jobs to say     (median ratio shown, illustrative)

Summary (written from these figures)
```

- **Layout.** Same as the contractor scorecard, with the three cards in one row at wide.
- **Note.** The page explains in one sentence: "This ward has fewer than 30 jobs, so results are not compared yet."
- **States.** Same as 6.7.

### 6.9 Next-rupee plan (`/ward/:code/plan`)

- **Who.** Everyone, for any ward.
- **Role differences.** None. Citizens see the same plan.
- **Purpose.** Open issues ranked by risk, with method and cost, and a line where the budget runs out.

Two variants. Both are shown below.

#### 6.9.1 Within budget: Ward B (real budget, illustrative items)

Header: "Ward B · ₹7.9 L left of ₹43.0 L" (budget ₹43.0 L, spent ₹35.1 L, 82%).

Wide (1440 × 900):

```
Header: Ward B · Dongri, Masjid Bunder      [ Money trail | Plan | Scorecard ]
Remaining budget ₹7.9 L of ₹43.0 L

[ 1 ]  P D'Mello Road · Pothole cluster                       Risk 84 of 100
       14 complaints · 2 bus route · flood hotspot nearby
       Reasons: [Bus route] [Flood hotspot nearby] [14 complaints]
       Recommended: Hot mix patch · est. ₹ (illustrative) 0.9 L
       Alternative: Cold mix patch · ₹ (illustrative) 0.6 L · re-opens 32% (measured)
       > Score parts and trail

[ 2 ]  Nishanpada Road · Waterlogging                          Risk 78 of 100
       ...

------------------------------ Budget runs out here ------------------------------
                                  ₹7.9 L left after item 2

[ 3 ]  ...  est. ₹1.1 L  · needs ₹0.6 L more (illustrative)

Footer: 2 items within budget · ₹ (illustrative) 2.1 L total
```

- **Road names.** "P D'Mello Road" and "Nishanpada Road" are real Ward B roads in the data with the most work orders. Risk, cost and reasons are illustrative.
- **Expanded card.** ScoreParts (5.20) with points, and the trail link.
- **Alternative line.** Shows the alternative method, its cost, and its measured re-open rate where one exists.

Narrow (390 px): cards in a single column; the budget line is a full-width row between cards.

#### 6.9.2 Overspent: Ward E (real overspend)

Header: "Needs additional budget" (heading), then "Over budget by ₹10.2 L: everything below needs additional funds."

Wide (1440 × 900):

```
Header: Ward E · Byculla, Agripada, Mumbai Central      [ Money trail | Plan | Scorecard ]
Needs additional budget
Over budget by ₹10.2 L: everything below needs additional funds.

------------------------------ Budget already used up ------------------------------
                                  Over budget by ₹10.2 L

[ 1 ]  Bellasis Road · Road cave-in (illustrative)                 Risk 92 of 100
       Reasons: [Ambulance route to a hospital] [Bus route] [Safety record]
       Recommended: Excavation, pipeline repair, PQC patch · est. ₹1.8 L (illustrative)
       Needs ₹1.8 L more
[ 2 ]  ...  (cards continue, each with "Needs ₹x more" line, illustrative)

Footer: 0 items within budget · total needed ₹ (illustrative)
```

- **Design rule.** For an overspent ward every item is below the line. Show no item as "within budget".
- **Road name.** Bellasis Road is the top ward E road in the data by work orders; the risk and cost are illustrative.
- **Budget line.** At the top, not in the middle, because nothing in an overspent ward is affordable.

Narrow (390 px): heading, overspend sentence, budget-used-up divider, then cards.

- **States (both variants).**
  - Loading: skeleton cards.
  - Empty: "No open issues in this ward." Footer shows "0 items within budget".
  - Error: ErrorState with Retry and request id.
  - Stale: "Written before recent changes" applies only to the summary; the plan itself is live.

### 6.10 Trail search (`/trail`)

- **Who.** Everyone.
- **Role differences.** None.
- **Purpose.** Find any complaint, work order, road or locality and open its trail. The citizen's "what happened to my complaint" screen.

Wide (1440 × 900):

```
Section: Trail
Search  [ BMC25-001879, WO25-02461, Bellasis Road, Nagpada...                  ] (min 3 characters)

Complaints (2)
  BMC25-001879 · Road cave-in · Nagpada · Open                              >
  BMC25-001877 · Road cave-in · Nagpada · Open                              >
Work orders (2)
  WO25-02461 · Dr Babasaheb Ambedkar Road · Deccan Paving Solutions          >
  WO25-01323 · Dr Babasaheb Ambedkar Road · Deccan Paving Solutions          >
Roads (1)
  Bellasis Road · Ward E                                                      >
Localities (1)
  Nagpada · Ward E                                                            >
```

- **Behaviour.** Up to 20 matches, grouped by type. Each row opens the trail view. Results appear after three characters.
- **Narrow.** Search field at top, full width. Results as search result rows (5.32).
- **States.** Empty before typing: "Type a complaint id, work order id, road or locality. At least 3 characters." No results: "No matches for '[query]'. Try a road name or locality." Loading (three skeleton rows). Error (ErrorState with Retry).

### 6.11 Trail view (`/trail/issue/:id`, `/trail/work-order/:id`)

- **Who.** Everyone.
- **Role differences.** Citizen: complainant ids are not shown. Officer and auditor: flags on the work order are shown with links; citizens see the flag name and status only, not notes or decided-by.
- **Purpose.** One item end to end: complaints → issue → work order → road → outcome.
- **Layout.** Vertical TrailStage timeline, with the five stages in order. At wide, the timeline fills the main area with a right column for the outcome card if needed. At narrow, one column.

Common frame: title "Work order WO25-00008" or "Issue (complaint BMC25-001879)". Subtitle: ward, road.

Four variants follow. Each uses real data.

#### 6.11.1 Fixed: held, SLA missed (WO25-00008)

```
[ Complaints ]  ●
  BMC25-000023   English   channel and date as in the data
  BMC25-000022   Marathi   Choked drain / nullah overflow
     Original:    Madanpura मध्ये पाणी साचले आहे, गाड्या अडकल्या आहेत. पंप पाठवा.
     Translated:  Water has collected in Madanpura and vehicles are stuck. Please send a pump. (draft)
  BMC25-000021   English   ...
[ Issue ]  ●
  Category: Choked drain / nullah overflow
  Severity: 3 (estimated) (illustrative)
  Complaints: 3 · Related social posts: 2 (collapsed)
[ Work order ]  ●
  WO25-00008 · Western Coast Asphalt Co (synthetic)
  Method: Desilting and garbage removal
  Assigned: 2 Jun 2025 00:13 · Completed: 7 Jun 2025 19:26
  Cost: ₹88,502 against ₹70,000 expected · 1.26x
  SLA: missed (48 h limit)
  Engineer remark (as recorded): "Done as per site condition"
[ Road ]  ●
  Bellasis Road · Main · Concrete (CC) · last resurfaced 5 Apr 2022 · DLP: no
[ Outcome ]  ●
  SLA missed · Held (not re-opened within 30 days)
  Flags on this work order: none
```

Notes: the "Translated" line is marked "Translated" in 12 px. The reported category is not corrected here, so no strike-through is needed.

#### 6.11.2 Re-opened (WO25-00056)

```
[ Complaints ]  ●  BMC25-000150 · English · Pothole reported
   "Complainant states pothole at Byculla, near medical store on Clare Road. Water level rising."
[ Issue ]  ●  Category: Pothole · Severity 4 (estimated, illustrative) · Complaints: 1
[ Work order ]  ●
  WO25-00056 · Arabian Sea Engineering (synthetic)
  Method: Mastic asphalt · 10.0 sqm · ₹42,742 against ₹42,000 expected · 1.02x
  Assigned: 10 Jun 2025 07:51 · Completed: 12 Jun 2025 00:14
  SLA: missed
[ Road ]  ●  Clare Road · Main · Asphalt · last resurfaced 24 Feb 2024 · DLP: yes
[ Outcome ]  ●  Re-opened within 30 days · SLA missed
  Flags: Recover under DLP (₹42,742) · open · link
```

- **Re-opened label.** Use an info or neutral chip "Re-opened within 30 days" with an arrow icon. Not red unless the item is a confirmed problem. Confirmed status comes only from a decision.
- **Flag on this work order.** Shows "Recover under DLP", amount, and a link to its flag detail.

#### 6.11.3 Never fixed (issue BMC25-001879)

```
[ Complaints ]  ●  BMC25-001879 · English · Road cave-in · 39 upvotes
   "Part of Bellasis Road has sunk near Ganpati mandal pandal. Pipeline leaking below?"
   (Also: BMC25-001877, 5 upvotes, same place, reported as "Other")
[ Issue ]  ●  Category: Road cave-in · Severity 5 (estimated) · Complaints: 2 · Status: Open
[ Work order ]  ○  Never fixed
   Plan rank: 1 in the Ward E plan (illustrative)  > Open plan
[ Road ]  ●  Bellasis Road · Main · Concrete (CC) · last resurfaced 5 Apr 2022
[ Outcome ]  ○  Open. No work order yet.
```

- The "Never fixed" line is 16 px emphasis, `textPrimary`, with the empty node. It is text, not a red alert.
- Corrected category: BMC25-001877 reported "Other"; the corrected category shows with strike-through of "Other" and "Road cave-in" beside it, labelled "Corrected". Illustrative for this complaint.

#### 6.11.4 No complaint linked (WO25-02461)

```
[ Complaints ]  ○  No complaint linked
[ Issue ]  ○  No issue. This work order has no linked complaints.
[ Work order ]  ●
  WO25-02461 · Deccan Paving Solutions (synthetic)
  Method: Paver blocks relaid · 23.8 sqm · ₹64,531 against ₹71,400 expected · 0.90x
  Assigned: 2 Aug 2025 09:03 · Started: 2 Aug 2025 14:42 · Completed: 3 Aug 2025 03:10
  SLA: met (120 h limit)
  Engineer remark (as recorded): "Done as per site condition"
[ Road ]  ●  Dr Babasaheb Ambedkar Road · segment 2 · Paver blocks · last resurfaced 17 Feb 2022 · DLP: no · bus route: yes
[ Outcome ]  ●  Held. Not re-opened.
  Flags: Possible double billing (see WO25-01323) · open · link
```

- Stage "Complaints" uses the empty node and "No complaint linked" as the first stage text.

Narrow (390 px): stages stacked vertically with the same content. Long text (complaint text, Marathi) wraps.

States for trail view: loading (skeleton of five stages); error (ErrorState inside the stage that failed); not found (ErrorState: "No record with this id. Check the id or search again." with a link to search).

### 6.12 Ask panel

- **Who.** Everyone. Opens from the Ask button on the ward page, scorecards and trail view.
- **Role differences.** None.
- **Purpose.** Ask one question. Answer from the data only, with source ids.
- **Layout.** Opens in the DetailPanel (wide 420 px; medium sheet; narrow page).

Wide panel content:

```
Ask about this ward                                                       [ close ]
[ Ask about these figures                                           ] 0 of 500
[ Send ]

Answer
"Ward E spent ₹63.2 L against ₹53.0 L of budget. The largest breakdown line is ..." (sample, up to 120 words)
Sources: WO25-00008 · WO25-00056 · Ward E (ward summary)   (each id is a link)

The answer is from the figures on this page. Claude wrote it from the data listed in Sources. (proposed footnote)
```

- **Holds one answer.** A new question replaces the old one. Nothing is stored.
- **Sample questions (for empty-state chips, optional).** "What is the budget for this ward?" "Why is this plan ranked this way?" "Which contractor has the most re-opened repairs?" (Do not show a ranking answer; the assistant must not rank contractors.)
- **States.** Idle (placeholder). Sending (button disabled, "Sending…"). Answer. Error (plain message below, with the rest of the page unaffected). Rate limit (message above). Empty answer: "The data does not contain that answer. Try the Money trail or Plan screen."

### 6.13 New record (`/intake`)

- **Who.** Ward officer only. Own ward only.
- **Role differences.** Auditor and citizen: not allowed (redirect with notice).
- **Purpose.** Add a work order or a complaint. Both run the same rules as the rest of the app.
- **Layout.** Two tabs: Work order (default), Complaint.

#### 6.13.1 Work order tab

Wide (1440 × 900), two columns of fields with a result panel on the right after save:

```
New record                                  [ Work order | Complaint ]

Road (searchable, own ward)     [ Dr Babasaheb Ambedkar Road · segment 2 (RD0046)  ▾ ]
Work type                       [ Broken paver blocks ▾ ]
Method (filtered by work type)  [ Paver blocks relaid ▾ ]
Contractor                      [ Deccan Paving Solutions (synthetic) ▾ ]
Area (sqm)                      [ 23.8 ]
Cost                            [ ₹ 64,531 ]
Expected cost and ratio         Expected ₹71,400 · Ratio 0.90x
Assigned                        [ 2 Aug 2025 ]   Started [ ... ]   Completed [ ... ]
Linked complaint ids (optional) [ BMC25-____ ] [ + add ]

[ Save work order ]
```

Result card after save (sample, illustrative new id):

```
Saved: WO25-02500
Flags raised: 1
  Possible double billing · matches WO25-01323 · 4 days earlier   > Open flag
Ward E spend updated (see Money trail)  > Open ward
Contractor scorecard updated  > Open scorecard
```

Narrow (390 px): fields in one column; Save button sticky at bottom; result card below the form.

- **Method filtering.** Shows only methods for the chosen work type. Example: Broken paver blocks → Paver blocks relaid only.
- **Conflict.** "This work order id already exists." in `error` under the id field.

#### 6.13.2 Complaint tab

Wide (1440 × 900):

```
Description   [ text area, 5 rows                                      ]  0 of 500
Category      [ Pothole ▾ ]  (six work types)
Locality      [ Nagpada ▾ ] (searchable, own ward)
Channel       [ MyBMC App ▾ ]  (1916 Helpline, MyBMC Web Portal, MyBMC App)
[ Save complaint ]
```

Result card after save (illustrative):

```
Saved: BMC25-004010
Joined existing issue: Road cave-in · Bellasis Road · 3 complaints  > Open trail
```

or "Created a new issue: Pothole · Nagpada · 1 complaint  > Open trail".

- **Rule.** New complaints are located by locality; no Claude call is shown or implied.

States for both: saving (button "Saving…"); error (ErrorState with Retry and request id).

### 6.14 Rule settings (`/settings`)

- **Who.** Auditor only. Officer and citizen: not allowed.
- **Purpose.** Tune the thresholds and weights. Changing a setting recalculates everything.
- **Layout.** A table of settings. Each row: name, description, value, Save. At narrow, each row is a stacked card.

Wide (1440 × 900):

```
Settings                                         Saving any setting recalculates all figures.

Setting                       Description                                   Value    
Over-billed threshold         Cost above this times the rate card is a flag      1.5     [Save]
Watch threshold               Cost above this, up to the flag threshold, is watch 1.3    [Save]
Double-billing window         Days a repeat job can follow an earlier one         7      [Save]
Double-billing area tolerance Area difference counted as the same                5%     [Save]
Low-lying ward cutoff         Index at or above this is low-lying                0.6    [Save]
Moderate rain (mm)            Rain band boundary                                  15     [Save]
Heavy rain (mm)               Rain band boundary                                  65     [Save]
Minimum jobs for a band       Below this count, the band reads "too few jobs"     30     [Save]
Band threshold, z             Gap needed for above or below                       2      [Save]
Band threshold, strong z      Gap needed for well above or well below             3      [Save]
High-risk score               Score at which a pothole road uses the best method  70     [Save]
Hotspot radius (m)            Distance for flood exposure                         500    [Save]

Risk weights (must total 100)
Severity            30   [Save]
Critical access     15   [Save]
Safety record       15   [Save]
Traffic             15   [Save]
Flood exposure      15   [Save]
Demand              10   [Save]
Total               100 of 100   (Save disabled unless total is 100)
```

- **Notes.** Values shown are the defaults from the settings table. Descriptions are plain language, not code names.
- **States.** Default; changed (Save active); saving; saved ("Saved. Figures are recalculating." for three seconds); error (inline on that row); weights not 100 (total in `error`, Save disabled).
- **Narrow.** Each setting is a stacked card; the weights block sits last with its total line sticky at the bottom of its section.

### 6.15 Common screen states (apply to every data screen)

| State | Behaviour |
|---|---|
| Loading | Skeleton of the final layout; no spinner over a blank page |
| Empty | One sentence: what is empty and why |
| Error | Plain message, Retry button, request id for server errors |
| Stale summary | Summary shown with "Written before recent changes" |
| Not allowed | Redirect to the role's home with a brief notice |
| Synthetic | "Synthetic data" tag stays in the header in every state |

---

## 7. Language: English and Marathi

### 7.1 Rules

- Every visible string comes from the string files. Design every label twice, in English and Marathi.
- Marathi labels run longer than English. They **wrap to two lines before they truncate**. Test every label, button, tab, chip and header item in Marathi.
- Rupee amounts keep Western digits in both languages: "₹63.2 L" in Marathi too, with the lakh and crore suffixes written in Marathi (see below).
- Data values are shown as stored in English, such as road names, contractor names and ward names. Complaint text is shown in its original language, with the translation beneath it.
- Language toggle: "EN | मराठी". Saved per device.
- Use the Marathi version of the sample screens for Money trail and Plan at minimum, as shown below.

### 7.2 Navigation and page names

| English | Marathi (best rendering) | Notes |
|---|---|---|
| Overview | आढावा | |
| Flags | तपासण्या | Avoid accusatory wording; "तपासण्या" means checks (check) |
| Contractors | कंत्राटदार | |
| Plan | नियोजन | |
| Trail | मागोवा | "Trail" as tracing (check) |
| New record | नवीन नोंद | |
| Settings | सेटिंग्ज | |
| Ward | प्रभाग | |
| Sign in | प्रवेश करा | |
| Synthetic data | कृत्रिम माहिती | (check) |
| Independent prototype. Not an official BMC product. | स्वतंत्र प्रोटोटाइप. BMC चे अधिकृत उत्पादन नाही. | (check) |
| Light / Dark / System | प्रकाश / गडद / सिस्टम | |

### 7.3 Tabs and headings

| English | Marathi | Notes |
|---|---|---|
| Money trail | पैशाचा मागोवा | Ward tab (check) |
| Plan | नियोजन | Ward tab |
| Scorecard | कामगिरी पत्रक | Ward tab (check) |
| Where the money went | पैसा कुठे गेला | Heading (check) |
| Next rupee | पुढचा रुपया कुठे | Heading for plan (check) |
| Did the fix last? | दुरुस्ती टिकली का? | Heading (check) |
| Budget | अंदाजपत्रक | |
| Spent | खर्च | |
| Over by | जास्त खर्च | |
| Left | शिल्लक | |
| Summary (written from these figures) | सारांश (या आकड्यांवरून लिहिलेला) | (check) |
| Ask | विचारा | |
| Re-opened in 30 days | ३० दिवसांत पुन्हा उघडले | Use Western digits: 30 दिवसांत पुन्हा उघडले |
| Billed under DLP | DLP अंतर्गत बिल | |
| In open flags | उघड्या तपासण्यांमध्ये | (check) |
| Similar jobs | तत्सम कामे | |
| Budget runs out here | येथे अंदाजपत्रक संपते | |
| Needs additional budget | अतिरिक्त निधीची गरज | |
| Never fixed | कधीच दुरुस्त झाले नाही | |
| No complaint linked | कोणतीही तक्रार जोडलेली नाही | |

### 7.4 Band labels

| English | Marathi | Notes |
|---|---|---|
| Well above | खूप वर | (check) |
| Above | वर | |
| Similar | सारखेच | |
| Below | खाली | |
| Well below | खूप खाली | |
| Too few jobs to say | पुरेशी कामे नाहीत | (check) |
| Review (cost) | तपासा | |
| Typical (cost) | नेहमीसारखे | (check) |

Measure names: Speed → वेळेत पूर्ण; Durability → टिकाऊपणा; Cost → दर-पत्रकाशी तुलना (check all three).

### 7.5 Decision labels

| English | Marathi | Notes |
|---|---|---|
| Open | निर्णय बाकी | |
| Confirmed | पुष्टी झाली | |
| Needs explanation | स्पष्टीकरण हवे | |
| Not an issue | समस्या नाही | |
| Watch (no decision) | लक्ष ठेवा (निर्णय नाही) | (check) |

### 7.6 Flag type names

| English | Marathi | Notes |
|---|---|---|
| Over-billed | जास्त बिल | (check) |
| Possible double billing | संभाव्य दुहेरी बिल | (check) |
| Recover under DLP | DLP मधील रक्कम परत मिळवा | (check; keep the English tab name if the owner prefers) |
| Watch | लक्ष ठेवा | |

Flag reason template (English): "Billed {ratio} times the rate card for {method}."
Marathi: "{method} साठी दर-पत्रकाच्या {ratio} पट बिल." (check)

### 7.7 Plan reason chips

| English | Marathi | Notes |
|---|---|---|
| Ambulance route to a hospital | रुग्णालयाकडे जाणारा रुग्णवाहिका मार्ग | (check) |
| Bus route | बस मार्ग | |
| Flood hotspot nearby | जवळ पूर प्रवण भाग | (check) |
| Tide-sensitive | भरती-ओहोटीस संवेदनशील | (check) |
| Pothole accidents | खड्ड्यांमुळे अपघात | (check) |
| Complaints | तक्रारी | |
| Heavy traffic | जास्त वाहतूक | |
| School on road | रस्त्यावर शाळा | (check) |

### 7.8 Sample rendered text

Money trail headline, Marathi (Ward E):

```
प्रभाग E · Byculla, Agripada, Mumbai Central
अंदाजपत्रक ₹53.0 L     खर्च ₹63.2 L     जास्त खर्च ₹10.2 L (119%)
```

Plan header, Marathi (Ward E, overspent):

```
अतिरिक्त निधीची गरज
₹10.2 L जास्त खर्च: खालील सर्व कामांना अतिरिक्त निधी लागेल. (check)
```

Empty and error (Marathi):
- Empty: "या प्रभागात उघड्या तपासण्या नाहीत." (check)
- Error: "सहाय्यक उपलब्ध नाही. या पानावरील आकडे बदललेले नाहीत." (check)

Complaint in Marathi with translation (real complaint, BMC25-000022):
```
मूळ मजकूर:  Madanpura मध्ये पाणी साचले आहे, गाड्या अडकल्या आहेत. पंप पाठवा.
भाषांतर:    Water has collected in Madanpura and vehicles are stuck. Please send a pump.
```

### 7.9 Number and date conventions

- Rupee amounts: Western digits in both languages. Lakh and crore written as "L" and "cr" in both languages for layout consistency; Marathi long forms "लाख" and "कोटी" may appear in the summary text (check).
- Dates: "2 Aug 2025" in English. In Marathi, dates use the same format with the Marathi month name, for example "२ ऑग २०२५" (check).
- Percentages and ratios: Western digits, for example "119%" and "1.26x".

---

## 8. Accessibility

- **Colour is never the only carrier of meaning.** Every band, flag, decision and map step has a text label plus an icon or pattern.
- **Keyboard.** Every action is reachable by keyboard, in visual order. Focus ring is 2 px `focusRing` with a 2 px offset. Escape closes the DetailPanel and returns focus to the trigger.
- **Tables.** Real header and cell semantics, with `aria-sort` on sortable headers. The map has an equivalent table beside it.
- **Map.** Each ward has a text label. Selecting a ward in the table highlights it on the map and the reverse.
- **Touch targets.** 44 × 44 px minimum on narrow layouts.
- **Contrast.** Body text 4.5:1; large text and graphics 3:1; chip and input borders 3:1. Verified in both themes by the unit test (section 3.5).
- **Motion.** Panel slide and bar growth under 200 ms; both disabled under reduced motion.
- **Language.** Marathi labels wrap before they truncate. Check every screen in Marathi at wide and narrow widths.
- **Text sizes.** Nothing below 12 px. Figures are 28 px where they carry the headline.
- **Screen reader text.** Icons have labels. Band chips read the full label ("Below, speed"). Decision chips read the full state.
- **Projector.** Wide screen is used from the back of a room: contrast and sizes in section 3 are the minimum, not the target.

---

## 9. Deliverables to produce

Produce these outputs, in this order. Each item is a separate artboard or page.

### 9.1 Token sheet
- Light and dark side by side.
- All colour tokens from section 3.1 with hex values, role names and contrast ratio for each text-on-background pair.
- Map scale: five steps, light and dark, with labels and patterns.
- Typography: the five sizes, with a Latin sample and a Marathi sample for each size; tabular numerals shown.
- Spacing scale (4 px grid), corner radius (8 px), border (1 px), focus ring.
- Motion note (two motions, under 200 ms).

### 9.2 Component sheet
- Every component in section 5, as a grid of its variants and states: default, hover, focused, selected, loading, empty, error.
- Show BandChip, DecisionChip, MoneyText, StatTile, CompareBars, BarList, WorkOrderTable (wide and stacked), DetailPanel (wide, medium, narrow), EmptyState, ErrorState, LoadingSkeleton, SyntheticTag, navigation rail, bottom bar, header, toggles, ward selector, tabs, filter bar, ScoreParts, ReasonChip, TrailStage, EvidencePair, BudgetLine, map legend, form fields, ResultCard, Summary block, AskPanel, SettingRow.
- Light theme. Dark theme for BandChip, DecisionChip and map legend only.

### 9.3 Screens at wide width, light theme (1440 × 900)
One artboard per screen:
1. Sign-in (6.1)
2. City view (6.2)
3. Ward money trail, Ward E (6.3)
4. Flag queue (6.4)
5. Flag detail, over-billed (6.5.1)
6. Flag detail, possible double billing (6.5.2)
7. Flag detail, recover under DLP (6.5.3)
8. Flag detail, watch (6.5.4)
9. Contractor list (6.6)
10. Contractor scorecard, Mahalaxmi Civil Contractors (synthetic) (6.7)
11. Ward scorecard, Ward C, too few jobs (6.8)
12. Next-rupee plan, within budget, Ward B (6.9.1)
13. Next-rupee plan, overspent, Ward E (6.9.2)
14. Trail search (6.10)
15. Trail view, fixed (6.11.1)
16. Trail view, re-opened (6.11.2)
17. Trail view, never fixed (6.11.3)
18. Trail view, no complaint linked (6.11.4)
19. Ask panel open on the ward page (6.12)
20. New record, work order tab, with result card (6.13.1)
21. New record, complaint tab, with result card (6.13.2)
22. Rule settings (6.14)

### 9.4 Key screens in dark theme and at phone width (390 × 844)
Key screens: City view (6.2), Ward money trail (6.3), Flag detail, possible double billing (6.5.2), Contractor scorecard (6.7), Next-rupee plan, within budget (6.9.1), Trail view, re-opened (6.11.2).

For each key screen, produce:
- Dark theme at wide width.
- Phone width, light theme.
- Phone width, dark theme.

### 9.5 Marathi checks
- Money trail (6.3) and Plan (6.9.2) in Marathi, wide and phone width. Confirm labels wrap, not truncate.

---

## 10. Ready-to-paste prompts

Paste the whole brief above first, then one of these prompts. Each prompt covers one batch. Run the batches in order if one pass is too large.

**Batch 1: tokens and components.**
> Using the design brief above, sections 1 to 5 and 9.1 to 9.2, produce a token sheet (light and dark) and a component sheet. Use only the tokens in section 3.1 and the type sizes in 3.2. Show every variant and state listed in section 5. Include the map scale with labels and patterns. Follow the hard rules in section 2. Do not use any BMC crest or logo.

**Batch 2: city, ward and the money trail.**
> Using the design brief above, sections 2, 4, 6.2 and 6.3, produce these artboards at 1440 × 900, light theme: City view, and Ward money trail for Ward E. Use the sample rows and figures in those sections. Show the citizen variant of the ward page as a second artboard without the Flags link. Then produce phone-width (390 × 844) and dark-theme versions of both City view and Ward money trail.

**Batch 3: flags.**
> Using the design brief above, sections 2, 5.4 and 5.5, and 6.4 to 6.5.4, produce the Flag queue and four Flag detail artboards (over-billed, possible double billing, recover under DLP, watch) at 1440 × 900, light theme. The double-billing detail uses the real work orders WO25-01323 and WO25-02461. Then produce the possible double billing flag detail at phone width and in dark theme.

**Batch 4: scorecards and plan.**
> Using the design brief above, sections 5.3, 5.5, 5.20, 6.6 to 6.9.2, produce these artboards at 1440 × 900, light theme: Contractor list, Contractor scorecard for Mahalaxmi Civil Contractors (synthetic), Ward scorecard for Ward C (too few jobs), Next-rupee plan within budget (Ward B), and Next-rupee plan overspent (Ward E). Then produce the contractor scorecard and the within-budget plan at phone width and in dark theme.

**Batch 5: trail and Ask.**
> Using the design brief above, sections 5.22, 5.23, 6.10, 6.11.1 to 6.11.4 and 6.12, produce at 1440 × 900, light theme: Trail search, four Trail view artboards (fixed, re-opened, never fixed, no complaint linked), and the Ask panel open on the Ward E page. Then produce the re-opened trail view at phone width and in dark theme.

**Batch 6: intake, settings, sign-in.**
> Using the design brief above, sections 5.26, 5.27, 6.1, 6.13 and 6.14, produce at 1440 × 900, light theme: Sign-in, New record (work order tab with result card), New record (complaint tab with result card), and Rule settings. Include the phone-width version of the sign-in screen.

**Batch 7: Marathi check.**
> Using the design brief above, sections 7 and 9.5, produce Ward money trail (Ward E) and the overspent Next-rupee plan (Ward E) with all labels in Marathi, at 1440 × 900 and at 390 × 844. Labels must wrap to two lines before they truncate. Mark any text that is still a Marathi "check" in the artboard.

---

## 11. Assumptions and spec conflicts

### 11.1 Assumptions made for this brief

1. **Font.** Mukta is proposed as the one family. The source allows Mukta or Noto Sans with Noto Sans Devanagari. The frontend spec says one family, so Mukta is preferred. Fallback noted in 3.2.
2. **Colour values.** Every colour not given in the source is proposed and must pass the contrast test. Values for error, success and info in dark theme, and all tints, borders, `surfaceAlt`, `onPrimary`, `primaryContainer`, `focusRing`, and the map scale, are proposed.
3. **Map steps.** The source gives "under 80%" to "over 110%" and five steps. The breakpoints 80, 90, 100 and 110 are proposed.
4. **Band colours.** No band uses red. Below and well below use neutral fills with stronger borders and icons. This keeps red for confirmed problems and overspend.
5. **Decision colours.** Open and Needs explanation use amber. Confirmed uses red. Not an issue is neutral. The source says amber is for unreviewed flags, so Needs explanation (already reviewed once) uses amber with a solid border to differ from Open.
6. **Durability wording.** A "well below" band on re-opens means more re-opens than similar jobs. A plain sub-line is added to explain it.
7. **Cost measure bar.** The cost card compares the median ratio against the rate card at 1.00x. The source does not specify the second bar.
8. **Overspent plan.** The budget line sits at the top ("Budget already used up"), because every item is below it. The source says within_budget is false for every row.
9. **Ward E name.** The data says "Byculla, Agripada, Mumbai Central". The frontend spec's example says "Byculla, Mazgaon". This brief uses the data.
10. **Ward L example.** The PRD example "₹4.2 L left of ₹61 L" conflicts with the data. In the data, Ward L's budget is ₹1.19 cr and it is 110% spent. This brief uses Ward E for the overspent plan and Ward B for the within-budget plan, with real budget figures.
11. **Double-billing pair.** The PRD demo script says "2 days apart". The real pair in the data (WO25-01323 and WO25-02461) is 4 days apart. This brief uses the real pair and shows 4 days.
12. **Citizen landing.** The spec does not say how a citizen chooses a ward. This brief assumes a ward chooser (24 wards, by code and name) as the first screen, then the ward page.
13. **Officer and ward selector.** Officers can read any ward, but Flags and New record are limited to their own ward. The selector lists all wards, marking their own.
14. **Plan nav target.** The Plan navigation item needs a ward. This brief uses the selected ward, falling back to the officer's own ward, or the first ward in the list for auditor and citizen.
15. **Narrow navigation.** The bottom bar holds five items. New record and Settings go into the account menu at narrow widths. The spec does not say where they go.
16. **Narrow header.** Two rows (name and toggles; ward selector and synthetic tag). Not specified in the source.
17. **Phone width.** 390 × 844 used as the reference phone.
18. **Digits in Marathi.** Western digits for amounts (spec). Other numbers also use Western digits, for consistency. The spec says "numbers follow the language's conventions", so this is a choice.
19. **Illustrative figures.** Any amount, percentage, risk score or count not computed from the supplied data is marked (illustrative). Real figures used: city totals, ward budgets and spend, contractor job counts and spend, work orders and complaints quoted in sections 6.5 to 6.11, and the Ward E and Ward B road counts.
20. **Skeletons.** Static, no shimmer, to support reduced motion.
21. **Rate limit message.** "Too many questions. Try again in a minute." is proposed; the spec gives only the 429 code.
22. **Summary sample text.** The Ward E summary in 6.3 is a shape guide only. The stored summary text is written by the pipeline.
23. **Two-decimal rounding.** Crore to two decimals, lakh to one decimal (for example ₹1.30 cr, ₹63.2 L). Proposed; PRD examples are consistent with this.

### 11.2 Conflicts and gaps in the source specs

1. **Contractor "wards worked".** The contractor file lists 5 to 7 active wards per contractor. The work-order data shows every contractor working in all 24 wards. This brief shows "24" as the data shows. Confirm which is intended.
2. **Ward E name** (see 11.1 item 9).
3. **Ward L plan example** (see 11.1 item 10).
4. **Double-billing demo timing** (see 11.1 item 11).
5. **Scorecard figures.** The PRD scorecard example (Mahalaxmi: 39% on time, 38% re-opened, 1.08x) is not labelled illustrative. This brief uses it as a placeholder, because the computed values are not in the source files.
6. **Flag tab names.** The PRD has three flag tabs, and the frontend spec adds Watch. Watch is a tier, not a type, in the database. This brief uses four tabs as the frontend spec says.
7. **"Recover under DLP" wording.** The spec mandates this tab name and the liable-party line. The word "recover" may read as an accusation in some contexts; the brief keeps it, as the spec requires, and flags it for review.
8. **Ask panel form.** The spec says "a panel" but does not say whether it is the DetailPanel or a separate surface. This brief uses the DetailPanel.
9. **Citizen and complaint ids.** The backend says citizens never receive `complainant_id`. The frontend trail view shows complaint details. This brief hides complainant ids for citizens.
10. **SLA null.** Intake work orders have no SLA or re-open value. The spec excludes them from rates but does not say how to show them. This brief shows "SLA not yet recorded" (proposed) on those cards.
11. **Shading breakpoints.** Step boundaries between 80% and 110% are not given (see 11.1 item 3).
12. **Marathi translations.** All Marathi in this brief is a best rendering. Items marked "check" need a native reader before the demo.
13. **Trail route.** The backend lists `/trail/complaint/:id`, which redirects to the issue trail. The frontend route list does not include it. This brief treats it as a redirect with no screen of its own.
