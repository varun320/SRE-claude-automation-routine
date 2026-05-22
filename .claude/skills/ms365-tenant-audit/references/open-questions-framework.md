# Open Questions framework

Every audit produces an `openQuestions` array — the human-review surface. These are items that need product judgment, not engineering. This file defines the schema, categories, and priority semantics so different audit runs are comparable.

## Schema

```json
{
  "id": "OQ-01",
  "priority": "high | medium | low | resolved",
  "category": "<one of the categories below>",
  "question": "Single-sentence framing of the ambiguity",
  "actionIfX": "Recommended resolution if X is true",
  "actionIfY": "(optional) alternate resolution path",
  "_evidence": "(optional) reference to specific raw/ file or finding"
}
```

`id` starts at `OQ-01` and is sequential. New questions surfaced in later stages just continue the numbering.

## Priority semantics

- **`high`** — blocking. Cannot run any write-action routine against this tenant until resolved. Examples: operator identity ambiguity, mailbox-access scoping, conflicting Day-Clock vs reality.
- **`medium`** — non-blocking but shapes routine design. Examples: where does routine output land, which surfaces are in scope.
- **`low`** — nice to know. Examples: stale-folder cleanup candidates, naming-convention drift.
- **`resolved`** — was open at some point, now answered. Keep it in the list so future audits can see the resolution history.

## Categories (use exactly these strings)

| Category | When to use |
|---|---|
| `identity` | Confusion about who someone is, what role they have, whether they're active |
| `mailbox_access` | Operator has full-mailbox-access to other users → scoping decision |
| `scope` | Should this surface be in scope for routines? (shared mailboxes, external systems) |
| `operational` | A real workflow problem the audit surfaced (e.g., 24k unread inbox, 0 rules) |
| `data_anomaly` | A tool returned unexpected results (empty when data clearly exists) |
| `calendar` | Calendar-specific (shared calendar, organizer mismatch, etc.) |
| `calendar_convention` | Convention exists in plan but not in observed data (tags, standing meetings, rotation) |
| `groups_hygiene` | M365 group naming drift, dedup, dormant groups |
| `ecosystem` | External system relationship (Zoho, ClickUp, Salesforce, etc.) — usually about scope expansion |
| `sale_process` | Sale-process / DD / board-restricted material → redaction |
| `external_attendee` | Unexpected external attendee on a meeting |
| `tool_choice` | Where do routine outputs land (which task tracker, which doc surface) |
| `infrastructure` | Service accounts, custom Teams apps, org-scoped connectors — what is this? |
| `naming` | Where do specific artifacts live in the workspace |
| `sharepoint` | SharePoint-specific (modern vs classic, /sites/X vs /Y) |
| `pagination` | How deep should we paginate before synthesis |
| `completeness` | What's missing from this audit pass that downstream stages need |

## Quality bar — what counts as a real Open Question

A good Open Question:

1. Cannot be answered by reading more raw files. It needs a human (operator or someone they consult).
2. Has at least two plausible resolutions, each with downstream impact.
3. Surfaces evidence — quotes the file/path/finding that triggered it.
4. Has a recommended default. The operator should be able to say "yes, default" in 90% of cases.

A bad Open Question is:

- "Should we audit X?" — that's a scope decision, take it as `medium` only if the audit revealed unexpected dependency
- "What's the operator's manager?" — that's missing data, not an open question; flag as a finding instead
- Anything answerable by running one more tool call — just run the call

## Resolution flow

When a later audit run (or a question during walkthrough) resolves an OQ:

1. Change its `priority` to `resolved`
2. Add a `resolution` field with the answer
3. Keep `actionIfX` to show what the default was

Example:

```json
{
  "id": "OQ-04",
  "priority": "resolved",
  "category": "scope",
  "question": "Plan lists 7 AIMS members but only 5 are tenant guests. Find the other 2.",
  "actionIfFound": "Add to client-config.aims_partners with email + role",
  "_evidence": "raw/tenant/users-page1.json — 5 guests visible",
  "resolution": "Resolved 2026-05-21. Sent items + calendar surface 8 additional AIMS contacts (Shameem, Bader, Fazal, Junaid, Ali Albader, Maaz Khan, Yunus, Talha). Plus calendar-only attendees: Vahib Saleem, Sateesh D, Ravi Srinivas, Girish, Muhammad Bilal, Hameed, Naveed Hussain, Ahmad Patel. 21+ AIMS contacts total."
}
```

## Common Open Questions (seed list — pick what applies)

The following OQs appear in nearly every tenant audit. Copy the relevant ones, adapt the wording, fill in evidence:

1. **OQ-01 Operator title discrepancy** — Entra job title doesn't match the operator's actual role description. Decision: which framing drives routines.
2. **OQ-02 Disabled-in-Entra-but-mail-flowing user** — A staff member appears `accountEnabled:false` but their mailbox is still receiving mail. Confirm employment status.
3. **OQ-03 Pagination** — Page 1 only seen for users/groups; staff named in operator profile not yet surfaced.
4. **OQ-04 External partner contact discovery** — Operator profile lists N partners; audit surfaced M. Find the gap.
5. **OQ-05 Inbox rules + write-action expansion** — High unread + zero inbox rules → should routines seed rules or only summarize?
6. **OQ-06 Shared mailbox inclusion** — Which shared mailboxes (`ar@`, `info@`, `sales@`, etc.) are in scope for routine reads?
7. **OQ-07 Tool data anomaly** — A tool returns empty when data clearly exists (e.g., `search-sharepoint-sites`). Document fallback.
8. **OQ-08 Org chart not populated** — `get-my-manager` returns 404. Should we populate?
9. **OQ-09 Project group naming drift** — 50+ project groups with inconsistent naming (Altagas vs Harmattan vs Harmatten). Dedup strategy.
10. **OQ-10 Shared calendar access** — Operator has read+edit access to another user's calendar. Why?
11. **OQ-11 External CRM scope** — Outlook surfaces (contacts, ToDo) are empty; the real data lives in Zoho / ClickUp / Salesforce. Promote external system to in-scope?
12. **OQ-12 Service accounts** — Unidentified user with recent creation date. Service account or human?
13. **OQ-13 Custom Teams app** — Org-scoped Teams app with no public docs. What is it?
14. **OQ-14 Sale-process artifacts** — Where do board / DD / sale documents live? (For redaction.)
15. **OQ-15 Chat pagination depth** — Operator has 100+ chats. How deep to paginate?
16. **OQ-16 Mailbox-access scoping** — Operator has full access to multiple mailboxes; routines reading "their inbox" need explicit toRecipients filter.
17. **OQ-17 Mailbox active despite Entra disabled** — Same as OQ-02 but framed as a scoping question.
18. **OQ-18 Day Clock vs observed reality** — Execution plan defines standing meetings + calendar tags + rotation cadences that don't match observed data. Implement, rewrite plan, or hybrid?
19. **OQ-19 OneDrive sensitive folder** — Folder name suggests sale-process or board material. Confirm + add to redaction.
20. **OQ-20 External anomalous attendee** — A meeting includes an external email that looks like a typo or sister-venture. Confirm.
21. **OQ-21 Output channel** — Microsoft ToDo is dead. Where do routine outputs land (Zoho Tasks, ClickUp, SharePoint list, Teams pinned)?
22. **OQ-22 SharePoint modern-vs-classic** — Modern `/sites/X` exists alongside classic `/Y` for the same domain. Which is canonical?
23. **OQ-23 Pagination completeness** — Sufficient sample for synthesis, or pull more pages first?

## How to surface OQs in the dashboard

Render as collapsible cards in the Open Questions tab. Sort by priority (high → resolved). Filter chips for category. Show:

- ID (left, mono, muted color)
- Priority badge (left, color-coded)
- Question text (center, prominent)
- Click to expand → category + body + evidence + actionIfX

The walkthrough is led by the operator — they answer the high-priority ones live, the medium can be deferred to a follow-up, and low are FYI.
