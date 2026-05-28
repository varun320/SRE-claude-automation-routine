---
id: WEBAPP-PLAN-v0.1
title: Routine Output Webapp — Architecture Plan
status: draft
date: 2026-05-26
revised: 2026-05-27   # M2 hosting + M3 two-reader updates
linked_decisions:
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#d11"
  - "docs/decisions/2026-05-26-maaz-phase1-decisions.md#supplementary-2026-05-27"
operator: Maaz Ahmed Shareef
collaborator: Mohammad (info@callreceptionist.ai)
readers: [Maaz, Mohammad]                 # per M3
hosting: Vercel                            # per M2 (was: Azure Static Web Apps)
onedrive_root: "/SRE Routines/"            # per M4
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

## Decision summary (per D11 + M1–M4 supplementary 2026-05-27)

| Aspect | Choice |
|---|---|
| Auth | **Entra ID SSO** — Maaz signs in with his existing M365 identity; Mohammad signs in as a **guest user** in Maaz's tenant (per M3) |
| Storage | Routines write markdown to `/SRE Routines/` in Maaz's OneDrive (per M4); webapp reads via Microsoft Graph |
| Hosting | **Vercel** free tier (per M2 — Vercel chosen over Azure Static Web Apps for DX + boundary hygiene) |
| Domain | Start on `*.vercel.app`, optionally migrate to `routines.callreceptionist.ai` (Mohammad-owned subdomain) once W2 lands. **Not** on `sulfurrecovery.com` — routines is Mohammad's deliverable, not SRE IT. |
| Readers | Maaz + Mohammad (per M3). Mohammad is invited as a guest in Maaz's tenant; Maaz shares `/SRE Routines/` with him. |
| Charges | **None** — Vercel free tier + Graph reads against existing M365 licenses |
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
│ Vercel (Next.js or Vite + React SPA)                                 │
│   • Edge-served from Vercel CDN                                      │
│   • Entra ID SSO login via MSAL.js — Maaz (member) or Mohammad (guest)│
│   • Graph calls direct from browser; no backend proxy required        │
│   • Renders markdown in-place; supports pull-to-refresh on mobile     │
│   • Domain: *.vercel.app default, or routines.callreceptionist.ai     │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ HTTPS
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Maaz's iPhone + Mohammad's phone/laptop — Safari/Chrome (PWA)        │
│   No app-store flow; behaves like an installed app once added        │
└──────────────────────────────────────────────────────────────────────┘
```

## Auth model

**Choice: Entra ID SSO** (delegated permissions, each user acts as themselves).

- Webapp registers as a **single-tenant** Entra app inside Maaz's tenant.
- Scopes requested: `User.Read`, `Files.Read.All` (delegated).
- No client secret needed on the SPA (**PKCE** flow).
- Redirect URIs registered: `https://<vercel-app>.vercel.app` (and later the custom domain if added). Localhost added during dev only.
- Session lives in browser local storage with MSAL.js; refresh tokens silent.
- Sign-out is global (revokes session on all tabs).

### Two readers (per M3): Maaz + Mohammad

OneDrive read access is per-user, not per-tenant. Two reader identities require a slightly different setup than a Maaz-only build:

| Step | What | Owner |
|---|---|---|
| 1 | Maaz invites Mohammad as a **guest user** in his tenant (Azure AD → External Identities → Guest invitation, target `info@callreceptionist.ai`) | Maaz |
| 2 | Mohammad accepts the invitation and signs in once via M365 SSO to materialize his guest identity | Mohammad |
| 3 | Maaz shares the `/SRE Routines/` OneDrive folder with Mohammad's guest identity (read-only) | Maaz |
| 4 | Mohammad signs into the webapp using his guest account; MSAL.js handles the same flow as Maaz, just with a different `oid` | Mohammad |

This keeps a single Entra app, a single redirect URI set, and one code path. The only state that diverges is which OneDrive each token can access — and that's already governed by the share grant in step 3.

**Why not multi-tenant Entra app:** would let Mohammad sign in with his own org identity, but Files.Read.All would only see his own OneDrive — not Maaz's. Guest user is the cleaner pattern.

**Why not service-principal app credentials:** would require backend infra to hold the secret, expanding surface for a two-user MVP. Defer until there's a reason (write-back actions, more readers, etc.).

**Why not username/password or magic link:**
- Both readers already authenticate to M365 dozens of times a day — re-using that identity means zero new passwords.
- Tenant admin (Maaz) can revoke the app's consent OR Mohammad's guest invitation in one click if anything goes wrong.

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

- [ ] Entra app registration in Maaz's tenant (single-tenant, PKCE public client)
- [ ] Maaz invites Mohammad as a guest user; Maaz shares `/SRE Routines/` with him
- [ ] Vercel project created (Next.js or Vite + React)
- [ ] PKCE auth via MSAL.js — works for both Maaz (member) and Mohammad (guest)
- [ ] Graph read path for `_index.jsonl` and single markdown files
- [ ] List view (card per fire, sorted desc, R1 / R2 / R5 / R8 filter chips)
- [ ] Detail view (markdown rendered, frontmatter shown as a small badge row)
- [ ] PWA manifest (so Maaz can add to iPhone home screen)
- [ ] Mobile-first responsive layout (Maaz reads at 11:55, 12:00, 21:55, Sunday 16:00 — all phone moments)
- [ ] One toggle: "unread only" — derived from a local-storage cursor
- [ ] Per-reader cursor — Maaz's read state ≠ Mohammad's read state

**Out of scope for v0:**
- Push notifications (Phase 2 — Apple Web Push if Maaz wants)
- Write-back actions ("mark acted on", "snooze", "promote to task")
- More than two readers
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
| W0 | Decision recorded (v0.1 — Vercel + two readers) | Mohammad | done (this doc) |
| W1 | Entra app registration in Maaz's tenant + Mohammad guest invite + OneDrive folder share | Maaz + Mohammad | week of 2026-06-01 |
| W2 | Scaffold Vercel project + MSAL.js auth (Next.js or Vite + React) | Mohammad | week of 2026-06-08 |
| W3 | Graph read path + list/detail views | Mohammad | week of 2026-06-15 |
| W4 | PWA manifest + mobile polish + per-reader cursor | Mohammad | week of 2026-06-22 |
| W5 | Wire R1 routine to webapp_queue write path; pilot 5 fires | Mohammad + Maaz | week of 2026-06-29 |
| W6 | Roll to R2 / R5 / R8 | Mohammad | week of 2026-07-06 |
| W7 (opt) | Migrate to `routines.callreceptionist.ai` custom domain | Mohammad | after pilot stable |

**During W0–W4**, Phase 1 pilot is NOT blocked. Routines fire to Teams self-chat fallback. Webapp is parallel work.

## Resolved (per M1–M4 supplementary 2026-05-27)

| ID | Resolution |
|---|---|
| WEB-OPEN-1 | **Vercel hosted on `*.vercel.app` to start**, optional migration to `routines.callreceptionist.ai`. NOT on `sulfurrecovery.com` — boundary hygiene. |
| WEB-OPEN-2 | **Two readers**: Maaz + Mohammad. Mohammad joins as a guest user in Maaz's tenant; Maaz shares the OneDrive folder with him. |
| WEB-OPEN-3 | OneDrive root path = `/SRE Routines/` (default). |
| M1 | Entra "Allow public client flows" = already enabled. No action. |

## Open items (require Mohammad scoping)

| ID | Question |
|---|---|
| WEB-OPEN-4 | Confirm Vercel free tier limits for the workload (well within 100 GB bandwidth, 1 GB serverless, 10s function duration — we have no serverless functions in v0 so this is a non-issue). |
| WEB-OPEN-5 | Manifest rotation policy — append-only with monthly compaction, or write-new-file each month? |
| WEB-OPEN-6 | First-load cost — bundle size budget for the SPA on a phone over LTE. Target ≤ 50 KB gzipped if vanilla, ≤ 150 KB if Next.js. |
| WEB-OPEN-7 | Framework choice — Next.js (App Router, Vercel-native) vs Vite + React (smaller bundle, simpler mental model). Default: Next.js for DX. |

## Why not the alternatives (recap)

| Option | Why ruled out |
|---|---|
| Pushover/Pushbullet | Adds a paid service ($5+) and a third-party that sees payload metadata. |
| iMessage relay (LoopMessage, Sendblue) | $30–50/mo and a third-party seeing payload content. |
| Mac Shortcuts bridge | Requires a Mac to stay on; brittle. |
| Teams chat-with-self only | Works fine as fallback but doesn't give a scrollable cross-routine history. |
| Email summary | Maaz already has 24,763 inbox items; routine output should NOT pile into that. |
| **Azure Static Web Apps** | Originally proposed in v0 — superseded by Vercel per M2. Both work; Vercel chosen for DX, boundary hygiene (not on `sulfurrecovery.com`), and Mohammad's likely toolchain. |
| **Multi-tenant Entra app** | Would let Mohammad sign in with his own org identity, but Files.Read.All would only see his own OneDrive — not Maaz's. Guest-user pattern is cleaner. |
| **Service-principal app credentials reading OneDrive** | Requires backend infra to hold the secret, expanding surface. Defer until there's a real reason (more readers, write-back, etc.). |
