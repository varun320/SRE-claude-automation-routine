---
# ============================================================
# COMMON ROUTINE TEMPLATE — Weekly Memo
# Pattern: weekly written summary to a specific audience —
# usually a board member, shareholder, advisor, or operator's own log.
# Optionally CONFIDENTIAL with redaction.
#
# When to use this template:
#   - Operator says "I need to send a weekly update to <audience>"
#   - Sale-process work needs a weekly written memo (audit-flagged confidentiality)
#   - Operator writes the same kind of recap manually every week and wants pre-stage
# ============================================================

id: R9                                  # NEEDS_INPUT
slug: weekly-memo-{audience}            # e.g. weekly-memo-zaheer, weekly-memo-board, weekly-memo-operator-log
client_slug: NEEDS_INPUT
status: draft
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
pilot_revision: 0

schedule:
  # Friday afternoon — operator reviews + sends, OR operator drafts on Sunday for Monday send
  cron: "0 14 * * 5"
  timezone: NEEDS_INPUT
  hard_anchors_respected: true

scope:
  mailboxes: ["operator@client.com"]
  toRecipients_filter: false
  window_hours_back: 168                # 7 days
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders:
    - "linkedin.com"
    - "alarm.com"
    - "*-noreply@*"
  memo_audience: "NEEDS_INPUT"          # board | shareholder | advisor | operator-self | external-CFO
  include_sections:                     # what the memo body covers
    - sales_movements
    - ar_status
    - customer_health
    - operator_priorities_next_week
    - blockers_and_decisions_needed
  exclude_sections: []

trigger_event_hints:
  - regex: '(?i)\b(po\s*signing|po\s*approved)\b'
    severity: closing_event
  - regex: '(?i)\b(proposal\s+sent|draft\s+for\s+approval)\b'
    severity: proposal_in_flight
  - regex: '(?i)\b(blocked|blocker|need\s+approval|escalation)\b'
    severity: blocker

output:
  channel: note_file_in_onedrive        # confidential memos must stay private; this is the right channel
  channel_target: "/Operator Memos/Weekly/{date}-weekly-memo-{audience}.docx"
  format: note-file
  recipients: ["operator@client.com"]   # routine produces DRAFT — operator reviews + sends manually

safety:
  read_only: true                       # NEVER send the memo from the routine. Operator review + send is non-negotiable.
  write_actions: []                     # create_draft_reply is acceptable here if operator wants the memo prepared as a draft email; but body confidentiality means file-on-disk is usually safer
  confidential_topics_redacted:
    - sale_process_buyer
    - sale_process_advisor
    # add per client-config.confidentiality

budget:
  max_graph_calls: 80                   # 7 days × multiple surfaces (calendar + mail + customers)
  max_runtime_seconds: 240
  max_output_chars: 10000               # memos are long-form

observability:
  log_file: "routines/logs/R9-{date}.json"
  log_keep_days: 365                    # memo history is operationally valuable
  metric_signal: "Operator edits per memo < 30% of total content · means the draft is genuinely useful"

acceptance:
  - "First 3 weekly memos used as the basis for the actual sent message (>70% of draft retained)"
  - "Operator confirms ≥1 hour saved per memo vs writing from scratch"
  - "Confidential customers correctly redacted in all 3 first drafts"
  - "All required sections present + populated"

graduates_to_active_when:
  - "4 consecutive weekly memos where operator retained ≥70% of draft"
  - "Acceptance criteria met"
  - "Redaction verified by operator on confidential content"

retires_when:
  - "Operator no longer needs the weekly cadence"
  - "Audience changes (e.g., sale-process closes) — retire + start a new variant"
  - "Operator prefers to write from scratch — pivot to a different memo shape or retire"

linked_audit_findings:
  - "audits/<client>-<date>/data/tenant-summary.json#openQuestions.OQ-14"   # where do sale-process artifacts live
  - "audits/<client>-<date>/data/tenant-summary.json#openQuestions.OQ-19"   # sale-process redaction

owner: "NEEDS_INPUT"
co_owner: "NEEDS_INPUT"
---

# R9 · Weekly Memo ({audience})

## Why this exists

The operator writes a weekly written update to {audience} (e.g., Zaheer Juddy as shareholder + sale-process context). Without pre-stage, the operator spends 1-2 hours on a Friday gathering inputs across mail, calendar, AR status, sale-process tracker. This routine produces a structured first draft in the operator's own voice template — the operator reviews, edits, and sends.

Quote from audit: > "Sale-process is highest-stakes file — needs weekly written memo."

Audit reference: OneDrive SRE DD folder (sale-process material), 16+ Torstein × Maaz 1:1s on financials / DD / forecast.

## What it does

```
1. Hard-anchor check → exit if within prayer/family/sleep window
2. Apply confidential_topics_redacted from client-config.confidentiality
3. For each section in scope.include_sections:
   a. sales_movements:
      - List po_signed / proposal_sent events in past 7 days (from R6 log if available, else infer)
      - For each, summarize: customer, stage transition, key contact, next step
   b. ar_status:
      - Read R12's most recent output if available
      - Else compute aging buckets fresh
      - Summarize: total outstanding, escalations, customers at 60+/90+/120+ days
   c. customer_health:
      - Use R5 output: customers silent > threshold
      - Top 5 active customers + their current stage
   d. operator_priorities_next_week:
      - Read calendar week-ahead
      - Extract titled-meetings (skip recurring noise)
      - Identify top 3 by stake (customer-named > internal)
   e. blockers_and_decisions_needed:
      - Scan inbox + sent for `blocker` severity matches
      - Summarize each: blocker description, what's needed to unblock, urgency
4. Apply redaction:
   - For each confidential_customers entry, replace name with "[REDACTED — sale-process customer]"
   - For SRE DD / Board / M&A folder references, replace with "[CONFIDENTIAL]"
5. Format as markdown memo (template-styled):
   - Header with date, audience, audit period
   - Sections in specified order
   - Sign-off block (operator name + title from client-config)
6. Write to channel_target as .docx-compatible markdown
7. (Optional) Log links to source evidence in a separate appendix the operator can use during review
```

## Good output example

```markdown
# Weekly Memo · Operator Update to {Audience}
Period: 2026-05-15 → 2026-05-21

## Sales movements (3)

- **Saudi Aramco** — PO Signed on SRU-1 Onsite Testing (2026-05-19). Kickoff with
  Dharmesh next week. Next step: project plan + invoice schedule.

- **Q-Chem** — Proposal sent on 2025-05-13 for SGRU/SRU 2028 Feed Study + Training.
  Awaiting Sanjay Bhatt review. Next step: follow up Friday May 30.

- **Phillips 66 Rodeo** — RFQ received for GC Testing. Bid prep in progress with
  Ashley. Next step: deliver bid by 2026-05-28.

## AR status

- Total outstanding: $XXX,XXX across 12 customers
- 90+ days: 3 customers — Tüpraş (reminder #5 sent), Anwil (silent), and [REDACTED]
- Year-end audit confirmations: in-flight with Mohammed Fazal and Junaid (AIMS)

## Customer health · top 5 active

1. ADNOC — in_execution, weekly cadence steady
2. Aramco RTR — in_execution, May 17 review went well, next May 31
3. INERCO — relationship recovery in progress (account-plan call this week)
4. SATORP — proposal stage, awaiting clarifications
5. KNPC — proposal stage, follow-up needed

## Operator priorities · week of 2026-05-22

1. Q-Chem proposal follow-up (Sanjay Bhatt)
2. Aramco RTR May 31 review prep
3. KNPC budgetary proposal sign-off

## Blockers / decisions needed

- **Anwil NDA pending** — has been outstanding 6+ weeks. Legal review needed.
- **Decision: SATORP LTSA scope** — operator + Talha need to align on engineering scope before next call.

[Section: CONFIDENTIAL — sale-process update] [REDACTED — to discuss verbally]
```

## Bad output example

```markdown
# Weekly Memo · 2026-05-21

(scaffolded but empty — no signal data populated)

## Sales movements
(no movements detected — likely budget exceeded)

## AR status
(R12 log not found at expected path)
```

Triage:
- Routine ran but couldn't read upstream R6 / R12 logs → check `depends_on` is configured
- Or budget exceeded mid-run → check log for `budget_exceeded` exit
- Or scope window too narrow (memo expects 7 days; some sections need longer lookback)

## Edge cases

- **Confidential audience**: if audience is sale-process buyer, the memo MUST go to operator's private channel for review BEFORE any send. Never auto-send.
- **Redaction breadth**: redact not just customer name but also project codes, regions, and any thread that references the confidential transaction. If unsure → redact.
- **Memo style drift**: operator may have a specific written voice (e.g., "we" vs "I", formal vs casual). After 2-3 memos the routine should adopt that style. Initial drafts may be too generic.
- **External CRM inputs**: if Zoho/Salesforce data would make memo richer, but routine is M365-only, annotate which sections need manual augmentation
- **Holiday weeks**: low-signal weeks should produce a shorter memo, not a fake-full one — explicitly note "quiet week" if applicable
- **Multi-audience same week**: if operator sends to multiple audiences (e.g., shareholder + board + own log), each needs its own spec variant; don't try to multiplex

## Rollback

1. **Pause**: `status: paused`. Operator writes the memo by hand.
2. **Investigate**: is the draft accurate? Is it the right shape? Is it missing or fabricating signal?
3. **Common fixes**:
   - Tighten sources (only use R5/R6/R12 logs; don't re-infer from raw mail unless those routines aren't yet active)
   - Add audience-specific sections / style guidelines to spec body
   - Redaction false positive (too aggressive) → tighten match
   - Redaction false negative (missed) → add to confidential_topics_redacted

Surface that breaks if this routine stops: operator writes weekly memo from scratch (~1-2 hours).

## Pilot revision history

- **v0** (YYYY-MM-DD): Initial spec, status: draft.
