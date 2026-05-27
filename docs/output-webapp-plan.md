---
id: WEBAPP-PLAN-v0
title: Routine Output Webapp — Architecture Plan
status: draft
date: 2026-05-26
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"
operator: Maaz Ahmed Shareef
collaborator: Mohammad (info@callreceptionist.ai)
---

# Routine Output Webapp — Architecture Plan

Maaz chose a custom webapp over iMessage / Pushover / SMS relays for routine output delivery. This document plans the MVP, the auth model, the data flow, deployment, and the staged rollout that keeps Phase 1 unblocked while the webapp is being built.

## Problem statement

Phase 1 routines (R1, R2, R5, R8) produce short markdown payloads on a cron. The payloads need to reach Maaz on his phone with:

- **Zero per-message charges** (no SMS / iMessage relay subscriptions)
- **Frictionless auth** (no new password to manage)
- **Phone-readable in 30 seconds** (not a desktop-only experience)
- **History he can scroll back through** (not ephemeral pushes)
- **Confidentiality preserved** (no third-party message relay that could log payload contents)

## Decision summary (per D11)

| Aspect | Choice |
|---|---|
| Auth | **Entra ID SSO** — Maaz signs in with his existing M365 identity |
| Storage | Routines write markdown to a dedicated OneDrive folder; webapp reads via Microsoft Graph |
| Hosting | Azure Static Web Apps free tier (single user, low volume) |
| Charges | **None** — Static Web Apps free tier + Graph reads against Maaz's existing M365 license |
| Fallback | Teams chat with self for daily, OneDrive markdown for weekly, while webapp is being built |

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ Anthropic cloud — Claude Code remote agents (cron)                   │
│   R1, R2, R5, R8 fire on schedule → produce markdown payload         │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ mcp__ms365__upload-file-content
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Maaz's OneDrive — /SRE Routines/{routine_id}/{YYYY-MM-DD}.md         │
│   Markdown payload, ~200–400 words, deterministic filenames          │
│   Permissions: Maaz only (no sharing, no public link)                │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ Microsoft Graph API — Files.Read.All (delegated)
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Azure Static Web App                                                 │
│   • SPA (React/Vue/vanilla) served from edge                         │
│   • Entra ID SSO login (Maaz's M365 identity)                        │
│   • API: Azure Function reads OneDrive folder, returns markdown list │
│   • Renders markdown in-place; supports pull-to-refresh on mobile    │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ HTTPS
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Maaz's iPhone — Safari (PWA-installable to home screen)              │
│   No app-store flow; behaves like an installed app once added        │
└──────────────────────────────────────────────────────────────────────┘
```

## Auth model

**Choice: Entra ID SSO** (delegated permissions, Maaz acts as himself).

- Webapp registers as a single-tenant Entra app inside Maaz's tenant.
- Scopes requested: `User.Read`, `Files.Read.All` (delegated).
- No client secret needed on the SPA (PKCE flow).
- Session lives in browser local storage with MSAL.js; refresh tokens silent.
- Sign-out is global (revokes session on all tabs).

**Why not username/password or magic link:**
- Maaz already authenticates to M365 dozens of times a day — re-using that identity means zero new passwords.
- Tenant admin (Maaz) can revoke the app's consent in one click if anything goes wrong.
- The same Entra app can later be elevated to a confidential client for write-back features (e.g., "mark routine output as acted on") without re-auth UX changes.

## Data flow

### Routine write path

1. Routine completes its scan.
2. Routine renders payload as markdown with frontmatter:
   ```yaml
   ---
   routine_id: R1
   fired_at: 2026-05-27T11:55:00-06:00
   token_usage: { input: 7842, output: 891 }
   confidential_items_count: 1   # never the subjects, just the count
   ---
   ```
3. Routine calls `mcp__ms365__upload-file-content` with path `/SRE Routines/R1-na-inbox-scan/2026-05-27.md`.
4. On success: routine appends one line to `/SRE Routines/_index.jsonl` (manifest for the webapp to skim without listing the whole folder).

### Webapp read path

1. User opens webapp (PWA or browser tab).
2. MSAL.js handles SSO if no session, else silent refresh.
3. Webapp API (Azure Function) calls Graph: `GET /me/drive/root:/SRE Routines/_index.jsonl:/content`
4. API returns the last 50 entries (sorted by fired_at desc).
5. SPA renders cards. Tapping a card fetches the full markdown via `GET /me/drive/root:/{path}:/content` and renders inline.

### Why a manifest jsonl

- Listing a folder over Graph is slow and pages awkwardly.
- A single-file manifest makes "what's new since I last checked?" a 1-request operation.
- Routines append on write; the webapp truncates / rotates monthly via a maintenance task.

## Confidentiality contract

- Webapp only reads files Maaz owns. No service-principal escalation.
- Confidential routine items (per D10) are NEVER written to the OneDrive markdown — only the count. The webapp cannot leak subjects it never received.
- The OneDrive folder has zero sharing permissions. If anyone gains access, it required Maaz's account to be compromised — at which point the OneDrive itself is compromised too. No new attack surface.
- Webapp logs (Azure Function logs) redact request bodies. Only auth events + file paths are recorded.

## MVP scope (v0)

Ship the smallest thing that makes Maaz stop opening Outlook for routine output:

- [ ] Entra app registration in Maaz's tenant
- [ ] Static Web App scaffolded (vanilla TS, no framework — keep bundle small)
- [ ] PKCE auth via MSAL.js
- [ ] Graph read path for `_index.jsonl` and single markdown files
- [ ] List view (card per fire, sorted desc, R1 / R2 / R5 / R8 filter chips)
- [ ] Detail view (markdown rendered, frontmatter shown as a small badge row)
- [ ] PWA manifest (so Maaz can add to iPhone home screen)
- [ ] Mobile-first responsive layout (Maaz reads at 11:55, 12:00, 21:55, Sunday 16:00 — all phone moments)
- [ ] One toggle: "unread only" — derived from a local-storage cursor

**Out of scope for v0:**
- Push notifications (Phase 2 — Apple Web Push if Maaz wants)
- Write-back actions ("mark acted on", "snooze", "promote to task")
- Multi-user — Maaz only
- Search — folder is small enough to scroll for v0

## Routine-side changes needed

Each routine spec already says `output: webapp_queue + onedrive_markdown` (per D11 update). The concrete write contract is now:

1. Build the markdown payload with the v0 frontmatter shape above.
2. Call `mcp__ms365__upload-file-content` to the deterministic path.
3. Append to `_index.jsonl`.
4. On any failure, route the error to the fallback channel (Teams self-DM during webapp build period).

A small library at `routines/lib/output-webapp.md` (to be created in Phase 1.5) will codify the write contract so every routine uses the same shape.

## Deployment plan

| Phase | Step | Owner | Target |
|---|---|---|---|
| W0 | Decision recorded | Mohammad | done (this doc) |
| W1 | Entra app registration in Maaz's tenant | Maaz + Mohammad | week of 2026-06-01 |
| W2 | Scaffold Static Web App + MSAL.js auth | Mohammad | week of 2026-06-08 |
| W3 | Graph read path + list/detail views | Mohammad | week of 2026-06-15 |
| W4 | PWA manifest + mobile polish | Mohammad | week of 2026-06-22 |
| W5 | Wire R1 routine to webapp_queue write path; pilot 5 fires | Mohammad + Maaz | week of 2026-06-29 |
| W6 | Roll to R2 / R5 / R8 | Mohammad | week of 2026-07-06 |

**During W0–W4**, Phase 1 pilot is NOT blocked. Routines fire to Teams self-chat fallback. Webapp is parallel work.

## Open items (require Maaz)

| ID | Question |
|---|---|
| WEB-OPEN-1 | Domain — webapp at `routines.sulfurrecovery.com` (subdomain on company domain) or `sre-routines.azurestaticapps.net` (default)? Subdomain is one DNS record + cert auto-issue. |
| WEB-OPEN-2 | Should Maaz be the ONLY user, or do we also grant read to Mohammad (collaborator) for monitoring? Default: Maaz-only. |
| WEB-OPEN-3 | OneDrive root path — `/SRE Routines/` (proposed) or under an existing folder like `/SRE General Manager/Routines/`? |

## Open items (require Mohammad scoping)

| ID | Question |
|---|---|
| WEB-OPEN-4 | Confirm Static Web Apps free tier covers Maaz's expected daily reads (well within 100GB/mo bandwidth). |
| WEB-OPEN-5 | Manifest rotation policy — append-only with monthly compaction, or write-new-file each month? |
| WEB-OPEN-6 | First-load cost — bundle size budget for the SPA on a phone over LTE. Target ≤ 50KB gzipped. |

## Why not the alternatives (recap)

| Option | Why ruled out |
|---|---|
| Pushover/Pushbullet | Adds a paid service ($5+) and a third-party that sees payload metadata. |
| iMessage relay (LoopMessage, Sendblue) | $30–50/mo and a third-party seeing payload content. |
| Mac Shortcuts bridge | Requires a Mac to stay on; brittle. |
| Teams chat-with-self only | Works fine as fallback but doesn't give Maaz a scrollable cross-routine history. |
| Email summary | Maaz already has 24,763 inbox items; routine output should NOT pile into that. |
