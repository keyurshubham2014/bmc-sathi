# Action pack: design

**Date:** 2026-11-21 · **Size:** small change, backend only · **Brief:** `docs/ideas/2026-11-21-sathi-next-features.md` (feature E)

## Intent

A decided flag should end in something an officer can send. Today a decision is recorded and nothing follows. The action pack turns a group of decided flags into one draft document that lists every job behind it.

## Goals

- One draft per group: one road for DLP flags; one contractor in one ward for billing flags (over-billing and double billing together).
- Written by Claude in English or Marathi from the flag evidence, with a fixed template when Claude is unavailable, so the request always returns a draft.
- Every job in the group is named in the draft with its work order id and amount.

## Non-goals

- No sending, no PDF, no storage of drafts. The response is text to copy.
- No screen. The design-overhaul screens add the button later.
- No drafts for watch items or for flags that are open or dismissed.

## Anti-goals

- Nothing that reads as an official BMC document: every draft starts with "DRAFT FOR REVIEW. Independent prototype, synthetic data." and ends with a blank signature line.
- No accusation. A billing draft asks for an explanation; a DLP draft asks the roads department to identify the contractor liable under the defect liability period and recover the amounts, because the data does not name that contractor.
- Claude never decides what is in the group. The rules and the recorded decisions do.

## Constraints

- Same worktree, branch and database copy as the other four features. Nothing merged; the live `sathi` database untouched.
- Officers and auditors only, with the existing ward scoping. Citizens get 403.
- Tests make no Claude calls.

## Approaches

| Approach | Trade-off | Outcome |
|---|---|---|
| Claude writes, fixed template as fallback | Plain wording in two languages; always returns something | **Chosen by Keyur** |
| Template only | Always works, no cost; English only | Rejected |
| Claude only | Least code; fails with the network | Rejected |

## Design

**Route:** `POST /api/v1/flags/draft`, body one of:

```json
{ "kind": "dlp", "road_id": "RD0220", "lang": "en" }
{ "kind": "billing", "contractor_id": "CT03", "ward_code": "K/W", "lang": "mr" }
```

Optional `"plain": true` skips Claude and returns the template. *My call: it gives the tests and the officer a version that never depends on the network.*

**Group.** Flags with `tier = 'flag'` and decision `confirmed` or `needs_explanation`, matching the road (DLP) or the contractor and ward (billing). No such flags: 409 `conflict`, "No decided flags in this group yet."

**Facts given to the writer:** for each job its work order id, date, road, work type, method, amount billed, amount at stake, flag type, decision, the officer's note, and the evidence fields the flag already carries (rate, expected cost and ratio; or the earlier job's id, date and days apart; or the road's last resurfacing date). Plus the group total, counting each job once.

**Response:** `{ draft: { title, body }, source: "claude" | "template", lang, work_order_ids, total_amount }`.

**Fallback.** The template is used when there is no API key, the call fails, it takes longer than 20 seconds, or the answer fails the check below. The template is English only; the response's `lang` then says `en` even if Marathi was asked for. *My call: a hand-written Marathi legal template is a translation risk I should not take without a reader.*

**Check on Claude's answer.** Accepted only if the body contains every work order id in the group and none of these words appear: fraud, scam, corrupt, theft, criminal. Otherwise the template is returned. The fixed first line, the total line and the signature line are added by the API, not by Claude, so a written draft cannot state a different total. *As built: this replaced checking Claude's own total.* The rate limit applies only when Claude is called.

**Limits.** The existing Ask rate limit (10 a minute per user) is shared. A group is capped at 60 jobs in one draft; a larger group returns the 60 largest and says how many were left out. *My call: Kurla Andheri Road has 35 DLP jobs, so 60 covers every group in the data.*

**Tests:** citizen gets 403; an officer cannot draft for another ward; a group with no decided flags gets 409; with one flag confirmed (then undone), `plain: true` returns a template naming that work order, its amount and the first line; the answer check rejects a body missing an id or containing a banned word.

## Left to the builder

- Exact template wording, within the anti-goals.
- Whether the writer is `askJson` wrapped in a 20-second race or a client with its own timeout.
