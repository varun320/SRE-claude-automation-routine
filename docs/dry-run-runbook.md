---
id: DRY-RUN-PHASE1
title: Phase-1 Dry-Run Runbook (local, read-only)
status: active
date: 2026-05-27
linked_routines:
  - routines/tier1/R1-na-inbox-scan.md
  - routines/tier1/R2-daily-setup.md
  - routines/tier1/R5-me-inbox-scan.md
  - routines/tier1/R8-sunday-planning.md
linked_decisions:
  - docs/decisions/2026-05-26-maaz-phase1-decisions.md
---

# Phase-1 Dry-Run Runbook

Validates the four Phase-1 routine prompts (R1, R2, R5, R8) against Maaz's live MS365 tenant from a LOCAL Claude Code session — before any cloud cron is registered. Catches prompt-logic bugs cheaply.

**Scope:** This runbook validates prompt logic, output shape, and the auto-archive ruleset. It does **not** validate cloud-cron timing, token refresh under claude.ai's MS365 connector, or scheduled-fire rate limits. Those need a real cloud one-shot.

**DRY-RUN HARD RULE:** Auto-archive pass logs *what would be moved* but **does not call `move-mail-message`**. Every other tool call is also strictly read-only.

---

## Pre-flight (run before every dry-run session)

Paste each into a fresh Claude Code session at `D:\projects\prodigy-ai\projects\routines-claude` and confirm green:

1. **Connector login.** `mcp__ms365__verify-login` returns `{"success": true}`. If not, run `scripts\ms365-login.bat`.
2. **Account.** `mcp__ms365__list-accounts` shows `maaz@sulfurrecovery.com` as default.
3. **Mailbox readable.** `mcp__ms365__list-mail-folder-messages` with `mailFolderId: "inbox"`, `top: 1` returns one message. If 403, scopes are wrong — re-run login.
4. **Shared-mailbox check (R5 + R8 only).** Try one read against each of the 10 shared mailboxes via the `account` parameter or shared-mailbox endpoint to confirm Maaz still has full-mailbox-access:
   ```
   ar@sulfurrecovery.com, ap@sulfurrecovery.com, info@sulfurrecovery.com,
   info-me@sulfurrecovery.com, sales@sulfurrecovery.com, careers@sulfurrecovery.com,
   apple@sulfurrecovery.com, HusamsBookingPageSRE@sulfurrecovery.com,
   boardroom@sulfurrecovery.com
   ```
   Note any that 403 — these become open items.
5. **Log directory.** Create `routines/logs/dry-run/` if missing. All dry-run output lands here.

---

## R1 — NA Inbox Scan dry-run

**Window override for testing:** since 24h ago (instead of "since 21:55 yesterday MT" — we're not running at the scheduled trigger time).

### Prompt to paste

> **DRY RUN — R1 NA Inbox Scan.** Read [`routines/tier1/R1-na-inbox-scan.md`](../routines/tier1/R1-na-inbox-scan.md) for the build prompt and apply it with these overrides:
>
> 1. **Window:** scan messages received in the last 24 hours.
> 2. **Auto-archive override:** for every message that meets the D5 auto-archive ruleset, append a row to `routines/logs/dry-run/R1-{TODAY}-archive-candidates.md` with `| sender | subject | message-id | rule that matched |`. **Do NOT call `mcp__ms365__move-mail-message`** even though the spec permits it. Pure-read mode.
> 3. **Summary output:** write the final RED/AMBER/GREEN summary to `routines/logs/dry-run/R1-{TODAY}-summary.md`. Keep it ≤200 words per the spec.
> 4. **Confidentiality:** drop any subject containing `Torstein`, `DD`, `board`, `P&L`, `Section 12`, or `boardroom@` sender → replace with `[1 confidential thread]` count.
> 5. **Token budget:** target ≤8k input, ≤1k output. Log final input/output token counts in the summary frontmatter.
>
> Confirm the cross-mailbox pollution filter is on: every surviving item's `toRecipients` must include `maaz@sulfurrecovery.com`, `info@sulfurrecovery.com`, or `info-me@sulfurrecovery.com`. Drop and count anything else.

### Pass criteria

- [ ] `R1-{TODAY}-summary.md` exists and is ≤200 words
- [ ] Output has RED/AMBER/GREEN buckets with sender + subject + ≤5-word context per item
- [ ] No message bodies appear in the summary (subjects only)
- [ ] `R1-{TODAY}-archive-candidates.md` contains at least the LinkedIn + alarm.com items seen yesterday (verified pattern)
- [ ] Zero messages bypassed the `toRecipients` filter — confirm by spot-checking 3 random rows
- [ ] Token usage logged within ceiling
- [ ] If any item contained a confidential keyword, it shows as count-only, not subject text

### Known good signals (from yesterday's manual look at the same mailbox)

3 of 3 most recent messages were LinkedIn newsletter + 2× alarm.com notifications. Auto-archive should catch all 3. If it catches fewer, the regex is too tight; if it catches more than expected, audit the false-positive carefully.

---

## R2 — Daily Setup dry-run

### Prompt to paste

> **DRY RUN — R2 Daily Setup.** Read [`routines/tier1/R2-daily-setup.md`](../routines/tier1/R2-daily-setup.md) for the build prompt and apply it with these overrides:
>
> 1. **Local-file fallback:** if `/Users/maazwork/Documents/Claude/Projects/SRE General Manager/` is not reachable (it almost certainly isn't — that's Maaz's Mac path, not this Windows machine), skip the Action-Package + Task-List read and note in the output: `(SRE GM project files not accessible from this dry-run host — skipped)`.
> 2. **Calendar pull:** today + tomorrow only, no archive.
> 3. **Theme detection:** use today's day-of-week as `[DAY]`.
> 4. **Cadence reality (D9):** cross-check today's calendar against the observed standing meetings (Thu 10:00 MT Bi-Weekly Job, weekly Maaz↔Torstein 1:1, Monthly Pitstop) and surface drift if any.
> 5. **Confidentiality (D10):** treat any meeting referencing Torstein, DD, board, P&L as `[confidential strategic item]` in the output.
> 6. **Output destination:** write to `routines/logs/dry-run/R2-{TODAY}-summary.md`. ≤250 words.
> 7. **Token budget:** target ≤6k input, ≤1k output.

### Pass criteria

- [ ] `R2-{TODAY}-summary.md` exists and is ≤250 words
- [ ] Top 3 tasks are proposed, each tied to today's theme
- [ ] Calendar conflicts vs prayer windows / family time identified (or "none" stated)
- [ ] Drift vs observed cadence noted (if any)
- [ ] Confidentiality redaction applied if any meeting hit the keyword list
- [ ] Local-file fallback note included (acknowledging the Windows-vs-Mac path gap)

---

## R5 — ME Inbox Scan dry-run

**Window override:** since 24h ago.

### Prompt to paste

> **DRY RUN — R5 ME Inbox Scan.** Read [`routines/tier1/R5-me-inbox-scan.md`](../routines/tier1/R5-me-inbox-scan.md) for the build prompt and apply it with these overrides:
>
> 1. **Window:** last 24 hours.
> 2. **Inbox scope (D6 + D7):** Maaz's mailbox + the 9 active shared mailboxes (skip the disabled scanner mailbox). For each shared mailbox other than `info@` and `info-me@`, only surface items that match the ME filter.
> 3. **Per-mailbox confirmation:** before scanning, attempt one read against each of the 9 shared mailboxes. List the result (`OK` / `403` / `not_found`) in the summary frontmatter.
> 4. **Auto-archive override:** same as R1 — log to `routines/logs/dry-run/R5-{TODAY}-archive-candidates.md` but **do NOT call `move-mail-message`**.
> 5. **Cross-mailbox filter:** every surviving item's `toRecipients` must include `maaz@`, `info@`, `info-me@`, or whichever shared mailbox is being scanned.
> 6. **Output destination:** write summary to `routines/logs/dry-run/R5-{TODAY}-summary.md`. ≤200 words.
> 7. **Confidentiality:** same as R1.
> 8. **Token budget:** target ≤12k input, ≤1k output (higher than R1 because of the 10-mailbox sweep).

### Pass criteria

- [ ] `R5-{TODAY}-summary.md` exists and is ≤200 words
- [ ] Per-mailbox access result table populated for all 9 active shared mailboxes
- [ ] Every surfaced item is ME-relevant per the filter (AIMS contact OR ME-customer domain/keyword)
- [ ] `R5-{TODAY}-archive-candidates.md` exists (empty is OK if no ME-region noise hit the window)
- [ ] Zero items bypass the cross-mailbox `toRecipients` filter
- [ ] Token usage logged within ceiling

### Known risk

The 24h window during a NA-weekend (Sat/Sun MT) may show very little ME traffic. If nothing surfaces, RE-RUN with a 7-day window to confirm the prompt at least *can* surface ME signal — then re-run with 24h to confirm the time filter still works.

---

## R8 — Sunday Planning dry-run

### Prompt to paste

> **DRY RUN — R8 Sunday Planning.** Read [`routines/tier1/R8-sunday-planning.md`](../routines/tier1/R8-sunday-planning.md) for the build prompt and apply it with these overrides:
>
> 1. **Local-file fallback:** same as R2 — the SRE GM project files are Mac paths, skip and note.
> 2. **Inbox sweep:** apply D7 — all 9 active shared mailboxes + Maaz's mailbox. Report per-mailbox: unread count, oldest unactioned thread (subject + sender + age in days).
> 3. **NA / ME split:** classify each per the spec's filter list.
> 4. **Calendar look-ahead:** next 7 days. Flag prayer / family / Jumua conflicts. Cross-check against observed cadence (Thu 10:00 Bi-Weekly, Maaz↔Torstein, Monthly Pitstop).
> 5. **Top 3 for next Monday:** propose, tied to CEO/Strategic theme. Per D10, replace any confidential item with `[confidential strategic item]`.
> 6. **Thank-you note:** pick one external contact from the past week's traffic.
> 7. **#1 risk for the week:** name it.
> 8. **Output destination:** `routines/logs/dry-run/R8-{TODAY}-summary.md`. ≤400 words.
> 9. **Token budget:** target ≤20k input, ≤2k output (largest of the four).

### Pass criteria

- [ ] `R8-{TODAY}-summary.md` exists and is ≤400 words
- [ ] All 10 mailboxes (Maaz + 9 active shared) have a row in the per-mailbox table (or `OK / 403 / not_found`)
- [ ] NA/ME split totals add up to inbox total per mailbox
- [ ] Calendar window: 7 days, every meeting evaluated for conflict
- [ ] Monday Top 3 proposed
- [ ] Thank-you note + #1 risk both populated
- [ ] No board-room or DD content in plain text

---

## Cross-routine acceptance summary

A complete dry-run pass means **all four routines produced their `routines/logs/dry-run/{Rx}-{TODAY}-summary.md` files**, each within the word + token budget, with every pass-criteria checkbox above true.

**Failure modes to log explicitly** (for Phase-1.5 fixes):

| Symptom | Where to log |
|---|---|
| Auto-archive false-positive (real mail flagged) | `routines/logs/dry-run/issues-{TODAY}.md` — describe the message + which rule misfired |
| Cross-mailbox pollution leaked through (Don/Inshan content surfaced) | same file — which filter failed |
| Confidentiality keyword missed | same file — which subject leaked |
| Per-mailbox 403 | same file — which mailbox + which scope is missing |
| Token usage over ceiling | same file — which routine + by how much |
| Local-file fallback noise | note in summary frontmatter — acceptable for dry-run |

---

## After a clean dry-run pass

1. Commit the dry-run logs (or just the issues file — the summaries contain mail content and should be reviewed for PII before committing).
2. Decide which routine to ship first. **Recommendation: R1 first** — smallest scope, validates the auto-archive pattern, fastest feedback loop.
3. Flip R1 `status: draft → status: pilot` in the spec.
4. Convert R1 cron to UTC (currently `55 11 * * 0-4` America/Edmonton):
   - **Standard time (MST, Nov–Mar):** UTC = MT + 7 → `55 18 * * 0-4`
   - **Daylight time (MDT, Mar–Nov):** UTC = MT + 6 → `55 17 * * 0-4`
   - This is **two separate cron registrations** with seasonal enable/disable, OR pick UTC + 6 and accept the 1h drift during MST. Document the choice.
5. Connect MS365 at https://claude.ai/customize/connectors (P2 from prereq list) — confirm the scopes match what R1 needs.
6. Install Claude GitHub App or run `/web-setup` (P1).
7. Register R1 via `RemoteTrigger create` (the `/schedule` skill will walk through it).
8. First fire: review the output by hand. If clean, repeat for R2, R5, R8.

---

## Where the dry-run does NOT help

To save you from false confidence:

- ❌ Does not validate cloud token refresh / re-consent on the claude.ai MS365 connector
- ❌ Does not validate cron-precision under UTC↔MT DST transitions
- ❌ Does not validate Graph rate limits at scheduled-fire scale
- ❌ Does not validate that the cloud agent can read the routine spec from GitHub (needs P1 done)
- ❌ Does not validate the webapp queue write path (webapp not built yet — pilot writes to OneDrive only)

A clean dry-run is a strong signal but not a green light. Plan one **cloud one-shot test fire** per routine (via `RemoteTrigger run` after `create`) before flipping cron to `enabled: true`.
