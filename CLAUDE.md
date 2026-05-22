# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is (and isn't)

This is **not a code repo**. It's the orchestration repo for **SRE Claude Routines** — a portfolio of 26 scheduled-agent workflows that operationalize the Weekly OS for Sulfur Recovery Engineering Inc. (SRE). Every "artifact" in here is a markdown spec — a routine prompt, an audit-stage runbook, a connector check, a dashboard recipe — that drives Claude Code remote agents on a cron. There's no build, no tests, no compile step. There's no production code path you can `npm run dev`.

The single most important global rule, repeated everywhere: **drafts only**. No routine, skill, or agent sends, posts, or commits anything to a customer-facing surface without explicit operator review. Drafts go to `proposals/`, `email-drafts/`, Outlook drafts folder, or local notification surfaces — never directly to a recipient.

## How the four pieces fit together

```
┌──────────────────────────────────────────────────────────────────────┐
│ ~/.claude/skills/  (installed globally, 4 SRE-specific skills)       │
│   ms365-tenant-audit       — discovery: what's in the tenant         │
│   tenant-routine-author    — author scheduled-agent specs            │
│   sre-proposal-builder     — generate proposals in SRE structure     │
│   sre-email-drafter        — Maaz's voice + AIMS routing             │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ skills produce + consume artifacts in this repo
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ this repo (varun320/SRE-claude-automation-routine)                   │
│                                                                       │
│   runbook/ms365-deep-audit-workflow/   ← stages 00–13 + recipe       │
│   audits/<client-slug>-<date>/         ← audit output (gitignored)   │
│   routines/tier1..tier4/               ← cron specs by stake-level   │
│   routines/output/ + routines/logs/    ← runtime data (gitignored)   │
│   proposals/ + email-drafts/           ← skill output (gitignored)   │
│   connectors/connector-check.md        ← MS365 MCP smoke tests       │
│   scripts/ms365-login.{bat,ps1}        ← reliable device-code login  │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ /schedule registers these as remote agents
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Anthropic cloud (claude.ai/code/routines)                            │
│   cron-scheduled remote agents running the routine prompts           │
└──────────────────────────────────────────────────────────────────────┘
```

The two top-level plans drive everything:
- `SRE Claude Routines - Execution Plan.md` — **the WHAT** (26 routines, cadence, build prompts)
- `IMPLEMENTATION_PLAN.md` — **the HOW** (8-phase rollout, exit criteria, safety rules)

Read those two before any non-trivial change.

## Where the project is right now

- **Phase 0 complete** (M365 connection live, all 5 connector smoke tests pass — see `connectors/connector-check.md`)
- **Phase 1 in progress** — R1, R2, R5, R8 all drafted at `routines/tier1/*.md`, **all `status: draft`**, no crons registered yet. Operator hasn't approved any for pilot.
- **Audit ran 2026-05-21** — full output at `audits/sre-2026-05-21/` (gitignored locally). Findings are baked into every routine spec via `linked_audit_findings`.
- **Phase 2+ deferred** — R3 (draft replies), R4 (file writes), R12 (AR drafts), R13/R14 (Weekly + Zaheer) all wait for Phase 1 acceptance criteria.

When a fresh session starts, check `git log --oneline -3` + `routines/README.md` to see what's most recently changed.

## Commands that matter

### Working with routines

There are no `npm test` / `cargo build` style commands. The operational verbs are:

| Action | Command |
|---|---|
| List scheduled remote agents | `/schedule list` (skill auto-loaded) |
| Register a new cron from a routine spec | `/schedule` → choose "Create" → walk through prompts |
| Run a routine manually (one-shot) | `/schedule run <trigger_id>` |
| Smoke test connectors | run the 5 prompts in `connectors/connector-check.md` |
| Audit the tenant | invoke the `ms365-tenant-audit` skill |
| Draft a new routine spec | invoke the `tenant-routine-author` skill |
| Build a proposal | invoke the `sre-proposal-builder` skill |
| Draft an email in Maaz's voice | invoke the `sre-email-drafter` skill |

### MS365 MCP auth (this is the hardest part of working in this repo)

When `mcp__ms365__verify-login` returns `{"success": false}`, **do not call `mcp__ms365__login` from Claude** — its polling state doesn't reliably survive across tool calls. Use the standalone CLI instead:

```bash
cmd //c 'D:\projects\prodigy-ai\projects\routines-claude\scripts\ms365-login.bat'
```

The `.bat` sets the env vars, runs `npx -y @softeria/ms-365-mcp-server --login -v`, owns the polling end-to-end, and writes the token to `~/.config/ms365-mcp/.token-cache.json` — which Claude's MCP picks up automatically on the next call. After completion, `mcp__ms365__verify-login` should return success.

If you see `invalid_client`, the Entra app's **"Allow public client flows"** is off. Fix at Azure Portal → App registrations → AI My → Authentication → Advanced settings → toggle to Yes → Save.

### Git

```bash
git status                                 # see what's untracked / modified
git log --oneline -5                       # recent commits
git diff main..HEAD                        # what's about to be pushed
git push origin main                       # only when explicitly asked
```

Commit message style: lowercase conventional commits (`docs:`, `feat:`, `chore:`). Attribution disabled globally — do not add `Co-Authored-By` trailers.

## Architecture conventions baked in

### Routine tiers map to risk

`routines/tier1/` through `routines/tier4/` is **not file-organization shorthand** — it's the rollout phase. Tier-N requires Tier-(N-1) to have survived a full cycle. From `IMPLEMENTATION_PLAN.md`:

- **Tier 1** (Phases 1–4) — daily/weekly NA + ME cycle, weekly review, Zaheer update, AR
- **Tier 2** (Phase 5) — theme-day memos, AIMS country pre-briefs, pre-meeting briefs
- **Tier 3** (Phase 6) — monthly/quarterly compliance + lead capture
- **Tier 4** (Phase 7) — quarterly HQ touchpoints + framework reviews

A "ready" routine has `status: pilot` and a registered cron. A "drafted" routine has `status: draft` and exists in `tier{N}/` but the operator hasn't approved it.

### Hard anchors override cron

Every routine's `schedule.cron` MUST respect the operator's prayer / family / sleep windows. These live in `client-config.yaml` (gitignored — `runbook/ms365-deep-audit-workflow/client-config.yaml.draft` is the starting template). Concretely for Maaz (Calgary):

| Block | Time |
|---|---|
| Fajr / Zuhr / Asr / Maghrib / Isha | ~05:20 / ~14:00 / ~19:00 / ~21:00 / ~22:15 |
| Friday Jumua | 14:00–15:30 |
| Family time | 17:00–22:00 (ME-work-prep is an explicit exception at 21:55) |
| Sleep | 02:00–05:20 |

Routines with `hard_anchors_respected: true` self-check at run start and exit cleanly if local time falls in a hard-anchor window — even if cron fires.

### Mailbox-access scoping is mandatory

Maaz has full-mailbox-access to `dongreen@`, `inshanm@`, and `info@sulfurrecovery.com`. Any routine reading his inbox MUST filter by `toRecipients ∋ maaz@sulfurrecovery.com` — otherwise LinkedIn newsletters routed to Don Green pollute every triage. This is audit finding OQ-16; every Phase 1 spec encodes it. See `routines/tier1/R1-na-inbox-scan.md` for the canonical pattern.

### AIMS routing for ME customers

For Aramco / ADNOC / KNPC / SATORP / Q-Chem / Petro-Rabigh / Qatar Energy / etc., emails route via the AIMS bridge contact, not direct to end-customer. The mapping lives in `~/.claude/skills/sre-email-drafter/references/aims-routing-map.md`. Direct-to-end-customer emails for AIMS-bridged accounts are a relationship error.

### MS365 MCP gotchas

When working with the `mcp__ms365__*` tools, three patterns will burn you if you don't know them:

| Symptom | Why | Fix |
|---|---|---|
| `search-sharepoint-sites` returns empty `[]` | Tool is broken/scope-limited on many tenants | Use `mcp__ms365__search-query` with `entityTypes:["site"]` and `queryString:"<tenant-keyword>"` |
| `400 "Query option 'Top' is not allowed"` | A handful of endpoints reject `$top` | Drop `$top` for `list-joined-teams`, `list-my-associated-teams`, `list-my-installed-teams-apps` |
| `400 "Invalid entity type combination"` | `search-query` forbids mixing `message` + `event` | Split into separate calls per entity type |
| Tool result `exceeds maximum allowed tokens` | Calendar / mail pulls > ~50KB | Auto-saved to disk by the harness; dispatch a subagent to read+summarize in 230-line chunks |
| `get-my-manager` returns `404 Request_ResourceNotFound` | Org chart isn't populated in Entra | Treat as "no manager set", not as an error |
| `$skip` ignored on `list-users` | Graph quirk | Use `@odata.nextLink` from the response, not `$skip` |

Full cookbook: `~/.claude/skills/ms365-tenant-audit/references/mcp-tools-cookbook.md`.

### Calendar pulls overflow at ~50 events

For any time window > ~30 days, `get-calendar-view` will overflow the token cap. Chunk into 6-month windows, save each chunk's overflow file path, dispatch parallel subagents to read+summarize each. The pattern is documented in `~/.claude/skills/ms365-tenant-audit/SKILL.md` Stage 2B.

### Subagent prompt size limit

When dispatching subagents (Agent tool), keep the prompt under **~400 words**. Longer prompts return `Prompt is too long`. Put file paths + structured asks + verbatim quote requests in the prompt; leave detailed explanation to the subagent's own reads.

## What's gitignored and why

Aside from standard noise, the project deliberately excludes:

| Pattern | Reason |
|---|---|
| `audits/` | Live customer PII per audit-execution-recipe safety rules |
| `client-config.yaml` | Operator-filled, contains real customer + staff names. `.draft` IS committed. |
| `routines/output/` + `routines/logs/` | Runtime data populated when routines fire |
| `proposals/` + `email-drafts/` | Customer-specific drafts produced by skills |
| `MOSulfurPlus/` | Nested `.git/` (Replit-based Python app), would corrupt main repo |
| `*.pdf`, `*.docx`, `*.xlsx`, `*.pptx` | Large binaries, technical-library IP, Office documents. One existing tracked `.docx` is grandfathered. |
| `*.png`, `*.jpg`, `*.jpeg`, `**/Screenshot*` | May carry credentials / PII / internal screenshots |
| `*.pit`, `.env*`, `creds.*` | Credentials |

When in doubt: large binary or customer-content = ignore. Markdown spec / runbook / template = commit.

## Operator + collaborator

- **Maaz Ahmed Shareef** — Calgary — primary operator. CEO/GM of SRE. Global Administrator on the tenant. Owns every routine.
- **Mohammad** (`info@callreceptionist.ai`) — co-operator. Builds + maintains the routines + skills. Has full-mailbox-access via Maaz's account when running audits.

Tone in Maaz's voice: direct, technically precise, no corporate filler. See `~/.claude/skills/sre-email-drafter/references/maaz-voice-profile.md` for the canonical voice. When drafting on his behalf: never "I hope this email finds you well", never "kindly do the needful", never "ASAP".

## When something looks wrong

Before declaring a bug: check whether the audit (`audits/sre-2026-05-21/data/stage-2-to-7-summary.json` if it exists locally) already surfaced it as an open question (OQ-01 through OQ-23). Many "this seems off" observations are documented findings — the routine specs link back to the relevant OQ via `linked_audit_findings`. Resolve the OQ first, then change the routine.
