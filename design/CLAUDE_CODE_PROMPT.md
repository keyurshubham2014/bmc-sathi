# Prompt for Claude Code

Paste the block below into Claude Code from the root of the BMC Sathi frontend repo, after copying this folder into the repo as `design/`.

---

You are implementing the approved visual design for BMC Sathi · Roads. The design lives in `design/`:
- `design/DESIGN.md` — read this first: screen map with routes, shell, components and the rules that must hold.
- `design/tokens.css` — design tokens as CSS variables.
- `design/screens/*.html` — one static HTML file per screen, inline styles and inline SVG. These are the source of truth.
- `design/screens/png/*.png` — renders of the same screens at 1440 wide.

Goal: make the running app match these screens at desktop width in the light theme. We demo in under an hour, so work in this order and keep each step shippable:

1. Read `design/DESIGN.md`, `design/tokens.css` and `design/screens/03-ward-money-trail.html`. Load `tokens.css` globally and the Geist + Noto Sans Devanagari fonts.
2. Build the app shell once (sidebar, top bar, content column, optional 440 px detail panel) by lifting the markup from `03-ward-money-trail.html`. Drive the selected nav item, page title, role-specific items and the Flags badge from props or route state.
3. Implement the screens in demo order, lifting markup and inline SVG straight from the matching HTML file and replacing the hard-coded values with our data:
   1. `01-sign-in.html` (three demo account cards)
   2. `03-ward-money-trail.html`
   3. `06-flag-detail-double-billing.html` (queue + detail panel, decision form)
   4. `19-trail-no-complaint.html` and `16-trail-fixed.html` (one Trail component with five stages; empty stages use the dashed hollow node)
   5. `11-contractor-scorecard.html` and `10-contractors.html`
   6. `13-plan-within-budget.html` and `14-plan-overspent.html` (one Plan component; the budget line moves to the top when the ward is overspent)
   7. `02-city-view.html`
   8. then the rest: other flag details (07 to 09), trail search (15), other trails (17, 18), Ask panel (20), New record (21, 22), Rule settings (23), ward scorecard (12), ward roads overview (04).
4. Extract shared pieces into components as you go, using the names in `DESIGN.md` ("Components to build once and reuse"): Panel, Card, StatBlock, Button, StatusPill, DecisionChip, BandChip, ProgressBar, BudgetBar, CompareBars, RangeStrip, TrailStepper, EvidencePair, BudgetLine, DataTable, form fields. Keep the illustrations (road slabs, ward map) as inline SVG components copied from the HTML; do not redraw them.

Rules:
- Do not restyle or "improve" the design. Match spacing, sizes, radii, colours and copy from the HTML. Where our data has a state the mockup does not show, follow the nearest pattern in `00-foundations-and-components.html` (empty, error with Retry and request id, loading skeleton).
- Follow every rule in `DESIGN.md` → "Rules that must hold". In particular: no contractor ranking or grades, no accusatory words, amber = unreviewed, red = overspend or confirmed only, "Synthetic data" tag always visible, no BMC crest.
- Figures marked illustrative in `DESIGN.md` come from our API, not from the mockup. Format money with the lakh/crore rules in `DESIGN.md`.
- Dark theme, phone layout and Marathi are out of scope for this pass. Leave the toggles in place.
- After each screen, open it next to its PNG in `design/screens/png/` and fix visible differences before moving on. Tell me which screens are done and which are not when you stop.
