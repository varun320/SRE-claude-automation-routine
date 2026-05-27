---
name: sre-email-drafter
description: Draft emails in Maaz's voice for Sulfur Recovery Engineering's common scenarios — proposal cover letters, AR follow-ups, year-end audit confirmations, AIMS bridge correspondence, customer health-check pings, RFQ acknowledgements, post-meeting recaps, NDA chasers, and operator-internal coordination notes. Subject-line conventions match observed sent-item patterns (e.g., "DRAFT for your approval - <customer> - <topic>"). Output is always a DRAFT in Outlook — never sends, never auto-archives, never forwards. Use when an operator says "draft an email to <customer>", when a proposal is ready and needs a cover, when an AR thread needs a follow-up, or when post-meeting notes need to go out to attendees.
---

# SRE Email Drafter

> **⚠️ DECISION OVERRIDE 2026-05-26:** Templates, examples, or guidance below that mention an "active sale process", "sale-process buyer", "DD buyer correspondence", or related framing are **superseded**. The SRE sale process ended 2026-05-26. Generic confidentiality framing — *"Sensitive corporate / financial / HR / board material — never surface in any output"* — applies. See [`docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10`](../../../docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10).

Maaz writes a particular kind of email — short, technically precise, signed `Maaz Ahmed Shareef · Sulfur Recovery Engineering Inc.`, often routed via AIMS contacts for ME customers, frequently following the pattern *"DRAFT for your approval - <customer> - <topic>"* when the email is itself a draft sent to AIMS for review before it goes to end-customer. This skill codifies that voice and the common scenarios into reusable templates.

This skill is **draft-only**. It produces email content in Outlook-draft format. Sending happens only after operator review.

---

## When to use

- Operator says *"draft a cover email for the Q-Chem proposal"* (pair with `sre-proposal-builder` output)
- Operator says *"follow up on the Tüpraş AR thread"* (AR escalation cadence)
- Year-end audit confirmation requests come in (Fazal/Junaid @ AIMS finance pattern)
- Customer hasn't been touched in N+ days (paired with R5 / R22 silence-monitor output)
- A meeting just ended and notes need to go to attendees within 24h
- RFQ landed and an acknowledgement-of-receipt email is needed before the full proposal
- An NDA has been in legal review > 2 weeks and needs a status-check email
- Internal coordination — SRE team members need updates on customer status / next steps

## When NOT to use

- The email is to the press, investors, or sale-process buyer/advisor — those need a separate (manual) review path, not this skill
- The email touches confidential / DD / board content — escalate to operator-only review
- The user wants to send directly — this skill is draft-only; send happens after operator approval
- A fully novel scenario not in the template library — start from `templates/blank-draft.md.template` and document the new pattern for future use

---

## Skill contents

```
~/.claude/skills/sre-email-drafter/
├── SKILL.md                                ← this file
├── references/
│   ├── maaz-voice-profile.md               ← signature, salutation, sign-off, length norms
│   ├── subject-line-conventions.md         ← observed patterns from sent-items audit
│   └── aims-routing-map.md                 ← which AIMS contact bridges which customer
└── templates/
    ├── blank-draft.md.template             ← when no pre-built scenario matches
    ├── proposal-cover.md.template          ← cover email for a freshly-drafted proposal
    ├── ar-followup.md.template             ← AR reminder, escalation #N pattern
    ├── year-end-audit-confirmation.md.template
    ├── rfq-acknowledgement.md.template     ← "received your RFQ, full proposal in N days"
    ├── post-meeting-recap.md.template      ← "as discussed, here are the action items"
    ├── customer-health-check.md.template   ← silence-breaker, paired with R5/R22
    ├── nda-status-chaser.md.template       ← legal/contract follow-up
    └── internal-coordination.md.template   ← SRE team-internal update
```

---

## Pre-flight

Before drafting any email, confirm:

1. **Recipient resolution** — exact email address(es). For AIMS-bridged customers, route via AIMS contact, not direct (see `references/aims-routing-map.md`).
2. **Subject-line convention** — pick the right pattern from `references/subject-line-conventions.md`. Most are templated; do not invent.
3. **Source context** — what triggered the email? (RFQ thread, AR reminder count, meeting just ended, proposal just drafted). Without source context, the draft will be generic.
4. **Maaz's voice baseline** — read `references/maaz-voice-profile.md` once before first draft of a session. Subsequent drafts inherit the voice.
5. **Confidentiality flag** — if the customer or topic is on `client-config.confidentiality.*` lists, halt. Don't draft confidential emails through this skill.

---

## Workflow

### Step 1 — Identify the scenario

The operator's request → one of the template families:

| Request keyword | Template |
|---|---|
| "cover email" / "proposal cover" | `proposal-cover.md.template` |
| "follow up on AR" / "invoice reminder" / "balance overdue" | `ar-followup.md.template` |
| "year-end audit" / "balance confirmation" / "31.12 confirmation" | `year-end-audit-confirmation.md.template` |
| "acknowledge RFQ" / "received RFQ" / "RFQ receipt" | `rfq-acknowledgement.md.template` |
| "meeting recap" / "post-meeting" / "as discussed" | `post-meeting-recap.md.template` |
| "haven't heard from" / "checking in" / "any updates" | `customer-health-check.md.template` |
| "NDA status" / "legal review" / "contract follow-up" | `nda-status-chaser.md.template` |
| "internal" / "Ashley" / "Dharmesh" / "Ron" / "Talha" / "team update" | `internal-coordination.md.template` |
| Other / novel | `blank-draft.md.template` |

### Step 2 — Pull source context

For each scenario type, the draft needs specific context:

| Scenario | Context needed |
|---|---|
| Proposal cover | Path to the proposal draft, customer's contact, AIMS routing flag |
| AR follow-up | Invoice number, amount, days overdue, reminder count (look in Sent items for prior reminders), customer's local payment-team contact |
| Year-end audit | Balance as of date (typically 31.12 prior year), AIMS auditor name (usually Fazal or Junaid), confirmation request format (often comes from AIMS finance) |
| RFQ ack | RFQ number, RFQ subject, expected proposal turnaround, who's drafting |
| Meeting recap | Date + attendees + 3-5 action items + owners + due dates |
| Health check | Last interaction date, last topic, soft excuse to re-engage (industry news, conference, etc.) |
| NDA chaser | Counterparty legal contact, NDA version number, weeks-in-review count, internal SRE owner |
| Internal coord | Recipient role (Ashley = admin/HR, Dharmesh = engineering, Ron = BD/NA, Talha = ME technical) |

### Step 3 — Generate draft in Maaz's voice

Read `references/maaz-voice-profile.md`. Apply the voice to the chosen template. Replace all `{{PLACEHOLDER}}` tokens with real values.

### Step 4 — Format as Outlook draft

Output to `<project>/email-drafts/<date>-<scenario>-<customer-slug>.md` with frontmatter:

```yaml
---
status: draft
scenario: proposal_cover | ar_followup | year_end_audit | ...
to: ["bader@aimsgt.com"]
cc: ["shameem@aimsgt.com"]
bcc: []
subject: "DRAFT for your approval - Q-Chem (Sanjay Bhatt) - SGRU/SRU 2028 Feed Study and SRU/AGRU Training"
attachments: ["proposals/2026-05-22-qchem-sgru-2028-feed-study.pdf"]
drafted_by: "Claude · sre-email-drafter"
drafted_on: 2026-05-22
aims_routed: true
aims_contact: "bader@aimsgt.com"
end_customer: "Q-Chem · Sanjay Bhatt"
review_status: pending_operator_review
---
```

Body follows below the frontmatter, as plain text (no markdown rendering inside Outlook).

### Step 5 — Surface for review

Tell the operator:
- Draft file path
- Recipient list (so they can confirm AIMS routing is right)
- Subject line (so they can confirm convention)
- Attachment list
- 1-line summary of what the email says

Operator either marks `review_status: approved_for_send` (and sends manually from Outlook drafts folder), or edits and re-reviews.

---

## Safety rules

1. **Draft-only.** This skill writes files; it does not send, save-to-Outlook-drafts-folder, or call any `mcp__ms365__send-*` / `mcp__ms365__create-draft-email` tool. Sending requires manual operator action from Outlook itself.
2. **No invented facts.** Invoice numbers, amounts, dates, contact names, deliverable counts — all must come from operator input or source-thread evidence. Never fabricate.
3. **No invented citations.** If the draft references a prior thread or document, the reference must exist in the operator's actual mail/file history.
4. **AIMS routing is mandatory for ME-bridged customers.** See `references/aims-routing-map.md`. Direct emails to ME end-customer when an AIMS bridge exists is a relationship error.
5. **Confidential customers** — halt. Do not draft for confidential_customers entries via this skill.
6. **Bcc usage** — Maaz rarely uses bcc except for internal-record copying. Don't add bcc unless operator explicitly requests.
7. **Reply-all default** — for thread-replies, default to reply (not reply-all) unless the thread context shows reply-all is expected (e.g., AIMS multi-party thread).
8. **Attachment caps** — don't reference attachments larger than 25 MB without explicit operator approval (Outlook attachment limits + AIMS pass-through limits).

---

## Voice constraints

Every draft must satisfy these checks (from `references/maaz-voice-profile.md`):

- **Length**: typical 80–150 words. Exceeds 250 words → operator review red flag.
- **Sentences**: short to medium. No multi-clause sentences > 30 words.
- **Opening**: never "I hope this email finds you well" or similar generic warmth. Maaz opens with reference to a prior interaction or direct context.
- **Sign-off**: `Best regards, / Maaz` for direct customer. `Thanks, / Maaz` for AIMS-bridged or internal. Never "Sincerely" or "Yours faithfully" (formal British) unless tender context.
- **Signature block**: `Maaz Ahmed Shareef · Sulfur Recovery Engineering Inc. · maaz@sulfurrecovery.com · +1 (XXX) XXX-XXXX`
- **No emoji** except in extremely informal internal Teams DMs (out of scope for this skill).
- **No "Please find attached"** — Maaz writes "Attached is..." or "The proposal is attached for your review."

---

## Quick-start invocation

When invoked, ask the operator:

1. **What's the scenario?** (proposal cover · AR follow-up · audit confirmation · etc.)
2. **Who's the recipient?** (or "the AIMS contact who routes to <customer>")
3. **What's the trigger context?** (proposal-just-drafted · invoice-N-days-overdue · meeting-just-ended · etc.)

Then pick the matching template, fill in placeholders from operator input, output to `<project>/email-drafts/`, and surface the 5-point review summary.

End with one line: scenario, recipient, draft file path, what operator should verify first.
