# Stage 8 — Customer 360 Synthesis

**Purpose.** Join every signal pulled in stages 2A–7 into a single **unified customer record**. This is the linchpin output of the audit — every dashboard, every routine, every downstream skill consumes this file.

**Pre-requisite.** All previous stages completed; all raw + per-stage analysis JSONs present.

**Output.** `data/customer-360.json` — one record per customer with everything we know joined together AND a synthesized narrative note.

**Safety.** No new data is pulled here; this is pure local joining + summarization. But the OUTPUT contains everything sensitive in one place — `customer-360.json` is the most security-critical artifact of the audit. Keep it inside the audit-run directory.

**Run time.** 2–10 minutes (Python over local JSONs).

---

## 1. The join key problem

GHL gave us a stable `contactId` to join on. MS365 doesn't. We need to invent a canonical customer key.

**Strategy: the customer's email domain is the primary join key.**

- `aramco.com` → "Saudi Aramco"
- `adnoc.ae` → "ADNOC"
- `cenovus.com` → "Cenovus Energy"

For each external domain seen across mail/calendar/Teams/people:
- Aggregate all signals
- Resolve a canonical company name (via `client-config.yaml :: known_top_customers`, OR via Outlook `companyName`, OR via SharePoint Jobs Tracker, OR via inferred-from-domain heuristics)
- Mark whether it's a `customer`, `prospect`, `vendor`, `partner`, or `unknown` (based on signals + Maaz's confirmation)

**Edge cases the synthesizer must handle:**
- **Generic provider domains** (`gmail.com`, `outlook.com`, `yahoo.com`) — never auto-promote to a "customer". Group as `personal_email_individuals` and surface per-person.
- **Multi-domain customers** (a customer that emails from `@parent.com` AND `@subsidiary.com`) — use `client-config.yaml :: known_top_customers` for the explicit grouping. Otherwise keep as separate records and flag in `openQuestions`.
- **Internal-as-external mistakes** (a colleague who emails from their personal address) — `client-config.yaml :: internal_personal_aliases` covers these.
- **NDA/private customers** — handled via `client-config.yaml :: excluded_customers`; rendered as `***REDACTED***` in dashboards but still present in the underlying JSON.

---

## 2. Input materials

| Stage | Output consumed | What we extract |
|---|---|---|
| 1 — Tenant | `tenant-summary.json` | Internal domain, in-scope mailboxes |
| 2A — Mail | `mail-analysis.json`, `messages-flat.json`, `attachments-flat.json` | Per-domain message counts, last in/out, subject classifications, attachment classifications, folder placements |
| 2B — Calendar | `calendar-analysis.json`, `events-flat.json` | Per-domain meeting counts, time spent, last met, recurrence patterns, transcripts (linked) |
| 2C — Contacts | `people-analysis.json` | Per-person attributes (name, title, phones), rolodex status |
| 3 — SharePoint | `sharepoint-analysis.json`, `documentInventory` portion, CRM-candidate lists | Customer-tagged docs, CRM stage values |
| 4 — OneDrive | `onedrive-analysis.json` | Customer-tagged files (proposals/contracts/invoices) |
| 5 — Teams | `teams-analysis.json` | Per-customer chats, channel mentions, meeting count/time, transcripts |
| 6 — Planner/ToDo | `tasks-analysis.json` | Customer-named tasks, overdue items |
| 7 — OneNote | `onenote-analysis.json` | Per-customer notebook section presence |

---

## 3. Output JSON shape — `data/customer-360.json`

```json
{
  "generatedAt": "...",
  "client": "sulfur-recovery-engineering",
  "totals": {
    "customers": 187,
    "customersActive2yr": 92,
    "customersDormant": 51,
    "customersWithOpenProposal": 18,
    "customersWithOpenAR": 11,
    "prospects": 24,
    "vendors": 38,
    "redacted": 2
  },
  "customers": [
    {
      "key": "aramco.com",
      "displayName": "Saudi Aramco",
      "type": "customer",
      "domains": ["aramco.com"],
      "region": "ME",
      "category": "hot",                                  // hot/warm/cooling/stalled/ghosted/cold/won/lost/dormant
      "engagementScore": 92,                              // 0-100, computed from signals
      "firstSeen": "2024-09-12",
      "lastTouch": "2026-05-19",
      "daysSinceLastTouch": 3,
      "people": [
        { "address": "...", "displayName": "Mohammed Al-...", "jobTitle": "Senior Process Engineer",
          "isInRolodex": true, "lastSeen": "2026-05-19", "messageCount2yr": 102 }
      ],
      "mail": {
        "messages2yr": 412,
        "inbound2yr": 198,
        "outbound2yr": 214,
        "lastInbound": "2026-05-19",
        "lastOutbound": "2026-05-19",
        "subjectsByClass": { "proposal": 14, "invoice": 8, "ar_followup": 3 },
        "attachmentsByClass": { "proposal_pdf": 6, "drawing_pdf": 4, "invoice_pdf": 8 },
        "folderPlacements": { "Inbox/Customers/Saudi Aramco": 380, "Inbox": 32 }
      },
      "calendar": {
        "meetings2yr": 23,
        "hours2yr": 41.5,
        "lastMet": "2026-05-19",
        "recurringSeries": ["Saudi Aramco - bi-weekly review"],
        "scheduledForward": 3
      },
      "teams": {
        "channels": [],
        "chats": [ { "chatId": "...", "messages2yr": 84, "lastMessage": "..." } ],
        "meetings2yr": 11,
        "transcriptsAvailable": 6
      },
      "documents": [
        { "source": "sharepoint", "site": "SRE Operations", "library": "Proposals",
          "name": "Proposal_Aramco_Train4_2026-05-20.pdf", "classification": "proposal",
          "lastModified": "2026-05-20", "webUrl": "..." },
        { "source": "onedrive", "drive": "Maaz", "path": "/Customers/Saudi Aramco/2026/Train 4",
          "name": "Proposal_Aramco_Train4_v3.docx", "classification": "proposal_draft" }
      ],
      "crmStage": {
        "source": "sharepoint:Jobs Tracker",
        "stage": "Proposal Sent",
        "value": 850000,
        "currency": "USD",
        "owner": "Maaz",
        "due": "2026-08-01",
        "rowId": "37"
      },
      "tasks": [
        { "source": "planner", "title": "Aramco Train 4 - send proposal", "status": "inProgress",
          "due": "2026-06-01", "owner": "Maaz" }
      ],
      "notebookSections": ["Aramco"],
      "openProposals": [ { "name": "Proposal_Aramco_Train4_2026-05-20.pdf", "sent": "2026-05-20" } ],
      "openInvoices": [],
      "narrativeNote": "Saudi Aramco. Active customer in ME region. 412 emails (198 in / 214 out), 23 meetings over 2yr, 6 sales-call transcripts available. Currently in 'Proposal Sent' stage on Jobs Tracker — $850K value, due 2026-08-01. Proposal sent 2 days ago (Proposal_Aramco_Train4_2026-05-20.pdf). 1 active planner task. Replied within the last 3 days — engagement is hot.",
      "findings": [
        { "severity": "low", "title": "Proposal sent 2 days ago — no follow-up scheduled" }
      ]
    }
  ],
  "openQuestions": [
    "Domain 'gmail.com' has 248 messages across 32 senders — no auto-grouping; review per-person",
    "Domain 'aramcosc.com' likely a subsidiary of aramco.com — confirm grouping",
    "Detected 14 customers via mail but no SharePoint Jobs Tracker row — pipeline gap"
  ]
}
```

---

## 4. Categorization logic

Each customer is assigned a single `category` based on multi-signal rules:

| Category | Rule |
|---|---|
| **won** | CRM-candidate row says `Won` OR ≥1 paid invoice OR explicit signed-contract file |
| **lost** | CRM row says `Lost` OR explicit "regret/not selected" inbound OR proposal sent + 180d silence |
| **hot** | Active proposal + inbound reply within last 7d + meeting within last 14d |
| **warm** | Active proposal + inbound within last 30d |
| **cooling** | Active proposal + no inbound 30–60d |
| **stalled** | Active proposal + no inbound 60–120d |
| **ghosted** | Active proposal + no inbound >120d |
| **cold** | No proposal, no meeting in 180d, but historically active |
| **dormant** | No activity in 12mo+ |
| **prospect** | First seen <90d, no proposal yet, ≥1 inbound or ≥1 meeting |
| **unknown** | Doesn't fit any of the above |

Rules check in order — first match wins.

---

## 5. Engagement score (0–100)

```
score =  20 * tanh(messages2yr / 50)        // mail volume
       + 20 * tanh(meetings2yr / 10)        // meeting volume
       + 15 * recency_factor(lastInbound)    // reply recency (decays over 90d)
       + 10 * (1 if openProposals else 0)
       + 10 * (1 if recurringSeriesExists else 0)
       + 10 * tanh(transcriptsAvailable / 3)
       + 10 * (1 if notebookSection else 0)
       + 5  * (1 if isInRolodex else 0)
```

Higher = more engaged. Used for ranking on the Customer 360 dashboard.

---

## 6. Narrative-note generator

Each customer gets a 2–4 sentence English note synthesizing the joined record. Generated deterministically (no LLM call — Python templating) using rules like:

```
"{displayName}. {type=customer→'Active customer in {region}.'}
 {messages2yr} emails ({inbound2yr} in / {outbound2yr} out),
 {meetings2yr} meetings over 2yr.
 {transcriptsAvailable>0 ? f'{transcriptsAvailable} call transcripts available.' : ''}
 {crmStage.stage ? f"Currently in '{crmStage.stage}' stage" + (f" — ${crmStage.value:,.0f} value" if crmStage.value else "") + '.' : ''}
 {openProposals ? f"Proposal sent {openProposals[0].sent.ago}." : ''}
 {tasks.length} planner task(s).
 {category=hot→'Replied within last 7 days — engagement is hot.'}
 {category=stalled→'No reply in {days_since_inbound} days — at risk.'}"
```

The note is what the operator skims. Every routine consumes it.

---

## 7. Cleanup / deduplication

Before writing the final JSON, the synthesizer runs:

1. **Multi-domain merge** based on `client-config.yaml :: known_top_customers[*].domains`
2. **Inferred parent-subsidiary** flagged in `openQuestions` — never auto-merged
3. **Internal-mistakes** removed: any domain in `client-config.yaml :: primary_domain` or `internal_personal_aliases`
4. **Excluded customers** redacted
5. **Per-customer doc dedup**: same fingerprintHash across SharePoint + OneDrive collapsed into one entry with multiple `locations`

---

## 8. Findings emitted at this stage

| Severity | Finding |
|---|---|
| HIGH | Customer in `stalled` or `ghosted` with an open proposal (deal at risk) |
| HIGH | Customer with open AR + last inbound >60d (collection risk) |
| HIGH | Active customer NOT in SharePoint Jobs Tracker (pipeline gap) |
| MED | Customer with no notebook section (operational handoff risk) |
| MED | Customer with multiple open proposals (pipeline confusion) |
| LOW | Customer with no people in Rolodex (cold relationship) |

---

## 9. Output sizes (rough)

For SRE-scale tenant:
- ~180–400 customer records
- ~1–10 MB JSON
- Synthesizer takes <60s on a laptop

---

## 10. Acceptance criteria

- [ ] Every external domain seen across all sources appears as a customer record OR is explicitly classified as internal/excluded
- [ ] Top-10 known customers from `client-config.yaml` all appear with correct categorization
- [ ] Engagement scores sane (highest belongs to a known top account)
- [ ] Narrative notes readable on a 10-customer spot-check
- [ ] `openQuestions` empty OR all items written into `client-config.yaml` for next run
- [ ] No body content from documents/transcripts inlined — only references
- [ ] File total <50MB (otherwise reconsider what we're storing per-customer)
