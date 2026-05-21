# SRE Claude Routines — Implementation Plan

**Companion to:** `SRE Claude Routines - Execution Plan.md`
**Owner:** Maaz Ahmed Shareef
**Created:** 2026-05-11
**Goal:** Operationalize the 26-routine plan as scheduled Claude Code remote agents.

This document is the **HOW**. The Execution Plan is the **WHAT**.

---

## Guiding Principles

1. **Drafts only.** No routine sends, posts, or commits without human review. Outputs are Outlook drafts, file writes, or notifications.
2. **One routine = one scheduled agent.** Maps 1:1 to Claude Code's `/schedule` skill. No bundling.
3. **Cron in Calgary local time.** Match Weekly OS slots exactly. Never schedule inside prayer/family/sleep windows.
4. **Validate before scaling.** Every tier ships only after the prior tier survives one full cycle (week / month / quarter).
5. **Project files are the source of truth.** Routine prompts, outputs, and logs live in this repo so they can be versioned and improved.

---

## Repo Layout

```
routines-claude/
├── README.md
├── SRE Claude Routines - Execution Plan.md   # the WHAT
├── IMPLEMENTATION_PLAN.md                    # this file (the HOW)
├── routines/
│   ├── tier1/
│   │   ├── R1-na-inbox-scan.md               # full prompt + cron + connector list
│   │   ├── R2-daily-setup.md
│   │   ├── R3-na-inbox-triage.md
│   │   ├── R4-daily-close.md
│   │   ├── R5-me-inbox-scan.md
│   │   ├── R8-sunday-planning.md
│   │   ├── R12-ar-aging.md
│   │   ├── R13-weekly-review.md
│   │   └── R14-zaheer-update.md
│   ├── tier2/ ...
│   ├── tier3/ ...
│   └── tier4/ ...
├── connectors/
│   └── connector-check.md                    # smoke-test prompts per connector
├── logs/
│   ├── runs/                                 # per-routine run logs (timestamped)
│   ├── cost/                                 # weekly cost roll-ups
│   └── incidents/                            # failures, missed fires, manual fixes
└── playbooks/
    ├── add-routine.md                        # how to onboard a new routine
    ├── edit-routine.md                       # how to safely change a live routine
    └── kill-switch.md                        # how to pause/disable everything fast
```

---

## Phase 0 — Prerequisites (Day 1, ~30 min)

**Goal:** Confirm the environment can actually run scheduled remote agents that touch the listed connectors.

### Steps

1. **Confirm `/schedule` skill availability.** Run `/schedule list` in Claude Code. Should return either an empty list or any pre-existing schedules. If the command errors, escalate before proceeding.
2. **Inventory connectors.** Open Claude Code in this directory and verify the following are connected and authenticated for headless/remote use:
   - Outlook (mail + calendar + Teams chat)
   - ClickUp
   - Pocket
   - File system access to `Documents/Claude/Projects/SRE General Manager/`
3. **Verify the project tracker file path.** Confirm `Documents/Claude/Projects/SRE General Manager/SRE Project Tracker.xlsx` exists and is readable.
4. **Create the repo skeleton** (folders listed above). Empty placeholder files are fine.
5. **Create `connectors/connector-check.md`** with one short test prompt per connector (e.g., "List 3 most recent unread Outlook emails — subjects only").

### Exit criteria

- [x] `/schedule list` runs cleanly
- [x] All Tier 1 connectors authenticated
- [x] Repo folder structure committed
- [x] Connector smoke tests pass when run interactively

**Closed 2026-05-20.** M365 connection plan (`M365_Claude_Connection_Plan.docx`) executed through §8 — custom Entra app live, delegated Graph scopes admin-consented, MCP server pointed at the custom app, Claude connected, mail/calendar/Teams/OneDrive validated read+write.

### Rollback

Nothing live yet — abandon and re-plan if connectors require interactive auth that headless agents cannot satisfy.

---

## Phase 1 — Pilot: R1 Only (Day 2, ~1 hour)

**Goal:** Prove the full loop end-to-end with the lowest-stakes routine before fanning out. Validate cost per run.

### Steps

1. **Author `routines/tier1/R1-na-inbox-scan.md`.** Copy the build prompt verbatim from the Execution Plan. Add a header block:

   ```
   ---
   id: R1
   name: NA Inbox Scan
   cron: "55 11 * * 0-4"
   timezone: America/Edmonton
   tier: 1
   connectors: [outlook, teams]
   output: notification
   safety: read-only, subjects-only, no drafts
   ---
   ```

2. **Schedule it.** Use `/schedule` to create the cron entry. Point the agent at the prompt file.
3. **First-fire dry-run.** Either wait for the natural fire or trigger once manually via `/schedule run R1`.
4. **Log the run.** Save the output to `logs/runs/R1-YYYY-MM-DD.md`. Capture:
   - Wall-clock time
   - Token usage (in / out)
   - Connector calls made
   - Whether output respected the "subjects only, ≤200 words" constraint
5. **Cost extrapolation.** Multiply R1 cost × 26 routines × estimated weekly fires. If projected weekly cost is unacceptable, stop and re-scope before Phase 2.

### Exit criteria

- [ ] R1 fired on schedule without intervention
- [ ] Output matched the build prompt's constraints (no drafts, no over-reach)
- [ ] Cost per run measured and projected total within budget
- [ ] One full Sun–Thu cycle (5 fires) completed cleanly

### Rollback

`/schedule delete R1` and revisit prompt or connector setup.

---

## Phase 2 — Tier 1 Wave A: NA Day Cycle (Week 1)

**Goal:** Get the four NA-day routines running so the inbox windows + daily setup/close are self-staging.

**Routines:** R2, R3, R4 (R1 already live from Phase 1)

### Steps

1. **Author each routine file** under `routines/tier1/` using the same frontmatter pattern as R1.
2. **Schedule R2 first** (12:00 daily setup) — it depends on R1's earlier output but only as context, not a hard input. Confirm one fire works.
3. **Schedule R4 next** (15:50 daily close) — writes to `Daily Logs/`. Verify the file write actually lands and is well-formed Markdown.
4. **Schedule R3 last** (15:35 inbox triage) — this is the riskiest because it creates Outlook drafts. **Manual review of every draft for the first 5 fires before relying on it.**
5. **First Friday gut-check.** Read all five days of R4 daily log outputs. If they're noisy or wrong, fix prompts before adding more routines.

### Exit criteria

- [ ] All 4 NA routines fire on their scheduled days for one full week
- [ ] R3 drafts are usable without rewrite ≥ 80% of the time
- [ ] R4 daily logs accumulate cleanly in the right folder
- [ ] No routine fired into a prayer slot or family time

### Rollback

Per-routine `/schedule delete <id>`. Drafts in Outlook remain — review and discard manually.

---

## Phase 3 — Tier 1 Wave B: ME + Weekly Cycle (Week 2)

**Goal:** Add ME-side scan and the load-bearing weekly routines.

**Routines:** R5, R8, R13, R14

### Steps

1. **R5 (ME inbox scan, 21:55).** Author and schedule. Same shape as R1, different sender filter.
2. **R8 (Sunday weekly planning, Sun 16:00).** Schedule. Verify it has read access to prior week's R4 daily logs.
3. **R13 (Friday weekly review, Fri 15:30).** Schedule. **Critical:** verify it can read Project Tracker xlsx and aggregate Mon–Fri R4 logs.
4. **R14 (Friday Zaheer update, Fri 16:00).** Schedule **after** R13 has fired successfully at least once. R14's quality depends entirely on R13's output.
5. **First Friday end-to-end test.** Walk the chain: R4 logs accumulate Mon–Thu → R13 fires Fri 15:30 → R14 fires Fri 16:00 → manually review and send Zaheer message.

### Exit criteria

- [ ] R13 produces a Weekly Review usable as-is or with light edits
- [ ] R14 produces a WhatsApp-ready message in the exact format Zaheer expects
- [ ] Sunday planning brief surfaces real conflicts, not noise
- [ ] The Friday Zaheer message went out (manually) on time for two consecutive weeks

### Rollback

If R13/R14 quality is poor, keep R13 running (data still useful) and disable R14 until prompt is fixed.

---

## Phase 4 — Tier 1 Wave C: CFO Day (Week 3)

**Goal:** Close out Tier 1 with the AR + cash routine.

**Routines:** R12

### Steps

1. **Confirm Project Tracker AR column is current.** R12 is garbage-in-garbage-out without it.
2. **Author and schedule R12** (Thu 11:30).
3. **Manual review the first two fires.** AR drafts must not over-promise or misstate balances.
4. **Adjust the build prompt** if drafts consistently miss a follow-up rule (e.g., Q-Chem invoice format from Item 44).

### Exit criteria

- [ ] R12 produces an AR aging report that matches the manual one within ±5%
- [ ] Top-3 AR follow-up drafts land in Outlook drafts every Thursday
- [ ] Cash forecast line is directionally correct

**At end of Phase 4: all 8 Tier 1 routines live. Goal: Weeks 1–4 of the Execution Plan rollout complete.**

---

## Phase 5 — Tier 2: Theme-Day + ME Pre-Briefs (Weeks 4–6)

**Goal:** Add the routines that pre-stage day-themed deep work and bi-weekly AIMS calls.

**Routines:** R6, R7, R9, R10, R11, R15a–d, R17, R19, R20

### Build order (within Phase 5)

1. **R6 (ME block setup, daily 22:00)** — generalizes R5 with country focus
2. **R15a–d (AIMS country pre-briefs, bi-weekly)** — deeper version of R6 on call nights
3. **R7 (ME close + CRM logging, 01:30 next-day)** — closes the loop on ME calls
4. **R9, R10, R11 (Mon/Tue/Wed theme-day memos)** — one per week
5. **R19 (pre-meeting brief, event-triggered)** — requires calendar event title convention `[Client]/[AIMS]/[Buyer]`
6. **R17 (monthly compliance, 1st of month)** — schedule once, validate after first month
7. **R20 (manual email drafter)** — ad-hoc, no cron; document the trigger phrase

### Special notes

- **R7 needs Pocket and Zoom recording access** in remote mode. Smoke-test before scheduling.
- **R19 needs an event-trigger mechanism**, not pure cron. If `/schedule` doesn't support event triggers, use a daily 08:00 lookup that scans the next 24h of calendar.
- **R15 + R6 overlap on AIMS-call nights.** Run both — R15 is deeper, R6 is the lighter fallback.

### Exit criteria

- [ ] Each routine survives 2 full cycles (2 weeks for daily/weekly, 2 months for monthly)
- [ ] No double-fires or conflicts between R6 and R15
- [ ] Pre-meeting briefs (R19) have ≥ 70% useful-without-edit rate

---

## Phase 6 — Tier 3: Lower-Frequency (Month 2)

**Routines:** R16, R18, R21

### Steps

1. **R16 (monthly prayer calendar refresh, 1st 09:00).** Verify the prayer-time data source is reliable. Test the .ics regeneration manually first.
2. **R18 (lead triager, daily 14:00).** Schedule only after Sulfur Space + Squarespace API access is confirmed.
3. **R21 (contract reviewer, file-watch).** Manual or watch on `Documents/Claude/Inbox/Contracts/`. If watch isn't supported, use a daily 08:00 folder scan.

---

## Phase 7 — Tier 4: Quarterly (Month 3+)

**Routines:** R22, R23

### Steps

1. Schedule both during a calm week, well before the next quarterly fire date.
2. Document the quarterly cadence in a calendar reminder so a missed fire doesn't go unnoticed for 3 months.

---

## Phase 8 — Operations & Maintenance (Ongoing)

### Weekly maintenance ritual (Friday 17:00, 15 min)

1. Read `logs/runs/` — any failed fires? Any blank outputs?
2. Read `logs/cost/this-week.md` — within budget?
3. One routine per week gets a prompt-quality review. Rotate through all 26 over ~6 months.

### Monthly maintenance ritual (1st of month, 30 min)

1. Run `/schedule list` and confirm all expected routines are present.
2. Reconcile against `routines/` folder — any drift?
3. Review `logs/incidents/` — patterns? Recurring root cause?
4. Cost roll-up: total tokens × $/token, vs hours saved.

### Kill switch

`playbooks/kill-switch.md` documents how to disable all routines in under 60 seconds (single `/schedule pause --all` or per-routine loop). Test this twice a year.

---

## Safety Rules (Non-Negotiable)

| Rule | Enforcement |
|---|---|
| No routine sends external messages | Build prompts explicitly say "save as draft, do not send" |
| No routine fires during prayer slots | Cron schedules audited against `★` slots in Day Clock |
| No routine fires during family time (19:00–22:00) | Same audit |
| No routine modifies Project Tracker without dry-run | R11 outputs *suggestions*, not edits |
| No routine bypasses the Friday Zaheer review | R14 saves a draft, you copy-paste manually |
| Every routine logs its run | `logs/runs/<routine-id>-<date>.md` |
| Failed fires escalate to inbox | Notification on failure, not silent |

---

## Decision Log

Decisions made during build that future-you needs to remember. Append-only.

| Date | Decision | Why |
|---|---|---|
| 2026-05-11 | One routine = one schedule, no bundling | Easier debug, independent kill |
| 2026-05-11 | Drafts-only across all 26 routines | External comms keep human signature |

---

## Open Questions (resolve before Phase 1)

1. Does `/schedule` support event-based triggers (R19 needs this) or only cron? If cron-only, switch R19 to daily 08:00 24h-lookahead pattern.
2. Are remote agents authenticated for the same connector set as interactive sessions? Confirm in Phase 0.
3. What is the per-fire cost ceiling above which we re-scope? Suggest: $0.50/fire average, $5/day total.
4. Where do failure notifications land? Outlook inbox? Teams self-DM? Pick one before Phase 1.

---

## Success Criteria (End of Month 2)

- 18 routines running (all Tier 1 + Tier 2)
- ≥ 6 hours/week of pre-staged work that previously consumed deep-work blocks
- Zero routine-caused incidents (no wrong-recipient sends, no prayer-slot fires, no data loss)
- Friday Zaheer update goes out on time 8 weeks running
- Cost within agreed budget

---

*End of implementation plan. Pair with Execution Plan for full context.*
