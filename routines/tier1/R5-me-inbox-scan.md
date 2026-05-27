---
id: R5
name: ME Inbox Scan (subjects only)
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "55 21 * * 0-4"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365]
ms365_scopes: [Mail.Read, Chat.Read]
output: webapp_queue + onedrive_markdown                # per D11
safety: read-only-for-bodies, archive-only-for-noise, no drafts, no sends, ≤200 words
window: "since 15:35 today MT"
ms365_scopes: [Mail.Read, Mail.ReadWrite, Chat.Read]   # ReadWrite added for auto-archive (D5)
linked_audit_findings:
  - "audits/sre-2026-05-21/data/tenant-summary.json#mailbox_signals"
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-04"   # AIMS membership resolved to 21+ contacts
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-06"   # info-me@ shared mailbox inclusion
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-16"   # toRecipients_filter for cross-mailbox pollution
  - "audits/sre-2026-05-21/raw/calendar/calendar-2yr-aggregate.json#customer_touch_2yr"   # ME customer roster
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d5"   # auto-archive ruleset
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d6"   # scope = maaz + info@ + info-me@
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d7"   # all 10 shared mailboxes
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10"  # confidentiality reframe
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"  # webapp + OneDrive output
---

# R5 — ME Inbox Scan (subjects only)

**Trigger:** Sun–Thu at 21:55 America/Edmonton, immediately before the 22:00 ME block setup. Same shape as R1 but ME-focused.

**Goal:** Five-minute scan of ME-relevant inbound traffic since the 15:35 NA triage. Returns subjects grouped by urgency so Maaz walks into the 22:00 ME deep-work block knowing what landed during Mountain afternoon. NO drafting, NO replies.

**Why it matters:** ME deep work starts at 22:20 (Mountain time = early-morning Gulf). You should not learn about a 22:20 surprise *at* 22:20. From Weekly OS §3.

---

## Build prompt

> Scan inbound mail and Teams DMs received since 15:35 today America/Edmonton time.
>
> **Inbox scope (per D6 + D7):** Maaz's mailbox + `info@sulfurrecovery.com` + `info-me@sulfurrecovery.com` + the 8 other active shared mailboxes (`ar@`, `ap@`, `sales@`, `careers@`, `apple@`, `HusamsBookingPageSRE@`, `boardroom@` — the disabled scanner mailbox stays excluded). For shared mailboxes other than info@ / info-me@, only surface items that are ME-relevant (filter below). Don's and Inshan's personal mailboxes are explicitly OUT of scope.
>
> **Filter to ME-relevant traffic:**
> - **AIMS contacts** (any `@aimsgt.com` sender, including: Shameem, Maaz Khan, Bader Ansari, Mohammed Fazal, Junaid Muhammad E, Ali Albader, Zaheer Juddy, Mohammed Yunus, Naveed Hussain, Ahmad Patel, Ravi Srinivas, Sateesh D, Vahib Saleem, Muhammad Bilal, Hameed, Girish, plus tenant guests: a.shaikh, abrar, arahman, azad, khayaz)
> - **ME customer domains/keywords:** Aramco (aramco.com), ADNOC (adnoc.ae), Q-Chem, Petro Rabigh, KNPC, Tüpraş, SATORP, Qatar Energy, QE-LNG, JIGPC, BSE/BAPCO, KOC, ERIELL, Anwil/Orlen, Mellitah/Dolphin, Kanoo, Baker Hughes
>
> **Cross-mailbox pollution filter (audit OQ-16, mandatory):** drop every message whose `toRecipients` does NOT include at least one of: `maaz@`, `info@`, `info-me@`, or whichever shared mailbox is being scanned. Otherwise Don's LinkedIn newsletters pollute the output.
>
> **Auto-archive pass (per D5) — runs BEFORE summarization:**
> Same ruleset as R1. If sender domain ∈ {`linkedin.com`, `alarm.com`} AND subject matches marketing regex AND the message is a bulk send, move to `Archive/Auto-Archived/{YYYY-MM}` and exclude from summary. Use `mcp__ms365__move-mail-message`. Log every archive action.
>
> Group survivors into RED (decision needed tonight), AMBER (response needed this week), GREEN (FYI). Return only sender + subject + 5-word context per item. No drafting, no full reads, no recommendations. Maximum 200 words total.
>
> Use ms365 MCP. For mail: `list-mail-folder-messages` on the Inbox folder of each in-scope mailbox, ordered by receivedDateTime desc, filtered by the time window. `$select=id,subject,from,toRecipients,receivedDateTime,hasAttachments,importance` — never include `body` or `bodyPreview`. For Teams: `list-chat-messages` across recent ME-themed chats only. **Read-only on bodies — never call create-, send-, update-, delete-, accept-, decline-, reply-, or forward-. The ONLY write tool permitted is `move-mail-message` for the auto-archive pass.**
>
> **Confidentiality (per D10):** never surface SRE DD, Torstein 1:1, P&L, or board-prep subjects. Replace with `[1 confidential thread]` count-only.

---

## Output shape

> 6 new since 15:35 NA triage.
> **RED (1):** Ali Albader — Aramco RTR May-31 reschedule (Maaz to confirm tonight)
> **AMBER (3):** Sateesh D (AIMS) — Amine Expert call deck · Naveed Hussain — Petro-Rabigh follow-up · Tüpraş — invoice #INV-2025-0314 reminder #6
> **GREEN (2):** [list]

**Delivery (per D11):** webapp queue at `/queue/R5/{YYYY-MM-DD}.md` + OneDrive mirror at `OneDrive/SRE Routines/R5-me-inbox-scan/{YYYY-MM-DD}.md`. Fallback during webapp build: Teams chat with self.

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 12k input, ≤ 1k output. Higher than R1 because of the 10-mailbox sweep.
- **Write-scope guardrail:** Only `move-mail-message` is permitted. Verify at `/schedule` registration that scoped role cannot exceed `Mail.Read` + `Mail.ReadWrite` + `Chat.Read`.
- **Auto-archive safety:** Same dry-run-first pattern as R1 — log archive actions for first 5 fires before enabling actual moves.
- **Prayer/family windows:** 21:55 MT is between Maghrib (~21:00) and Isha (~22:15). Inside the family-time block (17:00–22:00) but the Day Clock makes ME-work-prep an explicit exception. **Audited safe per execution plan §10.** If operator's prayer schedule shifts (seasonal), revisit cron.
- **Cross-mailbox pollution (audit OQ-16):** Hard requirement — without the `toRecipients` filter, Don Green's LinkedIn newsletters become noise. Verify on first run.
- **AIMS contact list freshness:** the AIMS roster grows. Re-sync with audit's AIMS-contacts list quarterly.
- **Failure mode:** If ms365 errors, escalate per Phase 0 OQ #4. Do NOT retry silently.

---

## Edge cases

- **Maaz Khan @ AIMS vs Maaz @ SRE name collision:** disambiguate by domain. `maaz@aimsgt.com` is AIMS-Maaz; `maaz@sulfurrecovery.com` is operator. Don't flag operator's own threads.
- **AIMS-bridged Aramco threads:** Aramco mail often flows AIMS → SRE. Categorize as Aramco RED/AMBER, mention AIMS bridge in context.
- **Calendar-response noise:** Teams meeting threads auto-generate "Accepted:" / "Tentative:" subjects. Exclude these.
- **Low-volume nights:** holidays / Eid / Friday evenings — annotate "low-volume night" rather than producing a misleading "0 RED" that looks like routine failure.
- **Inshan ambiguity (audit OQ-02 + OQ-17):** Inshan is Entra-disabled but mail still flows. If a thread is addressed to `inshanm@`, decide per OQ-17 — default is exclude from operator's Top 3 until employment status is confirmed.

---

## Run log

`logs/runs/R5-YYYY-MM-DD.md`. Capture same fields as R1 plus:

- AIMS senders vs ME-customer senders vs shared-mailbox-only — count per bucket
- Cross-mailbox pollution leaks (any subject in output addressed to dongreen@ or inshanm@? → bug, fix filter)

---

## Phase-1 exit criteria

- [ ] R5 fires on schedule without intervention
- [ ] Output matched constraints (no drafts, no over-reach, ≤200 words)
- [ ] No noise senders (LinkedIn, alarm.com) in escalations across 10 runs
- [ ] No cross-mailbox pollution — every escalation's `toRecipients` includes maaz@ or info-me@
- [ ] One full Sun–Thu cycle (5 fires) completed cleanly
