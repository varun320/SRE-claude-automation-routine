# SRE Claude Routines — Execution Plan
**Owner:** Maaz Ahmed Shareef | President / CEO / GM, Sulfur Recovery Engineering Inc.
**Generated:** Thu, April 30, 2026
**Anchored to:** SRE Weekly Operating System (Calgary MT, prayer + sleep aware)
**Scope:** SRE only. Other businesses (Shaghf, Mechways, etc.) deferred to a separate plan.

> **⚠️ DECISION OVERRIDE 2026-05-26:** The SRE sale process has ended. Wherever this plan says "sale process", "sale-process buyer", or "Sale-Process Memo" (R9), reframe as **"Sensitive corporate / financial / HR / board material — never surface in any output."** R9's purpose remains valid (weekly written memo of the highest-stakes file) but its topic shifts to whatever IS the highest-stakes file at the time — no longer assumed to be the sale. See [`docs/decisions/2026-05-26-maaz-phase1-decisions.md`](docs/decisions/2026-05-26-maaz-phase1-decisions.md) sections D9 and D10 for the authoritative reframe and cadence reality (Thu 10:00 Bi-Weekly Job, weekly Maaz↔Torstein 1:1, Monthly Pitstop).

---

## How to Read This Plan

Each routine below has:
- **Tier** — recommended rollout order (T1 = build first)
- **Trigger** — cron schedule in Calgary local time (matches your Weekly OS slots)
- **What it does** — a 1-line description
- **Inputs** — the connectors/data it pulls from (Outlook, Teams, Calendar, Pocket, ClickUp, Files)
- **Output** — the deliverable (briefing, draft, checklist, alert)
- **Why it matters** — the operating-system rule it enforces
- **Build prompt** — the instruction Claude will execute on each run

Routines run autonomously on schedule and surface a notification when done. You review the output, take action, and the cycle repeats.

---

## Connector Reality Check (what's already wired)

Before I build anything, here's what I see connected based on tools available in this session — these are the data sources your routines will pull from:

| System | Available | Use For |
|---|---|---|
| Outlook (email + calendar + chat) | ✅ | Inbox triage, meeting prep, AR follow-ups |
| Microsoft Teams | ✅ via Outlook chat search | Ron/Ashley/AIMS internal threads |
| Gmail | ✅ | Personal/secondary email |
| Google Calendar | ✅ | Cross-calendar conflict checks |
| ClickUp | ✅ | Task/project tracking, jobs tracker |
| Pocket (meeting AI) | ✅ | Action items from past calls |
| Zoom | ✅ | Call recordings + transcripts |
| Apple Notes / iMessages | ✅ | Personal capture |
| Files (Documents/Claude) | ✅ | Project Tracker, Weekly OS, Action Packages |
| SharePoint | ✅ | Shared docs |

**Not yet connected (worth adding):** dedicated CRM, Outlook contacts API for direct WhatsApp generation, banking feed for live cash position. These don't block the Tier 1 routines.

---

## The Day Clock (chronological routine map)

This is what your SRE day looks like with routines layered on top. Times are Calgary local. Anchors marked **★** are immovable (prayers, sleep, Jumua).

```
05:20 ★ Fajr
08:00     Personal
09:00     [Other businesses block — out of scope here]
11:55  R1 NA INBOX SCAN (subjects only)              ← T1
12:00  R2 DAILY SETUP — Top 3 + calendar             ← T1
12:15     SRE Deep Work #1
14:00 ★ Zuhr
14:05     NA Meetings (Mon Ashley / Tue Sales 1:1 / Wed Eng / Thu Bookkeeper / Fri Top-5)
14:00     [Day-themed pre-meeting brief auto-fires 30 min before each meeting]   ← T2
15:35  R3 NA INBOX TRIAGE TO ZERO + draft replies   ← T1
15:50  R4 DAILY CLOSE — risk register + tomorrow's top-3   ← T1
17:00     Family
19:00 ★ Asr
21:00 ★ Maghrib
21:55  R5 ME INBOX SCAN (subjects only)              ← T1
22:00  R6 ME SETUP — country focus tonight           ← T2
22:15 ★ Isha
22:20     ME Deep Work
23:30     ME Live Calls (AIMS bi-weekly slots at 00:00)
01:30  R7 ME CLOSE + CRM logging                    ← T2
02:00     Sleep
```

**Weekly overlay (every week, on top of the day clock):**

```
SUN 16:00  R8  WEEKLY PLANNING SLOT — top 3 for Mon, thank-you note   ← T1
MON 11:30  R9  SALE-PROCESS MEMO — buyer Q&A + data room status        ← T2
TUE 11:30  R10 PIPELINE HYGIENE — stale deals, missing close dates     ← T2
WED 13:30  R11 PROJECT TRACKER REFRESH PROMPT — RAG + % complete       ← T2
THU 11:30  R12 AR AGING + CASH FORECAST                                ← T1
FRI 15:30  R13 WEEKLY REVIEW BUILDER — KPIs across all axes            ← T1
FRI 16:00  R14 ZAHEER WHATSAPP UPDATE DRAFTER                          ← T1
```

**Bi-weekly overlay (AIMS country reviews):**

```
SUN 22:00  R15a AIMS KSA + Kuwait pre-brief (call at Mon 00:00)        ← T2
MON 22:00  R15b AIMS Oman pre-brief (call at Tue 00:00)                ← T2
TUE 22:00  R15c AIMS UAE pre-brief (call at Wed 00:00)                 ← T2
WED 22:00  R15d AIMS Qatar pre-brief (call at Thu 00:00)               ← T2
```

**Monthly + episodic:**

```
1st of month  09:00  R16 PRAYER CALENDAR REFRESH (Calgary)             ← T3
1st of month  10:00  R17 MONTHLY COMPLIANCE PULSE (Mushtaryat, K-Tend) ← T2
Daily 14:00          R18 LEAD/INQUIRY TRIAGER (Squarespace + cold)     ← T3
Ad-hoc               R19 PRE-MEETING BRIEF (24h before any client call)← T1
Ad-hoc               R20 EMAIL REPLY DRAFTER (manual trigger)          ← T2
Ad-hoc               R21 CONTRACT/RFQ FIRST-PASS REVIEWER              ← T3
Quarterly            R22 ARAMCO HQ TOUCHPOINT GENERATOR                ← T4
Quarterly            R23 SRE × AIMS FRAMEWORK REVIEW                   ← T4
```

---

# TIER 1 — BUILD FIRST (8 routines)

These directly enforce the four hard rules from your Weekly OS: inbox windows, daily top-3, weekly review, and the Friday Zaheer update. They are the load-bearing routines.

---

## R1 — NA Inbox Scan (subjects only)

- **Trigger:** Cron `55 11 * * 0-4` (Sun–Thu, 11:55 MT)
- **What it does:** 5-minute scan of unread Outlook + Teams. Returns subject lines grouped by urgency (red/amber/green) so you walk into 12:00 setup already knowing the shape of the day. NO drafting, NO replies.
- **Inputs:** Outlook inbox (last 18h), Teams DMs (last 18h)
- **Output:** Single short message — "8 new since 21:55 ME triage. 2 RED (CSV bid Q from Caleb, Aramco RTR scheduling). 3 AMBER (Petro Rabigh, Anwil NDA, Q-Chem invoice). 3 GREEN."
- **Why it matters:** Enforces the "subjects only" discipline — prevents you from getting sucked into the inbox before deep work.
- **Build prompt:**
  > Scan my Outlook inbox and Teams DMs received since 21:55 yesterday. Group senders/subjects into RED (decision needed today), AMBER (response needed this week), GREEN (FYI). Return only sender + subject + 5-word context per item. No drafting, no full reads, no recommendations. Maximum 200 words total.

---

## R2 — Daily Setup (Top 3 + calendar + energy check)

- **Trigger:** Cron `0 12 * * 0-4` (Sun–Thu, 12:00 MT)
- **What it does:** Pulls today's calendar, the unfinished items from yesterday's Daily Close, and proposes today's Top 3 based on the day's theme (Mon=Sale, Tue=BD, Wed=Eng, Thu=Finance, Fri=Top-5+Reflection).
- **Inputs:** Outlook calendar (today + tomorrow), yesterday's Daily Close output, current week's Action Package (`Documents/Claude/Projects/SRE General Manager/`)
- **Output:** A concrete 3-item list with: task, expected output, time-box, and which calendar slot to do it in.
- **Why it matters:** "Hardest task tied to day's primary hat" rule from Weekly OS §2. Without this, deep work drifts into reactive work.
- **Build prompt:**
  > Today is [DAY]. The Weekly OS theme for [DAY] is [Mon=CEO/Sale, Tue=CMO/BD, Wed=GM/Engineering, Thu=CFO/Finance, Fri=Jumua+Top-5+Reflection]. Read the latest Action Package and Task List in /Users/maazwork/Documents/Claude/Projects/SRE General Manager/. Read yesterday's Daily Close output if present. Read today's Outlook calendar. Propose exactly 3 tasks for the 12:15–13:55 deep-work block, each tied to today's theme. For each: task title, expected output, time-box (max 1h40m total), the calendar slot, and the single biggest risk to finishing it. Output ≤ 250 words.

---

## R3 — NA Inbox Triage to Zero + Draft Replies

- **Trigger:** Cron `35 15 * * 0-4` (Sun–Thu, 15:35 MT)
- **What it does:** Reads every unread email/Teams message since the 11:55 scan. For each, decides: archive / forward / reply now / schedule. Drafts the reply replies (Outlook drafts) for items needing your review. Surfaces the 3 you must read yourself.
- **Inputs:** Outlook inbox + Teams DMs (since 11:55 today), Action Package context
- **Output:** Inbox-zero report — "Triaged 14 items. 6 archived. 4 forwarded to Ashley/Talha. 3 drafts saved (review before send). 1 needs you to handle directly: [link]."
- **Why it matters:** Email is closed outside the four windows. Without a triage routine the 15:35 slot expands into 16:30 and eats family time.
- **Build prompt:**
  > Search Outlook + Teams DMs received between 11:55 today and now. For each message: classify as ARCHIVE / FORWARD / REPLY / SCHEDULE. For FORWARDs, identify the right person from this directory: Ashley=admin/HR/bank, Talha=ME technical/conferences, Dharmesh=engineering, Utsav=technical writing, Inshan=Qatar/Kuwait compliance, Ron=BD/clients. For REPLYs, draft a reply (≤ 150 words, professional, signed Maaz) and save as Outlook draft. Do NOT send anything. Surface the items needing my direct read. Respect copyright — never quote large chunks of any email back to me.

---

## R4 — Daily Close (risk register + tomorrow's top-3)

- **Trigger:** Cron `50 15 * * 0-4` (Sun–Thu, 15:50 MT)
- **What it does:** Captures today's deltas (what shipped, what slipped, decisions made), updates the risk register, and pre-stages tomorrow's Top 3. Saves to a daily journal file in `Documents/Claude/Projects/SRE General Manager/Daily Logs/`.
- **Inputs:** Today's calendar (what actually ran vs. what was planned), today's R3 triage output, ClickUp project tracker
- **Output:** A short daily log entry + tomorrow's Top 3 candidate list (R2 will refine at 12:00).
- **Why it matters:** "No drift, no slippage, no blind spots" from Weekly OS §1. Without daily close, items rot in your head and re-surface as fires.
- **Build prompt:**
  > Today is [DATE]. Look at: today's calendar (events that ran), R3 triage output, ClickUp tasks I touched today. Generate a daily log with sections: SHIPPED (3-5 bullets), SLIPPED (with reason + recovery action), DECISIONS MADE (1-line each), RISKS (any new amber/red), TOMORROW'S TOP 3 (candidates only). Append to /Users/maazwork/Documents/Claude/Projects/SRE General Manager/Daily Logs/[YYYY-MM-DD].md. Total ≤ 300 words.

---

## R5 — ME Inbox Scan (subjects only)

- **Trigger:** Cron `55 21 * * 0-4` (Sun–Thu, 21:55 MT)
- **What it does:** Same shape as R1 but for ME-relevant traffic. Filters to senders matching AIMS / Aramco / KNPC / Petro Rabigh / Q-Chem / Mellitah / Anwil / Kanoo / Baker Hughes / SATORP / ADNOC.
- **Inputs:** Outlook inbox + Teams DMs (since 15:35 NA triage), filtered by ME-domain senders
- **Output:** Subject + sender list, 3-tier urgency.
- **Why it matters:** ME deep work starts at 22:20. You should not learn about a 22:20 surprise at 22:20.
- **Build prompt:**
  > Scan Outlook + Teams since 15:35 today, filter to senders/topics involving: AIMS (Shameem, Naveed, Zaheer Juddy, Ali, Aslam, Fazal, Majid), Aramco, KNPC, Petro Rabigh, Q-Chem, QE-LNG, Mellitah/Dolphin, ADNOC/Habshan, Anwil/Orlen, Kanoo, Baker Hughes (Libya), SATORP, Oryx GTL. RED/AMBER/GREEN classification. Subjects only. ≤ 200 words.

---

## R8 — Sunday Weekly Planning Slot

- **Trigger:** Cron `0 16 * * 0` (Sunday 16:00 MT)
- **What it does:** Compiles inbox-to-zero status across NA + ME, scans the calendar for the upcoming week's commitments, surfaces conflicts with prayer/sleep anchors, drafts Monday's Top 3, and reminds you to send a thank-you note (the system requires one weekly).
- **Inputs:** Outlook inbox state, Outlook calendar (next 7 days), Project Tracker, Action Package, prior week's Friday review
- **Output:** "Week of [date]" planning brief — Monday Top 3, calendar conflicts, who needs a thank-you note (rotate through: a client, a partner, a teammate).
- **Why it matters:** Weekly OS §2 explicitly mandates this slot.
- **Build prompt:**
  > It's Sunday 16:00. Build my Week of [next Mon date] planning brief: (1) Inbox state — count by NA/ME, oldest unactioned. (2) Calendar conflicts next week — any meeting crossing prayer slots (14:00 Zuhr, 19:00 Asr, 21:00 Maghrib, 22:15 Isha) or family time (19:00–22:00) or Friday 14:00–15:30 Jumua. (3) Monday's Top 3 candidates tied to CEO/Sale-Process theme. (4) Thank-you-note suggestion — pick one person from this week's interactions I should thank in writing (rotate client/partner/teammate). (5) One sentence: this week's #1 risk. ≤ 400 words.

---

## R12 — Thursday AR Aging + Cash Forecast

- **Trigger:** Cron `30 11 * * 4` (Thursday 11:30 MT, before 12:00 setup)
- **What it does:** Reviews AR aging (Project Tracker xlsx + Outlook search for invoice threads), flags >60 day and >90 day items, drafts AR follow-up emails for the 14:35 Thursday slot.
- **Inputs:** SRE Project Tracker, Outlook (invoice keyword + AP team threads), Q-Chem invoice rules (Item 44 from April Action Package)
- **Output:** AR dashboard + 2-3 ready-to-send AR follow-up drafts, split NA / ME.
- **Why it matters:** Thursday is CFO day. The Weekly OS says "AR aging line by line, AP scheduled, cash forecast, margin review" — this routine pre-stages it.
- **Build prompt:**
  > Read SRE Project Tracker xlsx (AR Outstanding column). Search Outlook for invoice/payment/AP threads in the last 30 days. Build an AR aging report split by NA / ME: count + $ at 0-30, 31-60, 61-90, 90+. List the top 5 oldest open invoices with client, amount, days outstanding, last touch date. For each of the top 3, draft a polite follow-up email (saved as Outlook draft, not sent). Include a one-line cash forecast: bank balance trend, next 30 days expected receipts, next 30 days committed AP. ≤ 500 words.

---

## R13 — Friday Weekly Review Builder

- **Trigger:** Cron `30 15 * * 5` (Friday 15:30 MT)
- **What it does:** Compiles the 9 weekly KPIs from Weekly OS §7 — sale process, NA pipeline, ME pipeline, cash, delivery, team, personal touches, sleep, prayers — pulled from the Project Tracker, calendar, and your prior week's daily logs.
- **Inputs:** Project Tracker, Outlook calendar (last 7 days), Daily Logs from R4, prior week's Zaheer update
- **Output:** Single 1-page weekly review document, saved to `Daily Logs/Weekly Review [date].md`. This becomes the input to R14 (Zaheer WhatsApp).
- **Why it matters:** "If you miss the Friday weekly review → next week's #1 task is fix the system" — Weekly OS §8.
- **Build prompt:**
  > Build the SRE Weekly Review for week ending [Friday date]. Pull from: Project Tracker (active count, RAG, AR), Daily Logs Mon-Fri (R4 outputs), calendar (NA top-client touches, ME top-client touches, deep work blocks count). Produce KPIs in the Weekly OS §7 format: (1) Sale process — stage, open buyer asks, days since last buyer contact. (2) NA pipeline — $ open / won / lost. (3) ME pipeline — same. (4) Cash — bank, AR>60, AR>90 split NA/ME. (5) Delivery — # active, # red, # complaints. (6) Team — # blockers cleared, # at capacity. (7) Personal — # NA top-client touches (target 10), # ME top-client touches (target 5), # deep work blocks (target 15). (8) Sleep — # nights ≥5:30hrs (best estimate from late-night calendar activity). (9) Prayers on time — leave blank for me to fill. End with: this week's #1 win, this week's #1 risk into next week, next week's #1 task. Save to Daily Logs/Weekly Review [date].md. ≤ 600 words.

---

## R14 — Friday Zaheer WhatsApp Update Drafter

- **Trigger:** Cron `0 16 * * 5` (Friday 16:00 MT, immediately after R13)
- **What it does:** Takes the R13 weekly review and converts it into the structured WhatsApp message format Zaheer expects: sale-process status, pipeline delta, cash/AR snapshot, delivery flags, top risk, top win. Short. Structured.
- **Inputs:** R13 output, Weekly OS §11 list of open flags
- **Output:** A WhatsApp-ready message (markdown, ≤ 250 words, copy-paste into WhatsApp). Saved to `Daily Logs/Zaheer Update [date].md`.
- **Why it matters:** This is your single most important external communication of the week. Zaheer is Group CEO / Shareholder. The format must be consistent.
- **Build prompt:**
  > Read this week's Weekly Review (R13 output). Convert it into a WhatsApp message to Zaheer Juddy (Group CEO / Shareholder) using exactly this structure: 🔵 SALE PROCESS — 1 line. 🟢 PIPELINE — NA $ delta + ME $ delta + 1-line on biggest pursuit. 💰 CASH/AR — bank, AR>60 split NA/ME, 1-line action. 🚧 DELIVERY — # active / # red / 1-line on the red ones. ⚠️ TOP RISK — 1 line. 🏆 TOP WIN — 1 line. ❓ ASK FROM YOU — if any (else "None"). Total ≤ 250 words. Use single-line spacing. No markdown headers — emoji bullets only (renders cleanly in WhatsApp). Save to Daily Logs/Zaheer Update [date].md.

---

# TIER 2 — BUILD SECOND (10 routines)

These either pre-stage day-themed deep work, run bi-weekly, or trigger on event (meeting in calendar, lead inbound). Build after T1 stabilizes.

---

## R6 — ME Block Setup (country focus tonight)

- **Trigger:** Cron `0 22 * * 0-4` (Sun–Thu, 22:00 MT)
- **What it does:** Identifies which AIMS country has the bi-weekly call tonight (Sun→KSA+Kuwait, Mon→Oman, Tue→UAE, Wed→Qatar, Thu→none). Pulls last call's action items from Pocket, recent emails from that country's contacts, and outstanding deliverables.
- **Inputs:** Outlook calendar (next 4h), Pocket (last AIMS call recording for that country), Outlook (country-tagged senders, last 14 days)
- **Output:** 1-page country brief: open items from last call, top 3 things to raise tonight, any client-specific deliverables due.
- **Why it matters:** Bi-weekly cadence means a 2-week gap. Without a brief, you walk in cold.

---

## R7 — ME Close + CRM Logging

- **Trigger:** Cron `30 1 * * 1-5` (Mon–Fri 01:30 MT — *next* day after each ME night)
- **What it does:** Reviews the ME night's call recordings (Pocket/Zoom), extracts action items, drafts ClickUp/CRM updates, sends pre-bed reply drafts where promised on call.
- **Inputs:** Pocket recordings (last 4h), Zoom recordings (last 4h), Teams DMs to AIMS contacts
- **Output:** ClickUp task draft list + Outlook draft replies for review tomorrow.
- **Why it matters:** ME accounts forget who's accountable when there's a 24h+ logging gap. Closes the loop same-night.

---

## R9 — Monday Sale-Process Memo

- **Trigger:** Cron `30 11 * * 1` (Monday 11:30 MT)
- **What it does:** Pulls buyer Q&A status, data room access logs (if available), days-since-buyer-contact, IM (information memorandum) revision status. Drafts the weekly status memo to self.
- **Inputs:** Outlook (buyer / advisor threads), data room logs (manual upload if needed), prior week's memo
- **Output:** "Sale Process Status — Week of [date]" memo, ≤ 1 page.
- **Why it matters:** "Written thinking. Memos, not slides" — Weekly OS §10. Sale process is the highest-stakes file you're carrying.

---

## R10 — Tuesday Pipeline Hygiene

- **Trigger:** Cron `30 11 * * 2` (Tuesday 11:30 MT)
- **What it does:** Audits the pipeline (Project Tracker + ClickUp): flags deals with stale close dates, single-threaded relationships, missing next-step, > 21 days since last touch.
- **Inputs:** Project Tracker, ClickUp, Outlook (last touch per contact)
- **Output:** Hygiene report — 5-10 deals needing attention, with the specific hygiene flag, ranked by deal value.
- **Why it matters:** Tue is BD day. Without hygiene, the pipeline lies to you on Friday's Weekly Review.

---

## R11 — Wednesday Project Tracker Refresh Prompt

- **Trigger:** Cron `30 13 * * 3` (Wednesday 13:30 MT, just before Eng standup at 14:05)
- **What it does:** Pre-populates a draft refresh of the Project Tracker for the Eng standup: % complete deltas (from ClickUp), RAG suggestions based on last call notes (Pocket), next milestones due, hours-budget pressure flags.
- **Inputs:** Project Tracker xlsx, ClickUp tasks, Pocket call notes by project
- **Output:** A pre-filled "suggested updates" block the project leads can validate at standup, instead of recreating from scratch.
- **Why it matters:** "Decisions, not status" — Item 31 of April action package. This routine pulls the status work *out* of the meeting.

---

## R15a-d — AIMS Country Pre-Brief (bi-weekly × 4 countries)

- **Triggers:**
  - **R15a (KSA + Kuwait):** Sun 22:00 MT, every other week — call at Mon 00:00
  - **R15b (Oman):** Mon 22:00 MT, every other week — call at Tue 00:00
  - **R15c (UAE):** Tue 22:00 MT, every other week — call at Wed 00:00
  - **R15d (Qatar):** Wed 22:00 MT, every other week — call at Thu 00:00
- **What it does:** For the country whose call is tonight, pulls last 14 days of email/Teams traffic, prior call's action items (Pocket), open deliverables, current pipeline value.
- **Inputs:** Outlook (country-tagged senders), Pocket (last call), Project Tracker (country filter)
- **Output:** 1-page brief: status, open items, your asks for tonight.
- **Why it matters:** R6 is the daily 22:00 setup — these are the *deeper* prep that fires earlier when there's an actual AIMS call.

> Note: R6 and R15 overlap on AIMS-call nights. R15 is the deeper pre-brief; R6 stays as the lighter every-night version. Run both — R15 is more thorough.

---

## R17 — Monthly Compliance Pulse

- **Trigger:** Cron `0 10 1 * *` (1st of month 10:00 MT)
- **What it does:** Checks status of all in-flight compliance items: Qatar Mushtaryat (Item 43), K-Tendering Kuwait (Item 45), Q-Chem invoice format (Item 44), Aramco vendor packs, Azure subscription renewals, audit confirmations.
- **Inputs:** Outlook (compliance senders), Inshan's last update, IT support threads
- **Output:** Compliance status board — green/amber/red per registration, with the specific blocker for any amber/red.
- **Why it matters:** Compliance lapses block tendering. Item 43 alone blocks 2 other tenders.

---

## R19 — Pre-Meeting Brief (event-triggered)

- **Trigger:** Event-based — fires 24h before any calendar event tagged `[Client]`, `[AIMS]`, or `[Buyer]` in the title
- **What it does:** Pulls everything you have on the meeting: prior call notes (Pocket), recent emails with attendees, open deliverables to/from them, any open commitments. Drafts an agenda if none exists.
- **Inputs:** Outlook calendar, Outlook email history with attendees, Pocket (prior calls), ClickUp (open items)
- **Output:** 1-page brief in `Daily Logs/Pre-Meeting Briefs/[meeting].md`.
- **Why it matters:** "Pre-mortems before every commitment" — Weekly OS §10.

---

## R20 — Email Reply Drafter (manual trigger)

- **Trigger:** Ad-hoc — you hit the routine and pass it a thread ID or paste content
- **What it does:** Drafts a reply that matches your voice (trained from prior sent items), respects the action package's existing positioning, and flags any commitment-language ("we will...", dates, dollars) for you to verify.
- **Inputs:** The target email thread, your sent-items voice corpus, Action Package position notes
- **Output:** A draft saved to Outlook drafts.
- **Why it matters:** R3 handles inbox-window drafting. R20 is for the off-window emergency where Ron pings you mid-Asr and you need a reply at 19:30.

---

# TIER 3 — BUILD THIRD (5 routines)

Lower-frequency or lower-stakes than T1/T2. Build once T1+T2 are running smoothly.

---

## R16 — Monthly Prayer Calendar Refresh

- **Trigger:** Cron `0 9 1 * *` (1st of month 09:00 MT)
- **What it does:** Pulls Calgary Fajr/Zuhr/Asr/Maghrib/Isha times for the new month, updates the Weekly OS prayer block, regenerates the .ics calendar file with new prayer slots.
- **Inputs:** Calgary prayer-time data (web), Weekly OS markdown, .ics file
- **Output:** Updated Weekly OS + new .ics import file. Notification: "Re-import the calendar — prayer times shifted by ~X minutes."
- **Why it matters:** Weekly OS §9 — schedule must be re-calibrated each month or it drifts.

---

## R18 — Lead/Inquiry Triager

- **Trigger:** Cron `0 14 * * 0-4` (Sun–Thu 14:00 MT — runs during Zuhr break)
- **What it does:** Triages incoming Squarespace forms, cold inbound emails, Sulfur Space new members. Classifies as: qualified discovery / nurture / decline / spam.
- **Inputs:** Outlook (forms@ + cold inbound senders), Sulfur Space new-member feed
- **Output:** Triaged list with recommended action per item; auto-drafts the "tell me more" reply for the qualified ones.
- **Why it matters:** Items 26, 27, 40 of the April action package — these triage decisions are formulaic and don't need a human until the qualification call.

---

## R21 — Contract / RFQ First-Pass Reviewer

- **Trigger:** Manual or file-watch on `Documents/Claude/Inbox/Contracts/`
- **What it does:** When an NDA / MSA / RFQ lands, runs the legal:triage-nda or legal:review-contract skill against it, surfaces deviations from your standard positions (Alberta law, mutual, 3-year, no assignment).
- **Inputs:** The contract PDF/docx, your standard positions playbook
- **Output:** Triage classification + redline summary + draft response email.
- **Why it matters:** Item 24 (Anwil NDA) sat for weeks. A first-pass routine compresses lawyer cycles.

---

# TIER 4 — BUILD FOURTH (3 routines)

Quarterly cadence — lowest priority but high signal when they do fire.

---

## R22 — Aramco HQ Touchpoint Generator

- **Trigger:** Cron `0 10 1 1,4,7,10 *` (quarterly, 1st of Jan/Apr/Jul/Oct 10:00 MT)
- **What it does:** Surfaces last quarter's interactions with Aramco HQ contacts (Cobus, Bernedict Kheswa, others), drafts a quarterly thank-you + capabilities-refresher 1-pager (Item 23 of April action).
- **Inputs:** Outlook history with Aramco HQ domains, Project Tracker (Aramco-tagged jobs delivered last quarter)
- **Output:** Draft message + 1-page cap refresher PDF (uses canvas-design skill).

---

## R23 — SRE × AIMS Framework Review

- **Trigger:** Cron `0 11 1 1,4,7,10 *` (quarterly, 1st of Jan/Apr/Jul/Oct 11:00 MT)
- **What it does:** Re-reads the SRE × AIMS partnership framework doc, surfaces any deviations from it observed in the past quarter (cost allocation disputes like Talha's $2K conference, market overlaps, exclusivity questions), proposes amendments.
- **Inputs:** Framework doc, prior quarter's flagged exceptions (R4 daily logs)
- **Output:** Amendment proposal memo to Ron + Shameem.

---

# TIER 5 — DEFER (3 routines, build only if you ask)

These are nice-to-haves that I'd skip until you explicitly want them. Listed for completeness.

| ID | Routine | Why deferred |
|---|---|---|
| R24 | Conference speaking calendar watcher | Annual cadence; manual review at year-start works fine |
| R25 | Sleep+prayer compliance scorecard | Self-tracking better than auto — autonomy preserves intent |
| R26 | Other-businesses 09:00–12:00 brief | Out of scope per your answer; build separately |

---

# Routines I'm explicitly NOT recommending

These would be tempting to automate but I'd advise against:

- ❌ **Auto-send emails on your behalf** — every routine above stops at "draft saved." External communication needs your signature.
- ❌ **Auto-post on social / LinkedIn** — voice drift risk, not enough volume to justify.
- ❌ **Auto-decision on bid/no-bid** — too consequential. Routine surfaces the data; you decide.
- ❌ **Cross-business automation in this plan** — Shaghf and Mechways have different rhythms and partners. Separate plan.
- ❌ **Routines that fire during prayer slots, family time (19:00–22:00), or recovery nights (Fri/Sat ME blocks)** — none scheduled in those windows. These are anchors.

---

# Recommended Rollout

| Week | Build | Goal |
|---|---|---|
| Week 1 | R1, R2, R3, R4 (NA day cycle) | Inbox windows + daily setup/close run themselves |
| Week 2 | R5, R8, R13, R14 (ME scan + weekly cycle) | Friday review + Zaheer update auto-stage |
| Week 3 | R12 (Thu CFO), R6, R15a-d (ME pre-briefs) | CFO day + AIMS bi-weekly briefs |
| Week 4 | R9, R10, R11 (theme-day memos) | Mon Sale + Tue Pipeline + Wed Eng tracker |
| Month 2 | R17, R19, R20 | Compliance + meeting brief + on-demand drafter |
| Month 2+ | R16, R18, R21 | Monthly + lead triage + contract reviewer |
| Quarterly | R22, R23 | Aramco touchpoint + AIMS framework review |

**At the end of Week 4 you'll have 18 routines running** that cover every recurring slot in your Weekly OS. That's roughly 6–8 hours/week of pre-staged work that previously consumed your deep-work blocks.

---

# What I Need From You to Build These

For each routine to actually pull live data, two conditions must hold:

1. **The right MCP connector is connected.** All Tier 1 routines work with your current connector set. Tier 2 R7 needs Pocket; Tier 2 R11 needs ClickUp; Tier 3 R18 needs Sulfur Space membership feed (manual or scraped — flag if Squarespace API access is available).

2. **The Project Tracker xlsx is kept current.** R12, R13, R14 all read it. Wednesday Eng standup is the natural refresh point — R11 is designed to feed it.

If both hold: **green light to start building Tier 1 — say "build R1-R4 now" and I'll create the four scheduled tasks.**

If you'd prefer a different rollout order or want to fold in a specific recurring task I missed (e.g., the Junior EIT profile sourcing pattern from a recent session, or the Playhouse review pattern), tell me which and I'll re-slot.

---

*End of plan. Sources: SRE Weekly Operating System, Task List April 2026, Action Package April 2026, recent session transcripts (Plan CEO Week, Funds Required, Pipeline Reviews).*
