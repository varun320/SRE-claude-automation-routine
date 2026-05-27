---
id: R2
name: Daily Setup (Top 3 + calendar + energy check)
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "0 12 * * 0-4"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365, filesystem]
ms365_scopes: [Calendars.Read, Files.Read.All]
output: webapp_queue + onedrive_markdown                # per D11
safety: read-only, no drafts, recommendation-only, ≤250 words
window: "today + tomorrow calendar; last 24h R4 output (when R4 ships)"
linked_audit_findings:
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-18"   # Day Clock mismatch — observed cadence ≠ plan
  - "audits/sre-2026-05-21/raw/calendar/calendar-2yr-aggregate.json"            # 24-month recurring meetings observed
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d9"   # cadence = observed reality, not plan
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10"  # confidentiality reframe
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"  # webapp + OneDrive output
---

# R2 — Daily Setup (Top 3 + calendar + energy check)

**Trigger:** Sun–Thu at 12:00 America/Edmonton, the 12:00 Daily Setup slot per Weekly OS §2.

**Goal:** Five-minute deep-work prep — proposes today's Top 3 tied to the day's theme (Mon=Sale, Tue=BD, Wed=Eng, Thu=Finance) and surfaces calendar conflicts so the 12:15–13:55 deep-work block opens with intent, not reaction. NO drafts. NO commitments to anyone but the operator.

**Why it matters:** Without this, deep work drifts into reactive work. "Hardest task tied to day's primary hat" from Weekly OS §2.

---

## Build prompt

> Today is [DAY]. The Weekly OS theme for [DAY] is [Mon=CEO/Strategic, Tue=CMO/BD, Wed=GM/Engineering, Thu=CFO/Finance + Bi-Weekly Job (10:00 MT), Fri=Jumua+Top-5+Reflection]. Read the latest Action Package and Task List in `/Users/maazwork/Documents/Claude/Projects/SRE General Manager/`. Read yesterday's Daily Close output if present at `Daily Logs/[yesterday].md`. Read today's Outlook calendar. Propose exactly 3 tasks for the 12:15–13:55 deep-work block, each tied to today's theme. For each: task title, expected output, time-box (max 1h40m total), the calendar slot, and the single biggest risk to finishing it. Output ≤ 250 words.
>
> **Cadence reality (per D9):** the observed standing meetings are: Thursday 10:00 MT Bi-Weekly Job Meeting, weekly Maaz ↔ Torstein 1:1, Monthly Pitstop. The original Day Clock plan is aspirational — note drift in the output's "Calendar conflicts" section but do not block on it.
>
> **Confidentiality (per D10):** never surface SRE DD folder content, Torstein 1:1 subjects, P&L content, or board-prep material in the Top-3 output. If today's theme would naturally pull from those (e.g. Monday strategic), reference them as "[confidential strategic item]" with no further detail.
>
> Use the ms365 MCP server for calendar (`get-calendar-view startDateTime=today 00:00 endDateTime=tomorrow 23:59`) — keep `$select` narrow: id, subject, start, end, isOnlineMeeting, location, organizer. Use filesystem read for the Action Package + Daily Logs. **Read-only — never call any ms365 tool whose name starts with create-, send-, update-, delete-, move-, accept-, decline-, reply-, forward-.**

---

## Output shape

A single short message:

> Top 3 for Mon (CEO/Strategic theme):
> 1. **Anwil NDA review** — output: signed-off NDA v3 sent to legal · 30 min · 12:20–12:50 slot · risk: legal team out today
> 2. **Q-Chem proposal follow-up draft** — output: response email skeleton ready for R3 to polish · 40 min · 12:55–13:35 · risk: missing Sanjay's last call notes
> 3. **[confidential strategic item]** — output: per Action Package · 20 min · 13:35–13:55 · risk: low
>
> Calendar conflicts: Aramco RTR pre-brief at 14:00 sits exactly on Zuhr — move or skip?
> Energy: 3rd ME night this week — consider Top 3 closer to 30/30/40 min split, not 40/40/30.

**Delivery (per D11):** webapp queue at `/queue/R2/{YYYY-MM-DD}.md` + OneDrive mirror at `OneDrive/SRE Routines/R2-daily-setup/{YYYY-MM-DD}.md`. Fallback during webapp build: Teams chat with self.

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 10k input, ≤ 1k output. Reads more files than R1, so slightly larger budget.
- **No write tools.** Build prompt forbids them; operator should confirm scoped role at /schedule registration.
- **Prayer/family windows:** 12:00 MT is before Zuhr (~14:00) and outside the 19:00–22:00 family block. Audited safe.
- **Day Clock fragility (audit OQ-18):** the routine's quality depends on operator keeping calendar honest. If observed calendar drifts from theme-day rule (as audit found), R2 output degrades — pilot must surface this.
- **Failure mode:** If filesystem or ms365 errors, route the failure notification per D11 fallback (Teams self-DM). Do NOT retry silently.

---

## Edge cases

- **Theme-day skip:** if today's calendar is dominated by a customer crisis (e.g., Aramco RTR urgent), the theme-day rule should be overridden. Output should flag this rather than force the theme.
- **Empty Action Package:** new month / first day of fiscal — fall back to ClickUp top items + last week's R8 Sunday brief.
- **First weekday after vacation:** the prior Daily Close may be 2+ weeks stale. Output should explicitly note "first day back — Top 3 are reset" rather than acting like a normal Sun-Thu.
- **Two-meeting Zuhr conflict (audit-found pattern):** some weeks have meetings at 14:00 — explicitly call out the prayer conflict.

---

## Run log

Per-fire output and metrics land in `logs/runs/R2-YYYY-MM-DD.md`. Capture:

- Wall-clock time
- Token usage (in / out)
- Connector calls made (count + names)
- Whether output respected "≤ 250 words"
- Whether the 3 proposed tasks tied to that day's theme (operator self-checks at next day's R4)

---

## Phase-1 exit criteria

- [ ] R2 fires on schedule without intervention
- [ ] Output matched constraints (3 tasks, ≤250 words, no drafts)
- [ ] Operator used the Top 3 (kept ≥2 of the 3 as-proposed) on ≥3 of first 5 fires
- [ ] No calendar-source-of-truth misalignment (operator confirms calendar reflects reality)
- [ ] Cost per run measured + projected total within budget
