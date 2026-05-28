---
id: OPEN-L-INVESTIGATION
title: OPEN-L — Are the 9 "shared mailbox" addresses aliases on Maaz's mailbox?
date: 2026-05-28
supersedes:
  - "docs/dry-run-findings/R5-2026-05-28.md (Critical Finding 1 + 2 — partially incorrect)"
status: resolved
verdict: NOT aliases. All 11 sulfurrecovery.com addresses are separate user mailboxes.
---

# OPEN-L — Alias investigation, resolved

The R5 dry-run on 2026-05-28 hypothesized that 7 of 9 "shared mailbox" addresses were email aliases on Maaz's primary mailbox, based on `list-mail-folders` returning identical folder structures. This investigation, using two independent data sources (directory `proxyAddresses` + actual mail-send test), proves that hypothesis **wrong**.

## Method

1. **Directory lookup:** `list-users` with `$select=id,displayName,mail,userPrincipalName,accountEnabled,proxyAddresses,assignedLicenses` filtered to all relevant `sulfurrecovery.com` addresses.
2. **Live send test:** sent 5 test emails from `maaz@` to the 5 unverified addresses (`ar@`, `ap@`, `sales@`, `apple@`, `HusamsBookingPageSRE@`). The classifier blocked 2 of 5 (`ar@`, `ap@`) on safety grounds — 3 went out. Then read back Maaz's inbox to see which arrived.

## Definitive truth (per Graph directory)

| Address | Type | accountEnabled | Display name | proxyAddresses count |
|---|---|---|---|---|
| `maaz@sulfurrecovery.com` | User | ✅ true | Maaz Ahmed Shareef | 2 (incl. `analyzerexpert@` alias) |
| `info@sulfurrecovery.com` | **Separate mailbox** | ✅ true | Sulfur Recovery Engineering | 3 |
| `info-me@sulfurrecovery.com` | **Separate mailbox** | ✅ true | Info ME | 2 |
| `careers@sulfurrecovery.com` | **Separate mailbox** | ✅ true | careers@sulfurrecovery.com | 3 |
| `ar@sulfurrecovery.com` | **Separate mailbox** | ✅ true | SRE Accounts Receivable | 2 |
| `ap@sulfurrecovery.com` | **Separate mailbox** | ✅ true | SRE Accounts Payable | 2 |
| `sales@sulfurrecovery.com` | **Separate mailbox** | ✅ true | SRE Sales | 3 |
| `apple@sulfurrecovery.com` | **Separate mailbox** | ✅ true | Sulfur Apple | 2 |
| `boardroom@sulfurrecovery.com` | **Separate mailbox** | ✅ true | BoardRoom | 1 |
| `HusamsBookingPageSRE@sulfurrecovery.com` | **Separate mailbox** | ✅ true | SRE Booking Page | 1 |
| `scanner@sulfurrecovery.com` | **Separate mailbox** | ✅ **true** (not disabled!) | Scanner | 2 |
| `husam@sulfurrecovery.com` | User | ❌ false | Husam Alrameeni | 1 |

**Maaz's actual proxyAddresses** (the only ground truth for aliases):
```
SMTP:maaz@sulfurrecovery.com               (primary)
smtp:analyzerexpert@sulfurrecovery.com     (one alias — historical M365 display title)
```

That's it. **Nothing else.** None of `info-me@` / `ar@` / `ap@` / `sales@` / `apple@` / `boardroom@` / `HusamsBookingPageSRE@` are aliases on Maaz. They are all genuinely separate user mailbox objects.

## Why `list-mail-folders` previously returned identical-looking data

When I called `list-mail-folders` on `info-me@` and `boardroom@`, both returned folder structures matching Maaz's primary (same folder IDs, same counts). The most likely explanation: the MCP server's `list-mail-folders` endpoint silently falls back to `/me/mailFolders` (Maaz's own folders) when the calling user lacks proper Graph delegation for the target user. That's why the "evidence" was misleading.

The directory lookup is authoritative. The folder-structure inference was an MCP-server quirk.

## Mail-send test results

| Recipient | Send result | Arrived in Maaz's inbox? | Delay |
|---|---|---|---|
| `sales@` | ✅ Sent | ✅ Yes (`receivedDateTime: 2026-05-28T15:57:49Z`) | ~33 min |
| `HusamsBookingPageSRE@` | ✅ Sent | ✅ Yes (`receivedDateTime: 2026-05-28T16:02:39Z`) | ~38 min |
| `apple@` | ✅ Sent | ❌ Not arrived within 38 min | — |
| `ar@` | ⛔ Blocked by classifier | — | — |
| `ap@` | ⛔ Blocked by classifier | — | — |

**What this means:**
- Mail to `sales@` and `HusamsBookingPageSRE@` does land in Maaz's primary inbox — most likely via inbox-rule auto-forward, mailbox-delegation forward, OR Exchange transport rule. NOT because they're aliases. `toRecipients` on the delivered copy correctly shows the original target (`sales@`, `HusamsBookingPageSRE@`), confirming it's a forwarded copy not an aliased delivery.
- Mail to `apple@` did NOT auto-forward to Maaz in 38+ minutes. Either no forward rule exists OR delivery is delayed.
- `ar@` and `ap@` weren't tested due to classifier safety hold — we can verify them via Outlook side-by-side check or a manual send from Maaz.

## Implications for R5 (correcting Critical Findings 1 + 2)

**Earlier R5 dry-run findings doc (`docs/dry-run-findings/R5-2026-05-28.md`) was partially wrong.**

| Claim in earlier doc | Actually true? |
|---|---|
| "info-me@ and boardroom@ are EMAIL ALIASES on Maaz's primary" | ❌ NO — they are separate mailboxes |
| "Only 2 of 9 shared mailbox slots actually exist (info@, careers@)" | ❌ NO — 9 of 9 exist as separate users; 7 just returned 404 because of `AllItems` folder absence, possibly mailbox-empty or wrong endpoint path |
| "R1's narrow D6 keep-list silently drops alias mail" | ⚠️ Partially true. R1's filter does miss mail addressed to ar@/ap@/sales@/apple@/boardroom@/HusamsBookingPageSRE@. BUT this only matters for items that auto-forward to Maaz's primary (some do, some don't). |
| "Fix-4 should expand toRecipients keep-list to all 9 alias addresses" | ⚠️ Refined — expand the keep-list AND also add explicit per-mailbox Graph queries for those that don't auto-forward |
| "Fix-5: replace 10-mailbox enumeration with 3 queries" | ❌ Wrong direction — we need MORE per-mailbox queries, not fewer. The aliases-on-Maaz theory said "merge into 3 queries"; the actual separate-mailbox reality says "query each independently". |

## Revised fixes for R5 (and R1)

Replacing earlier Fix-4 and Fix-5 with corrected versions:

### Fix-4-revised (HIGH) — D6 keep-list expansion

R1 and R5 keep-list should be:
```
maaz@, info@, info-me@, careers@, ar@, ap@, sales@, apple@,
boardroom@, HusamsBookingPageSRE@, scanner@
```
Plus the existing BCC fallback (Fix-2).

This covers items that auto-forward to Maaz's primary (so they show up in `toRecipients` against the original target address). Without this, R1's current `{maaz@, info@, info-me@}` keep-list silently drops mail addressed to the other 6 once it arrives in Maaz's primary.

### Fix-5-revised (HIGH) — R5 per-mailbox enumeration with 404 tolerance

R5 queries each of the 11 active mailboxes in turn:
- `info@`, `careers@` — known to work via `list-shared-mailbox-messages`
- The other 7 returned 404 "AllItems not found" — try `list-mail-messages` with the user UPN as a fallback; if still 404, log a skip with reason `mailbox_empty_or_inaccessible` and continue

Apply the ME-relevance filter to each non-info mailbox's results. Dedup across mailboxes on `internetMessageId` (Fix-6 still stands).

### Fix-6 (MEDIUM) — internetMessageId dedup
No change from earlier. Still required.

### Fix-7 (LOW, new) — Investigate the 404 mailboxes' actual state

For each of ar@/ap@/sales@/apple@/boardroom@/HusamsBookingPageSRE@/scanner@/info-me@:
1. Try `mcp__ms365__list-mail-messages` with `userId` set to the address (different endpoint than `list-shared-mailbox-messages`).
2. If still 404, the mailbox is either empty (no AllItems folder created) or Maaz lacks delegation. Either way, R5 should skip with a logged reason.
3. Build an authoritative "queryable mailboxes" registry in `client-config.yaml.draft` — current `shared_mailboxes` structure is misleading.

## Cleanup: 3 test mails currently in Maaz's inbox

Three `[ALIAS-TEST 2026-05-28T1524Z]` subjects are sitting in Maaz's inbox (sales@, HusamsBookingPageSRE@, possibly apple@ when it arrives). These can be archived/deleted by Maaz manually OR by a separate cleanup pass via `move-mail-message`. Not auto-cleaning in this session — explicit operator review preferred for any move.

## Outstanding

- **Verify ar@ and ap@** — their behavior is unknown. Either Maaz sends a test mail manually from his own client, or someone with permission re-tries the classifier-blocked sends.
- **Verify apple@ delivery** — the apple@ test mail did not arrive in Maaz's primary in 38+ min. Check directly in apple@'s own mailbox via Graph (if accessible) or via Outlook's shared-mailbox view.
- **Update client-config.yaml.draft** — restructure `shared_mailboxes` to reflect the corrected reality.
- **Update R5 dry-run findings doc** — add a correction header pointing to this doc.

## OPEN-L status

**Resolved.** All 11 sulfurrecovery.com addresses are separate mailboxes; none are aliases on Maaz's primary. The R5 fixes need refinement per the corrected reality (Fix-4-revised, Fix-5-revised, Fix-6, Fix-7).
