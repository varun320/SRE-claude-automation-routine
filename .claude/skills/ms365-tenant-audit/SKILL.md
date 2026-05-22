---
name: ms365-tenant-audit
description: Run a read-only Microsoft 365 tenant audit for any client — discovers users, groups, mailboxes, calendars, SharePoint, OneDrive, Teams, OneNote, Planner via the MS-365 MCP server, persists raw JSON, synthesizes a dashboard. Use when starting a client engagement, doing pre-routine discovery, producing a CEO briefing for a new tenant, or building a Customer-360 baseline before automation work.
---

# MS-365 Tenant Audit

A reusable, read-only audit workflow against any Microsoft 365 tenant via the `@softeria/ms-365-mcp-server`. Produces a per-client `audits/<client-slug>-<date>/` directory with raw JSON evidence, a synthesized tenant summary with open questions, and a single-file HTML dashboard for executive walk-through.

This skill is **read-only**. It never calls `create-*`, `update-*`, `delete-*`, `send-*`, `set-*`, `move-*`, `accept-*`, `decline-*`, `reply-*`, `forward-*`, `pin-*`, or `unpin-*` MS365 tools. It does not read mail/document/chat bodies — only metadata, folder structures, attendee lists, subjects, and timestamps.

---

## When to use

- Onboarding a new client and needing to know what's in their M365 environment before scheduling routines
- Pre-flight before any automation that will write to a tenant (so you know what's already there)
- Producing a CEO/executive briefing that surfaces drift between assumed-state and observed-state
- Building Customer-360 baseline data for sales-pipeline inference
- Cleaning up after an acquisition / re-org (who's still active, what mailboxes are shared, what sites are dormant)
- Compliance / sale-process due diligence (with explicit redaction)

## When NOT to use

- The user only needs one specific Graph query — call `mcp__ms365__*` directly
- The tenant isn't yet authenticated and the user doesn't want a multi-stage discovery
- The audit needs to write — this skill is metadata-only

---

## Skill contents

```
~/.claude/skills/ms365-tenant-audit/
├── SKILL.md                          ← this file
├── references/
│   ├── mcp-tools-cookbook.md         ← which MS365 MCP tool to call per stage + gotchas
│   ├── authentication-playbook.md    ← Entra setup, public-client flow, .bat workaround
│   ├── dashboard-template.html       ← single-file GHL-style dark dashboard, parameterized
│   └── open-questions-framework.md   ← OQ categories, priority levels, resolution paths
├── templates/
│   ├── client-config.yaml.template   ← per-client config skeleton
│   └── discovery-questionnaire.md.template ← 20-question intake form for the operator
└── scripts/
    └── ms365-login.bat               ← reliable standalone device-code login
```

---

## Pre-flight (run before Stage 1)

Before touching any MS365 tool, confirm:

1. **MS-365 MCP server is installed** in Claude's MCP config (`~/.claude.json` → `mcpServers.ms365`). The reliable command is:
   ```json
   { "type": "stdio", "command": "cmd", "args": ["/c", "npx -y @softeria/ms-365-mcp-server --org-mode"] }
   ```

2. **Entra app registered + public client flows ON**. Read `references/authentication-playbook.md`. The most common failure is `invalid_client` from Microsoft → fix: Azure Portal → App registrations → <app> → Authentication → Advanced settings → Allow public client flows = **Yes** → Save.

3. **Token cache exists**. Run `mcp__ms365__verify-login`. If it returns `{"success": false, "message": "No valid token found"}`, use `scripts/ms365-login.bat` (configure CLIENT_ID + TENANT_ID first) and have the operator complete the device-code flow in their browser. The standalone process owns polling end-to-end; Claude's MCP picks up the persisted token afterward.

4. **Discovery questionnaire**. Walk the operator through `templates/discovery-questionnaire.md.template` (~20 min) to capture client-specific assumptions: primary domain, staff roster, key customers, shared mailboxes, sale-process flags, redaction targets. Save the answered version as `audits/<client>-<date>/discovery-questionnaire.md` and produce `audits/<client>-<date>/client-config.yaml` from `templates/client-config.yaml.template`.

5. **`audits/` is gitignored.** Audit output contains live PII; it must not be committed.

---

## Output directory structure

Every audit lands at:

```
audits/<client-slug>-<YYYY-MM-DD>/
├── discovery-questionnaire.md       ← operator-answered intake
├── client-config.yaml               ← single source of truth for this audit run
├── raw/
│   ├── tenant/      (~20 files)    ← Stage 1: users, groups, mailbox, drives, teams, chats, OneNote, ToDo, apps, memberships
│   ├── mail/        (2+ files)     ← Stage 2A: Inbox + Sent metadata samples
│   ├── calendar/    (1+ files)     ← Stage 2B: calendar-view per quarter
│   ├── contacts/    (1 file)       ← Stage 2C
│   ├── sharepoint/  (1+ files)     ← Stage 3
│   ├── onedrive/    (1 file)       ← Stage 4
│   ├── teams/       (1 file)       ← Stage 5
│   ├── planner-todo/ (1 file)      ← Stage 6
│   └── onenote/     (1 file)       ← Stage 7
├── data/
│   ├── tenant-summary.json         ← Stage 1 synthesis + initial openQuestions
│   └── stage-2-to-7-summary.json   ← Stages 2-7 synthesis + new openQuestions
└── dashboards/
    └── audit-report.html           ← parameterized from references/dashboard-template.html
```

---

## Stage workflow

### Stage 1 — Tenant discovery (read-only metadata sweep)

**Goal**: Enumerate every surface in the tenant before pulling any business data. Saves under `raw/tenant/`.

**MCP tools (parallel batch where possible)**:

- `get-current-user` — confirm identity (refuse if not the expected operator)
- `get-my-manager`, `list-my-direct-reports` — org chart (often empty)
- `list-users` (top 50, `ConsistencyLevel: eventual`, `$select` narrow)
- `list-groups` (top 50, same headers)
- `list-mail-folders` (Maaz's), `get-mailbox-settings`, `list-mail-rules` (use Inbox folder id)
- `list-contact-folders`
- `list-calendars`, `list-my-calendar-permissions`
- `list-drives`
- `list-joined-teams`, `list-my-associated-teams` — **do NOT pass `$top`**, these endpoints reject it (Graph 400)
- `list-team-channels` per joined team
- `list-chats` (top 50)
- `list-onenote-notebooks`
- `list-todo-task-lists`
- `list-my-installed-teams-apps` — **do NOT pass `$top`** (Graph 400)
- `list-my-memberships`

**SharePoint sites — do NOT use `search-sharepoint-sites`** (returns empty on many tenants — believed broken or scope-limited). Use:
```
mcp__ms365__search-query  body={"requests":[{"entityTypes":["site"],"query":{"queryString":"<tenant-keyword>"},"from":0,"size":25,"fields":["id","name","webUrl","createdDateTime","lastModifiedDateTime","description"]}]}
```

**Persist**: each tool's response → its own JSON file under `raw/tenant/<name>.json`. Write a `_finding` annotation when the data implies something non-obvious (e.g., zero inbox rules with high unread, Entra-disabled user with active mailbox traffic, etc).

**Synthesize**: write `data/tenant-summary.json` per the schema below:

```json
{
  "generatedAt": "ISO",
  "tenantDomain": "...",
  "tenantId": "...",
  "operator": { "id":"...", "displayName":"...", "mail":"...", "directoryRoles":[], "timeZone":"...", "workingHours":{} },
  "totals": { /* counts of users / groups / mailFolders / sites / drives / teams / channels / chats / notebooks / tasks / apps */ },
  "mailbox_signals": { "inbox_total":N, "inbox_unread":N, "inbox_unread_pct":"...", "sent_total":N, ... },
  "shared_mailboxes_detected": [ {upn, name, active, _likely_routine}, ... ],
  "key_active_internal_users": [ {name, upn, entraTitle, planRole, _flag}, ... ],
  "openQuestions": [ {id, priority, category, question, actionIfX}, ... ]
}
```

Stage 1 acceptance: every JSON file listed above is populated; `tenant-summary.json` exists; `openQuestions` is non-empty and surfaces real ambiguity (not boilerplate).

### Stage 2A — Mail audit

**Goal**: Sample recent traffic to characterize inbox shape, sent-item patterns, and pipeline-stage signals. Save under `raw/mail/`.

**Pulls (per scoped mailbox)**:
- `list-mail-folder-messages` on Inbox folder: `$top=20`, `$orderby=receivedDateTime desc`, `$select=id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,categories,conversationId,importance`. **Do NOT include `body` or `bodyPreview`** — these are body content.
- Same on Sent Items: `$select=id,subject,toRecipients,sentDateTime,hasAttachments,categories,conversationId`.

**Analysis hooks**:
- Count of LinkedIn-newsletter / alarm.com / external-marketing noise in last-N inbox
- Pipeline-stage signal regexes against subject lines (see open-questions-framework for the regex set: `proposal_subject_regex`, `invoice_subject_regex`, `rfq_subject_regex`, `contract_subject_regex`, `ar_followup_regex`)
- Closing-event detection: `PO Signing`, `PO Approved`, `Awarded`, `Order Placed`
- Mailbox-access leak: does the operator's Inbox contain messages whose `toRecipients` are different mailboxes? Flag as routine-scoping issue.

### Stage 2B — Calendar audit

**Goal**: Surface recurring meetings, customer touchpoints, and Day-Clock vs observed-cadence drift over a 2-year window.

**Pulls (chunked)**:

`get-calendar-view` will overflow token limits past ~50 events. Chunk into 4 × 6-month windows for a 2-year audit:

```
2024-05-21 → 2024-11-20
2024-11-21 → 2025-05-20
2025-05-21 → 2025-11-20
2025-11-21 → 2026-05-21
```

Per chunk: `$select=id,subject,start,end,isOnlineMeeting,categories,isAllDay,sensitivity,showAs,type` (NO attendees, NO location, NO organizer — these explode response size). `$top=200`. `timezone="America/Edmonton"` or whatever matches the operator's mailbox settings.

Each chunk WILL still overflow — Graph saves it to disk and returns the file path. Use a subagent (general-purpose) to read each file in 230-line chunks and return a structured summary. Send 4 subagents in parallel with prompts under 400 words each (longer prompts get "Prompt is too long").

**Synthesize** to `raw/calendar/calendar-Nyr-aggregate.json`:
- `monthly_counts`: events per ISO month across the window
- `recurring_meetings`: subjects appearing 3+ times, with span + cadence + first/last seen
- `customer_touch_<N>yr`: per-customer count + first/last seen + region + stage hint, generated from subject-keyword match against the customer list in client-config.yaml

### Stage 2C — Contacts audit

**Goal**: Determine whether Outlook contacts is a source of truth or a sync target.

**Pulls**: `list-contact-folder-contacts` for each folder (use the folder ids from Stage 1 `list-contact-folders`).

**Finding to look for**: An empty Zoho-or-CRM-sync folder means contact data lives in the external CRM, not Outlook. Routines must hit the CRM API directly.

### Stage 3 — SharePoint audit

**Goal**: Inventory tenant sites and understand the file hierarchy.

**Pull**: `search-query` with `entityTypes:["site"]`, `queryString:"<tenant-keyword> OR <tenant-onmicrosoft-prefix>"`, `size:25`. Returns total + first page. Paginate by adjusting `from`.

**Look for**:
- A `/sites/Projects` (modern) coexisting with classic root paths like `/Clients/<Customer>/<ProjectId>/`
- Site descriptions that admit current-state (`"Zoho is replacing X"` / `"this site is deprecated"` are common)
- Alphabetical bucket sites (`/ClientsA-D`) implying parallel A-Z buckets

### Stage 4 — OneDrive audit

**Goal**: Map the operator's personal drive root and flag sensitive folders.

**Pull**: `list-folder-files` with `driveId=<from Stage 1>`, `driveItemId="root"`, `$select=id,name,folder,file,size,createdDateTime,lastModifiedDateTime,webUrl`, `$top=50`.

**Flag**:
- Folders with names containing `DD`, `Due Diligence`, `Sale`, `Confidential`, `Board`, `M&A` → likely sale-process / restricted, add to `redaction.folders` in client-config
- Banking PDFs / offer letters at root → HR/finance leakage candidates
- Stale folders untouched > 18 months — candidates for archive cleanup

### Stage 5 — Teams audit

**Goal**: Map joined teams and channels, identify private/dormant ones.

**Pulls**: `list-team-channels` per joined team id from Stage 1. NO message bodies.

### Stage 6 — Planner & ToDo audit

**Goal**: Determine whether Microsoft ToDo is in active use or dead.

**Pulls**: `list-todo-tasks` per list (use list ids from Stage 1). NOTE: ToDo `$select` is not supported — Graph returns 400 if you pass it.

**Finding to look for**: < 5 tasks in a 12-week window across all lists = dead surface. Real task tracking lives elsewhere (ClickUp, Zoho Projects, Asana, etc).

### Stage 7 — OneNote audit

**Goal**: Determine whether OneNote is an active note surface.

**Pulls**: `list-onenote-notebook-sections` per notebook id from Stage 1.

**Finding to look for**: All notebooks have last-modified > 12 months ago, or contain only "Quick Notes" section → dead surface.

---

## Synthesis after Stage 7

Write `data/stage-2-to-7-summary.json` with:

```json
{
  "generatedAt": "ISO",
  "scope": "Stages 2A-7",
  "stage_status": { "2A_mail": "...", "2B_calendar": "...", ... },
  "stage_2A_mail_findings": [...],
  "stage_2B_calendar_findings": [...],
  "stage_2C_contacts_findings": [...],
  "stage_3_sharepoint_findings": [...],
  "stage_4_onedrive_findings": [...],
  "stage_5_teams_findings": [...],
  "stage_6_planner_todo_findings": [...],
  "stage_7_onenote_findings": [...],
  "openQuestions_resolved_this_pass": [{ id, status, resolution }],
  "newOpenQuestions": [...],
  "client_config_updates_needed": [...],
  "stage_8_synthesis_readiness": "READY | NEEDS_X"
}
```

---

## Dashboard

Copy `references/dashboard-template.html` into `audits/<client>-<date>/dashboards/audit-report.html`. The template has clearly marked `<!-- DATA -->` blocks at the bottom where you inject:

- `META` (operator, tenant, audit_date)
- `METRICS` (12 scorecard tiles — adapt to the numbers from synthesis)
- `FINDINGS` (10–15 finding cards with `sev`/`cat`/`title`/`body`)
- `CUSTOMERS` (rows for the customer-touch table)
- `STAFF`, `AIMS`, `SHARED_MAILBOXES`
- `MONTHLY` (calendar bar chart, from calendar-Nyr-aggregate)
- `RECURRING` (recurring-meeting cards)
- `OQ` (open questions list)

The dashboard is single-file, no external assets except Inter + JetBrains Mono via Google Fonts CDN. Opens in any modern browser, has print-friendly styles, scroll-spy nav, modal drill-down, searchable/sortable tables. Inspired by the GHL-account-overview style: dark theme, sulfur-amber accent (#F0B53C — change in `:root` to match client brand), tabbed sections, dense data tables.

---

## Safety rules (every audit must honor)

1. NEVER call any `create-*`, `update-*`, `delete-*`, `send-*`, `set-*`, `move-*`, `accept-*`, `decline-*`, `reply-*`, `forward-*`, `pin-*`, `unpin-*` MS365 tool. Read-only path.
2. NEVER pull mail bodies, document bodies, chat messages, or meeting transcripts. Even when calling `list-mail-folder-messages`, omit `body` and `bodyPreview` from `$select`.
3. NEVER call `download-bytes` unless the operator has opted into OCR for a specific stage AND a specific file class.
4. NEVER persist data outside `audits/<client>-<date>/`.
5. NEVER upload audit output to any external service. Dashboards are self-contained HTML on disk.
6. `audits/` MUST be in `.gitignore`. Raw audit output must not be committed.
7. Honor `confidentiality.redact_sale_process_buyer` and any per-folder/per-customer redaction from client-config.

---

## Generalization notes — adapting to a new client

The audit workflow is tenant-agnostic. To adapt:

1. **Discovery questionnaire** — different client, different answers. The questions don't change.
2. **client-config.yaml** — fill in domain, operator, customer list, shared mailboxes, sales stages, geography, file paths.
3. **Customer keyword set** for Stage 2B subject matching — refresh per client (e.g., for an oil-and-gas EPC: Aramco, ADNOC, QChem; for a SaaS shop: known customer logos).
4. **Stage hints in customer-touch table** — the state names (`lead`, `qualified`, `rfq_received`, `proposal_sent`, `po_signed`, `in_execution`, etc) are defined in `client-config.sales_stages` — adapt the definitions per client's sales motion.
5. **Dashboard accent color** — `--accent` in dashboard-template.html is sulfur-amber by default; change to match client brand. Default fallbacks: GHL-green `#3CD49D`, Anthropic-orange `#E67E50`, Microsoft-blue `#0078D4`.
6. **Redaction list** — every client has its own DD / sale-process / board-only folders. Capture these in discovery and apply to outputs.

---

## Estimated wall-clock

For a tenant with ~50 active users, ~100 groups, ~200 SharePoint sites, ~25k inbox items:

| Stage | Time |
|---|---|
| Pre-flight (auth + questionnaire) | 30 min (Entra config + walking operator through questionnaire) |
| Stage 1 — tenant discovery | 3–8 min (parallel calls + writes) |
| Stage 2A — mail samples | 2 min |
| Stage 2B — calendar 24mo | 10–15 min (4 chunks + 4 parallel subagents) |
| Stage 2C — contacts | 1 min |
| Stage 3 — SharePoint sites | 2 min |
| Stage 4 — OneDrive root | 1 min |
| Stage 5 — Teams channels | 1 min |
| Stage 6 — ToDo tasks | 1 min |
| Stage 7 — OneNote sections | 1 min |
| Synthesis | 5 min |
| Dashboard generation | 5 min |
| **Total** | **~75 min** (excludes operator walkthrough) |

---

## When something breaks

| Symptom | Likely cause | Fix |
|---|---|---|
| `device_code_required` from `mcp__ms365__login` | No active token | Run `scripts/ms365-login.bat` (operator completes device code in browser) |
| `verify-login` returns false after login | Polling timed out OR token cached elsewhere | Re-run standalone `--login`; ensure `MS365_MCP_TOKEN_CACHE_PATH` matches Claude's MCP env |
| `invalid_client` from Microsoft | Public client flows NOT enabled in Entra app | Azure Portal → app → Authentication → Allow public client flows = Yes → Save |
| `invalid_grant` | App permissions not consented OR wrong tenant | Re-consent in Entra; verify `MS365_MCP_TENANT_ID` matches the operator's tenant |
| `403 Forbidden` on `list-users` | Token lacks `User.Read.All` scope | Admin consent for the app |
| `400 Bad Request "Top is not allowed"` | Endpoint rejects `$top` | Drop `$top` for: `list-joined-teams`, `list-my-associated-teams`, `list-my-installed-teams-apps`. Drop `$select` for: `list-todo-task-lists`, `list-todo-tasks` |
| `400 "Invalid entity type combination"` | `search-query` got both `message` and `event` | Call separately — Graph forbids cross-entity search for these two |
| `search-sharepoint-sites` returns empty | Known broken-or-limited on many tenants | Use `search-query` with `entityTypes:["site"]` instead |
| Tool result overflows token cap | Response > ~50KB | Result auto-saved to disk by the harness; dispatch a subagent to read+summarize the file in 230-line chunks |

---

## What this skill explicitly does NOT do

- Customer-360 join (Stage 8) — separate skill / manual synthesis pass after this audit lands
- Sales-pipeline state-machine inference (Stage 9) — same
- Skills-extraction (Stage 11+) — same
- Pulling Zoho / ClickUp / Asana / external CRM data — out of scope; the audit will surface the dependency, but a separate connector skill should be built per external system

---

## Quick-start invocation

When invoked, ask the operator three questions and proceed:

1. **Client slug** (e.g., `acme-corp`, `sre`) — used in directory names and dashboard branding.
2. **Audit window** (default: 2 years back to today, +6 months ahead for calendar).
3. **Operator email** — the account that will be authenticated; refuse if `verify-login` returns a different `userPrincipalName`.

Then run pre-flight → Stages 1–7 → synthesis → dashboard. Surface every open question to the operator at the end and write the dashboard path so they can open it.
