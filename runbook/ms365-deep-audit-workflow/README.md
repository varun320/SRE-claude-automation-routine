# MS365 Deep Audit Workflow — Master Runbook

> **⚠️ DECISION OVERRIDE 2026-05-26:** SRE sale process ended. Every reference to "sale process", "sale-process buyer", "Sale-Process Memo" (R9), or related confidentiality framing in this runbook is superseded by [`docs/decisions/2026-05-26-maaz-phase1-decisions.md`](../../docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10). The broader framing is *"Sensitive corporate / financial / HR / board material — never surface in any output."*

**Status:** PLAN. Nothing in this directory has been executed yet. All pullers + generators described here are designed but not implemented.
**Owner:** Mohammad (operator) for **Maaz Ahmed Shareef / Sulfur Recovery Engineering Inc. (SRE)**.
**Target tenant:** the Microsoft 365 tenant that backs SRE.
**Companion plan:** [`SRE Claude Routines - Execution Plan.md`](../../SRE%20Claude%20Routines%20-%20Execution%20Plan.md) (the 26-routine operating-system this audit will inform).
**Modelled on:** the GHL Deep Audit Workflow (referenced inline) — but adapted for MS365's reality where data is spread across many less-structured surfaces.

---

## 1. Why this exists

SRE has **no dedicated CRM**. Their CRM is the **implicit graph already living inside MS365**:

| Where the CRM data actually lives | What it really contains |
|---|---|
| Outlook mailbox | every customer conversation, every proposal sent, every invoice, every AR follow-up, every meeting confirmation |
| Outlook calendar | every customer meeting (past + scheduled), attendees, recurrence patterns, time spent per account |
| SharePoint sites + lists | job trackers, project status, possibly an explicit "Clients" or "Pipeline" list |
| SharePoint document libraries + OneDrive | proposal docs, contract PDFs, technical drawings, project files |
| Teams chats + channels | live deal conversations, internal commentary on accounts, file drops |
| Teams meeting recordings + transcripts | sales call content, technical review calls, AIMS bi-weekly slots |
| Planner / ToDo | active task surface (partly), reconciled against ClickUp |
| OneNote | meeting notes, account notes, technical reference |
| Outlook contacts + relevant-people | the explicit + inferred Rolodex |

The job of this audit is to **read every one of those surfaces, extract the business reality, and stitch it into a single coherent picture** — so we can answer questions Maaz currently can't answer cleanly:

- How many active customers do we have right now?
- Top-5 customers by revenue? By meeting-time? By email volume?
- What proposals are out and not yet won/lost?
- What's our average sales cycle from first-touch to invoice?
- Who are our prospects that have gone quiet for >30 days?
- What's our AR aging look like, by customer, with the original invoice attached?
- Which projects haven't moved in two weeks?
- Where's all the time going (calendar reality vs Weekly OS plan)?
- What docs/proposals exist that we could repurpose?

Once the audit lands those answers, the **same data layer** powers the 26 scheduled routines in the Execution Plan — R1 inbox scans, R2 daily setups, R12 AR aging, R10 pipeline hygiene, R8 weekly planning, etc. The audit is the foundation; the routines are the operating cadence on top of it.

---

## 2. Comparison to the GHL audit

The GHL audit (referenced in this session) is the prior art. It produced three dashboards in ~10 min from a single, structured CRM API. **MS365 is harder** because:

| | GHL audit | MS365 audit |
|---|---|---|
| Number of source surfaces | 1 (the GHL API) | 9+ (mail, calendar, contacts, SharePoint, OneDrive, Teams, Planner, ToDo, OneNote, directory) |
| Structured customer entity | Yes — every contact has a stable contactId | No — customers are inferred from email domains + repeated names |
| Structured pipeline | Yes — opportunities have explicit pipelineStageId | No — must infer from subjects, attachments, folder placement, meeting cadence |
| Structured revenue | Yes — monetaryValue on every opp | No — must parse invoice PDFs/XLSX + bank deposits if available |
| Confidentiality risk | Medium — operator data | **HIGH** — production mailboxes, contracts, financial data; per-stage approvals required |
| Run time estimate | ~5–10 min | **30–90 min on first run**, then 10–15 min incremental |
| API budget | ~3,000–4,000 calls | ~10,000–50,000 calls depending on mailbox depth |

This means our MS365 audit needs **more stages, harder joins, stricter safety, longer-lived raw caches, and an inference layer GHL didn't need**.

---

## 3. The 7+ stage pipeline

Read each per-source runbook for full details. Below is the orchestration shape.

```
┌────────────────────────────────────────────────────────────────────┐
│  Stage 0 — DISCOVERY (one-time, manual)                            │
│    Maaz answers the questionnaire (00-discovery-questionnaire.md)  │
│    Output: client-config.yaml  (canonical customer list, vocab,    │
│    naming conventions, what's in/out of scope)                     │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Stage 1 — TENANT DISCOVERY                                        │
│    Users, groups, mailboxes, shared mailboxes, SharePoint sites,   │
│    drives, Teams. Establishes the data universe.                   │
│    Runbook: 01-tenant-discovery.md                                 │
│    Output: raw/tenant/*.json                                       │
└────────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Stage 2A — MAIL │ │  Stage 2B — CAL  │ │  Stage 2C — CT'S │
│  02-outlook-mail │ │  03-outlook-cal  │ │  04-outlook-cts  │
│  2yr scan        │ │  2yr scan        │ │  full hydrate    │
└──────────────────┘ └──────────────────┘ └──────────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Stage 3 — SHAREPOINT  (05-sharepoint-audit.md)                    │
│    Site-by-site walk; list inventory; auto-detect list-as-CRM.     │
└────────────────────────────────────────────────────────────────────┘
                              │
┌────────────────────────────────────────────────────────────────────┐
│  Stage 4 — ONEDRIVE  (06-onedrive-audit.md)                        │
│    Per-user drive inventory; proposal/contract/invoice file class. │
└────────────────────────────────────────────────────────────────────┘
                              │
┌────────────────────────────────────────────────────────────────────┐
│  Stage 5 — TEAMS  (07-teams-audit.md)                              │
│    Channels, chats, channel messages, online meetings, recordings. │
└────────────────────────────────────────────────────────────────────┘
                              │
┌────────────────────────────────────────────────────────────────────┐
│  Stage 6 — PLANNER + TODO  (08-planner-todo-audit.md)              │
│    Active plans, buckets, task status, owner workload.             │
└────────────────────────────────────────────────────────────────────┘
                              │
┌────────────────────────────────────────────────────────────────────┐
│  Stage 7 — ONENOTE  (09-onenote-audit.md)                          │
│    Notebook inventory + page-level last-modified for staleness.    │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Stage 8 — CUSTOMER 360 SYNTHESIS  (10-customer-360-synthesis.md)  │
│    Join everything by canonical company → unified customer record. │
│    Synthesize a narrative note per customer.                       │
└────────────────────────────────────────────────────────────────────┘
                              │
┌────────────────────────────────────────────────────────────────────┐
│  Stage 9 — SALES PIPELINE INFERENCE  (11-sales-pipeline-...)        │
│    Reconstruct prospect → proposal → won/lost stages from data.    │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Stage 10 — DASHBOARD GENERATION  (12-dashboards-catalog.md)       │
│    Self-contained HTML dashboards, dark theme, drill-down.         │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Stage 11 — SKILLS EXTRACTION  (13-skills-extraction-plan.md)      │
│    Convert audit findings → permanent skills + scheduled routines. │
└────────────────────────────────────────────────────────────────────┘
```

Stages 2–7 are **parallelizable** once Stage 1 is done. Stages 8+ are sequential and depend on everything before.

---

## 4. MCP tool inventory (what the pullers will call)

The MS365 MCP server is already wired (per Phase 0 of `IMPLEMENTATION_PLAN.md`). Below is which tool family powers which stage. Tools beginning `mcp__ms365__` are read-only Microsoft Graph proxies (the audit MUST NOT call any `create-*`, `update-*`, `delete-*`, `send-*`, or `set-*` tool).

| Stage | Tool families used |
|---|---|
| 1 — Tenant | `get-current-user`, `list-users`, `list-groups`, `list-group-members`, `search-sharepoint-sites`, `list-drives`, `list-joined-teams`, `list-mail-folders` (per user where allowed) |
| 2A — Mail | `list-mail-folders`, `list-mail-folder-messages`, `list-mail-folder-messages-delta`, `get-mail-message`, `list-mail-attachments`, `list-mail-rules`, `search-query` (KQL) |
| 2B — Calendar | `list-calendars`, `list-calendar-events`, `get-calendar-view`, `list-calendar-events-delta`, `list-calendar-event-instances` |
| 2C — Contacts | `list-contact-folders`, `list-contact-folder-contacts`, `list-outlook-contacts`, `list-relevant-people`, `list-trending-insights` |
| 3 — SharePoint | `search-sharepoint-sites`, `get-sharepoint-site`, `list-sharepoint-site-lists`, `get-sharepoint-site-list`, `list-sharepoint-list-columns`, `list-sharepoint-site-list-items`, `list-sharepoint-site-drives`, `list-sharepoint-site-items`, `get-sharepoint-sites-delta` |
| 4 — OneDrive | `list-drives`, `get-drive-root-item`, `list-folder-files`, `search-onedrive-files`, `list-drive-item-permissions`, `list-drive-item-versions`, `extract-drive-item-sensitivity-labels`, `get-drive-delta` |
| 5 — Teams | `list-joined-teams`, `list-my-associated-teams`, `get-team`, `list-team-channels`, `list-channel-messages`, `list-channel-message-replies`, `list-chats`, `list-chat-messages`, `list-chat-members`, `list-online-meetings`, `list-meeting-recordings`, `list-meeting-transcripts`, `get-meeting-transcript-content` |
| 6 — Planner/ToDo | `list-planner-tasks`, `get-planner-plan`, `list-plan-buckets`, `list-plan-tasks`, `get-planner-task-details`, `list-todo-task-lists`, `list-todo-tasks`, `get-todo-task` |
| 7 — OneNote | `list-onenote-notebooks`, `list-onenote-notebook-sections`, `list-onenote-pages`, `get-onenote-page-content` |
| 8+ — Synthesis | None — pure Python over the raw cache |

---

## 5. Directory layout

This is the layout the audit produces. Nothing exists yet; the runbook commits to this shape so the pullers + generators can be written against it consistently.

```
runbook/ms365-deep-audit-workflow/
├── README.md                              ← this file
├── 00-discovery-questionnaire.md          ← stage 0, manual with Maaz
├── 01-tenant-discovery.md                 ← stage 1
├── 02-outlook-mail-audit.md               ← stage 2A
├── 03-outlook-calendar-audit.md           ← stage 2B
├── 04-outlook-contacts-audit.md           ← stage 2C
├── 05-sharepoint-audit.md                 ← stage 3
├── 06-onedrive-audit.md                   ← stage 4
├── 07-teams-audit.md                      ← stage 5
├── 08-planner-todo-audit.md               ← stage 6
├── 09-onenote-audit.md                    ← stage 7
├── 10-customer-360-synthesis.md           ← stage 8
├── 11-sales-pipeline-inference.md         ← stage 9
├── 12-dashboards-catalog.md               ← stage 10 spec
├── 13-skills-extraction-plan.md           ← stage 11 + bridge to routines
└── lib/                                   ← placeholder for future Python
    └── README.md
```

The audit RUN itself (when implemented) will produce — **outside** this runbook directory, somewhere like `~/ms365-audits/sre-<date>/`:

```
~/ms365-audits/sre-2026-05-22/
├── raw/
│   ├── tenant/                            ← users.json, groups.json, sites.json
│   ├── mail/<userId>/                     ← folders.json, messages-<folder>.json, attachments-<msgId>.json
│   ├── calendar/<userId>/                 ← calendars.json, events-<cal>.json
│   ├── contacts/<userId>/                 ← contacts.json, relevant-people.json
│   ├── sharepoint/<siteId>/               ← site.json, lists.json, list-<listId>-items.json, drive-items.json
│   ├── onedrive/<userId>/                 ← drive-tree.json, files.json
│   ├── teams/                             ← joined.json, channels-<teamId>.json, chats.json, messages-<convId>.json
│   ├── meetings/                          ← online-meetings.json, recordings.json, transcripts-<meetingId>.txt
│   ├── planner/                           ← plans.json, tasks-<planId>.json
│   ├── todo/                              ← task-lists.json, tasks-<listId>.json
│   └── onenote/                           ← notebooks.json, sections-<nbId>.json, pages-<sectionId>.json
├── data/
│   ├── customer-360.json                  ← the join — every customer + every signal
│   ├── sales-pipeline.json                ← inferred deals + stages + values
│   ├── communications-graph.json          ← who talks to whom, how often
│   ├── document-inventory.json            ← every proposal/contract/invoice with class + customer link
│   ├── time-allocation.json               ← calendar time aggregated per customer + per category
│   └── findings.json                      ← heuristic anomaly list (orphan docs, stale deals, etc.)
└── dashboards/
    ├── index.html                         ← sub-hub
    ├── ms365-account-overview.html
    ├── ms365-customer-360.html
    ├── ms365-sales-pipeline.html
    ├── ms365-communications-heatmap.html
    ├── ms365-document-library.html
    ├── ms365-time-allocation.html
    └── ms365-cleanup-report.html
```

---

## 6. Safety + scope rules

Because we're reading a live production tenant for a real business, the audit holds itself to stricter rules than the GHL one did.

1. **Read-only.** The audit never calls any MS365 tool that creates, updates, sends, deletes, or moves anything. The MCP exposes many such tools; we explicitly do not use them. See `connectors/connector-check.md` for the parallel rule applied to R1.
2. **Per-mailbox consent.** Mail bodies and attachments are only pulled from mailboxes Maaz has explicitly named in stage 0. Other users' mailboxes get directory-level metadata only (name, role, group membership).
3. **PII + financials stay local.** All raw + joined JSON stays in `~/ms365-audits/<slug>-<date>/`. Nothing gets uploaded to a third-party service. Dashboards are generated as **self-contained HTML files with the data inlined** — same pattern as GHL — so Maaz can open them locally without any backend service.
4. **Attachment bodies are optional.** By default the audit records attachment NAMES + SIZES + CONTENT-TYPES. Full body download (for OCR'ing invoices, etc.) is a separate opt-in stage with its own approval gate.
5. **Personal mailboxes off-limits.** Gmail and any personal accounts visible through the MCP are out of scope unless explicitly enabled in stage 0.
6. **Window:** default 2-year window mirrors GHL. Configurable per stage.
7. **Rate limits respected.** All pullers retry on 429/5xx with exponential backoff (same pattern as GHL `_req`).
8. **No body data in dashboards by default.** Aggregates and metadata only; click-through to a body requires a separate keystroke and the body never gets cached client-side.

---

## 7. What this audit answers (the actual deliverable to Maaz)

Once the pipeline runs, Maaz can open `ms365-customer-360.html` and answer in seconds:

**Strategic**
- Who are our top-N customers across the dimensions of (revenue, recency, meeting-time, email-volume, doc-count)?
- Which customers are at risk (cooling, ghosted, stalled)?
- What's our actual sales cycle from first-email to invoice?
- Which products/services dominate our revenue?
- Where are we leaking time vs the Weekly OS plan?

**Operational**
- Open proposals not yet decided — list with last-touch date and original PDF.
- AR aging — every unpaid invoice with the customer + days overdue.
- Stale projects — no calendar / mail / doc activity in 30+ days.
- Orphan docs — proposals/contracts not linked to any active customer record.

**Hygiene**
- Mailbox folders that are unused, mail rules that are dead.
- SharePoint sites with no activity in 12+ months.
- OneDrive duplicate proposal templates.
- Teams channels with zero recent messages.

**Bridge to the runtime**
- Which routines from the Execution Plan (R1–R26) now have everything they need to run? Which are blocked on what?

---

## 8. From audit to runtime — the bridge

This audit is **the data foundation** for the 26 scheduled routines in `SRE Claude Routines - Execution Plan.md`. Concretely:

| Audit output | Powers which routines |
|---|---|
| `customer-360.json` | R2 (Daily Setup), R8 (Weekly Planning), R10 (Pipeline Hygiene), R12 (AR Aging), R20 (Top-5 Friday), R26 (Quarterly Review) |
| `sales-pipeline.json` | R9 (Sale-Process Memo), R10 (Pipeline Hygiene), R12 (AR Aging) |
| `communications-graph.json` | R1 (NA Inbox Scan), R3 (NA Inbox Triage), R5 (ME Inbox Scan), R6 (ME Setup) |
| `time-allocation.json` | R2, R4 (Daily Close), R8, R25 (Monthly Time Review) |
| `document-inventory.json` | R9 (Sale-Process Memo), R11 (Project Tracker Refresh), R22 (Doc-room readiness) |
| `findings.json` | R4 (Daily Close — risk register), R10 (Pipeline Hygiene — stale deals) |

`13-skills-extraction-plan.md` formalizes this mapping into the **skills + sub-runbooks** that should be created once the audit ships, so the routines can call them by name instead of re-implementing the same logic each fire.

---

## 9. Implementation status

| Stage | Plan written | Python puller | Dashboard generator |
|---|---|---|---|
| 0 — Discovery | ✅ this PR | n/a (manual) | n/a |
| 1 — Tenant | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 2A — Mail | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 2B — Calendar | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 2C — Contacts | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 3 — SharePoint | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 4 — OneDrive | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 5 — Teams | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 6 — Planner/ToDo | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 7 — OneNote | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 8 — Customer 360 | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 9 — Sales pipeline | ✅ this PR | ⬜ TODO | ⬜ TODO |
| 10 — Dashboards | ✅ this PR (spec) | n/a | ⬜ TODO |
| 11 — Skills extraction | ✅ this PR | n/a | n/a |

When we move from plan to implementation, this table is the build manifest. Per-stage runbooks specify endpoints, request shapes, error modes, output JSON schemas, and dashboard sections — so each stage is implementable independently.

---

## 10. Next actions

1. **Run stage 0** with Maaz: walk through `00-discovery-questionnaire.md`, fill out `client-config.yaml`. ~30 min on a call.
2. **Sanity-fire stage 1** as a pure-read check: run `01-tenant-discovery.md` against the live tenant, verify scope feels right (e.g. site list isn't 10× larger than expected, user list looks correct). ~10 min.
3. **Pick the stage to implement first.** Recommendation: **2A — Outlook mail audit**, because it's the highest-information single source and it unblocks R1/R3/R5/R6 (four of the Tier-1 routines) at the same time.
4. **Build the puller + the matching dashboard section incrementally**, in the order Maaz's day actually relies on them: Mail → Calendar → SharePoint → Customer 360 → Sales Pipeline → everything else.

Each per-source runbook below is detailed enough that a developer (human or Claude) can implement it without further design questions. Cross-references inside the runbooks always link to other files in this same directory.
