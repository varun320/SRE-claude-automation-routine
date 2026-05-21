# Routines

Scheduled remote agents for the SRE Claude Routines project. Each routine is one file with YAML frontmatter + markdown body. Status field is authoritative:

- `draft` — spec exists, no cron registered, operator hasn't approved
- `pilot` — cron live, operator reviews every fire, 1–2 week window
- `active` — cron live, operator samples output
- `paused` — cron disabled, spec retained
- `retired` — cron removed, spec moved to `_retired/`

Lifecycle docs and routine-spec schema live in `~/.claude/skills/tenant-routine-author/`.

## Phase 1 — low-stakes pilot batch (drafted 2026-05-22)

All read-only, all output-as-notification (no drafts, no external sends, no file writes). Phase 1 ships only when each spec is operator-approved.

| ID | Name | Cadence | Status | Connector | Output |
|---|---|---|---|---|---|
| [R1](tier1/R1-na-inbox-scan.md) | NA Inbox Scan (subjects only) | Sun–Thu 11:55 MT | `draft` | ms365 (Mail.Read, Chat.Read) | notification ≤200w |
| [R2](tier1/R2-daily-setup.md) | Daily Setup (Top 3 + calendar + energy check) | Sun–Thu 12:00 MT | `draft` | ms365 (Calendars.Read, Files.Read.All) | notification ≤250w |
| [R5](tier1/R5-me-inbox-scan.md) | ME Inbox Scan (subjects only) | Sun–Thu 21:55 MT | `draft` | ms365 (Mail.Read, Chat.Read) | notification ≤200w |
| [R8](tier1/R8-sunday-planning.md) | Sunday Weekly Planning Slot | Sun 16:00 MT | `draft` | ms365 (Mail.Read, Calendars.Read, Files.Read.All) | notification ≤400w |

**Why these four are "low-stakes":**

- All `safety: read-only`. None create drafts, send messages, write files, or modify calendar.
- Output is delivered to operator's own surface (Outlook self-DM / Teams self-chat) — no external recipients.
- Failure mode is "no output" — not "wrong message sent" or "wrong file overwritten".
- All four are explicitly listed as Phase 1 / Tier 1 in the IMPLEMENTATION_PLAN.md and Execution Plan.

**What is NOT in this Phase 1 batch (deliberately):**

| Routine | Why deferred |
|---|---|
| R3 NA Inbox Triage | Creates Outlook drafts — higher stakes. Phase 2. |
| R4 Daily Close | Writes Daily Log files — borderline. Phase 2. |
| R12 AR Aging | Creates AR follow-up drafts — higher stakes. Phase 4. |
| R13 Weekly Review | Writes Weekly Review file — borderline. Phase 3. |
| R14 Zaheer Update | Creates draft to Group CEO / Shareholder — high stakes. Phase 3. |

## Approval workflow (per routine)

1. Operator reads the spec file.
2. Operator confirms: cron timing OK · output channel OK · safety guardrails OK · build prompt OK.
3. Operator records approval inline in the spec body (one-line quote with date).
4. Status flips `draft → pilot`.
5. `/schedule` registers the cron.
6. Operator reviews every fire for the first 5 occurrences.
7. After acceptance criteria met → status flips `pilot → active`.

## Audit evidence

Every spec links back to specific audit findings via `linked_audit_findings`. The full audit lives at `audits/sre-2026-05-21/`. The dashboard (`audits/sre-2026-05-21/dashboards/audit-report.html`) is the visual entry point.

Key audit insights baked into Phase 1 specs:

- **24,735 inbox items · 8,679 unread · 0 inbox rules** → R1 + R5 are the highest-leverage routines.
- **Full-mailbox-access to dongreen@ + inshanm@ + info@** → R1/R5 require `toRecipients_filter` to avoid cross-mailbox pollution (OQ-16).
- **Day Clock mismatch** (planned 14:05 Mon-Fri 1:1s don't exist as observed events) → R2 + R8 must surface drift, not assume conformity.
- **AIMS roster** (21+ contacts mapped, far more than execution plan's 7) → R5's filter list updated to reflect reality.
- **Sale-process redaction** (SRE DD folder + Torstein 1:1s) → all Phase 1 outputs default to operator-private channel.

## Directory structure

```
routines/
├── README.md                    ← this file
├── tier1/                       ← lowest-stakes, daily/weekly read-only routines
│   ├── R1-na-inbox-scan.md      ← drafted
│   ├── R2-daily-setup.md        ← drafted
│   ├── R5-me-inbox-scan.md      ← drafted
│   └── R8-sunday-planning.md    ← drafted
├── tier2/                       ← phase 2+ — draft → write actions (R3, R4)
├── tier3/                       ← phase 3+ — Weekly + Zaheer (R13, R14)
├── tier4/                       ← phase 4+ — CFO Day AR drafts (R12)
├── output/                      ← per-fire output written here (created on first fire)
├── logs/                        ← per-fire run logs
└── _retired/                    ← retired routine specs, kept for institutional memory
```

## See also

- `IMPLEMENTATION_PLAN.md` — the WHO/WHEN/HOW phasing (this file is the WHAT and WHY)
- `SRE Claude Routines - Execution Plan.md` — full vocabulary of 26 routines
- `audits/sre-2026-05-21/dashboards/audit-report.html` — the audit dashboard
- `~/.claude/skills/tenant-routine-author/SKILL.md` — the global skill that authored these specs
