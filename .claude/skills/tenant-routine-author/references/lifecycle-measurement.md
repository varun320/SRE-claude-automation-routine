# Lifecycle and measurement

How a routine evolves through `draft → pilot → active → paused → retired`, and how to know which phase it should be in.

---

## State machine

```
              create
          ─────────────►
              ┌──────┐
              │draft │  spec exists, no cron, operator hasn't approved
              └──┬───┘
                 │ operator approves + /schedule registers cron
                 ▼
              ┌──────┐
              │pilot │  cron live, operator reviews EVERY run, 1-2 weeks
              └──┬───┘
                 │
        ┌────────┼────────┐
        │        │        │
   acceptance  pilot   acceptance
    passes    revision  fails 3x
        │     (loop)     │
        ▼        │       ▼
  ┌────────┐     │  ┌────────┐
  │ active │◄────┘  │retired │
  └──┬─────┘        └────────┘
     │                  ▲
     │ pause/resume     │
     ▼                  │ explicit retire
  ┌────────┐            │
  │ paused │────────────┘
  └────────┘
```

---

## Phase definitions

### draft

- Spec file exists at `routines/<id>-<slug>.md`
- `status: draft`
- Cron NOT registered
- Operator has NOT approved
- Body of spec has been walked through with operator but they haven't signed off

**Time-cap**: 1 week. After 7 days as draft without approval, surface as a pending decision. Either approve → pilot or retire → "operator chose not to proceed".

**Exit to pilot when**: operator gives explicit go-ahead AND `/schedule` registers the cron AND first scheduled run is logged.

### pilot

- Spec is `status: pilot`
- Cron IS registered, running on cadence
- Operator reviews EACH run's output within 24h
- Iteration is expected: scope tweaks, budget tweaks, output-channel changes
- Track each iteration with `pilot_revision` increment in frontmatter + inline note in body

**Time-cap**: 4 weeks. Hard limit. After 4 weeks:
- If acceptance criteria are met → graduate to `active`
- If acceptance criteria are not met after 3 pilot revisions → retire
- If progress is real but not done → operator's call: extend or retire

**Exit to active when**: acceptance criteria checked off AND 10 consecutive runs without operator pushback.

**Exit to retired when**: 3 pilot revisions completed without meeting acceptance OR operator explicit retire.

### active

- Spec is `status: active`
- Cron IS registered, running on cadence
- Operator samples output (e.g., 1-in-10 runs)
- Quarterly review: still useful? Still accurate? Budget still right?
- Operator updates only when scope or behavior should change — otherwise hands-off

**No time cap** — active routines run indefinitely until paused or retired.

**Quarterly review checklist**:
- [ ] Sampling shows accuracy still > 80%
- [ ] Output is still being acted on (not ignored)
- [ ] Budget creep < 50% from initial
- [ ] No silent failures in the last 30 days
- [ ] Operator still endorses "this saves me time"
- [ ] No drift between routine output and source-of-truth state (CRM, calendar, etc.)

If any answer is no → flip back to `pilot` for a revision.

### paused

- Spec is `status: paused`
- Cron is DISABLED (or its `cron_alternate_paused` field holds the previous cron value)
- No runs happening
- Operator can resume → flip back to `active` or `pilot` depending on previous state

**Use cases**: operator vacation, sale-process freeze, client engagement boundary changes, holiday weeks.

**Best practice**: when pausing, write a `paused_reason` field in the frontmatter and a date for review (e.g., `resume_check_date: 2026-06-15`). Don't leave routines paused forever — that's effectively retired without the paperwork.

### retired

- Spec is `status: retired`
- Cron is REMOVED entirely (not just disabled)
- Spec file is retained as a `routines/_retired/<id>-<slug>.md` reference

**Why retain retired specs**: future routine design benefits from knowing what was tried and why it didn't work. A retirement note in the spec body — what failed, what we learned, what to try differently — is part of the institutional memory.

---

## Acceptance criteria — what makes them real

Bad acceptance criteria:

- "Routine works" (too vague)
- "Operator likes it" (subjective without anchor)
- "Output looks good" (no measurement)
- "No errors in pilot" (absence of failure ≠ presence of value)

Good acceptance criteria are **yes/no questions the operator can answer after 1-2 weeks** with specifics:

- "False positive rate < 20% across the first 10 runs"
- "Operator took action on > 5 of the first 10 routine outputs"
- "Operator confirms 'this routine surfaced something I would have missed' on at least 2 occasions"
- "Routine output is in the channel where operator's workflow already lives"
- "Average runtime under 60s across the first 10 runs"
- "No budget overruns in pilot window"
- "When operator was on vacation, paused/resumed cleanly without backlog corruption"

Every spec MUST have at least 2 measurable criteria. If you can't write 2, the routine probably isn't well-defined enough to ship.

---

## Measurement signals

Each routine emits a structured log per run. Standard fields:

```json
{
  "run_id": "R1-2026-05-21T13:00:00Z",
  "routine_id": "R1",
  "client_slug": "acme",
  "started_at": "2026-05-21T13:00:00Z",
  "finished_at": "2026-05-21T13:00:43Z",
  "duration_seconds": 43,
  "exit_code": "success | hard_anchor_skip | budget_exceeded | error | spec_invalid",
  "graph_calls_made": 28,
  "graph_calls_budget": 50,
  "output_chars": 1840,
  "items_processed": 47,
  "items_escalated": 3,
  "items_filtered_noise": 31,
  "items_in_window": 47,
  "escalations": [
    { "type": "closing_event", "subject": "...", "from": "...", "score": 0.92 }
  ],
  "warnings": [],
  "errors": []
}
```

### Per-routine metrics (computed from logs)

| Metric | Definition | Healthy range |
|---|---|---|
| **Escalation rate** | `items_escalated / items_processed` | 5–30% (lower = potentially missing signal; higher = noisy) |
| **Noise rate** | `items_filtered_noise / items_in_window` | 30–70% (much lower = scope too narrow; much higher = trying to do too much) |
| **Action rate** | `operator_actions_taken / items_escalated` | > 50% target — if escalations land but nobody acts, output is wrong-channel or wrong-content |
| **Duration p95** | 95th percentile runtime | < `max_runtime_seconds * 0.7` (room to grow) |
| **Budget headroom** | `1 - max(graph_calls_made) / max_graph_calls` | > 30% (anything tighter is fragile) |
| **Skip rate** | `hard_anchor_skip + error / total_scheduled_runs` | < 10% (otherwise the schedule is wrong) |

### Cross-routine metrics

Roll up across all routines for the client:

- Total routines: by status (draft / pilot / active / paused / retired)
- Average pilot duration to graduate
- Average pilot revisions before graduate
- Pilot graduation rate (graduates / [graduates + retired-from-pilot])
- Routines that have NOT logged a run in > 7 days (stale or broken cron)
- Routines that exceed budget more than once a week (candidate for tightening)

A simple dashboard can render these metrics — see `ms365-tenant-audit` dashboard-template for the visual style.

---

## Common failure modes during pilot

| Symptom | Diagnosis | Fix |
|---|---|---|
| Operator doesn't review pilot output | Output channel wrong, or routine fires at wrong time of day | Switch to higher-signal channel; check `schedule.cron` vs operator's actual workflow time |
| Output is correct but ignored | Wrong channel OR output format too dense | Try `teams_pinned` instead of `local_file`; or change `format: structured-summary` → `one-line` |
| Output is wrong (false positives) | Scope too broad OR keywords too generic | Tighten `scope.window_hours_back`, add `exclude_keywords`, narrow `customer_keywords_source` |
| Output misses real signal (false negatives) | Scope too narrow OR routine missing a regex case | Loosen `scope.exclude_senders`, add more `trigger_event_hints` |
| Budget overruns | Window too large OR endpoint paginates too aggressively | Switch to delta/incremental pull, tighten `window_hours_back`, raise `max_graph_calls` only if window can't shrink |
| Routine works but feels redundant | Operator already does this task by hand and routine just confirms | Either retire OR add a write-action that saves the manual step (with the safety preconditions) |
| Output channel breaks (Teams 404 / Zoho 500) | Routine has no fallback | Add `output.fallback_channel: local_file` so failed channel ≠ lost run |

---

## Pilot → active checklist

Before flipping status from pilot to active, run through:

- [ ] All acceptance criteria satisfied (yes to every yes/no)
- [ ] 10 consecutive runs without operator pushback
- [ ] Output channel decision validated (not "we'll figure it out later")
- [ ] Budget headroom > 30%
- [ ] Run log retention configured (`observability.log_keep_days`)
- [ ] Spec body has a real example of good output (not "TBD")
- [ ] Spec body has a real example of bad output (caught at least one false positive)
- [ ] Operator has signed off in writing (quote captured in spec body)
- [ ] Hard-anchor enforcement verified (one run during a hard-anchor window correctly skipped)
- [ ] Quarterly review date scheduled

If any unchecked → keep in pilot one more revision.

---

## Retirement done well

When a routine retires, the spec body gets a retirement note:

```markdown
## Retirement note

**Retired on**: 2026-06-20
**By**: Maaz Ahmed Shareef
**Status before retire**: pilot (rev 3)
**Why**:
- 3 pilot revisions did not bring false-positive rate below 30%
- Underlying issue: subject-line regexes can't distinguish closing events from
  routine progress reports without per-customer customization
- Routine kept escalating engineering progress meetings as "closing events"

**What we learned**:
- Closing-event detection needs more than subject keywords; it needs context
  (was there a draft proposal sent recently? Is there a recent `verbal_yes` signal?)
- The next iteration should be a R6-style state-machine watcher, not a R1-style
  inbox scan.

**Linked: R6 (CRM-Watch)** — the replacement routine that addresses this gap.
```

Retired routines stay in `routines/_retired/` indefinitely. They're the institutional memory of what was tried.
