---
# ============================================================
# COMMON ROUTINE TEMPLATE — Sales Pipeline Watcher
# Pattern: state-machine over mail+calendar+external CRM to detect
# pipeline-stage TRANSITIONS (lead → qualified → rfq → proposal → po → ...).
# Posts deltas only when state changes.
#
# When to use this template:
#   - Operator's pipeline lives in external CRM (Zoho / Salesforce) but state changes
#     are also evidenced in M365 events and they want a single view
#   - Audit revealed pipeline lies on Friday review without Tuesday hygiene
#   - Closing-event detection (PO Signing) needs to surface to operator within hours
# ============================================================

id: R6
slug: sales-pipeline-watcher
client_slug: NEEDS_INPUT
status: draft
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
pilot_revision: 0

schedule:
  # Daily 17:00 — end of operator's local workday, surfaces today's deltas before next-morning routines
  cron: "0 17 * * 1-5"
  timezone: NEEDS_INPUT
  hard_anchors_respected: true

scope:
  mailboxes: ["operator@client.com"]
  toRecipients_filter: false            # need both outbound proposals AND inbound POs
  window_hours_back: 30                 # daily delta + a few hours overlap for safety
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders:
    - "linkedin.com"
    - "alarm.com"
    - "*-noreply@*"
  state_machine_source: client-config.yaml#sales_stages
  closing_event_field: client-config.yaml#closing_event

trigger_event_hints:
  - regex: '(?i)\b(po\s*signing|po\s*approved|order\s+placed|awarded|po\s*number)\b'
    severity: closing_event
    state_transition_to: po_signed
  - regex: '(?i)\b(we''d\s+like\s+to\s+proceed|verbal\s+yes|proceeding\s+with)\b'
    severity: verbal_yes_signal
    state_transition_to: verbal_yes
  - regex: '(?i)\b(rfq|rfp|tender|inquiry|bid)\b'
    severity: rfq_inbound
    state_transition_to: rfq_received
  - regex: '(?i)\bproposal\s*(sent|attached|for\s+review)\b'
    severity: proposal_outbound
    state_transition_to: proposal_sent
  - regex: '(?i)\b(regret|not\s+selected|another\s+vendor|chosen\s+different)\b'
    severity: loss_signal
    state_transition_to: lost_explicit

output:
  channel: local_file                   # pilot · promote to teams_pinned (high-signal alerts must be visible same-day)
  channel_target: "routines/output/R6-{date}.md"
  format: structured-summary
  recipients: ["operator@client.com"]

safety:
  read_only: true
  write_actions: []
  confidential_topics_redacted: []

budget:
  max_graph_calls: 50
  max_runtime_seconds: 180
  max_output_chars: 4000

observability:
  log_file: "routines/logs/R6-{date}.json"
  log_keep_days: 365                    # pipeline state history is operationally valuable
  metric_signal: "Daily count of detected transitions · 0 transitions for >5 consecutive days = either pipeline truly idle or routine missing signals"

acceptance:
  - "First 5 runs reviewed by operator within 24h"
  - "Closing-event detection: when a PO signing happens, the routine surfaces it within one daily run"
  - "False positive rate < 15% (transitions that operator disagrees with)"
  - "Operator confirms 'I see pipeline movement I would have missed' on ≥ 3 occasions in week 1"

graduates_to_active_when:
  - "10 consecutive runs without operator pushback"
  - "All acceptance criteria met"
  - "Channel migrated to teams_pinned (closing events MUST be visible same-day)"

retires_when:
  - "Client's CRM emits its own state-transition notifications operator already sees"
  - "Routine's state inferences diverge persistently from CRM ground truth"

linked_audit_findings:
  - "audits/<client>-<date>/data/stage-2-to-7-summary.json#stage_2A_mail_findings"
  - "audits/<client>-<date>/raw/calendar/calendar-2yr-aggregate.json#customer_touch_2yr"

owner: "NEEDS_INPUT"
co_owner: "NEEDS_INPUT"
---

# R6 · Sales Pipeline Watcher

## Why this exists

The audit shows pipeline-stage signals scattered across mail subjects ("PO Signing", "RFQ", "DRAFT proposal"), calendar events ("Pre-Meet"), and external CRM stages. The operator's Friday pipeline review relies on memory unless the state has been logged in CRM by Tuesday. This routine watches M365 surfaces daily, infers stage transitions, and surfaces deltas — so the Friday review starts with evidence, not memory.

Quote from audit: > "Pipeline lies on Friday review without Tuesday hygiene."

Audit reference: closing event captured live in Stage 2A — "SRU-1 Onsite Testing 6511226695 *PO Signing*" on 2026-05-19.

## What it does

```
1. Hard-anchor check → exit if within prayer/family/sleep window
2. Load state machine from client-config.yaml#sales_stages
3. Load previous run's state_snapshot (per-customer) from observability.log_file (most recent)
4. For each in-scope customer (from client-config customer_keywords):
   a. Search inbox last scope.window_hours_back
   b. Search sent items last scope.window_hours_back
   c. Search calendar events that day with customer-domain attendees
   d. For each match, check trigger_event_hints regex → potential state_transition_to
5. Apply state-transition rules:
   - Per customer, infer current stage based on most-recent signal
   - Compare against state_snapshot.previous_stage
   - If different → add to transitions[]
6. Filter transitions:
   - Drop low-confidence: stage went backwards (e.g., po_signed → proposal_sent is suspicious — flag, don't auto-transition)
   - Drop conflicting: same customer has both proposal_outbound and loss_signal in same day → mark for human review
7. Format transitions grouped by direction:
   - Forward movements (lead → qualified → ... → po_signed → in_execution)
   - Backward movements / regressions
   - Conflicting signals
   - Closing events (separate section, highest priority)
8. Write to channel_target. Closing events also escalate to teams_pinned regardless of pilot channel
9. Update state_snapshot for next run
10. Append run log
```

## Good output example

```
# Sales Pipeline Watcher · 2026-05-21

## 🎉 Closing events (1)

### Saudi Aramco · po_signed
- Trigger: "SRU-1 Onsite Testing 6511226695 *PO Signing*" sent to quotes.ksa@aimsgt.com (2026-05-19 18:58 MT)
- Previous state: in_execution → po_signed
- Suggested: log to Zoho CRM, notify Dharmesh (Principal Engineer) for kickoff

## Forward movements (2)

### Q-Chem · proposal_sent (was: qualified)
- Trigger: "DRAFT for your approval - QChem (Sanjay Bhatt): SGRU/SRU 2028 Feed Study"
  sent to bader@aimsgt.com on 2026-05-13
- Days at previous stage: 18 (within normal range)

### Phillips 66 (Rodeo) · rfq_received (was: lead)
- Trigger: "Re: Request for Quote - GC Testing at Phillips 66 Rodeo Sulfur Plant"
  sent to ashleyh@acme.com on 2026-05-06
- Days at previous stage: 5

## Conflicting signals (1)

### CEPSA · ambiguous (was: lead)
- Inbound suggests proposal_sent, but calendar shows no follow-up meeting
- Suggested: human review needed before stage change

## No-change customers (10)
[customers checked, no transition: ADNOC, INERCO, KNPC, SATORP, Qatar Energy, ...]
```

## Bad output example

```
# Sales Pipeline Watcher · 2026-05-21

## 🎉 Closing events (15)
1. ADNOC · po_signed
   Trigger: "RE: For review - reinstatement of trains 50/51 - ADNOC Gas Habshan"
   ← false positive: "RE: For review" doesn't mean approved

2. LinkedIn Newsletter · po_signed
   Trigger: "Doing business in China: preparing for success"
   ← false positive: noise sender + over-broad regex
```

Triage:
- `closing_event` regex too loose ("approved" matching marketing) → tighten to require explicit "PO" within N chars
- Noise senders not excluded → check `exclude_senders`
- State machine should require at least 2 corroborating signals before transitioning to `po_signed` (audit OQ-18 — convention enforcement)

## Edge cases

- **Single-signal transitions**: most stages are inferred from one signal. po_signed should require BOTH a subject match AND either a calendar event in the next 14 days OR a sent-confirmation reply. Don't transition on a single ambiguous subject.
- **Customer-name overlap**: "Maaz Khan" (AIMS) vs operator "Maaz" — already handled in customer-touch but matters here too
- **AIMS-bridged customers**: a PO signed at AIMS-side might or might not be a customer transition for SRE — flag for human review when AIMS is the intermediary
- **Vendor stages**: PrismTeck-class entries are vendors, not customers — they should never appear in pipeline output. Verify their `stage_hint: vendor` in client-config.
- **Sale-process redaction**: pipeline output may include confidential customers in some clients — redact name but keep stage signal so operator can act privately
- **Cancellation events**: Outlook "Canceled:" subjects can trigger false `loss_signal` matches — add explicit `exclude_keywords: ["Canceled:"]`
- **Project-code-only references**: subjects like "2024119" may not match customer_keywords by name — keep project codes mapped in client-config

## Rollback

1. **Pause**: `status: paused`. Operator reverts to manual pipeline review.
2. **Investigate**: are transitions wrong or are they correct but in wrong channel/format?
3. **Common fixes**:
   - Require 2 corroborating signals for po_signed (not just one regex match)
   - Add `exclude_keywords` for known confusing phrases
   - Tighten regex word-boundaries
   - Move `state_snapshot` reset to weekly rather than per-run (prevents flapping)
4. If closing-event false positives keep landing in `teams_pinned`: revert to `local_file` until accuracy proves out

Surface that breaks if this routine stops: pipeline drift only catches on Friday review, with up-to-5-day lag on closing events.

## Pilot revision history

- **v0** (YYYY-MM-DD): Initial spec, status: draft.
