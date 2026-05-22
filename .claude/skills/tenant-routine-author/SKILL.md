---
name: tenant-routine-author
description: Author and schedule operator routines (scheduled remote agents) that run against a client's M365 + external CRM/PM stack on a cadence — inbox triage, AR pre-stage, top-client touch monitor, sales-pipeline watcher, weekly memos, country-rotation cadences. Takes the output of an MS365 tenant audit + an operator interview, produces routine spec files, and registers crons via the /schedule skill. Use after a tenant audit lands, when an operator says "I want X to happen automatically every Y", or when an execution plan defines a numbered set of routines (R1, R3, R5...) that need to ship.
---

# Tenant Routine Author

Pairs with `ms365-tenant-audit`. Where that skill discovers what's in the tenant, this skill defines what to **do about it on a cadence** — scheduled routines that run as the operator, read evidence, surface what changed, and either summarize or take a narrowly-scoped write action.

This is **not** a place to design new automation patterns from scratch. It's a templated workflow for taking known operator pain points (inbox eats deep-work time, AR aging needs Thursday pre-stage, ME top accounts forget accountability when CRM logging is delayed) and turning them into well-scoped, pilot-able, measurable scheduled agents.

---

## When to use

- An audit landed (`audits/<client>-<date>/`) and the operator wants the first routines to ship
- The execution plan names numbered routines (R1, R3, R12...) and you need spec files for each before scheduling
- The operator says "I want X to happen every Y" and you need to convert that into a spec → cron → pilot
- A pilot routine has been running and needs to graduate to active (or be retired)
- Routine output is going to the wrong channel (operator can't see it) and the channel decision needs to be revisited

## When NOT to use

- The user wants a one-off action ("send this email now") — just call the tool directly
- The audit hasn't run yet — routines built on assumed-state instead of observed-state drift fast. Run `ms365-tenant-audit` first.
- The action is a write to a customer-facing surface (mail/calendar to external recipients) — that's a separate review-gate skill, not a routine
- The cadence is "whenever a webhook fires" — use a hook + handler skill, not a scheduled routine

---

## Skill contents

```
~/.claude/skills/tenant-routine-author/
├── SKILL.md                              ← this file
├── references/
│   ├── routine-spec-schema.md            ← YAML schema + validation rules
│   ├── safety-budget-output.md           ← read-only default, write-action opt-in, output channel decision
│   └── lifecycle-measurement.md          ← define → pilot → active → graduate → retire + how to measure each
└── templates/
    ├── routine-spec.md.template          ← canonical per-routine spec
    └── common-routines/
        ├── inbox-scan.md                 ← R1-style daily inbox triage
        ├── ar-prestage.md                ← R12-style weekly AR pre-stage
        ├── customer-touch-monitor.md     ← R5-style "haven't touched in N days" alarm
        ├── sales-pipeline-watcher.md     ← R6-style external CRM state-transition detector
        ├── calendar-hygiene.md           ← housekeeping (cancellations, drift, tagging)
        └── weekly-memo.md                ← R9-style confidential weekly written summary
```

---

## Pre-flight (run before authoring any routine)

1. **Audit must exist** at `audits/<client-slug>-<YYYY-MM-DD>/`. Read its `data/tenant-summary.json` and `data/stage-2-to-7-summary.json`. Specifically extract:
   - `operator.upn` and `operator.full_mailbox_access_to` — sets the `scope.mailboxes` default
   - `operator.time_zone` and `operator.working_hours` — sets the cron timezone and acceptable cadence windows
   - `hard_anchors` — times the routine MUST NOT fire (prayers, family time, sleep)
   - `customer_keywords` and `known_top_customers` — used by inbox-scan and customer-touch-monitor
   - `sales_stages` and `closing_event` — used by sales-pipeline-watcher
   - `openQuestions` — resolve any HIGH-priority ones that block routine design (especially OQ-16 mailbox scoping, OQ-18 calendar conventions, OQ-21 output channel)

2. **`client-config.yaml` must exist** and be reviewed with operator (no `NEEDS_INPUT` placeholders left).

3. **`/schedule` skill must be available** (check the skills list). This skill writes the spec; `/schedule` registers the cron.

4. **Operator interview** (~30 min if first time, ~10 min if extending an existing set). Required answers:
   - Which pain points from the audit are top-3 to address first?
   - For each candidate routine, what does the output look like — a Teams message, a daily note file, a Zoho task, a ClickUp ticket?
   - What's the explicit "good outcome" — what would they need to see in the first 5 runs to say "yes, keep this running"?
   - Any write-actions they want the routine to take, or summarize-only?

---

## The routine-spec format

Every routine has one spec file at `routines/<R-ID>-<slug>.md` in the client project. It's a markdown file with YAML frontmatter + body. See `templates/routine-spec.md.template` for the canonical version; the schema is documented in `references/routine-spec-schema.md`.

Key frontmatter fields:

```yaml
---
id: R1                          # operator-facing identifier
slug: na-inbox-scan
client_slug: acme
status: draft | pilot | active | paused | retired
schedule:
  cron: "0 13 * * 1-5"          # Mon-Fri 13:00 local
  timezone: America/Edmonton    # IANA, must match operator's mailbox tz
  hard_anchors_respected: true  # never fires during prayers/sleep/family
scope:
  mailboxes: ["maaz@acme.com"]
  toRecipients_filter: true     # only count mail explicitly to scoped mailbox (OQ-16)
  window_hours_back: 24
  customer_keywords_source: client-config.yaml#customer_keywords
  exclude_senders: [linkedin.com, alarm.com, ...]
trigger_event_hints: []         # subject regexes — if any matches, escalate
output:
  channel: zoho_tasks           # see references/safety-budget-output.md for the decision matrix
  format: structured-summary    # structured-summary | bullet-list | one-line | note-file
  recipients: ["maaz@acme.com"]
safety:
  read_only: true               # default
  write_actions: []             # explicit allowlist; empty = pure read
budget:
  max_graph_calls: 50
  max_runtime_seconds: 120
  max_output_chars: 4000
observability:
  log_file: routines/logs/R1-{date}.json
  metric_signal: "ratio of escalations to runs · should be < 30%"
acceptance:
  - "First 5 runs reviewed by operator within 24h"
  - "False positive rate < 20%"
  - "Operator confirms 'this saved me time' by week 2"
graduates_to_active_when:
  - "10 consecutive runs without operator pushback"
  - "Acceptance criteria met"
---
```

Then the **body** of the spec describes (in prose):

1. **Why this routine exists** — link back to the audit finding or operator quote
2. **What it actually does** — step-by-step pseudocode of the runtime behavior
3. **What "good output" looks like** — a real example
4. **What "bad output" looks like** — a real example, used to triage failures
5. **Known edge cases** — Inshan-style ambiguity, sale-process redaction, AIMS-overlap, etc.
6. **Rollback** — how to pause/retire if it goes sideways

---

## Workflow

### Step 1 — Inventory candidate routines

Read the audit's `openQuestions` and `pain_points` from `client-config.yaml`. Map each operator-stated pain to a routine template family:

| Operator pain | Candidate routine template |
|---|---|
| "Inbox eats deep-work time" | `common-routines/inbox-scan.md` |
| "AR aging not surfaced for Thursday CFO Day" | `common-routines/ar-prestage.md` |
| "ME top accounts forget accountability" | `common-routines/customer-touch-monitor.md` |
| "Aramco HQ touchpoints fall through quarterly" | `common-routines/customer-touch-monitor.md` (with quarterly cadence) |
| "Sale-process needs weekly written memo" | `common-routines/weekly-memo.md` |
| "Pipeline lies on Friday review without Tuesday hygiene" | `common-routines/calendar-hygiene.md` + `sales-pipeline-watcher.md` |
| "External CRM state isn't visible from where decisions get made" | `common-routines/sales-pipeline-watcher.md` |
| "Lead capture form submissions get lost" | `common-routines/inbox-scan.md` (scoped to lead mailbox + form domains) |
| "Country rotation calls (AIMS biweekly) drift" | scope a variant of `customer-touch-monitor.md` per country |

Don't try to ship every routine on day one. **Pick 1–3 to pilot**. The rest land as draft specs in `routines/` so they exist as known work, not invented later.

### Step 2 — Spec each candidate

Copy `templates/routine-spec.md.template` to `routines/<R-ID>-<slug>.md`. Fill in:

- `id` — operator-facing, matches execution plan numbering if there is one
- `client_slug` — from client-config
- `status: draft` — always start as draft
- `schedule.cron` + `timezone` — match operator's local time, respect hard_anchors
- `scope.mailboxes` — start tight (one mailbox); expand later
- `scope.toRecipients_filter: true` — by default, filter to mail addressed to the operator (avoids the OQ-16 cross-mailbox pollution issue)
- `output.channel` — choose per `references/safety-budget-output.md` decision matrix
- `safety.write_actions: []` — empty unless the operator explicitly opts in to a write
- `acceptance` — write 3 concrete tests the operator can answer "yes/no" to after 1-2 weeks

If you're adapting one of the common-routines templates, **read it first, then copy + customize**. Don't ship the template verbatim.

### Step 3 — Pilot

Use the `/schedule` skill to register the cron. Status `draft → pilot`. The routine runs for 1–2 weeks. Every run writes to `observability.log_file`.

During pilot:
- Operator reviews each run's output (24-hour review SLA)
- False positives / misses get logged as inline comments on the spec
- Scope/budget tweaks are version-bumped in the spec frontmatter (`pilot_revision: 2`)

### Step 4 — Measure → graduate or retire

After 5–10 runs:

- **Graduate to active** if `acceptance` criteria pass: status `pilot → active`. Stop reviewing every run; sample 1-in-10.
- **Retire** if acceptance fails: status `pilot → retired`. Write a `retirement_note` in the body explaining what didn't work. Future routines can learn from it.
- **Iterate** if it's close: bump `pilot_revision`, adjust scope/output/budget, keep running. Hard limit: 3 pilot revisions before retire-or-graduate.

### Step 5 — Steady state

Active routines:
- Are sampled monthly
- Get a quarterly review pass: still useful? Output still actionable? Budget creeping?
- Can be paused (`status: paused`) for vacation / sale-process windows. Resume by toggling status.

---

## Safety rules (every routine must honor)

1. **Default read-only.** `safety.write_actions: []`. Any write requires explicit operator approval per-action.
2. **Hard-anchor respect.** Cron must NOT fire during `hard_anchors` from client-config. If the cron syntax can't express it (e.g., prayer times shift seasonally), the routine itself must check and exit cleanly when current local time falls in a hard-anchor window.
3. **Sale-process / DD redaction.** If `client-config.confidentiality.redact_folders` lists a folder or `confidential_customers` lists a buyer/advisor, the routine MUST NOT mention them in any output channel that isn't the operator's private surface (e.g., zoho_tasks fine, teams_pinned with other employees in the channel = leak).
4. **Budget caps.** `budget.max_graph_calls` enforced — if a run exceeds it, abort with an error log entry, don't silently keep going.
5. **Output cap.** `budget.max_output_chars` — if a run would produce more, summarize + write the full detail to a log file, don't dump 50KB into a Teams message.
6. **Failure surfacing.** Routine errors are logged AND escalated (one-line operator alert) — silent failure is worse than no routine.

---

## Output channel decision (summary)

Full matrix in `references/safety-budget-output.md`. Short version:

| Output channel | When to use |
|---|---|
| `local_file` (daily log) | Pilot phase; operator reviews on demand |
| `zoho_tasks` / external CRM tasks | When the operator's task workflow lives there and routine produces an actionable item |
| `clickup` (or other PM tool) | Same — but for project-tracked items |
| `teams_pinned` (1:1 chat with operator) | High-signal alerts the operator must see same-day |
| `teams_channel` (org channel) | NEVER for confidential or operator-only content — use only for items the whole channel should see |
| `outlook_flagged_email` | When the action is "operator should reply to this thread" — flag the original |
| `note_file_in_onedrive` | Weekly/monthly memos · long-form output |

Default for new routines: **`local_file` in pilot, then promote to `zoho_tasks` or `teams_pinned` once acceptance criteria are met.**

---

## Common routine templates — quick reference

Each lives in `templates/common-routines/` and includes its own pre-filled spec + body:

| Template | Cadence | Purpose | Read |
|---|---|---|---|
| `inbox-scan.md` | daily weekday | classify inbound mail since last run, escalate customer / RFQ / closing-event signals | mail folder, Stage 2A regexes |
| `ar-prestage.md` | weekly (default Thu morning) | scrape AR follow-up subjects from sent + AR mailbox, produce 1-pager for CFO day | ar@ mailbox, AR followup regex |
| `customer-touch-monitor.md` | configurable (daily / weekly / quarterly) | flag customers with no touchpoint > threshold | calendar + sent items |
| `sales-pipeline-watcher.md` | daily | infer stage transitions across mail/calendar/external CRM, post deltas | sales-stage state machine in client-config |
| `calendar-hygiene.md` | weekly | strip `Canceled:` events, surface placeholder-subject events, flag trailing-space subjects | calendar metadata |
| `weekly-memo.md` | weekly | write a confidential weekly memo to a designated audience (e.g., board, shareholder, advisor) | OneDrive note file + recipient list |

---

## Lifecycle states (full picture in references/lifecycle-measurement.md)

```
draft  →  pilot  →  active  ↔  paused
           │          │
           ↓          ↓
        retired    retired
```

- **draft**: spec exists, no cron registered. Operator hasn't approved.
- **pilot**: cron registered, runs every cadence, operator reviews each output, 1-2 week window.
- **active**: cron registered, runs, operator samples output. Steady state.
- **paused**: cron disabled, spec retained. Resumable.
- **retired**: cron removed, spec retained with `retirement_note` in body. Reference for future similar routines.

---

## Anti-patterns

- **Generic mass routines** ("scan every mailbox every hour for anything important") — too noisy, gets ignored, dies in pilot. Always scope tightly.
- **Stage-9 features in a Stage-1 routine** — don't try to do CRM stage transitions in the first inbox-scan. Build narrow + composable.
- **Write actions before pilot validates the read.** If the routine doesn't reliably IDENTIFY the right thing read-only, it has no business taking write actions.
- **Output channel as afterthought.** "Put it in a file somewhere" = nobody reads it. Choose channel deliberately; default to local_file only during pilot.
- **No acceptance criteria.** "Looks good" is not an acceptance test. Write 3 yes/no questions the operator must affirm in week 2.
- **Forever-pilot.** If a routine has been "in pilot" for >4 weeks, either graduate it or retire it. The middle is rot.
- **Routines that bypass client-config.** Hardcoded mailbox names / keywords / customer lists. If client-config changes, the routine must inherit — never duplicate.

---

## Quick-start invocation

When invoked:

1. Confirm the audit directory exists at `audits/<client>-<date>/`. Refuse to proceed if not (`run ms365-tenant-audit first`).
2. Read `client-config.yaml` and the two summary JSONs.
3. Ask the operator: *"Top 3 pains from the audit you want to ship routines for?"*
4. For each pain, select the closest template, copy + customize. Land all specs as `status: draft`.
5. Walk the operator through each draft spec. Get explicit go/no-go.
6. For approved specs: bump to `status: pilot`, register the cron via `/schedule`, write the first run.
7. Schedule a 7-day check-in to review pilot output → decide graduate/iterate/retire.

End by writing a one-line summary of: routines created (id + status), next operator review date, where the spec files live.
