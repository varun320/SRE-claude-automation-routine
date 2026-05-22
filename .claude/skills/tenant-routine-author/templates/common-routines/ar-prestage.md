---
# ============================================================
# COMMON ROUTINE TEMPLATE — AR Pre-Stage
# Pattern: weekly scrape of AR mailbox + sent items, produce
# 1-pager of outstanding receivables grouped by customer + aging.
#
# When to use this template:
#   - Operator has a recurring CFO Day / Finance Day cadence
#   - AR follow-up emails exist but operator only sees them when they remember
#   - Aging reports come from QuickBooks/Zoho Books but not in operator's flow
# ============================================================

id: R12
slug: ar-prestage-{day}                 # e.g. ar-prestage-thursday
client_slug: NEEDS_INPUT
status: draft
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
pilot_revision: 0

schedule:
  # Default Thursday 07:00 — landing in operator's inbox BEFORE their CFO/Finance Day
  cron: "0 7 * * 4"
  timezone: NEEDS_INPUT
  hard_anchors_respected: true

scope:
  mailboxes:
    - "ar@client.com"                   # primary AR mailbox
    - "operator@client.com"             # operator's Sent items (for AR-followup chains they sent)
  toRecipients_filter: false            # we want both inbound (to AR) AND outbound (operator following up)
  window_hours_back: 168                # 7 days
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders:
    - "linkedin.com"
    - "*-noreply@*"
  include_keywords: []
  exclude_keywords:
    - "test"
    - "Tentative:"
    - "Accepted:"

trigger_event_hints:
  - regex: '(?i)\b(overdue|past\s+due|aging|outstanding|reminder)\b'
    severity: ar_explicit
  - regex: '(?i)\b(audit\s+confirmation|balance\s+as\s+of|balance\s+confirmation)\b'
    severity: ar_year_end
  - regex: '(?i)\b(account\s+reconciliation|reconcile|reconciliation)\b'
    severity: ar_reconciliation
  - regex: '(?i)\b(invoice|inv[-\s]?\d|invoice\s+number)\b'
    severity: invoice_reference
  - regex: '(?i)reminder\s*[-#]?\s*\d+'
    severity: ar_repeated_reminder

output:
  channel: local_file                   # pilot · promote to zoho_tasks or note_file_in_onedrive
  channel_target: "routines/output/R12-{date}.md"
  format: note-file                     # operator reads this on Thursday morning
  recipients: ["operator@client.com"]

safety:
  read_only: true
  write_actions: []
  confidential_topics_redacted: []

budget:
  max_graph_calls: 60                   # 2 mailboxes × 7 days of messages
  max_runtime_seconds: 120
  max_output_chars: 6000                # AR pre-stage is a richer document

observability:
  log_file: "routines/logs/R12-{date}.json"
  log_keep_days: 365                    # AR has compliance value — keep longer
  metric_signal: "Per run · count of unique customers with AR signal · should match operator's Thursday talking points within ±1"

acceptance:
  - "First 3 Thursday runs reviewed before CFO Day"
  - "Operator confirms AR pre-stage replaced manual scrape they previously did"
  - "Customer-attribution accuracy > 90% (right customer name per AR thread)"
  - "Aging buckets (30/60/90/120+) populated correctly when invoice ref is present"

graduates_to_active_when:
  - "4 consecutive Thursday runs without operator pushback"
  - "All acceptance criteria met"
  - "Output channel migrated from local_file to note_file_in_onedrive (so operator can edit + share with CFO)"

retires_when:
  - "Client's accounting system surfaces AR pre-stage natively"
  - "Routine duplicates work that has moved to Zoho Books / QuickBooks dashboards"

linked_audit_findings:
  - "audits/<client>-<date>/data/stage-2-to-7-summary.json#stage_2A_mail_findings"

owner: "NEEDS_INPUT"
co_owner: "NEEDS_INPUT"
---

# R12 · AR Pre-Stage ({day})

## Why this exists

Operator runs a weekly CFO Day (typically Thursday). Without pre-stage, the operator scans the AR mailbox + their own sent items in real time during the CFO call — slow, prone to missing reminders, customer name-attribution is manual. This routine produces a 1-pager AR brief 4 hours before the call.

Quote from audit: > "AR aging needs to be pre-staged for Thursday CFO day."

Audit reference: AR-followup signals visible in Stage 2A sent items (audit confirmation requests, Tüpraş reconciliation reminders, balance confirmation chains).

## What it does

```
1. Hard-anchor check → exit if within prayer/family/sleep window
2. For each mailbox in scope.mailboxes:
   a. List Inbox messages from last 7 days (ar@) and Sent items from last 7 days (operator)
   b. select="id,subject,from,toRecipients,receivedDateTime,sentDateTime,hasAttachments,conversationId"
3. Filter: drop noise senders, drop Tentative/Accepted (calendar response) noise
4. For each remaining message, classify with trigger_event_hints:
   - ar_explicit (most urgent)
   - ar_repeated_reminder (operator follow-up #N)
   - ar_year_end (audit confirmation requests)
   - ar_reconciliation
   - invoice_reference
5. For each AR-signaled message:
   a. Extract customer name via customer_keywords match (subject + from-domain)
   b. Extract invoice number via regex if present
   c. Estimate aging bucket: if subject says "reminder #5" or "past_due" → 60d+; if "audit confirmation" → year-end ritual; otherwise leave as "uncategorized"
6. Group output by customer, sorted by aging bucket descending (oldest first):
   For each customer:
     - Customer name + region from client-config
     - Threads in chronological order with severity tag
     - Latest follow-up date + sender
     - Suggested talking point for CFO call (one line)
7. Render as markdown table with sections per aging bucket
8. Write to channel_target
9. Append run log
```

## Good output example

```markdown
# AR Pre-Stage · Thursday 2026-05-21

## 120+ days outstanding (3 customers)

### Tüpraş (Turkey) · invoice #INV-2025-0314
- 2026-05-11 reminder #5 sent by ashleyh@acme.com
- 2026-05-06 reminder #4 sent by operator
- 2026-04-22 reminder #3 sent by operator
**Talking point**: "Tüpraş on reminder #5 — propose CFO call escalation"

### Anwil / Orlen (Poland) · invoice unclear
- 2026-05-19 tender platform notification (Orlen connect platform)
- 2026-05-10 outbound from ar@ — no response
**Talking point**: "Anwil — no engagement since last call; consider direct outreach"

## 60-90 days (1 customer)

### QChem (Qatar) · invoice #INV-2026-0044 (Item 44 April AP)
- 2026-05-13 DRAFT proposal sent → no AR follow-up yet
**Talking point**: "QChem invoice referenced in April AP doc — confirm Sanjay Bhatt received"

## Year-end (1 active)

### SRE Year-End Audit Confirmation 31.12.2025
- 2026-05-10 response sent to fazal@aimsgt.com
- 2026-05-06 response sent to junaid@aimsgt.com
**Status**: in flight — no action needed unless auditor escalates
```

## Bad output example

```markdown
# AR Pre-Stage · Thursday 2026-05-21

(empty — no customers detected)
```

Triage:
- Either `scope.window_hours_back` too narrow (try 14 days)
- Or `customer_keywords_source` not populated in client-config (run audit OQ-09 resolution)
- Or AR mailbox isn't in `scope.mailboxes`

## Edge cases

- **Customer name disambiguation**: "Maaz Khan" (AIMS) vs operator's name — match by domain, not name
- **Multiple invoices per customer**: don't dedupe — operator wants visibility into each
- **Year-end vs ongoing AR**: audit confirmation requests are a different category from past-due invoices — keep separate sections
- **Sale-process redaction**: if a confidential_customer is in AR, redact the customer name but keep the aging/amount signal so operator can ask CFO without revealing
- **Holiday weeks**: AR communication slows. Don't escalate "no follow-up this week" as a problem — annotate "holiday-affected"

## Rollback

If output is wrong:

1. **Pause**: `status: paused`. Operator returns to manual scrape.
2. **Investigate log**: check `items_processed` vs `items_in_window`. If `items_in_window` is 0, the scope is wrong.
3. **Common fixes**:
   - Widen `scope.window_hours_back` (14 or 30 days)
   - Add a customer-keyword for an AR customer not in client-config
   - Add a sender to `exclude_senders` if noise leaks through

Surface that breaks if this routine stops: operator reverts to live scrape during CFO Day (~45 min, less consistent).

## Pilot revision history

- **v0** (YYYY-MM-DD): Initial spec, status: draft.
