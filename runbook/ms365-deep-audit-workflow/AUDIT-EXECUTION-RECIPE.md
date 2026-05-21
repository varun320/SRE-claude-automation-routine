# Audit Execution Recipe — go from PLAN to live data

**Status note (2026-05-21).** This audit's pullers (under `lib/`) are not yet implemented. But Stage 1 — tenant discovery — is small enough to run **directly via the existing `mcp__ms365__*` tool surface** in any Claude session. This recipe shows exactly how.

**Why this file exists.** When we tried to verify the MS365 login from a Claude session today, it returned `device_code_required`. The login flow is interactive — it has to happen in Maaz's (or Mohammad's) own terminal, then the tokens carry forward to subsequent Claude sessions automatically.

---

## Pre-flight checklist

- [ ] `client-config.yaml.draft` reviewed with Maaz; every 🔴 and 🟡 confirmed
- [ ] File renamed to `client-config.yaml` and saved at `runbook/ms365-deep-audit-workflow/client-config.yaml`
- [ ] Audit-run directory created: `audits/sre-<YYYY-MM-DD>/raw/tenant/`
- [ ] `audits/` added to `.gitignore` (audit data contains PII — must not commit)

```bash
# from the routines-claude project root:
mkdir -p audits/sre-$(date +%Y-%m-%d)/raw/tenant
grep -qxF 'audits/' .gitignore || echo 'audits/' >> .gitignore
```

---

## Step 1 — Authenticate the MS365 MCP server

The MCP exposes `mcp__ms365__login`, but the actual device-code prompt appears in **Maaz/Mohammad's terminal**, not inside Claude. Two paths:

### Option A — Login from a terminal session (recommended)

If the ms365 MCP is launched as a CLI-wrapped server (per the `README_setup_mcp_Server.md` in this project), run its login subcommand directly in PowerShell:

```powershell
# Whatever command the MCP wraps — typically:
npx ms365-mcp-server --login
# follow the device-code URL it prints; sign in as Maaz; close the tab when it says "you can return to your app"
```

Then verify in any Claude session:

```text
Run mcp__ms365__verify-login → expect {"success": true, ...}
Run mcp__ms365__list-accounts → expect Maaz's account listed
```

### Option B — Login from Claude

In a Claude session, ask: *"Run `mcp__ms365__login` and give me the device-code URL"*. Claude calls the tool; the response contains a URL + code; you complete the login in your browser; come back and ask Claude to re-verify.

---

## Step 2 — Run Stage 1 (tenant discovery) — read-only metadata sweep

Once authenticated, paste this into a fresh Claude session inside this project:

> Read `runbook/ms365-deep-audit-workflow/01-tenant-discovery.md` then execute Stage 1 against the live tenant. Save every raw response to `audits/sre-<today>/raw/tenant/<name>.json`. Use only the tool families listed in §1.1 through §1.8. Do not pull mail bodies, document bodies, chat messages, or meeting transcripts. After all calls complete, write `audits/sre-<today>/data/tenant-summary.json` per the schema in §3 of that runbook. Report the `openQuestions` array at the end.

Claude will then iterate through these tools (representative — exact order in `01-tenant-discovery.md`):

1. `mcp__ms365__get-current-user` — confirms identity is Maaz
2. `mcp__ms365__get-my-manager`, `mcp__ms365__list-my-direct-reports`
3. `mcp__ms365__list-users` (paginated)
4. `mcp__ms365__list-groups` → `mcp__ms365__list-group-members` per group
5. `mcp__ms365__list-mail-folders` (Maaz's)
6. `mcp__ms365__get-mailbox-settings` (Maaz's)
7. `mcp__ms365__list-mail-rules`
8. `mcp__ms365__list-contact-folders`
9. `mcp__ms365__list-calendars` + `mcp__ms365__list-my-calendar-permissions`
10. `mcp__ms365__search-sharepoint-sites` with `q="*"`
11. `mcp__ms365__list-drives`
12. `mcp__ms365__list-joined-teams` + `mcp__ms365__list-my-associated-teams`
13. `mcp__ms365__list-team-channels` per team
14. `mcp__ms365__list-chats` (page-1 metadata)
15. `mcp__ms365__list-online-meetings` (page-1 metadata)
16. `mcp__ms365__list-onenote-notebooks`
17. `mcp__ms365__list-todo-task-lists`
18. `mcp__ms365__list-my-installed-teams-apps`
19. `mcp__ms365__list-my-memberships`

Expected wall-clock: ~3–8 minutes for SRE-scale tenant.

Each call's JSON output is saved literally under `raw/tenant/`. Then a small synthesizer pass writes `data/tenant-summary.json` per §3 of the runbook.

---

## Step 3 — Review the tenant summary with Maaz

Open `audits/sre-<today>/data/tenant-summary.json`. The `openQuestions` array is the human-review surface. Walk through each item:

- User count looks right? (within ±10% of mental model)
- Every named SRE staff member appears in `users.json`?
- Every customer-y SharePoint site is there? (e.g. "SRE Operations" or whatever the equivalent is)
- Drives + Teams counts match expectation?
- AIMS partners visible as guests OR confirmed external?
- Any unexpected site / mailbox / drive surfaces?

Any answer becomes a `client-config.yaml` update — re-save and proceed.

---

## Step 4 — Pick the first deep-pull stage

Stage 1 is a sweep. Stages 2–7 are deep pulls. Recommended first deep pull: **Stage 2A (Outlook Mail)** because it unblocks four Tier-1 routines (R1, R3, R5, R6) at once.

To run it (when implemented in `lib/`):

```bash
GHL_PIT_TOKEN=... PYTHONPATH=. python3 lib/pull_mail.py \
  --client-config client-config.yaml \
  --audit-dir audits/sre-$(date +%Y-%m-%d)
```

Until `lib/pull_mail.py` exists, the same logic can be run from a Claude session by reading `02-outlook-mail-audit.md` and iterating the MCP tools accordingly.

---

## Step 5 — When ready for full pipeline

The full sequence (when `lib/run_audit.py` exists):

```bash
python3 lib/run_audit.py \
  --client-config client-config.yaml \
  --audit-dir audits/sre-$(date +%Y-%m-%d)
```

It runs stages 1 → 11 in safe order, producing every JSON + every HTML dashboard.

---

## Safety reminders (every single run)

1. The audit NEVER calls any `mcp__ms365__create-*`, `update-*`, `delete-*`, `send-*`, `set-*`, `move-*`, `accept-*`, `decline-*`, `reply-*`, `forward-*`, `pin-*`, `unpin-*` tool. Read-only path.
2. The audit NEVER calls `mcp__ms365__download-bytes` unless the operator has opted into OCR for a specific stage AND for a specific file class.
3. The audit NEVER persists data outside `audits/sre-<date>/`.
4. The audit NEVER uploads data to any external service. Dashboards are self-contained HTML on disk.
5. `audits/` is in `.gitignore`. Never commit raw audit output.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `device_code_required` from `mcp__ms365__login` | No active token; need to complete device-code flow | Run login from terminal (Step 1, Option A); verify-login again |
| `verify-login` returns `success: false` after device-code | Token didn't persist; MCP server may need restart | Restart the ms365-mcp-server process, then login again |
| `403` on `list-users` | App permissions not consented for `User.Read.All` | Admin re-consent in the Entra app (already done per Phase 0; re-check token scopes) |
| Slow first run | Cold caches, single-stream pagination | Normal — Stage 1 takes 3–8 min. Stage 2A can take 30+ |
| `Cloudflare 1010` errors | UA header rejected | The MCP handles this internally; if you call Graph directly, set a browser UA |

---

## What gets unblocked when Stage 1 is done

After Stage 1 ships its `tenant-summary.json`, the following downstream stages have everything they need:
- **2A Mail** — needs the mailbox folder list (have it)
- **2B Calendar** — needs the calendar list (have it)
- **2C Contacts** — needs the contact folder list (have it)
- **3 SharePoint** — needs the site list (have it)
- **4 OneDrive** — needs the drive list (have it)
- **5 Teams** — needs the joined-team + channel + chat lists (have it)
- **6 Planner/ToDo** — needs the task-list inventory (have it)
- **7 OneNote** — needs the notebook list (have it)

Stages 8 (Customer 360) and 9 (Sales Pipeline) only need the outputs of 2–7 — they don't pull anything new.

---

## In-session next actions for Mohammad

1. Decide where Maaz will do the device-code login (terminal vs in-Claude). Send him the 3-line instruction.
2. Walk Maaz through `00-discovery-questionnaire.md` (PRE-FILLED version) — ~20 min.
3. Save the reviewed answers as `client-config.yaml`.
4. Trigger Stage 1 from a Claude session using the prompt in Step 2 above.
5. Open `tenant-summary.json` together; resolve `openQuestions`.
6. Then start implementing `lib/pull_mail.py` for Stage 2A, OR keep iterating Stage 1's review until everything looks right.
