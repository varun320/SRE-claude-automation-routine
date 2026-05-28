---
id: DECISION-2026-05-26
title: Maaz's Phase-1 Routine Approval Decisions
date: 2026-05-26
status: authoritative
operator: Maaz Ahmed Shareef
collaborator: Mohammad (info@callreceptionist.ai)
supersedes:
  - "Maaz-Routine-Approval-Answers.docx (root, original artifact)"
linked_audit_findings:
  - "audits/sre-2026-05-21/data/stage-2-to-7-summary.json (all 23 OQs)"
applies_to:
  - routines/tier1/R1-na-inbox-scan.md
  - routines/tier1/R2-daily-setup.md
  - routines/tier1/R5-me-inbox-scan.md
  - routines/tier1/R8-sunday-planning.md
  - runbook/ms365-deep-audit-workflow/client-config.yaml.draft
  - ".claude/skills/sre-email-drafter/**"
  - ".claude/skills/tenant-routine-author/**"
---

# Maaz's Phase-1 Routine Approval Decisions

Authoritative record of the 12 questions Mohammad sent Maaz on 2026-05-22 (generated from the 23 Open Questions surfaced by the 2026-05-21 audit) and the answers Maaz returned 2026-05-26. Every Phase-1 routine spec references this document; do not modify decisions here without writing a superseding decision record.

The original source artifact is `Maaz-Routine-Approval-Answers.docx` at repo root (gitignored under `*.docx` pattern; track its sha256 here if needed for provenance).

---

## D1 — Maaz's role title in routine outputs

**Decision:** Treat Maaz as **CEO / General Manager** (decision-maker). Leave the Microsoft directory title "Analyzer Expert" in place — it signals technical-work context inside the tenant, not org-chart authority.

**How routines apply this:**
- Routine outputs that name Maaz (R2 Top 3, R8 weekly brief) address him as decision-maker.
- Skills that read directory titles (`ms365-tenant-audit`) keep the "Analyzer Expert" entry but annotate it as a technical role tag, not the canonical title.

---

## D2 — Inshan's status in routines

**Decision:** Inshan has left, but routines should **continue treating him as on-staff for now**. The Microsoft account state needs to be aligned with HR records.

**Open item for Mohammad:** Reconcile Inshan's Entra account (currently disabled per audit) with HR's actual record before R1 fires. Decide whether his mail folders are read-only-archived or fully removed from `in_scope_users_metadata`.

---

## D3 — Don Green calendar access

**Decision:** Maaz's full read-access to Don's calendar is **intentional** and persists. Don has left, but the access stays.

**Hard rule:** Routines must NOT surface Don's meetings as if they were Maaz's. Anything pulled from Don's calendar is annotated `[via Don's calendar]` or excluded from R2/R8 personal-planning outputs.

---

## D4 — Org chart (used by routines for "who reports to whom" logic)

**Decision:** Use the **SRE DD Section 12 - HR and Benefits.docx** structure as of **November 2025**. Override the earlier "Dwayne Vinck (Board Chairman) as manager" placeholder — the DD record names **Zaheer Juddy as parent-company Director** (parent = ZSL Canada Holding Corp).

**Final structure for routine logic:**

```
Board of Directors
├── Mohammed Maaz Ahmed Shareef — Director
└── Zaheer Juddy — Director (Parent: ZSL Canada Holding Corp.)

Executive Leadership
└── Maaz Ahmed Shareef — General Manager / CEO

Reports directly to GM/CEO
├── Chuck Stephenson — General Manager, USA
├── Dharmesh Patel, P.Eng. — Principal Process Engineer
├── Ron Armstrong, P.Eng. — Senior Engineer / Business Development
└── Ashley Hartt — Administration & Health/Safety Representative

Reports to Principal Engineer (Dharmesh Patel)
├── Utsav Chovatia, EIT — Process Engineer
├── Kunal Rajput, EIT — Process Engineer
├── Sharukh Ali — Process Engineer
├── Kurtis Marshall — Junior Engineer
└── Hardik Lunagariya — Junior Engineer / Student
```

**Open items for Mohammad:**
1. Talha appears to be an AIMS resource (not on SRE payroll). Confirm.
2. Reconcile Inshan per D2.
3. Identify any post-Nov 2025 hires that should be added.

**Source:** SRE DD / Section 12 - HR and Benefits.docx (OneDrive, last updated 2025-11-19).

---

## D5 — Inbox behavior (R1, R5)

**Decision:** **Summarize + auto-archive obvious junk.**

**Auto-archive ruleset (must match all three):**
1. Sender domain is on the noise allowlist (initial seed: `linkedin.com`, `alarm.com`, plus marketing list patterns matching the Email-Marketing regex below).
2. Message is read-only / FYI — no action implied by subject.
3. No human-named SRE staff member is in `toRecipients` *individually* (i.e., it's a bulk send).

**Initial noise allowlist (Phase 1 seed):**
- `linkedin.com` (LinkedIn newsletters, alerts, learning emails)
- `alarm.com` (premise alarm notifications)
- Marketing regex: `(?i)(unsubscribe|view in browser|newsletter|promotional|special offer|webinar invite)` in the body **header** — never the body proper, to keep token budget down.

**Hold for later phases:**
- Option C (rule-based suggestions to operator) — deferred until pilot is stable.
- Option D (autonomous rule creation) — Phase 3+ at earliest.

**Volume rationale:** 24,763 inbox / 8,692 unread makes pure summarize-only too noisy. Some archival is mandatory to keep R1 output usable.

---

## D6 — Scope of "your inbox" (R1, R5)

**Decision:** Maaz's mailbox + `info@sulfurrecovery.com` + `info-me@sulfurrecovery.com`.

**Explicitly OUT of scope for morning summary:** Don's mailbox, Inshan's mailbox.

This works in tandem with the audit OQ-16 `toRecipients ∋ maaz@sulfurrecovery.com` filter — but extends the explicit allow-list to also include `toRecipients ∋ info@sulfurrecovery.com` OR `info-me@sulfurrecovery.com`.

---

## D7 — Shared mailboxes (R5, R8)

**Decision:** Include **all 10 active shared mailboxes** in the routine sweep.

**Roster:**
1. `ar@sulfurrecovery.com` — accounts receivable
2. `ap@sulfurrecovery.com` — accounts payable
3. `info@sulfurrecovery.com` — company-wide signal
4. `info-me@sulfurrecovery.com` — Middle East regional signal
5. `sales@sulfurrecovery.com` — sales inbox
6. `careers@sulfurrecovery.com` — hiring
7. `apple@sulfurrecovery.com` — apple-ecosystem device coordination
8. `HusamsBookingPageSRE@sulfurrecovery.com` — booking page
9. `boardroom@sulfurrecovery.com` — board / governance
10. *(disabled scanner mailbox — referenced for audit completeness, not actively swept)*

**Note:** "Active" excludes the disabled scanner mailbox from the live sweep but keeps it documented in `client-config.yaml`.

---

## D8 — Zoho One scope

**Decision:** **Remove Zoho One from all scope.** Zoho One was deactivated months ago.

**Open item for Mohammad:** Sweep repo for any residual Zoho references (templates, skill prompts, audit notes) and remove them. Future re-introduction requires an explicit superseding decision.

---

## D9 — Day Clock: plan vs reality

**Decision:** Routines operate against the **actual observed cadence**, not the original Day Clock plan.

**Observed cadence (canonical for routine cron + brief logic):**
- **Thursday 10:00 MT — Bi-Weekly Job Meeting** (replaces the planned daily Engineering standup pattern)
- **Weekly — Maaz ↔ Torstein 1:1** (replaces the previous fixed-day standing meeting assumption)
- **Monthly — Pitstop** (replaces the monthly all-hands assumption)

The original `Day Clock` from the Weekly OS remains as **aspirational target** — routines may surface drift from plan in R8 weekly brief, but they must not block on it.

---

## D10 — "SRE DD" folder confidentiality

**Decision:** Treat SRE DD folder contents, Torstein 1:1 subjects, P&L content, and any board-prep material as **fully confidential**. Never surface in any routine output (inbox summaries, Top 3, weekly brief, daily close, anywhere).

**CRITICAL UPDATE (2026-05-26):** The **SRE sale process is OFF** as of 2026-05-26. Update all routine instructions and skill templates to:
- **Remove:** "active sale process" framing, "sale-process buyer", "sale-process advisor", references to a live transaction.
- **Replace with:** *"Sensitive corporate / financial / HR / board material — never surface in any output."*

The folder remains confidential because it contains DD-grade financial, HR, and board material that pre-dated and outlasts the sale process.

**Files in scope of this reframe (initial list — see repo sweep task):**
- `runbook/ms365-deep-audit-workflow/client-config.yaml.draft` (lines mentioning sale_process_buyer/advisor, service_lines.sale_process)
- `.claude/skills/sre-email-drafter/**` (templates mentioning sale process)
- `.claude/skills/tenant-routine-author/**`
- `routines/tier1/R8-sunday-planning.md` (edge cases section)
- `SRE Claude Routines - Execution Plan.md`
- Any pain_points / confidential_customers entries

---

## D11 — Output channel for routines

**Decision:** Build a **custom webapp** with proper auth + session for Maaz to view routine outputs. No iMessage, no Pushover, no per-message charges.

**Channel split:**
- **Daily routines (R1, R2, R5):** webapp inbox queue + OneDrive markdown mirror (in case webapp is down)
- **Weekly / monthly (R8, R9 when shipped):** OneDrive markdown notes Maaz can re-open

**Architecture direction (full plan in `docs/output-webapp-plan.md`):**
- Auth: Entra ID SSO (Maaz logs in with his existing M365 identity — no new password)
- Storage: routines write markdown to a dedicated OneDrive folder; webapp reads via Graph
- No per-message charges: webapp polls/refreshes; no SMS/iMessage relay subscriptions
- Deployment: Azure Static Web Apps (lowest cost path, free tier acceptable for single user)

**Fallback during webapp build:** Teams chat with self for daily, OneDrive notes for weekly. This unblocks Phase 1 pilot independent of the webapp delivery date.

**Open item for Mohammad:** Webapp MVP scope, deployment target, and timeline. See webapp plan doc.

---

## D12 — calldental.ai / callreceptionist.ai

**Decision:** `calldental.ai` was a typo. The collaborator address is **`info@callreceptionist.ai`** (Mohammad). All references to calldental.ai should be removed or treated as the same identity.

---

## Open items requiring Mohammad-side action (consolidated)

| ID | From | Action | Blocks |
|---|---|---|---|
| OPEN-A | D2 | Align Inshan's MS account state with HR (active vs disabled) | R1 first fire |
| OPEN-B | D4 | Confirm Talha + post-Nov 2025 hires for org chart | R2/R8 high-fidelity output |
| OPEN-C | D8 | Sweep repo for residual Zoho config / connector references | Phase-1 cleanup commit |
| OPEN-D | D10 | Update routine instructions to drop "sale process" framing | Phase-1 cleanup commit |
| OPEN-E | D11 | Technical scoping for webapp MVP (auth, hosting, data flow) | Webapp delivery |

---

## Supplementary decisions (2026-05-27) — M1–M5 follow-up

After the 2026-05-26 answers landed, Mohammad surfaced 5 follow-up items in the "What Maaz needs to do" section of the audit response. Resolved 2026-05-27.

### M1 — Azure "Allow public client flows"
**Decision:** Already enabled. No action required.

### M2 — Webapp hosting + domain
**Decision:** **Vercel free tier**, on a domain separate from `sulfurrecovery.com`.

- **Start:** `*.vercel.app` default — zero DNS, instant.
- **Optional W7:** migrate to `routines.callreceptionist.ai` (Mohammad-owned subdomain) once the pilot is stable.
- **Not** on `sulfurrecovery.com` — routines is Mohammad's deliverable to Maaz, not SRE IT. Boundary hygiene.

**Why over Azure Static Web Apps (the v0 proposal):**
- Same free-tier economics, comparable performance.
- Mohammad's likely toolchain favors Vercel DX.
- Hosting outside `sulfurrecovery.com` keeps the webapp decoupled from SRE infrastructure choices.

Auth model is unaffected — Entra ID SSO from a non-Microsoft-owned domain is the same pattern Slack/Notion/etc. use every day.

### M3 — Webapp readers
**Decision:** **Maaz + Mohammad**. Both authenticate via Entra ID SSO.

**Mechanism:** Mohammad joins as a **guest user** in Maaz's tenant; Maaz shares the `/SRE Routines/` OneDrive folder with him. Single Entra app, single redirect-URI set, one code path. Maaz signs in as a member, Mohammad as a guest — same MSAL flow, different `oid`.

**Per-reader cursor:** "unread" state is local-storage per reader, not a shared global.

Alternative (multi-tenant Entra app) rejected because Mohammad signing in with his own `callreceptionist.ai` identity would only see his own OneDrive, not Maaz's. Guest-user pattern is the cleaner path.

### M4 — OneDrive root path
**Decision:** `/SRE Routines/` (default). Sub-folders per routine: `/SRE Routines/R1-na-inbox-scan/`, `/R2-daily-setup/`, `/R5-me-inbox-scan/`, `/R8-sunday-planning/`. Index manifest at `/SRE Routines/_index.jsonl`.

### M5 — Talha + post-Nov 2025 hires
**Decision:** **Deferred.** Not blocking Phase 1 pilot. Reconcile at next org-chart refresh cycle. Tracked as OPEN-B in the table below.

---

## Open items — updated status (2026-05-27)

| ID | Description | Status |
|---|---|---|
| OPEN-A | Inshan MS account state vs HR | **resolved 2026-05-27** via direct Graph lookup — `accountEnabled: false`, `assignedLicenses: []`, account already disabled. Only residual: stale `jobTitle: "Principal Process Engineer"` (Dharmesh holds that title now). Not blocking — routines don't read jobTitle. |
| OPEN-B | Talha + post-Nov 2025 hires confirmation | open — deferred per M5 |
| OPEN-C | Zoho cleanup sweep | done 2026-05-26 (no Zoho refs in routines/runbook) |
| OPEN-D | Sale-process reframe across docs | done 2026-05-26 (banners + client-config updated) |
| OPEN-E | Webapp scoping (auth, hosting, data) | resolved 2026-05-27 via M1–M4 + webapp plan v0.1 |
| OPEN-F | Run all 5 prompts in `connectors/connector-check.md` + append logbook entry | open — soft prereq |
| OPEN-G | Confirm with `/schedule` how cloud agents authenticate to MS365 MCP | **resolved 2026-05-27** via `schedule` skill invocation — cloud agent uses claude.ai connector marketplace (not local token cache). User confirmed MS365 is available in marketplace. Connect at https://claude.ai/customize/connectors before cloud-cron registration. |
| OPEN-H | Smoke-test `mcp__ms365__move-mail-message` | open — gated behind dry-run pass + cloud connector setup |
| OPEN-I (new) | Inshan `jobTitle` stale (residual from OPEN-A) | open — non-blocking cleanup |
| OPEN-J (new) | Cron UTC conversion for R1/R2/R5/R8 + DST handling | open — needed at cloud-cron registration time |
| OPEN-K (new) | Connect MS365 + install Claude GitHub App for varun320/SRE-claude-automation-routine | open — hard prereq for cloud cron, see dry-run-runbook §"After a clean dry-run pass" |

## Provenance

- **Question doc** (Mohammad → Maaz): generated 2026-05-22 by `scripts/generate-maaz-questions-docx.py` from audit `stage-2-to-7-summary.json` Open Questions.
- **Answer doc** (Maaz → Mohammad): `Maaz-Routine-Approval-Answers.docx`, dated 2026-05-26.
- **M1–M5 supplementary answers**: chat response 2026-05-27.
- **Audit base:** `audits/sre-2026-05-21/` (gitignored — local-only).
