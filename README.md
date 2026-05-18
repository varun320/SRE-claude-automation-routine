# SRE Claude Routines

Operationalize a portfolio of recurring SRE / GM workflows as **scheduled Claude Code remote agents**. Each routine is one self-contained prompt that fires on cron, talks to real connectors (Outlook, Calendar, Teams, ClickUp, the project tracker), and writes drafts or logs back into this repo.

> Drafts only. No routine sends, posts, or commits without human review.

## Status

Pre-Phase-0. Repo skeleton, connector inventory, and implementation plan are in place. Phase 0 smoke tests against the ms365 MCP server and the project tracker still need to run before Tier 1 routines are scheduled.

## Repo Layout

```
routines-claude/
├── README.md                              # this file
├── SRE Claude Routines - Execution Plan.md   # the WHAT — 26 routines, tiers, cadence
├── IMPLEMENTATION_PLAN.md                 # the HOW — 8-phase rollout
├── setup.md                               # ms365 MCP setup for teammates
├── README_setup_mcp_Server.md             # full @softeria/ms-365-mcp-server reference
├── M365_Claude_Connection_Plan.docx       # M365 → Claude connection plan
├── connectors/
│   └── connector-check.md                 # one smoke-test prompt per connector
├── routines/
│   ├── tier1/ … tier4/                    # one .md per scheduled routine
├── logs/
│   ├── runs/ cost/ incidents/
└── playbooks/
    ├── add-routine.md
    ├── edit-routine.md
    └── kill-switch.md
```

## Quick Start — ms365 MCP

The Microsoft 365 MCP server is the primary connector for Outlook mail, calendar, and Teams. Full instructions: [`setup.md`](setup.md).

```bash
# macOS / Linux
claude mcp add ms365 -s user -- npx -y @softeria/ms-365-mcp-server --org-mode

# Windows (cmd /c wrapper required)
claude mcp add ms365 -s user -- cmd /c "npx -y @softeria/ms-365-mcp-server --org-mode"
```

Then inside Claude Code: call `login` → open the URL with the device code → call `verify-login`.

## Guiding Principles

1. **Drafts only.** Output is Outlook drafts, file writes, or notifications — never auto-sends.
2. **One routine = one scheduled agent.** Maps 1:1 to Claude Code's `/schedule` skill. No bundling.
3. **Cron in Calgary local time** (`America/Edmonton`). Never schedule inside prayer / family / sleep windows.
4. **Validate before scaling.** A tier ships only after the prior tier survives one full cycle.
5. **Project files are the source of truth.** Routine prompts, outputs, and logs live in this repo so they are versioned and reviewable.

## Key Documents

| Document | Purpose |
|---|---|
| [`SRE Claude Routines - Execution Plan.md`](SRE%20Claude%20Routines%20-%20Execution%20Plan.md) | The 26-routine portfolio, tiers, and cadence |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | 8-phase rollout, exit criteria per phase |
| [`setup.md`](setup.md) | ms365 MCP install for a new machine / teammate |
| [`README_setup_mcp_Server.md`](README_setup_mcp_Server.md) | Upstream `@softeria/ms-365-mcp-server` reference |
| [`connectors/connector-check.md`](connectors/connector-check.md) | Smoke tests for each connector |

## Owner

Maaz Ahmed Shareef · Calgary
