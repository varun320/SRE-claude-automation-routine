# Routine spec schema

Every routine has exactly one file at `routines/<R-ID>-<slug>.md`. YAML frontmatter + markdown body. This document defines the schema both halves must follow so specs are comparable across clients and routines.

## Frontmatter — required fields

```yaml
---
id: R1
slug: na-inbox-scan
client_slug: acme
status: draft | pilot | active | paused | retired
created: 2026-05-21
last_updated: 2026-05-21
pilot_revision: 0                       # increment each iteration during pilot

schedule:
  cron: "0 13 * * 1-5"                  # crontab format
  timezone: America/Edmonton            # IANA — must match operator's mailbox tz
  hard_anchors_respected: true          # routine self-checks against hard_anchors before doing work

scope:
  mailboxes: ["maaz@acme.com"]          # which mailboxes the routine reads
  toRecipients_filter: true             # filter messages to ones explicitly addressed to scoped mailbox
  window_hours_back: 24                 # how far back to look each run
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders:                      # noise filters
    - "linkedin.com"
    - "alarm.com"
    - "*-noreply@*"
  include_keywords: []                  # if non-empty, only items matching are considered
  exclude_keywords: []                  # mute these

trigger_event_hints:                    # subject-regex matches that get escalated
  - regex: '(?i)\b(po\s*signing|po\s*approved|awarded)\b'
    severity: closing_event
  - regex: '(?i)\b(rfq|rfp|tender|inquiry|bid)\b'
    severity: rfq_received
  - regex: '(?i)\b(overdue|past\s+due|aging)\b'
    severity: ar_followup

output:
  channel: local_file | zoho_tasks | clickup | teams_pinned | teams_channel | outlook_flagged_email | note_file_in_onedrive
  channel_target: "routines/output/R1-{date}.md"   # path / list-id / chat-id
  format: structured-summary | bullet-list | one-line | note-file
  recipients: ["maaz@acme.com"]         # who sees it (matters for teams_channel)

safety:
  read_only: true                       # default true — flip with operator approval
  write_actions: []                     # explicit allowlist when read_only:false
                                        # e.g. ["seed_inbox_rule:read_then_archive", "flag_for_followup"]
  confidential_topics_redacted:
    - sale_process_buyer
    - SRE DD                            # any folder/customer from client-config

budget:
  max_graph_calls: 50
  max_runtime_seconds: 120
  max_output_chars: 4000

observability:
  log_file: "routines/logs/R1-{date}.json"
  log_keep_days: 90
  metric_signal: "ratio of escalations to runs — should be < 30%"

acceptance:                             # 2-4 concrete yes/no questions
  - "First 5 runs reviewed by operator within 24h"
  - "False positive rate < 20%"
  - "Operator confirms 'this saved me time' by week 2"

graduates_to_active_when:
  - "10 consecutive runs without operator pushback"
  - "All acceptance criteria met"

retires_when:
  - "3 pilot revisions without meeting acceptance"
  - "Operator explicitly requests retire"
  - "Routine duplicates work that has moved to another tool"

linked_audit_findings:                  # back-pointer to audit
  - "audits/acme-2026-05-21/data/tenant-summary.json#openQuestions.OQ-05"

owner: "Maaz Ahmed Shareef"             # operator
co_owner: "Mohammad"                    # whoever maintains the routine
---
```

## Frontmatter — optional fields

| Field | Used for |
|---|---|
| `experimental: true` | Mark routines that are research-grade, not production. They get an "EXPERIMENTAL" badge in dashboards |
| `requires_human_in_loop: true` | The output is a draft that must be reviewed before any send/action |
| `parent_routine: R1` | When a routine derives from another's output (e.g., R1 produces an inbox classification; R1b is the "send acknowledgement" follow-up that requires R1's output) |
| `depends_on: [R1, R3]` | Hard dependency — routine errors out if upstream routine hasn't run today |
| `replaces: R0` | If this routine supersedes a retired one — used for migration history |
| `cron_alternate_paused`: "0 13 * * 1-5" | Backup cron stored when status:paused so resume restores it |

## Body — required sections

After the frontmatter, the body MUST include these sections in this order:

```markdown
## Why this exists

(Link back to the audit finding / open question / operator quote. One paragraph.)

## What it does

(Step-by-step pseudocode of the runtime. Concrete enough that a fresh Claude session
could re-implement it from this section alone.)

## Good output example

(Show a real example of what the routine produces when working correctly. This is
the gold-standard reference for triaging future bad runs.)

## Bad output example

(Show a real example of what failed output looks like — wrong scope, false positive,
missed event, over-budget, etc. Used for fault diagnosis.)

## Edge cases

(Enumerate known weird cases: mailbox-access cross-pollination, sale-process redaction,
AIMS-overlap, name collisions, holiday weeks, etc.)

## Rollback

(How to pause or retire if it starts misbehaving. Include the specific cron-disable
command and the operator surface that breaks if it stops running.)
```

## Body — optional sections

```markdown
## Pilot revision history

- v0 (2026-05-21): initial spec
- v1 (2026-05-28): tightened toRecipients filter after OQ-16 confirmed
- v2 (2026-06-04): switched output channel from local_file to zoho_tasks

## Retirement note

(Filled in only when status: retired. Explains what didn't work and what we learned.)

## See also

- R3 (ME Inbox Scan) — same shape, ME-region scope
- R12 (AR Pre-Stage) — depends on R1's classification
```

## Validation rules

A routine spec is **valid** when:

1. `id` is unique within `routines/` for the client
2. `slug` is kebab-case and matches the filename
3. `status` is one of the enum values
4. `schedule.cron` parses as valid crontab (5 fields)
5. `schedule.timezone` is a valid IANA timezone
6. `scope.mailboxes` is non-empty
7. All paths under `output.channel_target` and `observability.log_file` are inside the client project directory (no `..`/`~`)
8. `safety.read_only: false` requires `safety.write_actions` to be non-empty AND the operator's explicit text approval recorded in the body
9. `budget.*` values are positive integers
10. `acceptance` has at least 2 entries
11. Body contains all required sections in order

## File naming

`routines/<R-ID>-<slug>.md`

Examples:
- `routines/R1-na-inbox-scan.md`
- `routines/R3-me-inbox-scan.md`
- `routines/R12-ar-prestage-thursday.md`
- `routines/R22-aramco-hq-quarterly.md`
- `routines/R9-sale-process-weekly-memo.md`

If the client uses non-numeric ids (e.g., `INBOX-NA-DAILY`), keep the format `<ID>-<slug>.md` and update the validation rule above.

## Versioning the spec itself

The spec is a markdown file under git. Use commit history for change-tracking, not in-file version fields (except `pilot_revision` for pilot iteration counting).

Major changes during active status (e.g., scope expansion, output channel switch):
- Bump `pilot_revision` and flip back to `status: pilot` for 1 week
- Re-verify acceptance criteria
- Promote back to `status: active` once stable

## Inheritance from client-config.yaml

The spec MUST NOT duplicate values that live in `client-config.yaml`. Examples of values to inherit by reference, not copy:

| Inherit | Reference syntax |
|---|---|
| Customer keywords | `scope.customer_keywords_source: client-config.yaml#customer_keywords` |
| Hard anchors | implicit — `hard_anchors_respected: true` triggers runtime check against client-config |
| Operator timezone | implicit when `schedule.timezone` is set to same value |
| Redaction list | `safety.confidential_topics_redacted` references items by name from client-config |
| Sales stages | `trigger_event_hints` reference stage names from client-config.yaml#sales_stages |

When client-config changes, routines automatically inherit. No spec edit needed.
