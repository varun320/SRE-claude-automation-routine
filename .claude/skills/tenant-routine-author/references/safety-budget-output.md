# Safety, budget, and output-channel decisions

Three closely-coupled decisions every routine has to make explicitly. This file gives the rules.

---

## 1. Safety — read-only by default

**Every new routine starts `safety.read_only: true` and `safety.write_actions: []`.** No exceptions, even if the operator asks for a write action up front.

The reason: a routine that can't reliably IDENTIFY the right thing has no business ACTING on it. Reads first, validate accuracy, then add writes one at a time.

### Promoting to a write-action routine

Requires all of:

1. **Pilot success on read-only version.** The routine has been running with `read_only: true` for at least 1 week, and the operator has confirmed it identifies the right thing > 90% of the time.
2. **Explicit operator approval per write action.** Captured as a quote in the spec body.
3. **Smallest possible scope.** A write to "mark as read" is acceptable; a write that sends an email to a customer is not — that needs a separate human-in-loop skill, not a scheduled routine.
4. **Reversible.** The write must be undoable. Acceptable: archive a message, set a category, create a draft. Not acceptable from a routine: delete a message, send a message to a customer, modify a calendar invite for someone else.
5. **Logged.** Every write action emits an audit log entry: `{routine_id, run_id, action, target_id, timestamp, before_state, after_state}`.

### Write-action allowlist (vocabulary)

When `read_only: false`, `write_actions` is an explicit list from this vocabulary:

| Action | Description | Reversibility |
|---|---|---|
| `mark_read` | Set `isRead: true` on a message | Trivial — operator can re-mark unread |
| `flag_for_followup` | Set follow-up flag on a message | Trivial |
| `archive_to_folder:<folder-name>` | Move to a named folder (must exist) | Trivial — can move back |
| `seed_inbox_rule:<rule-spec>` | Create a NEW inbox rule (must be additive only, never modify/delete existing) | Reversible — operator can delete the rule |
| `categorize:<category>` | Apply an Outlook category | Trivial |
| `set_importance:<low|normal|high>` | Adjust message importance | Trivial |
| `create_draft_reply` | Create a draft (does NOT send) | Trivial — drafts can be deleted |
| `create_zoho_task` / `create_clickup_task` / `create_planner_task` | Add a task to operator's queue | Operator can delete |
| `pin_in_chat:<chat-id>` | Pin a message in operator's own chat | Trivial |

**Never in the allowlist** (these require a separate review-gate skill, not a scheduled routine):

- `send_mail`
- `reply_mail`
- `forward_mail`
- `delete_mail`
- `move_to_deleted`
- `accept_event` / `decline_event` / `tentatively_accept_event`
- `forward_event`
- `cancel_event`
- `delete_event`
- `update_event`
- `set_my_presence`
- `update_mail_rule` / `delete_mail_rule` (only seed new ones; never touch existing)
- Anything writing to a SharePoint list / OneDrive file the operator doesn't own

---

## 2. Budget — bounded everything

Three budgets, all enforced at runtime, all logged when exceeded:

### `max_graph_calls`

How many MS-365 MCP tool calls one run may make. Default 50. The routine MUST track call count and abort if it would exceed.

Rationale: a runaway routine that paginates a 24,000-item inbox without limits will exhaust quota and is the leading cause of "why did our M365 hit a 429?" tickets.

### `max_runtime_seconds`

Wall-clock cap. Default 120s. If a routine exceeds, abort with a partial-results log entry.

Rationale: scheduled agents that hang block the queue.

### `max_output_chars`

Cap on the final output payload. Default 4000 (fits in a Teams pinned message). If a run would produce more, the routine MUST summarize and write the full detail to a log file referenced from the summary.

Rationale: 50KB output dumped into a Teams message is worse than no output — operator can't read it.

### Budget violations are findings

When a routine exceeds any budget twice in a week, the spec gets a `pilot_revision` bump and the budget is examined: is the routine doing too much, or is the budget too tight? Common fixes:

- Tighten `scope.window_hours_back` (look at less data per run)
- Tighten `scope.exclude_senders` or `scope.exclude_keywords` (less noise)
- Split the routine (R1 → R1a + R1b)
- Switch from per-run to incremental delta (track last-seen-id, only process new since)

---

## 3. Output channel decision matrix

Where the routine's output lands shapes whether the operator actually reads it. Wrong channel = ignored routine = wasted compute.

### Decision tree

```
Is this confidential (sale-process, board, DD, HR)?
├── YES → local_file OR note_file_in_onedrive (operator-only)
│         NEVER teams_channel, NEVER outlook_flagged with external CCs
└── NO  ↓

Does the output require operator action within 24h?
├── YES → zoho_tasks / clickup / planner / teams_pinned (high-signal, in-flow)
└── NO  ↓

Is the output a draft for operator review before send?
├── YES → create_draft_reply (Outlook drafts folder)
└── NO  ↓

Is the output a passive log / weekly summary / FYI?
├── YES → local_file / note_file_in_onedrive
└── NO  ↓

(default) → local_file in pilot, revisit channel after acceptance criteria met
```

### Channel rubric

| Channel | Cost to read | Cost to act on | Best for |
|---|---|---|---|
| `local_file` | Medium (operator must open file) | Low | Pilot phase, weekly memos, audit logs |
| `note_file_in_onedrive` | Medium | Low | Long-form summaries, confidential weekly memos |
| `zoho_tasks` | Low (already in operator's task UI) | Low (mark complete in same UI) | Actionable items the operator's task workflow already lives in |
| `clickup` | Low | Low | Same — but for project-tracked items |
| `planner_task` | Low (if operator uses Planner) | Low | If MS Planner is the active surface (rare — see audit OQ-21) |
| `teams_pinned` (operator 1:1 chat with self / a bot) | Lowest (always visible) | Medium (needs context to act) | Same-day urgent: closing-event detected, customer silence >threshold, AR red flag |
| `teams_channel` | Lowest | Medium | NEVER for confidential. Only for items the whole channel should see (e.g., all-staff Pit Stop reminder) |
| `outlook_flagged_email` | Low (folder is in operator's existing inbox flow) | Low | When the action is "operator should reply to this thread" — flag the original |
| `outlook_category` | Low (label visible in inbox) | Trivial | When categorization itself is the entire output (e.g., classify inbound by customer) |

### Recipients matter

For `teams_channel` and any output with multiple recipients:

```yaml
output:
  channel: teams_channel
  channel_target: "19:abc...@thread.v2"
  recipients: ["maaz@acme.com", "ashleyh@acme.com", "ron@acme.com"]
  recipients_audit: "Confirmed by Maaz 2026-05-21 — these are the standing all-staff channel recipients"
```

If `recipients_audit` is missing, the routine MUST NOT post to that channel. This is the failsafe against "I added a routine but didn't notice the channel had a customer in it."

### Channel migration during lifecycle

Typical channel evolution:

```
draft   →  pilot                                          →  active
        local_file (operator reviews on demand,                  zoho_tasks (or whatever the
        24-hour SLA)                                             stable output is — channel
                                                                 decided during pilot validation)
```

Don't graduate to a high-friction channel until the routine's accuracy is proven on a low-friction one.

---

## Hard-anchor enforcement

`schedule.hard_anchors_respected: true` triggers a runtime check at the start of every run:

```
1. Read client-config.yaml#hard_anchors
2. Current local-time = now() converted to schedule.timezone
3. If current local-time is within ANY hard anchor window → exit cleanly, log "hard_anchor_skip"
4. Otherwise proceed
```

This catches the case where prayer times shift seasonally or the operator adds a new family-time block after the cron was scheduled — the cron itself doesn't need updating.

When a hard_anchor_skip happens, log it but don't escalate. It's normal behavior.

---

## Failure modes — explicit handling

Every routine MUST handle these failure modes:

| Failure | Behavior |
|---|---|
| MCP `verify-login` returns false | Log + skip run + escalate to operator (one-line alert) |
| MS-365 returns 429 (rate limit) | Backoff 30s, retry once. If still 429, skip run + log. Don't burn the budget retrying. |
| Budget exceeded mid-run | Stop, log partial results, write what you have, don't pretend success |
| Output channel returns error (Zoho API 500, Teams chat 404) | Fall back to `local_file`, log the channel failure, escalate after 2 consecutive failures |
| `hard_anchor_skip` | Log only — not an error |
| Tool returns empty when data expected | Log + continue — empty is sometimes correct (audit OQ pattern). Escalate only if 3+ consecutive empty runs. |
| Spec is invalid at runtime (e.g., missing field after edit) | Refuse to run; escalate "spec invalid" |

Silent failure is the worst failure. Always log + always emit a signal the operator can see.
