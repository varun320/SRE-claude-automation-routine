---
id: R1
name: NA Inbox Scan
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "55 11 * * 0-4"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365]
ms365_scopes: [Mail.Read, Chat.Read]
output: notification
safety: read-only, subjects-only, no drafts, ≤200 words
window: "since 21:55 yesterday MT"
linked_audit_findings:
  - "audits/sre-2026-05-21/data/tenant-summary.json#mailbox_signals"   # 24,735 inbox · 8,679 unread · 0 rules
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-05"   # seed inbox rules or just summarize?
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-16"   # toRecipients_filter mandatory
---

# R1 — NA Inbox Scan (subjects only)

**Trigger:** Sun–Thu at 11:55 America/Edmonton, immediately before the 12:00 Daily Setup slot.

**Goal:** 5-minute scan that returns subject lines grouped by urgency so the operator walks into 12:00 setup already knowing the shape of the day. NO drafting, NO replies, NO recommendations.

**Why it matters:** Enforces the "subjects only" discipline — prevents inbox doom-spiral before deep work. From Weekly OS §3.

---

## Build prompt

> Scan my Outlook inbox and Teams DMs received since 21:55 yesterday America/Edmonton time. Group senders/subjects into RED (decision needed today), AMBER (response needed this week), GREEN (FYI). Return only sender + subject + 5-word context per item. No drafting, no full reads, no recommendations. Maximum 200 words total.
>
> Use the ms365 MCP server. For mail: `list-mail-messages` filtered by received date. For Teams: `list-chat-messages` across recent chats. Read-only — do not call any tool whose name starts with create-, send-, update-, delete-, move-, or reply-.

---

## Output shape

A single short message, e.g.:

> 8 new since 21:55 ME triage.
> **RED (2):** Caleb — CSV bid Q · Aramco — RTR scheduling
> **AMBER (3):** Petro Rabigh — sample delay · Anwil — NDA v3 · Q-Chem — invoice Q
> **GREEN (3):** [list]

Delivered to: Outlook self-DM or Teams self-chat (per Open Question #4 from IMPLEMENTATION_PLAN.md — decide before first fire).

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 8k input, ≤ 1k output. If a fire exceeds, log to `logs/incidents/` and review the prompt.
- **No write tools.** The build prompt above forbids them, but the operator should also confirm the scheduled agent's role/scope cannot exceed `Mail.Read` + `Chat.Read` if the platform supports per-routine scoping.
- **Prayer/family windows:** 11:55 MT is the slot before Zuhr (~13:15 winter, varies summer) and outside the 19:00–22:00 family block. Audited safe.
- **Failure mode:** If the ms365 connector errors, route the failure notification per Open Question #4. Do NOT retry silently.

---

## Run log

Per-fire output and metrics land in `logs/runs/R1-YYYY-MM-DD.md`. Capture:

- Wall-clock time
- Token usage (in / out)
- Connector calls made (count + names)
- Whether output respected "subjects only, ≤200 words"
- Any RED items that turned out to be false-positives or missed RED items (for prompt tuning)

---

## Phase-1 exit criteria (from IMPLEMENTATION_PLAN.md §Phase 1)

- [ ] R1 fires on schedule without intervention
- [ ] Output matched the build prompt's constraints (no drafts, no over-reach)
- [ ] Cost per run measured and projected (× 26 routines × weekly fires) within budget
- [ ] One full Sun–Thu cycle (5 fires) completed cleanly
