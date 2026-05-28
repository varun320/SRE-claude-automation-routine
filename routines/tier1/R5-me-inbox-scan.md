---
id: R5
name: ME Inbox Scan (subjects only)
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "55 21 * * 0-4"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365]
ms365_scopes: [Mail.Read, Mail.ReadWrite, Chat.Read]   # ReadWrite required for ARCHIVE bucket once dry_run flips false
output: webapp_queue + onedrive_markdown                # per D11
safety: read-only-for-bodies, archive-only-for-noise, no drafts, no sends, ≤200 words surfaced
window: "since 15:35 today MT"
dry_run: true                          # log ARCHIVE candidates only; do NOT call move-mail-message
dry_run_exit_threshold: 25             # flip to false after ≥25 ARCHIVE classifications with 0 operator-flagged false-positives
linked_audit_findings:
  - "audits/sre-2026-05-21/data/tenant-summary.json#mailbox_signals"
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-04"   # AIMS membership resolved to 21+ contacts
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-06"   # info-me@ shared mailbox inclusion
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-16"   # toRecipients_filter for cross-mailbox pollution
  - "audits/sre-2026-05-21/raw/calendar/calendar-2yr-aggregate.json#customer_touch_2yr"   # ME customer roster
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d5"   # summarize + auto-archive obvious junk
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d6"   # scope = maaz + info@ + info-me@
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d7"   # all 10 shared mailboxes
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10"  # confidentiality reframe
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"  # webapp + OneDrive output
linked_findings:
  - "docs/dry-run-findings/R1-2026-05-28.md"                  # Fix-1 (LLM ARCHIVE bucket) + Fix-2 (BCC fallback) — mirrored from R1
---

# R5 — ME Inbox Scan (subjects only)

**Trigger:** Sun–Thu at 21:55 America/Edmonton, immediately before the 22:00 ME block setup. Same shape as R1 but ME-focused.

**Goal:** Five-minute scan of ME-relevant inbound traffic since the 15:35 NA triage. Returns subjects grouped by urgency so Maaz walks into the 22:00 ME deep-work block knowing what landed during Mountain afternoon. NO drafting, NO replies.

**Why it matters:** ME deep work starts at 22:20 (Mountain time = early-morning Gulf). You should not learn about a 22:20 surprise *at* 22:20. From Weekly OS §3.

---

## Build prompt

> Scan inbound mail and Teams DMs received since 15:35 today America/Edmonton time.
>
> **Inbox scope (per D6 + D7):** Maaz's mailbox + `info@sulfurrecovery.com` + `info-me@sulfurrecovery.com` + the 7 other active shared mailboxes (`ar@`, `ap@`, `sales@`, `careers@`, `apple@`, `HusamsBookingPageSRE@`, `boardroom@`). The disabled scanner mailbox stays excluded. For shared mailboxes other than info@ / info-me@, only surface items that are ME-relevant (filter below). Don's and Inshan's personal mailboxes are explicitly OUT of scope.
>
> **Filter to ME-relevant traffic:**
> - **AIMS contacts** (any `@aimsgt.com` sender, including: Shameem, Maaz Khan, Bader Ansari, Mohammed Fazal, Junaid Muhammad E, Ali Albader, Zaheer Juddy, Mohammed Yunus, Naveed Hussain, Ahmad Patel, Ravi Srinivas, Sateesh D, Vahib Saleem, Muhammad Bilal, Hameed, Girish, plus tenant guests: a.shaikh, abrar, arahman, azad, khayaz)
> - **ME customer domains/keywords:** Aramco (aramco.com), ADNOC (adnoc.ae), Q-Chem, Petro Rabigh, KNPC, Tüpraş, SATORP, Qatar Energy, QE-LNG, JIGPC, BSE/BAPCO, KOC, ERIELL, Anwil/Orlen, Mellitah/Dolphin, Kanoo, Baker Hughes, PrefChem (prefchem.com.my)
>
> **Cross-mailbox pollution filter (audit OQ-16, mandatory):** for each message in the window, keep it only if ONE of these is true:
> 1. `toRecipients` includes at least one of: `maaz@`, `info@`, `info-me@`, OR the shared mailbox currently being scanned. OR
> 2. **BCC fallback (per Fix-2 from dry-run-findings R1-2026-05-28):** `toRecipients` is empty AND the message lives in Maaz's primary mailbox or in the shared mailbox being scanned (BCC pattern — common for ME-customer portals like PrefChem and tender platforms like Orlen Connect, Ariba). Annotate `[via BCC]` on its summary line.
>
> Drop everything else.
>
> **Bucket pass (per D5, implementation revised per Fix-1) — every survivor gets exactly ONE of four labels:**
>
> | Bucket | Definition |
> |---|---|
> | **RED** | Decision needed tonight — proposal/contract/RFQ requiring Maaz action, customer escalation, AIMS-flagged urgent item, tender deadline in ≤48h. |
> | **AMBER** | Response needed this week — customer follow-up, meeting request, AIMS coordination, tender deadline within window. |
> | **GREEN** | FYI — internal informational updates, news, status confirmations. |
> | **ARCHIVE** | Transactional notifications, bulk marketing, promotional sends, vendor newsletters, automated platform notifications. Signal: bulk-send patterns, marketing vocabulary, "act now" / "limited time" framing, generic vendor blasts. **When uncertain, prefer AMBER over ARCHIVE.** AIMS senders and ME-customer-domain senders are NEVER ARCHIVE-classified, regardless of subject. |
>
> Classify using sender domain + sender name + subject only. Do NOT read message bodies.
>
> **ARCHIVE bucket handling:** same as R1.
> - If `dry_run: true` (default): log candidates to today's run log (sender, subject, message-id, classification reason); do NOT call `move-mail-message`. Surface count in summary header.
> - If `dry_run: false`: log AND call `move-mail-message` to move each item to `Archive/Auto-Archived/{YYYY-MM}` in the message's source mailbox.
>
> **Surfaced summary = RED + AMBER + GREEN only.** Return sender + subject + ≤5-word context per item. ≤200 words for the surfaced summary.
>
> Use ms365 MCP. For mail: `list-mail-folder-messages` on the Inbox folder of each in-scope mailbox, ordered by receivedDateTime desc, filtered by the time window. `$select=id,subject,from,toRecipients,receivedDateTime,hasAttachments,importance` — never include `body` or `bodyPreview`. For Teams: `list-chat-messages` across recent ME-themed chats only. **Read-only on bodies — never call create-, send-, update-, delete-, accept-, decline-, reply-, or forward-. The ONLY write tool permitted is `move-mail-message` for items the bucket pass labeled ARCHIVE, AND only when `dry_run: false`.**
>
> **Confidentiality (per D10):** never surface SRE DD, Torstein 1:1, P&L, or board-prep subjects. Replace with `[N confidential threads]` count-only. Confidential items are never ARCHIVE-classified.

---

## Output shape

> 6 surfaced since 15:35 NA triage. **2 archived** (see archive log).
> **RED (1):** Ali Albader — Aramco RTR May-31 reschedule (Maaz to confirm tonight)
> **AMBER (3):** Sateesh D (AIMS) — Amine Expert call deck · Naveed Hussain — Petro-Rabigh follow-up [via BCC] · Tüpraş — invoice #INV-2025-0314 reminder #6
> **GREEN (2):** [list]

Archive log lives at `routines/logs/runs/R5-{YYYY-MM-DD}-archive.md` — operator reviews during the dry-run threshold period.

**Delivery (per D11):** webapp queue at `/queue/R5/{YYYY-MM-DD}.md` + OneDrive mirror at `OneDrive/SRE Routines/R5-me-inbox-scan/{YYYY-MM-DD}.md`. Fallback during webapp build: Teams chat with self.

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 12k input, ≤ 1k output. Higher than R1 because of the 9-mailbox sweep.
- **Write-scope guardrail:** Only `move-mail-message` is permitted as a write, and only when `dry_run: false`. Verify at `/schedule` registration that scoped role cannot exceed `Mail.Read` + `Mail.ReadWrite` + `Chat.Read`.
- **Dry-run gate:** `dry_run: true` is the default and stays true until ≥25 ARCHIVE classifications have been operator-reviewed with 0 false-positives. R1 and R5 dry-run thresholds count independently — R1's dry-run pass does not unlock R5.
- **Confidentiality + ARCHIVE interaction:** Confidential subjects (Torstein / DD / board / P&L / Section 12 / boardroom@) are NEVER ARCHIVE-classified. AIMS senders and ME-customer-domain senders also never ARCHIVE — they always reach RED/AMBER/GREEN classification.
- **Prayer/family windows:** 21:55 MT is between Maghrib (~21:00) and Isha (~22:15). Inside the family-time block (17:00–22:00) but the Day Clock makes ME-work-prep an explicit exception. **Audited safe per execution plan §10.** If operator's prayer schedule shifts (seasonal), revisit cron.
- **Cross-mailbox pollution (audit OQ-16):** Hard requirement — without the `toRecipients` filter (+ BCC fallback), Don Green's LinkedIn newsletters and similar cross-mailbox traffic become noise. Verify on first run by spot-checking 3 random surfaced items.
- **AIMS contact list freshness:** the AIMS roster grows. Re-sync with audit's AIMS-contacts list quarterly.
- **Failure mode:** If ms365 errors, escalate per D11 fallback (Teams self-DM). Do NOT retry silently.

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
- [ ] Output matched constraints (no drafts, no over-reach, surfaced ≤200 words)
- [ ] **ARCHIVE bucket precision ≥100% over first 25 dry-run classifications** — zero false-positives across AIMS / ME-customer / shared-mailbox sources, then operator flips `dry_run: false`
- [ ] No noise senders (LinkedIn, alarm.com, generic vendor blasts) in RED/AMBER/GREEN across 10 fires
- [ ] No cross-mailbox pollution — every surfaced item satisfies direct-to OR BCC-fallback rule with annotation
- [ ] Confidentiality reframe verified — no DD / Torstein / board subjects leak into surfaced buckets
- [ ] One full Sun–Thu cycle (5 fires) completed cleanly
