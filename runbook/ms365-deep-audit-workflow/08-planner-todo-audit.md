# Stage 6 — Planner + ToDo Audit

**Purpose.** Capture the structured task surface inside MS365 — both Planner (group-scoped, kanban-style) and ToDo (personal task lists). Reconcile against ClickUp (the primary project tracker per the Execution Plan) to identify drift, duplication, or hidden work.

**Pre-requisite.** Stage 1 complete; groups + ToDo task lists enumerated.

**Output.** Plan + bucket + task inventory; ToDo task lists + tasks; cross-source comparison.

**Safety.** Tasks may reference customers, deals, or sensitive deadlines. Same local-only rules apply.

**Run time.** <10 minutes.

---

## 1. Why this stage matters even though ClickUp exists

The Execution Plan calls ClickUp out as the primary project tracker. That's the working source of truth. But MS365 Planner + ToDo accumulate task data anyway because:
- Planner gets auto-populated by Teams group creation
- ToDo flagged-emails create tasks
- Planner tasks created by collaborators from other orgs (e.g. customer collaborating in a shared workspace)
- Standing routines / templates created in Planner historically before ClickUp was adopted

So the audit's job here is **inventory + reconcile** — not "use this as the task tracker", but "find work in Planner/ToDo that ClickUp doesn't know about".

The reconciliation against ClickUp itself is OUT OF SCOPE for this stage (no ClickUp puller exists yet). What we produce here is the **MS365 side of that reconciliation** — to be cross-walked once a ClickUp puller is built.

---

## 2. Planner pull plan

### 2.1 Plan discovery
Plans live under M365 groups. From stage 1 we have:
- Groups Maaz is a member of
- Groups Maaz owns

For each group, identify plans:
- `list-planner-tasks` works at the user level — gives EVERY task across every plan Maaz can see. Use this as the fast path.
- For each unique `planId` returned, then call `get-planner-plan` for plan metadata, and `list-plan-buckets`.

### 2.2 Per-plan
- `get-planner-plan` — name, owner group, createdDateTime
- `list-plan-buckets` — buckets (columns) in the plan
- `list-plan-tasks` — every task in the plan
- For high-value tasks (recent or assigned to Maaz), `get-planner-task-details` for the task description + checklist

Capture per task:
- `id, title, percentComplete, priority, dueDateTime, completedDateTime, createdDateTime, assignments, bucketId, planId, orderHint, hasDescription, checklistItemCount, referenceCount`

---

## 3. ToDo pull plan

### 3.1 Task lists
- `list-todo-task-lists` — cached from stage 1

For each list:
- `list-todo-tasks` paginated
- For each task with `hasAttachments` or `body.contentType != "text"`, fetch `get-todo-task` for the full body
- `list-todo-linked-resources` per task — these are flagged-email backlinks (very informative)

Capture per task:
- `id, title, status, importance, body, dueDateTime, reminderDateTime, isReminderOn, completedDateTime, createdDateTime, lastModifiedDateTime, linkedResources, listId`

---

## 4. Output JSON shape

```
raw/planner/
├── plans.json                         # array, one per discovered plan
├── buckets-<planId>.json              # buckets per plan
├── tasks-<planId>-flat.json           # tasks per plan
└── task-details-<taskId>.json         # only for high-value tasks

raw/todo/
├── task-lists.json
├── tasks-<listId>-flat.json
└── linked-resources-<taskId>.json
```

Planner task element:
```json
{
  "id": "...",
  "planId": "...",
  "planName": "SRE Operations",
  "bucketId": "...",
  "bucketName": "Proposal Pipeline",
  "title": "Aramco Train 4 - send proposal",
  "percentComplete": 50,
  "priority": 5,
  "dueDateTime": "2026-06-01T00:00:00Z",
  "createdDateTime": "...",
  "completedDateTime": null,
  "assignments": [
    { "assigneeId": "...", "assigneeName": "Maaz", "assignedDateTime": "..." }
  ],
  "checklistItemCount": 4,
  "checklistCompleted": 2,
  "hasDescription": true
}
```

ToDo task element:
```json
{
  "id": "...",
  "listId": "...",
  "listName": "Flagged",
  "title": "...",
  "status": "notStarted",
  "importance": "high",
  "dueDateTime": { "dateTime": "...", "timeZone": "America/Edmonton" },
  "reminderDateTime": null,
  "isReminderOn": false,
  "createdDateTime": "...",
  "lastModifiedDateTime": "...",
  "body": { "content": "...", "contentType": "text" },
  "linkedResources": [
    { "applicationName": "Outlook", "webUrl": "...", "displayName": "Re: Proposal Aramco" }
  ]
}
```

---

## 5. Stitched data — `data/tasks-analysis.json`

```json
{
  "generatedAt": "...",
  "totals": {
    "plannerPlans": 4,
    "plannerTasks": 168,
    "plannerTasksActive": 72,
    "plannerTasksOverdue": 14,
    "todoListsAll": 6,
    "todoTasks": 312,
    "todoTasksActive": 84,
    "todoTasksOverdue": 18,
    "todoLinkedToMail": 92
  },
  "plansByActivity": [
    { "planId": "...", "planName": "SRE Operations", "activeTasks": 32,
      "lastModified": "2026-05-20", "isActive": true }
  ],
  "overdueTasks": [
    { "source": "planner", "title": "Aramco — send proposal", "due": "2026-05-10",
      "owner": "Maaz", "daysOverdue": 12 }
  ],
  "ownerWorkload": [
    { "owner": "Maaz", "active": 41, "overdue": 18 },
    { "owner": "Ashley", "active": 22, "overdue": 4 }
  ],
  "tasksReferencingMail": [
    { "todoTaskId": "...", "title": "Re: Proposal Aramco", "linkedMessageId": "...",
      "linkedMessageSubject": "Re: Proposal Aramco" }
  ],
  "findings": [
    { "severity": "high", "title": "14 Planner tasks overdue >7d assigned to Maaz" },
    { "severity": "med",  "title": "2 plans with no activity in 90d (dormant)" },
    { "severity": "med",  "title": "1 Planner task assigned to former employee" },
    { "severity": "low",  "title": "120 flagged-email ToDo tasks never converted to action" }
  ]
}
```

---

## 6. Findings + heuristics

| Severity | Finding |
|---|---|
| HIGH | Overdue tasks >7 days assigned to Maaz |
| HIGH | Plans/lists with overdue tasks owned by deactivated user |
| MED | Plan dormant 90d but containing incomplete tasks (orphan work) |
| MED | Identical task title in both Planner and a likely ClickUp task (post-reconcile) |
| MED | Flagged-email ToDo tasks >30d old — backlog rot |
| LOW | Plan with no buckets configured |
| LOW | Task with no due date AND no completedDateTime — undated forever |

---

## 7. Pagination + parallelism

| Endpoint | Parallelism | Notes |
|---|---|---|
| `list-planner-tasks` (user-scope) | 1 | One shot for all |
| `get-planner-plan` | 4 plans parallel | After dedup |
| `list-plan-buckets` | 4 plans parallel | |
| `list-plan-tasks` | 4 plans parallel | |
| `get-planner-task-details` | 8 tasks parallel | Only for active/recent |
| `list-todo-task-lists` | 1 | Cached from stage 1 |
| `list-todo-tasks` | 6 lists parallel | |
| `list-todo-linked-resources` | 8 tasks parallel | Only when present |

---

## 8. Failure modes

| Case | Handling |
|---|---|
| Token lacks `Tasks.Read` | Stage skipped; findings note the gap |
| Plan exists in a group Maaz is no longer a member of | Returns 403; skip, log |
| Planner returns assignments without user names | Resolve via `list-users` (stage 1 cache) |
| ToDo task body in HTML form | Strip to plain text for classifier |

---

## 9. Cross-references this stage creates

- ToDo `linkedResources` → mail message IDs → stage 2A
- Planner task title containing customer name → customer-360 join → stage 8
- Assignee IDs → people graph → stage 2C

---

## 10. Acceptance criteria

- [ ] Every visible plan + bucket + task captured
- [ ] Every ToDo list + tasks captured
- [ ] Overdue counts reasonable (Maaz spot-checks)
- [ ] Owner workload distribution sane
- [ ] Linked-resource cross-walk into mail works on a 5-task spot-check
- [ ] Stage runs in <10 min
