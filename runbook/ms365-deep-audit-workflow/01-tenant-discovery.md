# Stage 1 — Tenant Discovery

**Purpose.** Enumerate the universe of the MS365 tenant *before* pulling any business data. Establishes:
- The user/group/site/team graph (who and what exists)
- Mailbox + shared-mailbox inventory
- Site + drive + Teams inventory
- Per-source pagination shape, so later stages can plan parallelism + API budget

**Why first.** Every downstream stage (mail, calendar, SharePoint, OneDrive, Teams, Planner, OneNote) iterates over entities discovered here. Skipping this stage means each downstream stage has to re-discover its own scope, producing inconsistent universes across runs.

**Pre-requisite.** `client-config.yaml` from stage 0 — specifically the `in_scope_mailboxes_full` list, `excluded_sites`, `excluded_users`.

**Safety.** This stage is purely **read directory-level metadata**. No mail body, no document body, no chat content. Safe to run unattended.

**Run time estimate.** 1–5 minutes for a tenant SRE's size.

---

## What gets pulled

### 1.1 Identity

| Pull | MCP tool | Notes |
|---|---|---|
| Current user | `get-current-user` | Confirms which identity the PIT token represents. Audit MUST refuse to run if this isn't Maaz's account (configurable via `client-config.yaml`). |
| Manager + reports | `get-my-manager`, `list-my-direct-reports` | Captures the org structure Maaz sees. |
| All users in tenant | `list-users` (paginated) | Directory-level only: name, UPN, mail, title, department. NOT mailbox settings unless in scope. |
| Groups | `list-groups` (paginated) | Captures M365 groups, security groups, distribution lists. |
| Group members | `list-group-members` per group | Used later to attribute account ownership (e.g. "Ashley's NA accounts"). |
| Group owners | `list-group-owners` per group | Same purpose. |

**Notes on `$search` headers.** The `list-users` and `list-groups` calls that filter by name need `ConsistencyLevel: eventual`. The MCP exposes that — pullers must pass it.

### 1.2 Mail surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Maaz's mail folders | `list-mail-folders` | Captures folder tree. Used later as scoping for mail audit (some folders may be excluded). |
| Maaz's mailbox settings | `get-mailbox-settings` | Time zone, working hours, automatic replies — needed for time-allocation calculations later. |
| Maaz's mail rules | `list-mail-rules` | Inventoried so we can later flag rules that point at folders no longer being read (dead rules). |
| Shared mailbox folder lists | `list-shared-mailbox-messages` (folder-list only, page 1) | For each shared mailbox in `client-config.yaml`. |
| Maaz's contact folders | `list-contact-folders` | Folder tree only; contacts pulled in stage 2C. |

### 1.3 Calendar surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Calendars Maaz can see | `list-calendars` | Default + any extra calendars (shared/team). |
| Permissions on Maaz's primary calendar | `list-my-calendar-permissions` | So we know who else can see the Weekly OS. |
| Time zones supported by tenant | `list-supported-time-zones` (cached once) | Reference data. |

### 1.4 SharePoint surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Search all sites | `search-sharepoint-sites` with `*` | First-pass enumeration. Stage 3 will deepen this site by site. |
| Sites delta | `get-sharepoint-sites-delta` | For incremental runs later. Captures the initial delta token. |
| Per-site basic metadata | `get-sharepoint-site` for each | Just web URL, name, last activity. Lists + items come in stage 3. |

### 1.5 OneDrive surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Drives the operator can see | `list-drives` | Includes Maaz's personal drive plus any group/site drives reachable. |
| Drive roots | `get-drive-root-item` per drive | Used to know if a drive has anything at all before stage 4 walks it. |

### 1.6 Teams surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Joined teams | `list-joined-teams` | Maaz's primary org-level Teams membership. |
| Associated teams | `list-my-associated-teams` | Includes recently-followed teams beyond explicit joins. |
| Channels per team | `list-team-channels` per joined team | Channel inventory (messages come in stage 5). |
| Chats | `list-chats` (page 1 only, metadata) | We don't pull chat messages here — just chat IDs + members + lastUpdated. |
| Online meetings (recent) | `list-online-meetings` page 1 | Sanity check of how many meetings have recordings. |

### 1.7 Planner / ToDo surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Maaz's installed Teams apps | `list-my-installed-teams-apps` | Detects whether Planner / ToDo apps are present. |
| Maaz's memberships | `list-my-memberships` | Captures the planner-relevant groups. |
| Plans visible to Maaz | (implicit via groups) | Plans live under groups; stage 6 walks them. |
| ToDo task lists | `list-todo-task-lists` | List inventory only; tasks pulled in stage 6. |

### 1.8 OneNote surfaces

| Pull | MCP tool | Notes |
|---|---|---|
| Notebooks visible to Maaz | `list-onenote-notebooks` | Inventory only; pages pulled in stage 7. |
| SharePoint-hosted notebooks | (per site) `list-sharepoint-site-onenote-notebooks` | Captured during stage 3 site walks, cross-referenced here. |

---

## Output JSON shape

Everything lands under `~/ms365-audits/<slug>-<date>/raw/tenant/`:

```
raw/tenant/
├── current-user.json
├── manager-and-reports.json
├── users.json                 # array — { id, displayName, mail, userPrincipalName, jobTitle, department, accountEnabled }
├── groups.json                # array — { id, displayName, mailEnabled, securityEnabled, groupTypes, mail, description, createdDateTime }
├── group-members.json         # { groupId: [{ id, displayName, mail, "@odata.type" }] }
├── group-owners.json          # same shape
├── mail-folders-<userId>.json # tree — for each user in scope
├── mail-rules-<userId>.json
├── mailbox-settings-<userId>.json
├── shared-mailboxes.json      # one entry per shared mailbox with summary stats
├── calendars-<userId>.json
├── calendar-permissions-<userId>.json
├── sharepoint-sites.json      # array — { id, name, webUrl, createdDateTime, lastModifiedDateTime, description }
├── sharepoint-sites-delta-token.json   # for incremental future runs
├── drives.json                # array — { id, driveType, owner, webUrl, quota }
├── teams-joined.json
├── teams-channels.json        # { teamId: [channels...] }
├── chats-summary.json         # array — { id, topic, chatType, members, lastUpdatedDateTime } — NO message bodies
├── online-meetings-summary.json
├── onenote-notebooks.json
├── todo-task-lists.json
├── installed-teams-apps.json
└── memberships.json
```

---

## What the stitcher produces

After raw pulls, a small synthesizer writes `data/tenant-summary.json`:

```json
{
  "generatedAt": "...",
  "tenantDomain": "sulfurrecovery.com",
  "operator": { "id": "...", "name": "Maaz ...", "mail": "..." },
  "totals": {
    "users": 12,
    "groups": 8,
    "mailFoldersUserScope": 38,
    "sharedMailboxes": 2,
    "sharePointSites": 14,
    "drives": 14,
    "teamsJoined": 3,
    "channelsTotal": 18,
    "chatsKnown": 47,
    "onenoteNotebooks": 4,
    "todoTaskLists": 6
  },
  "scope": {
    "fullMailboxes": ["maaz@..."],
    "metadataOnlyUsers": ["ashley@...", "...others"],
    "excludedSites": [],
    "excludedUsers": []
  },
  "openQuestions": [
    "Found 3 'Personal-*' SharePoint sites; confirm none are in scope.",
    "User 'guest_*' detected — likely external collaborator, confirm coverage.",
    "Mail folder named 'Archive 2018' has 9,800 messages — propose excluding from 2yr scan?"
  ]
}
```

The `openQuestions` array is the human-review surface. Stage 1 must NEVER auto-resolve scope ambiguity — it surfaces and asks.

---

## Heuristics + sanity checks

The stitcher runs these checks against `tenant-summary.json`:

1. **User count** vs the count Maaz expects. If off by >10%, halt and ask.
2. **Site count** vs explicit list in `client-config.yaml`. Unknown sites are listed in `openQuestions`.
3. **Shared mailbox match** — every shared mailbox in config must be reachable; every reachable shared mailbox should be in config or excluded.
4. **Time zone** of mailbox settings — must match the configured dashboard time zone. Mismatch → flag.
5. **Manager + reports presence** — if Maaz has no direct reports visible but the Execution Plan references Ashley/Ron/Eng, surface as a config gap.
6. **Empty drives / empty sites** — annotate so stages 3 + 4 can skip them.

---

## Pagination + parallelism rules

| Endpoint | Pagination shape | Cursor field | Max page | Parallelism |
|---|---|---|---|---|
| `list-users` | `@odata.nextLink` | URL | 100 | 4 |
| `list-groups` | `@odata.nextLink` | URL | 100 | 4 |
| `list-group-members` | `@odata.nextLink` | URL | 100 | 6 (one stream per group; cap at 6) |
| `list-mail-folders` | none (flat) | — | — | 1 per user |
| `search-sharepoint-sites` | `@odata.nextLink` | URL | 50 | 1 |
| `list-team-channels` | none (flat) | — | — | 6 |
| `list-chats` | `@odata.nextLink` | URL | 50 | 1 |
| `list-online-meetings` | `@odata.nextLink` | URL | 50 | 1 |

Per-tool 429 backoff: 1.5 × attempt seconds, max 3 retries.

---

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `403 Forbidden` on `list-users` | App / token lacks `User.Read.All` | Re-consent the MS365 app with admin (Phase 0 work). Verify token scopes via `verify-login`. |
| `404` on `get-mailbox-settings` for a user listed in scope | User has no mailbox (e.g. distribution-list account) | Drop them from `in_scope_mailboxes_full` and re-run. |
| Site count drastically lower than expected | Token issued with delegated scope that excludes some sites | Check Sites.Read.All consent; surface in `openQuestions`. |
| Empty `chats-summary.json` | Token lacks `Chat.Read` | Stage 5 will be limited to channel messages only; flag. |

---

## Acceptance criteria (this stage is "done" when…)

- [ ] `raw/tenant/` populated with every JSON listed above
- [ ] `data/tenant-summary.json` written and reviewed
- [ ] `openQuestions` empty OR each item explicitly resolved in `client-config.yaml`
- [ ] User count matches Maaz's mental model
- [ ] Every site / drive / team / shared mailbox referenced in `client-config.yaml` exists in the raw output
- [ ] No stage-1 call has touched a mail body, doc body, chat message, or meeting transcript

Once accepted, stages 2A through 7 can be launched in parallel.
