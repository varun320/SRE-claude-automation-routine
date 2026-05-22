---
# ============================================================
# COMMON ROUTINE TEMPLATE — Calendar Hygiene
# Pattern: weekly maintenance of operator's calendar — strip
# cancellations, flag placeholders, surface drift in naming conventions.
#
# When to use this template:
#   - Audit shows lingering "Canceled:" events / Placeholder subjects / trailing-space subjects
#   - Operator wants calendar-as-source-of-truth for time accounting
#   - Day Clock conventions exist on paper but observed reality drifts (audit OQ-18)
# ============================================================

id: R7                                  # adjust per client routine numbering
slug: calendar-hygiene
client_slug: NEEDS_INPUT
status: draft
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
pilot_revision: 0

schedule:
  # Friday afternoon — set the operator up for a clean Monday
  cron: "0 16 * * 5"
  timezone: NEEDS_INPUT
  hard_anchors_respected: true

scope:
  mailboxes: ["operator@client.com"]    # operator's calendar
  toRecipients_filter: false
  window_hours_back: 168                # past 7 days
  window_hours_forward: 336             # next 14 days
  customer_keywords_source: client-config.yaml#customer_keywords

trigger_event_hints:
  - regex: '^Canceled:'
    severity: cancellation_lingering
  - regex: '^(Placeholder|Tentative): '
    severity: uncommitted_placeholder
  - regex: '\s$'                        # trailing whitespace in subject
    severity: subject_typo
  - regex: '(?i)(â€"|Ã¢|â€™)'           # UTF-8 mojibake markers
    severity: encoding_artifact

output:
  channel: local_file                   # weekly memo style; rarely needs higher signal
  channel_target: "routines/output/R7-{date}.md"
  format: bullet-list
  recipients: ["operator@client.com"]

safety:
  read_only: true                       # phase 2 may add delete_event for known cancellations (extra-careful)
  write_actions: []
  confidential_topics_redacted: []

budget:
  max_graph_calls: 30
  max_runtime_seconds: 60
  max_output_chars: 3000

observability:
  log_file: "routines/logs/R7-{date}.json"
  log_keep_days: 90
  metric_signal: "Count of cleanup candidates · should trend down week-over-week if operator is actually acting"

acceptance:
  - "First 3 Friday runs reviewed within 24h"
  - "Operator agrees ≥ 80% of flagged items genuinely need cleanup"
  - "Cleanup-candidate count trends down (not up) after 4 weeks"

graduates_to_active_when:
  - "4 consecutive Friday runs without operator pushback"
  - "Acceptance criteria met"

retires_when:
  - "Operator's calendar is consistently clean — routine has nothing to surface for 6 consecutive runs"
  - "Convention enforcement (OQ-18) is solved by a different mechanism"

linked_audit_findings:
  - "audits/<client>-<date>/raw/calendar/calendar-2yr-aggregate.json#anomalies"
  - "audits/<client>-<date>/data/stage-2-to-7-summary.json#stage_2B_calendar_findings"

owner: "NEEDS_INPUT"
co_owner: "NEEDS_INPUT"
---

# R7 · Calendar Hygiene

## Why this exists

The audit surfaced lingering cancellations, "Placeholder" subjects that were never finalized, trailing-space typos in recurring subjects, and UTF-8 mojibake from email clients. Each is a small thing; together they make the calendar untrustworthy as a time-accounting surface. This routine produces a weekly cleanup list — items the operator can fix in 5 minutes Friday afternoon.

Quote from audit: > "Cancellations linger: 'Canceled:' prefix retained on many events."

Audit reference: calendar 2yr aggregate anomalies section.

## What it does

```
1. Hard-anchor check → exit if within prayer/family/sleep window
2. mcp__ms365__get-calendar-view
   - startDateTime = now - 7 days
   - endDateTime   = now + 14 days
   - select="id,subject,start,end,isOnlineMeeting,categories,sensitivity,showAs,type"
   - timezone=schedule.timezone
3. For each event:
   a. Match subject against each trigger_event_hints regex
   b. If any match → add to cleanup_candidates[] with severity
4. Bucket by severity:
   - cancellation_lingering (most cleanup-worthy)
   - uncommitted_placeholder
   - subject_typo (trailing whitespace, double spaces)
   - encoding_artifact (mojibake)
5. Render as bullet list with click-to-Outlook deep links where available
6. Optional analytics section:
   - Top recurring subjects with their counts (flag duplicates: same subject + different recurrence)
   - Categories used (compare to client-config.naming_conventions.calendar_tags_goal_state)
7. Write to channel_target
```

## Good output example

```markdown
# Calendar Hygiene · 2026-05-21 (Friday review)

## Cleanup candidates (8)

### Cancellations to remove (3)
- "Canceled: Placeholder: Roll out of Strategic Account Management" (2024-06-13 — leftover from 2 years ago)
- "Canceled: SRE Pricing Discussion" (2024-10-01)
- "Canceled: HSS Removal Technology Introduction" (2024-11-13)

### Placeholders never finalized (2)
- "Placeholder: AXENS Strategy Discussion" (2024-08-01, tentative)
- "Placeholder Ron & Maaz meeting" (2026-03-31, tentative)

### Subject typos (2)
- "SAT - Weekly Updates " (trailing space) — Mar 24, Mar 31, Apr 7 instances
- "Tupras Debriefing and Plan Forward " (trailing space, single instance)

### Encoding artifacts (1)
- "Meet the Experts - OFM 23 â€" Analyses Overview" (UTF-8 dash mojibake)

## Convention drift (audit OQ-18)

- Categories in use: ONLY 'Prayer' (11 events)
- Categories goal-state per client-config: [Client], [Partner], [Buyer]
- Drift: 100% — no events tagged with goal-state categories

## Suggested actions

1. Right-click each Canceled: event in Outlook → Delete (4 events)
2. Rename "SAT - Weekly Updates " series → "SAT - Weekly Updates" (trim trailing space)
3. Re-create encoded subject via Find & Replace or recreate event
4. (Optional) Apply [Client]/[Partner]/[Buyer] tags to recent customer events
```

## Bad output example

```markdown
# Calendar Hygiene · 2026-05-21

(No cleanup candidates · calendar is clean)
```

— But it's NOT clean. Triage:
- Time window too narrow (try 30 days back)
- Regex character-class issue (e.g., `\s$` not matching due to event-text normalization)
- Calendar API not returning the actual subject string the client uses (try `$select` adjustments)

## Edge cases

- **Recurring series**: a "Canceled:" prefix may apply to one instance of a series, not the whole series — distinguish via `type: occurrence|exception|seriesMaster`
- **Mojibake re-introduction**: some clients re-introduce mojibake when forwarding events — flag but don't try to autofix
- **Goal-state vs observed**: if the operator hasn't committed to categories at all, the convention-drift section becomes noise. Set a `show_convention_drift: false` flag if operator wants it muted.
- **Future events with old data**: a recurring series created in 2020 with a typo still has the typo in 2026 — the routine should surface it once, not weekly forever. Add a "muted_subject_typos" list per spec to suppress repeats.
- **Multi-calendar operator**: if the operator has multiple calendars (default, shared with Don, shared with Husam) — be explicit about which calendar is in scope, defaults to primary.

## Rollback

1. **Pause**: `status: paused`.
2. **Investigate**: are flagged items genuinely cleanup-worthy or noise?
3. **Common fixes**:
   - Add subjects to a `muted_subject_typos` allowlist (e.g., a legitimately-trailing-space subject)
   - Tighten regex to avoid matching legitimate "Tentative:" calendar responses (which are not the same as user-typed "Placeholder")
   - Narrow window if calendar is large and routine over-budgets

Surface that breaks if this routine stops: calendar drift accumulates; over months the calendar becomes untrustworthy as a time-accounting source.

## Pilot revision history

- **v0** (YYYY-MM-DD): Initial spec, status: draft.
