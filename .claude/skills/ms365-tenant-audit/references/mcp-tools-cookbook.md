# MS365 MCP tools cookbook

Quick lookup for which `mcp__ms365__*` tool to call per stage, with the parameters that actually work and the gotchas that don't.

## Universal rules

- Always set `$select` narrow. Default Graph responses are huge.
- Always prefer small `$top` (15–50) over `fetchAllPages:true`. Token caps overflow easily.
- When a tool says "do NOT pass `$top`" in the gotchas table, Graph rejects with HTTP 400. Just omit.
- When `$select` is rejected, Graph also returns 400. Strip and retry.
- All tools support `ConsistencyLevel: eventual` header. Set when using `$search`, `$count`, or `$filter` with `contains()`.

---

## Stage 1 — tenant discovery

### Identity

| Tool | Params | Notes |
|---|---|---|
| `get-current-user` | `select="id,displayName,mail,userPrincipalName,jobTitle,department"` | Always call first. Refuse audit if UPN doesn't match expected operator. |
| `get-my-manager` | same select | Often returns 404 `Request_ResourceNotFound` if org chart isn't populated. Treat as "no manager set". |
| `list-my-direct-reports` | `select="..."`, `top=50` | Returns `[]` if no reports. |
| `list-users` | `top=50`, `ConsistencyLevel:eventual`, `select="id,displayName,mail,userPrincipalName,jobTitle,department,accountEnabled,userType,createdDateTime"` | Returns `@odata.nextLink` for pagination. **`$skip` is ignored on /users** — must use nextLink. |
| `list-groups` | same shape | Same nextLink behavior. |

### Mail / calendar / contacts (per scoped user)

| Tool | Params | Notes |
|---|---|---|
| `list-mail-folders` | `select="id,displayName,parentFolderId,totalItemCount,unreadItemCount,childFolderCount"`, `top=50` | Returns root-level mail folders only — to walk deeper, traverse per `childFolderCount`. |
| `get-mailbox-settings` | none | Returns timeZone, workingHours, automaticReplies — feeds operator profile. |
| `list-mail-rules` | `mailFolderId=<Inbox-id-from-list-mail-folders>` | Required path param. Empty array = zero rules (a strong signal). |
| `list-contact-folders` | `top=25` | Returns user-folder + named folders (e.g., "Zoho CRM Contacts"). |
| `list-calendars` | `select="id,name,isDefaultCalendar,canShare,canEdit,owner"`, `top=25` | Returns default + holiday + birthday + shared-to-me calendars. |
| `list-my-calendar-permissions` | none | Surfaces who else can see Maaz's calendar (free/busy vs read vs delegate). |

### SharePoint / OneDrive

| Tool | Params | Notes |
|---|---|---|
| `list-drives` | `select="id,name,driveType,owner,webUrl,quota"`, `top=25` | Returns OneDrive + any Personal/Cache libraries. |
| `search-sharepoint-sites` | — | **AVOID**. Returns empty on many tenants. Use `search-query` instead. |
| `search-query` | `body={"requests":[{"entityTypes":["site"],"query":{"queryString":"<keyword>"},"size":25,"from":0,"fields":[...]}]}` | The working SharePoint discovery path. `size:25` max. |

### Teams / chats

| Tool | Params | Notes |
|---|---|---|
| `list-joined-teams` | NO `$top` (Graph 400) | Returns ~3-15 teams for typical operator. |
| `list-my-associated-teams` | NO `$top` | Includes shared-channel host teams. |
| `list-team-channels` | `teamId=<id>`, `select="id,displayName,description,membershipType,createdDateTime"` | Per team. |
| `list-chats` | `top=50`, `select="id,topic,chatType,createdDateTime,lastUpdatedDateTime"` | Page 1 metadata only. |

### Planner / ToDo / OneNote / apps / memberships

| Tool | Params | Notes |
|---|---|---|
| `list-todo-task-lists` | `top=25` | **NO `$select`** (Graph 400). |
| `list-todo-tasks` | `todoTaskListId=<id>`, `top=20` | **NO `$select`** (Graph 400). Status filter via `$filter=status eq 'notStarted'` works. |
| `list-onenote-notebooks` | `select="id,displayName,createdDateTime,lastModifiedDateTime,isDefault,isShared"`, `top=25` | |
| `list-onenote-notebook-sections` | `notebookId=<id>` | |
| `list-my-installed-teams-apps` | `expand=["teamsApp"]`, NO `$top` (Graph 400) | Useful for spotting third-party app integrations (Zoho, Adobe Sign, ClickUp). |
| `list-my-memberships` | `top=50` | Includes both groups AND directory roles. Filter `isof('microsoft.graph.group')` for groups only. |

---

## Stage 2A — mail audit

| Tool | Params |
|---|---|
| `list-mail-folder-messages` | `mailFolderId=<Inbox-id>`, `top=20`, `orderby="receivedDateTime desc"`, `select="id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,categories,conversationId,importance"` |
| same for Sent Items | `mailFolderId=<Sent-Items-id>`, `orderby="sentDateTime desc"`, `select="id,subject,toRecipients,sentDateTime,hasAttachments,categories,conversationId"` |

**Never include `body` or `bodyPreview` in `$select`.** These are body content; the audit is metadata-only.

---

## Stage 2B — calendar audit

| Tool | Params |
|---|---|
| `get-calendar-view` | `startDateTime`, `endDateTime` (ISO8601), `timezone="<IANA>"`, `top=200`, `select="id,subject,start,end,isOnlineMeeting,categories,isAllDay,sensitivity,showAs,type"` |

**Will overflow** for >100 events. Chunk the window into 6-month slices. Each chunk's response auto-saves to disk; dispatch a subagent per file to read+summarize.

`list-calendar-events` returns series-master only (no expanded recurrences). Use `get-calendar-view` for usable per-instance data.

---

## Stage 2C — contacts

| Tool | Params |
|---|---|
| `list-contact-folder-contacts` | `contactFolderId=<from-list-contact-folders>`, `select="id,displayName,emailAddresses,companyName,jobTitle,businessPhones,createdDateTime"`, `top=25` |

---

## Stage 3 — SharePoint

The single canonical pull:

```json
{
  "requests": [{
    "entityTypes": ["site"],
    "query": {"queryString": "<tenant-keyword> OR <onmicrosoft-prefix>"},
    "from": 0,
    "size": 25,
    "fields": ["id", "name", "webUrl", "createdDateTime", "lastModifiedDateTime", "description"]
  }]
}
```

Then paginate by adjusting `from`. The response includes `total` and `moreResultsAvailable`.

**Forbidden combination**: `entityTypes` cannot mix `message` + `event` in one request — Graph rejects with `Invalid entity type combination`. Use separate requests if you need both.

---

## Stage 4 — OneDrive

| Tool | Params |
|---|---|
| `list-folder-files` | `driveId=<from-list-drives>`, `driveItemId="root"`, `select="id,name,folder,file,size,createdDateTime,lastModifiedDateTime,webUrl"`, `top=50` |

Recursively walk only when `folder.childCount > 0` and the folder name is operationally interesting (avoid system folders like `Apps`, `Attachments`).

NEVER call `download-bytes` unless the operator has opted into OCR for a specific file.

---

## Stage 5 — Teams

| Tool | Params |
|---|---|
| `list-team-channels` | `teamId=<from-list-joined-teams>`, `select="id,displayName,description,membershipType,createdDateTime"` |
| `list-team-members` | `teamId=<id>` | For roster (optional — useful for routine attribution) |

Do NOT call `list-channel-messages` — that's body content.

---

## Stage 6 — Planner / ToDo

| Tool | Params |
|---|---|
| `list-todo-task-lists` | `top=25`, NO `$select` |
| `list-todo-tasks` | `todoTaskListId=<id>`, `top=20`, NO `$select`. Can filter with `$filter=status eq 'notStarted'` |

For Planner buckets per group, the `list-plan-buckets` / `list-plan-tasks` pair works once you have a `planId` from the group's plans.

---

## Stage 7 — OneNote

| Tool | Params |
|---|---|
| `list-onenote-notebook-sections` | `notebookId=<id>`, `select="id,displayName,createdDateTime,lastModifiedDateTime"` |
| `list-onenote-section-pages` | `sectionId=<id>`, top=20 | List only — do NOT call `get-onenote-page-content` (body) |

---

## Cross-cutting gotchas

| Symptom | Fix |
|---|---|
| `400 Query option 'Top' is not allowed` | Drop `$top` (rare endpoints reject it — see table above) |
| `400 Query option 'select' not allowed` | Drop `$select` (todo endpoints reject) |
| `400 Invalid entity type combination` | Split `search-query` into one request per entity type |
| `404 Request_ResourceNotFound` on get-my-manager | Treat as no-manager-set, not an error |
| Response saved to disk · "exceeds maximum allowed tokens" | Dispatch a subagent (general-purpose) to read the file in 230-line chunks and return a structured summary. Keep subagent prompts under ~400 words or "Prompt is too long". |
| `@odata.nextLink` present but `$skip` ignored | Use the nextLink URL directly via HTTP, or accept page 1 sample for v1 audit |
| Tool returns `[]` consistently for a surface you expect to have data | Either: (a) operator lacks scope, (b) the data really is empty (which is itself a finding — e.g., zero inbox rules, empty Zoho contacts folder, dead OneNote) |

---

## Pagination strategies

For a tenant-discovery audit, **page 1 of each list is usually sufficient** (50 users / 50 groups / 50 chats / 25 sites = good baseline). Surface the `_hasMore: true` and `_nextLink` in the raw JSON so the next pass can resume.

For full export use cases, the only reliable pagination is HTTP-following `@odata.nextLink`. The MCP `fetchAllPages:true` parameter works for some endpoints but explodes response size catastrophically — only enable when you've already verified the totals are small.

---

## Tool families to NEVER call from this audit

Any tool whose name starts with:

```
create-*, update-*, delete-*, send-*, set-*, move-*,
accept-*, decline-*, reply-*, forward-*, pin-*, unpin-*,
clear-*, dismiss-*, snooze-*, sort-*, merge-*, unmerge-*,
add-*, remove-*, copy-*, share-*, upload-*, format-*,
tentatively-accept-*
```

These mutate tenant state. The audit is observational only.

`download-bytes` is also off-limits unless the operator has opted into OCR with a specific scope.
