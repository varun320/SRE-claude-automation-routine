---
# ============================================================
# COMMON ROUTINE TEMPLATE — Inbox Scan
# Pattern: daily classification of inbound mail with regex-based
# escalation against the client's customer keyword set + stage signals.
#
# When to use this template:
#   - Operator says "inbox eats my deep work"
#   - Audit shows high unread % + zero/few inbox rules
#   - Operator needs same-day visibility on customer / RFQ / closing-event signals
# ============================================================

id: R1                                  # NEEDS_INPUT
slug: inbox-scan-{region}               # e.g. inbox-scan-na, inbox-scan-me
client_slug: NEEDS_INPUT
status: draft
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
pilot_revision: 0

schedule:
  # Daily weekday, late-morning operator local — after they've started but before lunch
  cron: "0 11 * * 1-5"
  timezone: NEEDS_INPUT                 # match operator mailbox tz
  hard_anchors_respected: true

scope:
  mailboxes: ["operator@client.com"]    # primary first; add shared mailboxes per region
  toRecipients_filter: true             # CRITICAL when operator has full-mailbox-access to others (audit OQ-16)
  window_hours_back: 24
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders:
    - "linkedin.com"
    - "alarm.com"
    - "*-noreply@*"
    - "newsletters-noreply@*"
    - "donotreply*@*"
    - "support@disa.com"                # vendor noise (compliance reports)
  include_keywords: []
  exclude_keywords: []

trigger_event_hints:
  - regex: '(?i)\b(po\s*signing|po\s*approved|order\s+placed|awarded|po\s*number|verbal\s+yes|we''d\s+like\s+to\s+proceed)\b'
    severity: closing_event
  - regex: '(?i)\b(rfq|rfp|tender|inquiry|bid|request\s+for\s+quote|request\s+for\s+proposal)\b'
    severity: rfq_received
  - regex: '(?i)\b(proposal|quote|offer)\b'
    severity: proposal_in_thread
  - regex: '(?i)\b(nda|msa|contract|agreement|po\b|purchase\s+order)\b'
    severity: contract_in_thread
  - regex: '(?i)\b(overdue|past\s+due|aging|payment|outstanding|reminder)\b'
    severity: ar_followup
  - regex: '(?i)\b(escalation|urgent|critical|asap)\b'
    severity: urgency_marker

output:
  channel: local_file                   # pilot default; promote to zoho_tasks or teams_pinned once accepted
  channel_target: "routines/output/R1-{date}.md"
  format: structured-summary
  recipients: ["operator@client.com"]

safety:
  read_only: true
  write_actions: []                     # phase 2 may add: ["categorize:<customer-name>", "flag_for_followup"]
  confidential_topics_redacted: []      # populate from client-config.confidentiality.redact_folders

budget:
  max_graph_calls: 30                   # one mailbox + ~20 message reads + overhead
  max_runtime_seconds: 90
  max_output_chars: 4000

observability:
  log_file: "routines/logs/R1-{date}.json"
  log_keep_days: 90
  metric_signal: "Escalation rate 5-30% · Action rate (operator acts on escalations) >50% after week 2"

acceptance:
  - "First 5 runs reviewed by operator within 24h"
  - "False positive rate < 20% across first 10 runs"
  - "Operator confirms ≥ 2 escalations 'would have been missed without routine' by week 2"
  - "No noise senders (LinkedIn, alarm.com) in escalations across 10 runs"

graduates_to_active_when:
  - "10 consecutive runs without operator pushback"
  - "All acceptance criteria met"
  - "Output channel migrated to zoho_tasks or teams_pinned (not stuck in local_file)"

retires_when:
  - "3 pilot revisions without meeting acceptance"
  - "Operator decides task-by-hand is faster"

linked_audit_findings:
  - "audits/<client>-<date>/data/tenant-summary.json#openQuestions.OQ-05"
  - "audits/<client>-<date>/data/stage-2-to-7-summary.json#stage_2A_mail_findings"

owner: "NEEDS_INPUT"
co_owner: "NEEDS_INPUT"
---

# R1 · Inbox Scan ({region})

## Why this exists

Operator's inbox has high unread volume + zero inbox rules (per audit). Real customer / RFQ / closing-event signals get buried under newsletter + vendor-marketing noise. This routine classifies inbound mail from the last 24 hours, filters noise, and surfaces ≤ 5 escalations per run — items the operator should look at today.

Quote from audit: > "Inbox eats deep-work time outside the four windows."

Audit reference: `audits/<client>-<date>/data/tenant-summary.json#mailbox_signals` (inbox unread% + 0 rules).

## What it does

```
1. Hard-anchor check → exit if within prayer/family/sleep window
2. For each mailbox in scope.mailboxes:
   a. mcp__ms365__list-mail-folders → find Inbox folder id
   b. mcp__ms365__list-mail-folder-messages
      - mailFolderId=<Inbox-id>
      - top=50
      - orderby="receivedDateTime desc"
      - select="id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,categories,conversationId,importance"
      - NO body / NO bodyPreview
3. Filter messages where receivedDateTime < now - scope.window_hours_back → drop
4. Filter messages where from.emailAddress.address matches any scope.exclude_senders pattern → drop (count as noise)
5. If scope.toRecipients_filter: drop messages whose toRecipients does NOT contain operator's UPN
6. For each remaining message:
   a. Match subject + from-domain against client-config.customer_keywords → tag with customer name(s)
   b. Match subject against each trigger_event_hints regex → tag with severity
   c. If any tag matches → add to escalations[]
7. Format escalations:
   - Group by customer (or "Internal" / "External-unknown")
   - Within group, sort by severity (closing_event > rfq_received > ...)
   - Render each as: "[severity] customer / subject (truncated 80c) — from email · receivedDateTime local"
8. Write to channel_target with header: "{date} {routine-name} · {time} {tz} · {n_processed} inbound · {n_escalated} escalations"
9. Append run log to observability.log_file with full structured data
```

## Good output example

```
2026-05-21 Inbox Scan NA · 11:00 MT · 47 inbound · 3 escalations · 31 noise filtered

ADNOC (1)
- [closing_event] ADNOC RSGP RSHT-2 · Technical Assistance Request – Jacketed Plunger Sampling System
  from yunus@aimsgt.com · 13:03 MT · hasAttachments

Phillips 66 (1)
- [rfq_received] Phillips 66 Rodeo Sulfur Plant · Request for Quote - GC Testing
  from drew@gp-solutions.ca · 6:30 MT (escalated from yesterday's late thread)

AR follow-up (1)
- [ar_followup] Tüpraş · Account Reconciliation 03/2026 (reminder #5)
  to ashleyh@acme.com · 5:30 MT

[noise filtered: 31 — 9 LinkedIn / 4 alarm.com / 4 vendor marketing / others]
```

## Bad output example

```
2026-05-21 Inbox Scan NA · 11:00 MT · 47 inbound · 18 escalations

Generic (18)
- [proposal_in_thread] Sungho Kim recently posted   ← false positive · LinkedIn
- [closing_event] DISA Global Solutions - The Clear Choice   ← false positive · vendor marketing
- [closing_event] Faire des affaires en Chine ...   ← false positive · LinkedIn newsletter (to dongreen@)
...
```

Triage:
- LinkedIn newsletter to a different mailbox surfaced → `toRecipients_filter` flipped to true (operator has full-mailbox-access to dongreen@ per audit OQ-16)
- "DISA" / "Engineering10" / "Equipment10" not in `exclude_senders` → add
- `closing_event` regex too loose ("approved" matching marketing copy) → tighten

## Edge cases

- **Cross-mailbox pollution**: operator has full-mailbox-access to other users → `toRecipients_filter: true` mandatory. Audit OQ-16.
- **Shared mailbox subset**: when running against a shared mailbox (e.g., `info-me@`), `toRecipients_filter` should match the shared mailbox UPN, not operator's.
- **Disabled-mailbox users**: operator may have access to a disabled colleague's mailbox (audit OQ-02). Decision: include or exclude. Default exclude — those mailboxes are paused.
- **AIMS-overlap meeting threads**: meetings auto-generate emails (Accepted / Tentative / Declined). These look like real customer mail but aren't actionable. Add `Tentative:|Accepted:|Declined:` to `exclude_keywords`.
- **Conversation-thread inflation**: same conversationId may produce multiple escalations across runs. Add deduplication: within last 7 days, don't escalate the same conversationId twice unless its severity has escalated.
- **Sale-process noise**: if `confidential_customers` includes a buyer/advisor, any thread matching their domain must be redacted in output (or sent only to operator-private channel).
- **Empty days**: low-volume days (holidays, vacations) → output should explicitly say "low-volume day" not produce a misleading "0 escalations" that looks like routine failure.

## Rollback

If escalations are wrong:

1. **Pause**: flip `status: paused` here, cron stops.
2. **Read latest log**: `routines/logs/R1-<date>.json` → check `items_escalated` vs `items_in_window`, check `errors[]`.
3. **Tighten or loosen** depending on FP vs FN — common fixes:
   - Add to `exclude_senders`
   - Tighten a trigger regex
   - Add `exclude_keywords` for known noise terms
4. Resume as pilot, bump `pilot_revision`.

Surface that breaks if this routine stops: operator reverts to manual inbox triage (~30 min/morning).

## Pilot revision history

- **v0** (YYYY-MM-DD): Initial spec, status: draft.
