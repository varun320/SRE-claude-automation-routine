---
# ============================================================
# COMMON ROUTINE TEMPLATE — Customer Touch Monitor
# Pattern: flag customers whose last touchpoint exceeds a threshold.
# Multiple cadences possible (daily for active accounts, quarterly for HQ relationships).
#
# When to use this template:
#   - Operator says "Top N accounts forget accountability when CRM logging is delayed"
#   - Strategic accounts (e.g., Aramco HQ) need quarterly heartbeat
#   - Sales pipeline has stale opportunities that need re-engagement
# ============================================================

id: R5                                  # NEEDS_INPUT — use R5 for daily/weekly, R22 for quarterly HQ
slug: customer-touch-monitor-{cadence}  # e.g. customer-touch-monitor-weekly, customer-touch-monitor-quarterly
client_slug: NEEDS_INPUT
status: draft
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
pilot_revision: 0

schedule:
  # Weekly default — Tuesday 08:00 (Tuesday is the "no touchpoints since last week?" canonical day)
  # For quarterly HQ: "0 8 1 1,4,7,10 *"  → 1st of Jan/Apr/Jul/Oct
  cron: "0 8 * * 2"
  timezone: NEEDS_INPUT
  hard_anchors_respected: true

scope:
  mailboxes: ["operator@client.com"]
  toRecipients_filter: false            # we want both inbound from + outbound to customer
  window_hours_back: 8760               # 365 days — looking for absence of touch within last year
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders: []
  include_keywords: []
  exclude_keywords:
    - "Tentative:"
    - "Accepted:"
    - "Declined:"
    - "newsletter"
  silence_threshold_days: 30            # CUSTOM FIELD — alert when no touch in this window
  customer_subset_filter: "tier_1"      # CUSTOM — which customers to monitor (see client-config)

trigger_event_hints: []
# This routine doesn't escalate on subject regex — it escalates on ABSENCE of any touch.

output:
  channel: local_file                   # pilot · promote to zoho_tasks (one task per stale customer) or teams_pinned
  channel_target: "routines/output/R5-{date}.md"
  format: structured-summary
  recipients: ["operator@client.com"]

safety:
  read_only: true
  write_actions: []
  confidential_topics_redacted: []

budget:
  max_graph_calls: 80                   # 365 days × calendar+sent — chunk by quarter
  max_runtime_seconds: 240
  max_output_chars: 5000

observability:
  log_file: "routines/logs/R5-{date}.json"
  log_keep_days: 180
  metric_signal: "Number of customers flagged as 'silent N+ days' — should match operator's mental model within ±1"

acceptance:
  - "First 3 runs reviewed by operator within 24h"
  - "Customer attribution accuracy > 90% (right customer flagged when silent)"
  - "Operator agrees with the flag for ≥ 80% of customers surfaced"
  - "No false negatives — no customer the operator considered silent escaped detection"

graduates_to_active_when:
  - "4 consecutive weekly runs without operator pushback"
  - "All acceptance criteria met"
  - "Output channel migrated to zoho_tasks (one task per stale customer)"

retires_when:
  - "Client's CRM surfaces last-touch metric natively in operator's workflow"
  - "Threshold customer list becomes too volatile to maintain"

linked_audit_findings:
  - "audits/<client>-<date>/data/stage-2-to-7-summary.json#stage_2B_calendar_findings"
  - "audits/<client>-<date>/data/stage-2-to-7-summary.json#customer_touch_2yr"

owner: "NEEDS_INPUT"
co_owner: "NEEDS_INPUT"
---

# R5 / R22 · Customer Touch Monitor

## Why this exists

The audit reveals customers that were active 6 months ago and have gone silent — possibly because the operator's attention shifted, possibly because the deal stalled, possibly because the customer is shopping competitors. Without a deliberate watcher, the operator only notices when a customer reaches out (which they often don't if they've already moved on).

Quote from audit: > "ME top accounts forget accountability when CRM logging is delayed >24h."

Audit reference: 24-month customer-touch table in audit dashboard.

## What it does

```
1. Hard-anchor check → exit if within prayer/family/sleep window
2. Read client-config.yaml → get customer_keywords + known_top_customers
3. Filter to scope.customer_subset_filter (e.g., tier_1, ME-only, quarterly-HQ)
4. For each in-scope customer:
   a. Search the operator's Sent items for last 365 days for subject containing any of customer's keywords
      mcp__ms365__list-mail-folder-messages on Sent Items
      orderby="sentDateTime desc"
      filter via customer_keywords match in subject OR to/cc domain match
   b. Search operator's Inbox last 365 days for inbound from customer domain
   c. Search calendar last 365 days for events with attendees from customer domain
      mcp__ms365__get-calendar-view (chunked 6-month windows)
   d. Compute last_touch_date = max of all signals
5. For each customer where (today - last_touch_date) > scope.silence_threshold_days:
   - Add to silent_customers[]
   - Annotate with: last_touch_subject + last_touch_channel + days_silent + last_known_stage (from client-config.sales_stages if mappable)
6. Sort silent_customers by days_silent descending
7. Format and write
```

## Good output example

```
# Customer Touch Monitor · 2026-05-21 (weekly)

Silent > 30 days · 6 of 12 tier-1 customers

1. KOC (Kuwait) · 156 days silent · last: "RE: KOC RFP-2103367" (Dec 11 2024)
   Last stage: rfq_received · Suggested: re-engage Naveed (AIMS) for status

2. Tidewater (Canada) · 89 days silent · last: calendar event "Tidewater commercial discussion" (Feb 22)
   Last stage: clarifications · Suggested: ping for status

3. CEPSA (Spain) · 78 days silent · last: "New Cepsa SRU Testing Tender" (Mar 4)
   Last stage: lead · Suggested: confirm still pursuing or move to dormant

4. Calumet Training · 65 days silent · last: 2019138 project group activity
   Last stage: in_execution (stale) · Suggested: verify project actually closed

5. Husky Lima · 47 days silent · last: project group 2021108 mailbox activity
   Last stage: dormant candidate · Suggested: deprioritize or formally retire

6. Big West Oil · 41 days silent · last: SharePoint /Clients/Big West Oil/2018103 access
   Last stage: in_execution · Suggested: confirm project status

[Other 6 tier-1 customers all touched in last 30 days — no action needed]
```

## Bad output example

```
# Customer Touch Monitor · 2026-05-21

Silent > 30 days · 12 of 12 tier-1 customers
- ALL customers shown as silent — appears budget exceeded before search completed

[Errors: budget_exceeded at item 4]
```

Triage:
- Budget too tight for 365-day calendar search → raise `max_graph_calls` to 120 OR
- Chunk by customer (process N customers per run, rotate weekly) OR
- Switch to delta — only re-check customers whose last_touch_date hasn't been updated in our local cache

## Edge cases

- **Customer-name aliasing**: project codes (e.g., "2024119") may be the only mention in subject — make sure customer_keywords includes both canonical name AND aliases AND project codes
- **Multi-domain customers**: large customers have multiple email domains (subsidiary, regional offices) — keep `domains: [...]` per customer in client-config
- **Partner-bridged customers**: e.g., Aramco touched through AIMS — count AIMS-organized meetings about Aramco as touches
- **Stale "in_execution"**: a customer at `in_execution` who's been silent 90 days is a different signal from a `lead` who's been silent 90 days — adjust threshold per stage
- **Quarterly HQ cadence**: for R22-style HQ relationships, silence_threshold_days = 90; the routine is a quarterly nudge, not a weekly alarm
- **Vendor vs customer**: PrismTeck-class entries are vendors, not customers — exclude from `customer_subset_filter`

## Rollback

1. **Pause**: `status: paused`.
2. **Investigate**: did the routine surface customers operator considers irrelevant? Tighten `customer_subset_filter` or shrink `customer_keywords` to active accounts only.
3. **Common fixes**:
   - Per-customer threshold override (Aramco quarterly = 90d, Tidewater monthly = 30d)
   - Add `last_known_stage_weight`: dormant customers don't need monitoring
   - Move to `zoho_tasks` so operator can dismiss vs act per customer

Surface that breaks if this routine stops: operator may miss silent strategic customers; relies on memory.

## Pilot revision history

- **v0** (YYYY-MM-DD): Initial spec, status: draft.
