# Stage 11 — Skills Extraction Plan

**Purpose.** Convert findings from the one-shot audit into **permanent capabilities** — Claude skills, sub-runbooks, and scheduled routines — so the same logic runs automatically going forward instead of re-implementing it each time.

**Pre-requisite.** Audit ships; Maaz reviews dashboards; we know what worked.

**Output.** A prioritized backlog of skills + sub-runbooks + scheduled routines, each mapped to (a) the audit data it consumes and (b) the routine in `SRE Claude Routines - Execution Plan.md` that depends on it.

**This is the bridge from "we ran an audit" to "Maaz has an operating system that runs itself."**

---

## 1. The four kinds of follow-up artifacts

| Artifact | When to extract one | Where it lives |
|---|---|---|
| **Skill** (`~/.claude/skills/<name>/SKILL.md`) | The audit found a repeatable pattern with clear inputs + outputs that Claude should be able to invoke from any session | global skills dir |
| **Sub-runbook** (`runbook/<topic>.md`) | The audit revealed a multi-step operational process Maaz wants to be able to re-run with a known recipe | project `runbook/` dir |
| **Scheduled routine** (R1–R26) | The audit revealed a recurring operating cadence the data now supports | project `routines/tier*/R*.md` |
| **Incremental puller** (`lib/`) | The audit exposed a data source we want to keep refreshing between full audits | project `lib/` dir |

---

## 2. Concrete extraction targets (the post-audit backlog)

### 2.1 Skills

Each becomes a `~/.claude/skills/<name>/SKILL.md` with a short description + invocation pattern. Reusable across SRE and (where applicable) other clients.

| Skill | What it does | Consumes | Powers |
|---|---|---|---|
| `ms365-customer-lookup` | Given a customer name OR email domain, returns the full 360 record (narrative + signals + open items) | `data/customer-360.json` | Any routine needing per-customer context |
| `ms365-deal-status` | Given a deal title or customer, returns stage + evidence trail + predicted next action | `data/sales-pipeline.json` | R9, R10, R20 |
| `ms365-ar-aging` | Returns AR aging buckets, optionally filtered by customer | `data/ar-aging.json` | R12 |
| `ms365-inbox-triage` | Classifies the last N messages in a mailbox into Skip / Info / Meeting-Info / Action-Required (matches chief-of-staff agent tiers) | live mail API + classifier | R1, R3, R5 |
| `ms365-meeting-prep` | Given a meeting ID OR calendar event, returns recent thread context + last 3 transcripts + open items | mail + calendar + transcripts | R2 day-themed pre-meeting brief |
| `ms365-search-everywhere` | Single query across mail + sharepoint + onedrive + teams; ranks results by recency + customer relevance | live KQL via `search-query` | Ad-hoc Maaz queries |
| `ms365-document-find` | Given a customer + document class (proposal/contract/invoice), returns the most recent file path | `document-inventory.json` | R9, R22 |
| `ms365-tag-time` | Aggregates time spent on a given customer / category over a window | `calendar-analysis.json` | R25 |
| `ms365-followup-detect` | Finds outbound emails > N days old without an inbound reply | `mail-analysis.json` | R3, R10 |

### 2.2 Sub-runbooks (under `runbook/`)

| Runbook | What it documents |
|---|---|
| `runbook/refresh-audit.md` | How to re-run the full pipeline incrementally (delta tokens, partial pulls) |
| `runbook/onboard-new-customer.md` | When a new external domain appears in mail, what manual steps update `client-config.yaml` + the SharePoint Jobs Tracker |
| `runbook/quarterly-cleanup.md` | Recipe to walk the cleanup dashboard with Maaz, mark items, execute approved deletes (separate `execute_cleanup.py`) |
| `runbook/incident-deal-stalled.md` | When a deal moves to `stalled`, the recovery sequence (mail draft, schedule call, internal note) |
| `runbook/incident-customer-cooling.md` | When a customer category goes `hot → warm → cooling`, recovery sequence |
| `runbook/ms365-pit-token-rotation.md` | How to refresh the MCP credentials when the cert/secret expires |

### 2.3 Scheduled routines (extending `SRE Claude Routines - Execution Plan.md`)

| New routine | Schedule | What it does |
|---|---|---|
| `R27 — Pipeline refresh` | Mon 11:00 | Re-runs the incremental audit (delta tokens), regenerates dashboards |
| `R28 — Customer health watcher` | Daily 06:00 | Scans `customer-360.json` for category transitions; if any customer moved into `cooling/stalled/ghosted`, surfaces in R2 setup |
| `R29 — Document leak watcher` | Weekly Sun 22:00 | Checks for newly-externally-shared sensitive docs |
| `R30 — Top-5 forecast refresh` | Friday 12:00 | Re-ranks Top-5 prep input for R20 |

R1–R26 from the Execution Plan stay as authored; the new routines are the ones the audit's data layer enables.

### 2.4 Incremental pullers (under `lib/`)

| Puller | What it refreshes | Run cadence |
|---|---|---|
| `pull_mail_delta.py` | Mail since last delta token | Daily |
| `pull_calendar_delta.py` | Calendar events since last delta | Daily |
| `pull_sharepoint_delta.py` | Site/list changes since last delta | Daily |
| `pull_onedrive_delta.py` | Drive changes since last delta | Weekly |
| `pull_teams_delta.py` | Channel + chat messages since last seen | Daily |
| `pull_planner_todo_delta.py` | Task changes since last sync | Daily |
| `synth_customer_360.py` | Re-runs the stage-8 join over current raw | Daily (after pulls) |
| `synth_sales_pipeline.py` | Re-runs stage 9 | Daily (after stage 8) |

Each is small + idempotent + delta-cursor-driven. Mirrors the GHL `fetch_contact_delta.py` pattern.

---

## 3. Priority order (suggested 8-week rollout)

| Week | Ship |
|---|---|
| 1 | Stage 0 + Stage 1 implemented and run; `client-config.yaml` finalized |
| 2 | Stages 2A + 2B implemented; first version of `customer-360.json` (mail + cal only) |
| 3 | Stage 3 + 8 implemented; first `customer-360.html` dashboard; R1/R3/R5 unblocked |
| 4 | Stage 9 implemented (sales-pipeline + AR); R10 + R12 unblocked |
| 5 | Stages 4 + 5 implemented (OneDrive + Teams); R9 + R20 unblocked |
| 6 | Stages 6 + 7 implemented (Planner/ToDo + OneNote); R11 + R26 unblocked |
| 7 | All 7 dashboards live; incremental pullers running daily; first R27 fires |
| 8 | Cleanup report + skills extracted to global skills dir; runbook documented end-to-end |

---

## 4. Quality gates between stages

Each transition has a Maaz-in-the-loop checkpoint. Without these, we ship false-precision data.

| Transition | Checkpoint |
|---|---|
| End of stage 0 | Maaz signs off on `client-config.yaml` |
| End of stage 1 | Maaz confirms scope (user/site/team counts feel right) |
| End of stage 2A | Maaz spot-checks 10 messages — classifier verdict matches his read |
| End of stage 3 | Maaz confirms which SharePoint list IS the CRM (the candidates the auto-detector surfaced) |
| End of stage 8 | Maaz spot-checks 10 customer records — narrative notes feel accurate |
| End of stage 9 | Maaz spot-checks 5 deals — stage + value + next-action feel accurate |
| End of stage 10 | Maaz uses customer-360 dashboard live for one day, reports back |
| End of stage 11 | First scheduled routine fires + delivers a usable artifact |

---

## 5. The metric that proves the audit worked

**One question:** can Maaz answer the questions in `README.md` section 7 ("What this audit answers") in <60 seconds each, without opening Outlook or SharePoint manually?

If yes — the audit shipped. If no — find the gap, refine the dashboard or the synthesis, re-test.

---

## 6. What this audit does NOT do (explicit non-goals)

To keep scope honest:

- ❌ It does NOT replace ClickUp as the task tracker.
- ❌ It does NOT replace SharePoint as the doc store.
- ❌ It does NOT WRITE to MS365. Every routine that writes (R3 drafts, R20 thank-yous, etc.) lives outside this audit and uses the audit's data layer as INPUT only.
- ❌ It does NOT bring in personal email/calendar (Gmail/Google Cal) unless explicitly opted in.
- ❌ It does NOT cover banking, accounting, payroll. AR detection is best-effort from mail + invoices in SharePoint/OneDrive.
- ❌ It does NOT do natural-language summarization with an LLM during synthesis (narrative notes are deterministic Python templates). LLM use stays in the routines that consume the data, not in the audit itself.
- ❌ It does NOT run unattended on first install — every stage has a manual review checkpoint until Maaz signs off.

---

## 7. Cross-client portability

The bones of this runbook port to any MS365 client (SRE, future audit clients). Per-client variation lives in `client-config.yaml`:
- Domain(s), in-scope mailboxes, vocabulary, stage definitions, redactions
- Per-client regex tuning for the subject classifier + document classifier
- Per-client stage probabilities for forecasting

The PYTHON CODE in `lib/` is meant to be client-agnostic. New clients = new `client-config.yaml`, same scripts.

This is the same pattern that made the GHL deep audit reusable across clients — and the lesson carries over.
