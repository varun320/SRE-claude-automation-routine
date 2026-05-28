---
id: R1
name: NA Inbox Scan
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "55 11 * * 0-4"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365]
ms365_scopes: [Mail.Read, Mail.ReadWrite, Chat.Read]   # ReadWrite required for ARCHIVE bucket once dry_run flips false
output: webapp_queue + onedrive_markdown                # per D11
safety: read-only-for-bodies, archive-only-for-noise, no drafts, no sends, ≤200 words surfaced
window: "since 21:55 yesterday MT"
dry_run: true                          # log ARCHIVE candidates only; do NOT call move-mail-message
dry_run_exit_threshold: 25             # flip to false after ≥25 ARCHIVE classifications with 0 operator-flagged false-positives
linked_audit_findings:
  - "audits/sre-2026-05-21/data/tenant-summary.json#mailbox_signals"   # 24,735 inbox · 8,679 unread · 0 rules
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-05"   # seed inbox rules or just summarize?
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-16"   # toRecipients_filter mandatory
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d5"   # summarize + auto-archive obvious junk
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d6"   # scope = maaz + info@ + info-me@
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10"  # confidentiality reframe (no "sale process")
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"  # webapp + OneDrive output
linked_findings:
  - "docs/dry-run-findings/R1-2026-05-28.md"                  # Fix-1 (LLM ARCHIVE bucket) + Fix-2 (BCC fallback) origin
---

# R1 — NA Inbox Scan (subjects only)

**Trigger:** Sun–Thu at 11:55 America/Edmonton, immediately before the 12:00 Daily Setup slot.

**Goal:** 5-minute scan that returns subject lines grouped by urgency so the operator walks into 12:00 setup already knowing the shape of the day. NO drafting, NO replies, NO recommendations.

**Why it matters:** Enforces the "subjects only" discipline — prevents inbox doom-spiral before deep work. From Weekly OS §3.

---

## Build prompt

> Scan inbound mail and Teams DMs received since 21:55 yesterday America/Edmonton time.
>
> **Inbox scope (per D6):** Maaz's mailbox + `info@sulfurrecovery.com` + `info-me@sulfurrecovery.com`. Don's and Inshan's mailboxes are explicitly OUT of scope for this routine.
>
> **Cross-mailbox pollution filter (audit OQ-16, mandatory):** for each message in the window, keep it only if ONE of these is true:
> 1. `toRecipients` includes at least one of: `maaz@sulfurrecovery.com`, `info@sulfurrecovery.com`, `info-me@sulfurrecovery.com`. OR
> 2. **BCC fallback (per Fix-2 from dry-run-findings R1-2026-05-28):** `toRecipients` is empty AND the message lives in Maaz's primary mailbox/folder (i.e., the message was delivered to Maaz via BCC — common for ME-customer portals, tender platforms, and some vendor systems). Annotate `[via BCC]` on its summary line.
>
> Drop everything else. Do not surface, do not classify, do not log.
>
> **Bucket pass (per D5, implementation revised per Fix-1) — every survivor gets exactly ONE of four labels:**
>
> | Bucket | Definition |
> |---|---|
> | **RED** | Decision needed today — proposals/contracts/RFQs requiring Maaz action, regulatory deadlines this week, customer escalations, internal blockers. |
> | **AMBER** | Response needed this week — meeting requests, customer follow-ups, action requested in subject, scheduled commitments. |
> | **GREEN** | FYI — internal informational updates, news without action implied, confirmations. |
> | **ARCHIVE** | Transactional notifications, bulk marketing, promotional sends, vendor newsletters, automated platform notifications, anything Maaz would tap "archive" on without reading. Signal: bulk-send patterns (sender targets a shared mailbox not a person), marketing-vocabulary, "your listing" / "act now" / "limited time" framing, alarm.com armed/disarmed notifications, equipment-dealer mass blasts. **When uncertain, prefer AMBER over ARCHIVE.** |
>
> Classify using sender domain + sender name + subject only. Do NOT read message bodies.
>
> **ARCHIVE bucket handling:**
> - If routine frontmatter `dry_run: true` (default): log ARCHIVE candidates to today's run log (sender, subject, message-id, one-line classification reason) but **DO NOT call `move-mail-message`**. The ARCHIVE count surfaces in the summary header (e.g., "3 archived"), candidates do not surface as line items.
> - If `dry_run: false`: log AND call `mcp__ms365__move-mail-message` to move each ARCHIVE-classified item to `Archive/Auto-Archived/{YYYY-MM}`. Same log entry per move.
>
> **Surfaced summary = RED + AMBER + GREEN only.** Return sender + subject + ≤5-word context per item. No drafting, no body reads, no recommendations. ≤200 words for the surfaced summary (ARCHIVE log is separate, no word budget).
>
> **Confidentiality (per D10):** treat any subject containing "Torstein", "DD", "board", "P&L", "Section 12", or board-room sender as confidential — surface only the count, not the subject. Replace with `[N confidential threads]`. Confidential items are never ARCHIVE-classified.
>
> Use the ms365 MCP server. For mail: `list-mail-messages` filtered by received date with `$select=id,subject,from,toRecipients,receivedDateTime,hasAttachments,importance`. For Teams: `list-chat-messages` across recent chats. **Read-only on bodies — never call create-, send-, update-, delete-, accept-, decline-, reply-, or forward-. The ONLY write tool permitted is `move-mail-message` for items the bucket pass labeled ARCHIVE, AND only when `dry_run: false`.**

---

## Output shape

A single short payload, written to the webapp queue and mirrored to OneDrive:

> 8 surfaced since 21:55 ME triage. **3 archived** (see archive log). 1 confidential thread.
> **RED (2):** Caleb — CSV bid Q · Aramco — RTR scheduling
> **AMBER (3):** Petro Rabigh — sample delay [via BCC] · Anwil — NDA v3 · Q-Chem — invoice Q
> **GREEN (3):** [list]

Archive log lives at `routines/logs/runs/R1-{YYYY-MM-DD}-archive.md` — operator reviews during the dry-run threshold period.

**Delivery (per D11):**
- **Primary:** webapp queue at `/queue/R1/{YYYY-MM-DD}.md` (Maaz reads in browser, Entra ID SSO)
- **Mirror:** OneDrive at `OneDrive/SRE Routines/R1-na-inbox-scan/{YYYY-MM-DD}.md`
- **Fallback while webapp is in build:** Teams chat with self (operator's own DM)

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 8k input, ≤ 1k output. If a fire exceeds, log to `routines/logs/incidents/` and review the prompt.
- **Write-scope guardrail:** Only `move-mail-message` is permitted as a write, and only when `dry_run: false`. The build prompt explicitly forbids every other write. Verify at `/schedule` registration that the scoped role cannot exceed `Mail.Read` + `Mail.ReadWrite` + `Chat.Read`.
- **Prayer/family windows:** 11:55 MT is the slot before Zuhr (~14:00) and outside the 19:00–22:00 family block. Audited safe.
- **Dry-run gate:** `dry_run: true` is the default and stays true until ≥25 ARCHIVE classifications have been operator-reviewed with 0 false-positives. Operator flips the frontmatter and the routine spec gets a commit + re-deploy. The threshold lives at `dry_run_exit_threshold`.
- **Confidentiality + ARCHIVE interaction:** Confidential subjects are NEVER ARCHIVE-classified. If a subject matches both the confidentiality keyword set and the ARCHIVE heuristic, confidentiality wins — surface as `[1 confidential thread]` count.
- **Failure mode:** If the ms365 connector errors, route the failure notification per D11 fallback (Teams self-DM). Do NOT retry silently.

---

## Edge cases

- **First fire after vacation:** > 24h window — cap at 200 most recent post-archive messages to keep token budget.
- **Confidentiality leak guard:** if the auto-archive pass accidentally archives a board-room sender, the run log will catch it. Add an explicit allowlist exception for `boardroom@sulfurrecovery.com` → never archived.
- **AIMS thread bleed-in:** AIMS senders technically aren't "NA" — but if they land in maaz@ during NA hours, treat as RED/AMBER per content, not bucketed out.

---

## Run log

Per-fire output and metrics land in `routines/logs/runs/R1-YYYY-MM-DD.md`. Capture:

- Wall-clock time
- Token usage (in / out)
- Connector calls made (count + names)
- Auto-archive count + per-message log (sender, subject, message-id, rule matched)
- Whether output respected "subjects only, ≤200 words"
- Any RED items that turned out to be false-positives or missed RED items (for prompt tuning)

---

## Phase-1 exit criteria (from IMPLEMENTATION_PLAN.md §Phase 1)

- [ ] R1 fires on schedule without intervention
- [ ] Output matched the build prompt's constraints (no drafts, no over-reach, surfaced ≤200 words)
- [ ] **ARCHIVE bucket precision ≥100% over first 25 dry-run classifications** — zero false-positives, then operator flips `dry_run: false`
- [ ] Confidentiality reframe verified — no Torstein / DD / board subjects leak into surfaced buckets, no confidential subjects ARCHIVE-classified
- [ ] Cross-mailbox pollution: every surfaced item satisfies either the direct-to (maaz/info/info-me) rule OR the BCC fallback (empty `toRecipients` + in Maaz's mailbox + `[via BCC]` annotation)
- [ ] Cost per run measured and projected (× 26 routines × weekly fires) within budget
- [ ] One full Sun–Thu cycle (5 fires) completed cleanly
