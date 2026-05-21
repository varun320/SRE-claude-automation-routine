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
output: notification
safety: read-only, subjects-only, no drafts, ≤200 words
window: "since 15:35 today MT"
linked_audit_findings:
  - "audits/sre-2026-05-21/data/tenant-summary.json#mailbox_signals"
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-04"   # AIMS membership resolved to 21+ contacts
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-06"   # info-me@ shared mailbox inclusion
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-16"   # toRecipients_filter for cross-mailbox pollution
  - "audits/sre-2026-05-21/raw/calendar/calendar-2yr-aggregate.json#customer_touch_2yr"   # ME customer roster
---

# R5 — ME Inbox Scan (subjects only)

**Trigger:** Sun–Thu at 21:55 America/Edmonton, immediately before the 22:00 ME block setup. Same shape as R1 but ME-focused.

**Goal:** Five-minute scan of ME-relevant inbound traffic since the 15:35 NA triage. Returns subjects grouped by urgency so Maaz walks into the 22:00 ME deep-work block knowing what landed during Mountain afternoon. NO drafting, NO replies.

**Why it matters:** ME deep work starts at 22:20 (Mountain time = early-morning Gulf). You should not learn about a 22:20 surprise *at* 22:20. From Weekly OS §3.

---

## Build prompt

> Scan my Outlook inbox and Teams DMs received since 15:35 today America/Edmonton time. **Filter to ME-relevant traffic:**
>
> - **AIMS contacts** (any `@aimsgt.com` sender, including: Shameem, Maaz Khan, Bader Ansari, Mohammed Fazal, Junaid Muhammad E, Ali Albader, Zaheer Juddy, Mohammed Yunus, Naveed Hussain, Ahmad Patel, Ravi Srinivas, Sateesh D, Vahib Saleem, Muhammad Bilal, Hameed, Girish, plus tenant guests: a.shaikh, abrar, arahman, azad, khayaz)
> - **ME customer domains/keywords:** Aramco (aramco.com), ADNOC (adnoc.ae), Q-Chem, Petro Rabigh, KNPC, Tüpraş, SATORP, Qatar Energy, QE-LNG, JIGPC, BSE/BAPCO, KOC, ERIELL, Anwil/Orlen, Mellitah/Dolphin, Kanoo, Baker Hughes
> - **Also include shared-mailbox flow:** mail addressed to `info-me@sulfurrecovery.com` (the ME info shared mailbox)
>
> Group into RED (decision needed tonight), AMBER (response needed this week), GREEN (FYI). Return only sender + subject + 5-word context per item. No drafting, no full reads, no recommendations. Maximum 200 words total.
>
> Use ms365 MCP. For mail: `list-mail-folder-messages` on the Inbox folder, ordered by receivedDateTime desc, filtered by the time window. `$select=id,subject,from,toRecipients,receivedDateTime,hasAttachments,importance` — never include `body` or `bodyPreview`. For Teams: `list-chat-messages` across recent ME-themed chats only. **Read-only — never call any tool starting with create-, send-, update-, delete-, move-, accept-, decline-, reply-, forward-.**
>
> **CRITICAL filter:** the operator has full-mailbox-access to Don Green, Inshan, and info@ (audit OQ-16). Drop messages whose `toRecipients` does not contain `maaz@sulfurrecovery.com` OR `info-me@sulfurrecovery.com`. Otherwise LinkedIn newsletters routed to Don Green pollute the output.

---

## Output shape

> 6 new since 15:35 NA triage.
> **RED (1):** Ali Albader — Aramco RTR May-31 reschedule (Maaz to confirm tonight)
> **AMBER (3):** Sateesh D (AIMS) — Amine Expert call deck · Naveed Hussain — Petro-Rabigh follow-up · Tüpraş — invoice #INV-2025-0314 reminder #6
> **GREEN (2):** [list]

Delivered to: same channel as R1.

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 8k input, ≤ 1k output (same as R1).
- **No write tools.** Build prompt forbids.
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
