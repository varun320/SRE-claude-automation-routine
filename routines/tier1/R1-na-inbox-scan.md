---
id: R1
name: NA Inbox Scan
status: draft                         # phase-1 low-stakes — not yet scheduled
cron: "55 11 * * 0-4"
timezone: America/Edmonton
tier: 1
phase: 1
connectors: [ms365]
ms365_scopes: [Mail.Read, Mail.ReadWrite, Chat.Read]   # ReadWrite added for auto-archive (D5)
output: webapp_queue + onedrive_markdown                # per D11
safety: read-only-for-bodies, archive-only-for-noise, no drafts, no sends, ≤200 words
window: "since 21:55 yesterday MT"
linked_audit_findings:
  - "audits/sre-2026-05-21/data/tenant-summary.json#mailbox_signals"   # 24,735 inbox · 8,679 unread · 0 rules
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-05"   # seed inbox rules or just summarize?
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json#openQuestions.OQ-16"   # toRecipients_filter mandatory
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d5"   # auto-archive ruleset
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d6"   # scope = maaz + info@ + info-me@
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10"  # confidentiality reframe (no "sale process")
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"  # webapp + OneDrive output
---

# R1 — NA Inbox Scan (subjects only)

**Trigger:** Sun–Thu at 11:55 America/Edmonton, immediately before the 12:00 Daily Setup slot.

**Goal:** 5-minute scan that returns subject lines grouped by urgency so the operator walks into 12:00 setup already knowing the shape of the day. NO drafting, NO replies, NO recommendations.

**Why it matters:** Enforces the "subjects only" discipline — prevents inbox doom-spiral before deep work. From Weekly OS §3.

---

## Build prompt

> Scan inbound mail and Teams DMs received since 21:55 yesterday America/Edmonton time. **Inbox scope (per D6):** Maaz's mailbox + `info@sulfurrecovery.com` + `info-me@sulfurrecovery.com`. Don's and Inshan's mailboxes are explicitly OUT of scope for this routine.
>
> **Cross-mailbox pollution filter (audit OQ-16, mandatory):** drop every message whose `toRecipients` does NOT include at least one of: `maaz@sulfurrecovery.com`, `info@sulfurrecovery.com`, `info-me@sulfurrecovery.com`.
>
> **Auto-archive pass (per D5) — runs BEFORE summarization:**
> For each message in the window, if ALL THREE conditions hold, move it to the `Archive/Auto-Archived/{YYYY-MM}` folder and exclude it from the summary:
> 1. Sender domain ∈ noise allowlist: `linkedin.com`, `alarm.com`
> 2. Subject matches marketing regex: `(?i)(unsubscribe|view in browser|newsletter|promotional|special offer|webinar invite)` — match against subject only, not body
> 3. No human-named SRE staff is in `toRecipients` individually (i.e., it's a bulk send to a distribution alias)
>
> Use `mcp__ms365__move-mail-message` for archival. Log every archive action to today's run log (sender, subject, message-id, reason).
>
> **Then summarize the survivors:** group senders/subjects into RED (decision needed today), AMBER (response needed this week), GREEN (FYI). Return only sender + subject + 5-word context per item. No drafting, no full body reads, no recommendations. Maximum 200 words total.
>
> **Confidentiality (per D10):** treat any subject containing "Torstein", "DD", "board", "P&L", "Section 12", or board-room sender patterns as confidential — surface only the count, not the subject text. Replace with `[1 confidential thread]`.
>
> Use the ms365 MCP server. For mail: `list-mail-messages` filtered by received date with `$select=id,subject,from,toRecipients,receivedDateTime,hasAttachments,importance`. For Teams: `list-chat-messages` across recent chats. **Read-only on bodies — never call create-, send-, update-, delete-, accept-, decline-, reply-, or forward-. The ONLY write tool permitted is `move-mail-message` for the auto-archive pass.**

---

## Output shape

A single short payload, written to the webapp queue and mirrored to OneDrive:

> 8 new since 21:55 ME triage. (12 noise items auto-archived.)
> **RED (2):** Caleb — CSV bid Q · Aramco — RTR scheduling
> **AMBER (3):** Petro Rabigh — sample delay · Anwil — NDA v3 · Q-Chem — invoice Q
> **GREEN (3):** [list]

**Delivery (per D11):**
- **Primary:** webapp queue at `/queue/R1/{YYYY-MM-DD}.md` (Maaz reads in browser, Entra ID SSO)
- **Mirror:** OneDrive at `OneDrive/SRE Routines/R1-na-inbox-scan/{YYYY-MM-DD}.md`
- **Fallback while webapp is in build:** Teams chat with self (operator's own DM)

---

## Cost & safety guardrails

- **Token ceiling per fire:** ≤ 8k input, ≤ 1k output. If a fire exceeds, log to `routines/logs/incidents/` and review the prompt.
- **Write-scope guardrail:** Only `move-mail-message` is permitted as a write. The build prompt explicitly forbids every other write. Verify at `/schedule` registration that the scoped role cannot exceed `Mail.Read` + `Mail.ReadWrite` + `Chat.Read`.
- **Prayer/family windows:** 11:55 MT is the slot before Zuhr (~14:00) and outside the 19:00–22:00 family block. Audited safe.
- **Auto-archive safety:** First 5 fires, log archive actions but DO NOT actually move messages (dry-run mode). Operator reviews the log; if precision is ≥95% (no real mail archived), enable actual moves.
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
- [ ] Output matched the build prompt's constraints (no drafts, no over-reach, ≤200 words)
- [ ] Auto-archive precision ≥95% over first 25 archive actions (no real mail archived)
- [ ] Confidentiality reframe verified — no Torstein / DD / board subjects leak into summary
- [ ] Cross-mailbox pollution: every summary item's `toRecipients` includes maaz@ or info@ or info-me@
- [ ] Cost per run measured and projected (× 26 routines × weekly fires) within budget
- [ ] One full Sun–Thu cycle (5 fires) completed cleanly
