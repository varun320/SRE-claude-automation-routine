---
id: R8
name: Sunday Weekly Planning Slot
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "0 16 * * 0"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365, filesystem]
ms365_scopes: [Mail.Read, Calendars.Read, Files.Read.All]
output: webapp_queue + onedrive_markdown                # per D11
safety: read-only, no drafts, recommendation-only, ≤400 words
window: "next 7 days calendar + last 7 days R4 logs (when R4 ships) + Action Package"
linked_audit_findings:
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-18"   # Day Clock mismatch (planned vs observed)
  - "audits/sre-2026-05-21/raw/tenant/mailbox-settings-maaz.json"               # working_hours + timezone
  - "audits/sre-2026-05-21/raw/calendar/calendar-2yr-aggregate.json"            # observed recurring meetings (Thu Bi-Weekly Job, Torstein 1:1)
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d7"   # all 10 shared mailboxes in weekly sweep
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d9"   # cadence = observed reality (Thu 10:00 Bi-Weekly, Maaz↔Torstein, Monthly Pitstop)
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10"  # confidentiality reframe
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"  # webapp + OneDrive output
---

# R8 — Sunday Weekly Planning Slot

**Trigger:** Every Sunday at 16:00 America/Edmonton — Maaz's explicit Sunday Weekly Planning slot per Weekly OS §2.

**Goal:** One read-only "Week of [next Mon]" planning brief. Surfaces inbox state, calendar conflicts against prayer/family/sleep anchors, Monday's Top 3 candidates, the thank-you-note rotation, and the week's #1 risk. NO drafts. NO sends.

**Why it matters:** Weekly OS §2 explicitly mandates a Sunday slot to set up the week. Without it, Monday gets reactive and the rest of the week drifts.

---

## Build prompt

> It's Sunday 16:00 America/Edmonton. Build my Week of [next Mon date] planning brief.
>
> Pull from:
> - **Outlook inbox state across all 10 active shared mailboxes (per D7) + Maaz's mailbox** — count unread by NA / ME split (NA = customers in Canada/US/EU outside Middle East; ME = AIMS + Aramco/ADNOC/Q-Chem/Petro-Rabigh/KNPC/SATORP/Qatar Energy/JIGPC/BSE/BAPCO/Mellitah/Orlen). Per mailbox: oldest unactioned thread (subject + sender + age in days). Mailboxes in scope: `maaz@`, `info@`, `info-me@`, `ar@`, `ap@`, `sales@`, `careers@`, `apple@`, `HusamsBookingPageSRE@`, `boardroom@`. Disabled scanner mailbox excluded.
> - **Outlook calendar next 7 days** — list every meeting with attendees. Flag any meeting whose start/end crosses: Zuhr (~14:00), Asr (~19:00), Maghrib (~21:00), Isha (~22:15), Friday Jumua (14:00–15:30), or family time (17:00–22:00). Flag any meeting > 90 min that doesn't have an explicit break. Cross-check against observed standing cadence (per D9): Thursday 10:00 MT Bi-Weekly Job, weekly Maaz ↔ Torstein 1:1, Monthly Pitstop.
> - **Project Tracker** + **Action Package** at `/Users/maazwork/Documents/Claude/Projects/SRE General Manager/` — propose Monday's Top 3 candidates tied to CEO/Strategic theme (Monday = strategic deep-work day).
> - **Prior week's R4 daily logs** at `Daily Logs/[Mon-Fri].md` (when R4 ships) — surface anything that slipped Mon→Fri last week that needs to land this week.
> - **Thank-you note rotation** — pick exactly one person from this week's interactions whom Maaz should thank in writing. Rotate through: a client, a partner, a teammate. Track the rotation across weeks (Sun N picked client → Sun N+1 pick partner → Sun N+2 pick teammate → repeat).
>
> Output a single brief in this structure:
> 1. **Inbox state** (1 line: "NA = X unread / oldest Y days · ME = X unread / oldest Y days")
> 2. **Calendar conflicts** (bulleted — meeting + conflict + suggested move)
> 3. **Monday Top 3 candidates** (3 items: task / expected output / which 12:15–13:55 slot block)
> 4. **Thank-you note** (one named person + one-line reason)
> 5. **This week's #1 risk** (one sentence)
>
> Total ≤ 400 words.
>
> Use ms365 MCP for inbox + calendar. **Read-only — never call any tool starting with create-, send-, update-, delete-, move-, accept-, decline-, reply-, forward-, set-, pin-.**

---

## Output shape

> **Week of Mon 2026-05-25 — planning brief**
>
> 📥 Inbox: NA = 47 unread / oldest 6 days (CSV Midstream RFQ) · ME = 31 unread / oldest 3 days (Naveed re Petro-Rabigh)
>
> ⚠️ Calendar conflicts:
> - Tue 14:00 "ADNOC Amine Expert" crosses Zuhr → move to 14:30
> - Thu 17:30 "Bi-Weekly Job Meeting overflow" runs into family time → cap at 17:00
> - Fri 14:00 "INERCO follow-up" crosses Jumua → reschedule
>
> 🎯 Monday Top 3 (CEO/Strategic):
> 1. Anwil NDA v3 review — output: signed-off draft to legal · 12:20–12:50
> 2. [confidential strategic item] · 12:55–13:35
> 3. Q-Chem follow-up to Sanjay Bhatt · 13:35–13:55
>
> 🙏 Thank-you note: **Bader Ansari (AIMS)** — for closing Q-Chem proposal review at speed
>
> ⚠️ #1 risk: **Aramco RTR May-31 review prep** — Dharmesh out Tue-Wed; backfill engineering scope before then.

**Delivery (per D11):** webapp queue at `/queue/R8/{YYYY-MM-DD}.md` + OneDrive mirror at `OneDrive/SRE Routines/R8-sunday-planning/{YYYY-MM-DD}.md`. Fallback during webapp build: Teams chat with self.

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 15k input, ≤ 1.5k output. R8 reads more than other Tier 1 routines (7-day calendar + prior R4 logs + Action Package).
- **No write tools.** Build prompt forbids; output is a notification, not a document write.
- **Prayer/family windows:** Sunday 16:00 MT is between Asr (~19:00) and start of family time (17:00). Buffer is tight — verify cron lands cleanly on first fire. If it drifts to 16:55, that's still before 17:00.
- **Sunday prayers/Jumua note:** Sunday has no Jumua (that's Friday). 16:00 Sunday is genuinely free.
- **Day Clock fragility (audit OQ-18):** the audit found planned standing meetings don't match observed calendar. R8 relies on calendar being honest. Pilot will surface drift.
- **R4 dependency (when R4 ships):** R8 expects prior week's Daily Logs at `Daily Logs/[date].md`. If R4 hasn't shipped yet, R8 must gracefully degrade — skip the "what slipped last week" section rather than fabricate.
- **Thank-you rotation state:** rotation must be tracked across weeks. Store rotation state in `routines/state/R8-thanks-rotation.json` (created on first fire). If state is missing, default to "client" for week 1.
- **Failure mode:** If ms365 or filesystem errors, escalate per Phase 0 OQ #4. Do NOT retry silently.

---

## Edge cases

- **Long holiday weeks (Eid, Christmas, Canadian Thanksgiving):** the brief should be shorter and flag "holiday week — short cadence" instead of treating it as normal.
- **First Sunday of fiscal month:** Action Package usually rotates monthly — confirm the routine reads the *current month's* Action Package.
- **No R4 history available:** for the first 2-3 weeks of pilot before R4 ships, the "what slipped last week" section is empty — annotate "R4 not yet shipped" rather than fabricate slippage.
- **Confidentiality redaction (per D10):** if Monday's Top 3 references Torstein 1:1, SRE DD folder content, P&L, or board-prep material, the output must replace the subject with `[confidential strategic item]` and surface only the time block — never the topic. Output always goes to operator-private channel (webapp queue + OneDrive), never a Teams team channel.
- **Calendar-conflict false positives:** a "Pre-Meet" meeting at 13:30 isn't a conflict with Zuhr 14:00 — it just ends before. Don't flag.
- **AIMS-call nights:** Sun–Wed 22:00 has bi-weekly AIMS country calls. The brief should note which country's call is *next* week so Maaz can pre-block the prep.

---

## Run log

`logs/runs/R8-YYYY-MM-DD.md`. Capture:

- Wall-clock time
- Token usage (in / out)
- Connector calls made
- Whether output respected ≤400 words
- Operator's Monday acceptance — at next Monday's R2, did the Top 3 carry over? Track in-week.
- Calendar conflict accuracy — were any flagged conflicts spurious?

---

## Phase-1 exit criteria

- [ ] R8 fires Sunday 16:00 without intervention
- [ ] Output ≤ 400 words and includes all 5 sections
- [ ] No calendar conflict flagged that wasn't a real conflict (≥80% precision)
- [ ] Monday's R2 (when shipped) carries forward ≥1 Top-3 item from R8 in ≥3 of first 4 Sundays
- [ ] Thank-you rotation state persists across weeks
- [ ] Cost per run within budget (single weekly fire — cheaper than daily routines)
