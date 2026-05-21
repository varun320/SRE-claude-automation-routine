# Stage 3 — SharePoint Audit

**Purpose.** SharePoint is the most likely place SRE keeps **structured business data** — Jobs trackers, customer lists, project status, financial summaries. Stage 3's job is to find those structured stores, understand their schema, and pull every row.

**Pre-requisite.** Stage 1 complete; `client-config.yaml :: known SharePoint sites / lists / libraries` populated where possible.

**Output.** Complete site → list → item walk; auto-detection of which lists act like CRM/PM tables; document libraries enumerated (no body content downloaded by default).

**Safety.** SharePoint sites often contain a mix of business + legal + HR content. The stage **must** honor `client-config.yaml :: excluded_sites` and never recurse into them. List items may contain financials — keep all output local.

**Run time.** 5–30 minutes depending on site count + list-item volume.

---

## 1. The high-leverage detection: list-as-CRM

The single biggest payoff of this stage is detecting that a SharePoint list is actually being used as a CRM/PM/AR/forecast tool. SREs almost certainly has one — calling it "Jobs Tracker" or similar (named in the Execution Plan).

Detection heuristic:
- A list has columns matching customer-like patterns: `Customer`, `Client`, `Account`, `Company`, `Project`, `Job`, `Status`, `Stage`, `Value`, `Amount`, `Due`, `Closed`, `Won`, `Owner`, `Salesperson`
- A list has >20 items AND a `Status` / `Stage` field with low cardinality (5–15 distinct values) — looks like a Kanban
- A list has been modified within the last 30 days — actively used
- A list's items have rich `[Lookup]` columns referencing other lists — relational structure

The stage produces a **ranked candidate list** of "this list IS the implicit CRM"; Maaz confirms.

---

## 2. Per-site pull plan

For each site enumerated in stage 1 (minus excluded):

### 2.1 Site metadata
- `get-sharepoint-site` — full record (web URL, description, created/lastModified)
- `list-sharepoint-site-drives` — every document library

### 2.2 Lists inventory
- `list-sharepoint-site-lists` — every list (excluding hidden system lists by default)
- For each list:
  - `get-sharepoint-site-list` — list metadata
  - `list-sharepoint-list-columns` — schema (column names, types)
  - `list-sharepoint-site-list-items` paginated — every item with `$expand=fields`
  - Capture only `$select=id,createdDateTime,lastModifiedDateTime,createdBy,lastModifiedBy,webUrl,fields`

### 2.3 Document libraries inventory
- `list-sharepoint-site-items` per drive — file tree
- Capture per file: `id,name,size,createdDateTime,lastModifiedDateTime,lastModifiedBy,webUrl,file.mimeType,parentReference.path`
- No file BODIES downloaded by default

### 2.4 SharePoint pages (modern + classic)
- The MCP doesn't expose a direct "list pages" tool; pages live in the `Site Pages` document library which the walk covers naturally. Capture filenames + last-modified for activity signal.

### 2.5 OneNote notebooks in the site
- `list-sharepoint-site-onenote-notebooks` — captured for cross-reference with stage 7

### 2.6 Site activity signal
- The `lastModifiedDateTime` on the site itself is a coarse activity indicator. Combined with most-recent list-item mod + most-recent file mod, classify the site as: ACTIVE / DORMANT / ARCHIVED.

---

## 3. Output JSON shape

```
raw/sharepoint/<siteId>/
├── site.json                          # full site metadata
├── drives.json                        # document libraries
├── lists.json                         # all lists with metadata
├── columns-<listId>.json              # schema per list
├── items-<listId>-page-001.json
├── items-<listId>-page-002.json
├── items-<listId>-flat.json           # merged
├── drive-items-<driveId>.json         # file tree per drive
└── onenote-notebooks.json             # if any in this site
```

A list item element (representative):
```json
{
  "id": "37",
  "createdDateTime": "...",
  "lastModifiedDateTime": "...",
  "createdBy":      { "user": { "displayName": "Maaz", "email": "maaz@..." } },
  "lastModifiedBy": { "user": { "displayName": "Ashley", "email": "ashley@..." } },
  "webUrl": "...",
  "fields": {
    "Title": "Aramco - Train 4 SRU revamp",
    "Customer": "Saudi Aramco",
    "Stage": "Proposal Sent",
    "Value": 850000,
    "Currency": "USD",
    "Owner": "Maaz",
    "DueDate": "2026-08-01",
    "Notes": "..."
  }
}
```

---

## 4. Stitched data — `data/sharepoint-analysis.json`

```json
{
  "generatedAt": "...",
  "totals": {
    "sites": 14,
    "sitesActive12mo": 9,
    "sitesDormant": 3,
    "sitesArchived": 2,
    "listsTotal": 87,
    "listsActive": 41,
    "listsAsCrmCandidate": 4,
    "documentsTotal": 8210,
    "documentLibrariesActive": 18
  },
  "sites": [
    {
      "id": "...",
      "name": "SRE Operations",
      "webUrl": "...",
      "lastModified": "2026-05-19",
      "classification": "ACTIVE",
      "documentLibraries": [
        { "name": "Proposals", "fileCount": 412, "lastModified": "...", "isActive": true },
        { "name": "Contracts", "fileCount": 38, "lastModified": "...", "isActive": true }
      ],
      "lists": [
        { "name": "Jobs Tracker", "itemCount": 87, "isCrmCandidate": true,
          "crmScore": 0.92, "lastItemModified": "2026-05-20",
          "columnsLookingLikeCrm": ["Customer", "Stage", "Value", "Owner", "DueDate"] }
      ]
    }
  ],
  "crmCandidateLists": [
    {
      "siteId": "...", "siteName": "SRE Operations",
      "listId": "...", "listName": "Jobs Tracker",
      "schema": [
        { "name": "Customer",  "type": "text" },
        { "name": "Stage",     "type": "choice", "choices": ["Lead","Qualified","Proposal","Won","Lost"] },
        { "name": "Value",     "type": "currency" },
        { "name": "Owner",     "type": "person" },
        { "name": "DueDate",   "type": "dateTime" }
      ],
      "rowCount": 87,
      "rowsByStage": { "Lead": 12, "Qualified": 18, "Proposal": 14, "Won": 31, "Lost": 12 },
      "totalValueByStage": { "Lead": 0, "Qualified": 1200000, "Proposal": 3400000, "Won": 8200000, "Lost": 1100000 },
      "currency": "USD",
      "topOwners": [ { "name": "Maaz", "count": 42 }, { "name": "Ashley", "count": 18 } ],
      "missingStageCount": 5,
      "missingValueCount": 11
    }
  ],
  "documentInventory": [
    { "siteId": "...", "libraryName": "Proposals",
      "files": [
        { "name": "Proposal_Aramco_Train4_2026-05-20.pdf",
          "size": 4283910, "mimeType": "application/pdf",
          "lastModified": "...", "modifiedBy": "Maaz",
          "classification": "proposal", "customerGuess": "Saudi Aramco",
          "webUrl": "..." }
      ]
    }
  ],
  "findings": [
    { "severity": "high", "title": "Jobs Tracker list has 5 rows with no Stage value", "evidence": [...] },
    { "severity": "high", "title": "Jobs Tracker list has 11 rows with no Value — pipeline math broken", "evidence": [...] },
    { "severity": "med", "title": "3 sites dormant 12+ months", "items": [...] },
    { "severity": "med", "title": "Proposals library has 14 files modified once + never opened — possible template forks", "items": [...] },
    { "severity": "low", "title": "Default 'Documents' library on 'SRE Operations' has 600 ungrouped files — folder hygiene", "items": [] }
  ]
}
```

---

## 5. Document classifier

For each file enumerated, classify based on name + (optionally) extension. This is metadata-only — no body reads.

```python
PROPOSAL_FILE   = re.compile(r'(?i)\b(proposal|quote|quotation|estimate|bid)\b.*\.(pdf|docx|pptx)$')
CONTRACT_FILE   = re.compile(r'(?i)\b(contract|agreement|msa|sow|po|purchase\s*order)\b.*\.(pdf|docx)$')
INVOICE_FILE    = re.compile(r'(?i)\b(inv|invoice|billing)\b.*\.(pdf|xlsx)$')
DRAWING_FILE    = re.compile(r'(?i)\b(drawing|isometric|p&id|pid|hazop|datasheet)\b.*\.(pdf|dwg)$')
REPORT_FILE     = re.compile(r'(?i)\b(report|summary|status)\b.*\.(pdf|docx|pptx)$')
SPREADSHEET_FIN = re.compile(r'(?i)\b(ar|aging|forecast|cash|budget|tracker|pipeline)\b.*\.(xlsx)$')
```

Customer-guess: longest-match against `client-config.yaml :: known_top_customers` names + their domains. If no match: parse the filename and surface for manual tagging in stage 8.

---

## 6. Findings + heuristics

| Severity | Finding | Detection |
|---|---|---|
| HIGH | CRM-candidate list has rows missing Stage / Value | data quality blocker for stage 9 |
| HIGH | Document library has zero files modified in 12 months but is referenced by an active mail rule | dead surface |
| MED | Two libraries with overlapping file names (template duplication) | hygiene |
| MED | Customer name appears in a folder but not in CRM-candidate list | unrecorded customer |
| MED | List item assigned to a former employee | ownership rot |
| LOW | List with no recent modification and < 5 items | dead list, recommend delete |
| LOW | Site title and webUrl segment mismatch | rename hygiene |

---

## 7. Pagination + parallelism

| Endpoint | Parallelism | Notes |
|---|---|---|
| `list-sharepoint-site-lists` | 4 sites in parallel | Cheap |
| `list-sharepoint-list-columns` | 8 lists in parallel | Cheap |
| `list-sharepoint-site-list-items` | 1 stream per list, 4 lists parallel | Heavy lists go solo |
| `list-sharepoint-site-items` (drive walk) | 1 per drive, 4 drives parallel | Recursive walk |
| `get-sharepoint-sites-delta` | 1 | For future incremental |

---

## 8. Failure modes

| Case | Handling |
|---|---|
| Token lacks `Sites.Read.All` | Stage limited to default site; surface in findings + halt with explicit message |
| List with > 5,000 items returns `Indexed column threshold` errors | Use `$filter` on `Created ge <date>` to slice |
| List columns with internal names different from display names | Capture both: `internalName` for filter use, `displayName` for dashboards |
| `Hidden=true` system lists (`appdata`, `Workflow History`, etc.) | Skip by default; configurable |
| Personal sites (`my.sharepoint.com`) | Excluded by default; opt-in per user |

---

## 9. Acceptance criteria

- [ ] Every non-excluded site has `site.json`, `lists.json`, `drives.json` populated
- [ ] Every list has `items-<listId>-flat.json` (or explicit skip reason in findings)
- [ ] `sharepoint-analysis.json :: crmCandidateLists` correctly identifies the Jobs Tracker (or equivalent) — Maaz confirms
- [ ] Document classifier yields the expected counts for "proposals" and "contracts" within ±10% of Maaz's manual count
- [ ] Findings spot-checked for false positives
- [ ] No body bytes of any document downloaded except where explicit opt-in
