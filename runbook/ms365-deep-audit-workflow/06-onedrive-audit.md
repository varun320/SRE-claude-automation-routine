# Stage 4 — OneDrive Audit

**Purpose.** Inventory every file in every drive the operator can reach, classify each file (proposal / contract / invoice / drawing / report / template / other), and link each file to a customer where possible. Surface the **document library** that will power the Sales Pipeline + AR dashboards.

**Pre-requisite.** Stage 1 complete; drives enumerated.

**Output.** Per-drive file tree, classified document inventory, sharing-posture audit, stale-file flags.

**Safety.** No file BODIES are downloaded by default. File metadata only. Body download is gated behind an explicit opt-in flag and is invoked selectively in stage 9 (e.g. OCR an invoice to extract amount + customer).

**Run time.** 10–30 minutes depending on drive depth.

---

## 1. Why OneDrive matters even though SharePoint already covers documents

Many SRE files will live in **Maaz's personal OneDrive** rather than a SharePoint site — early drafts, working copies, ad-hoc proposals, accountant-shared spreadsheets. The Execution Plan even calls out `Files (Documents/Claude)` as a working location. SharePoint covers the org's shared surface; OneDrive covers the operator's working surface.

Both stages produce a `documents` array — stage 8 merges them.

---

## 2. Per-drive pull plan

For each drive returned by `list-drives` (Maaz's personal drive plus any visible shared drives that aren't already covered by stage 3 site walks):

### 2.1 Drive metadata
- Owner, quota, drive type (`personal` / `business` / `documentLibrary`)

### 2.2 Tree walk

The MCP exposes two complementary walking strategies — pick based on size:
- **Small/Medium drives:** recursive walk via `list-folder-files` starting from `get-drive-root-item`
- **Large drives:** `get-drive-delta` to enumerate everything, then incremental delta after that

For each item captured:
- `id, name, size, createdDateTime, lastModifiedDateTime, lastModifiedBy, webUrl, parentReference.path`
- `file.mimeType` if it's a file; `folder.childCount` if it's a folder
- `shared` block when present (`scope`, `effectiveRoles`)

### 2.3 Per-item permissions

For files classified as **proposal / contract / invoice** (the high-confidentiality ones), additionally pull `list-drive-item-permissions`. We want to know:
- Is this proposal shared externally?
- Was it shared via anonymous link?
- Who has edit vs read?

This is the **leak-detection lane** of the audit.

### 2.4 Sensitivity labels

For each business-class file, `extract-drive-item-sensitivity-labels` (if the tenant uses MIP labels). Captures `displayName` + `sensitivityLabelId`.

### 2.5 Versions

`list-drive-item-versions` is **expensive** — call only for the top-N files most likely to be proposals/contracts (say, last 50 in the proposal class). Used to detect "this proposal had 14 versions over 3 months" — a sales-cycle length signal.

### 2.6 Search-based pull (complementary)

In parallel to the tree walk, run targeted searches:
- `search-onedrive-files` with `q="Proposal"`, `q="Contract"`, `q="Invoice"`, `q="AR aging"`, `q=".dwg"`, etc.
- Useful when the tree is large; finds high-value files faster.

---

## 3. Output JSON shape

```
raw/onedrive/<driveId>/
├── drive.json                        # drive metadata
├── tree-page-001.json                # delta pages
├── tree-flat.json                    # full merged file tree (metadata only)
├── permissions-<itemId>.json         # only for classified high-value files
├── sensitivity-<itemId>.json
├── versions-<itemId>.json
└── search-<query>.json               # complementary search results
```

`tree-flat.json` element (canonical):
```json
{
  "id": "01ABCDE...",
  "driveId": "...",
  "name": "Proposal_Aramco_Train4_2026-05-20.pdf",
  "path": "/drive/root:/Customers/Saudi Aramco/2026/Train 4",
  "size": 4283910,
  "mimeType": "application/pdf",
  "createdDateTime": "...",
  "lastModifiedDateTime": "...",
  "lastModifiedBy": "Maaz Ahmed Shareef",
  "webUrl": "...",
  "isFile": true,
  "isFolder": false,
  "isShared": false,
  "isExternallyShared": false,
  "sensitivityLabel": null,
  "classification": "proposal",
  "customerGuess": "Saudi Aramco",
  "fingerprintHash": "abc123...",     // sha256 of name+size, for dedup
  "versionCount": 14
}
```

---

## 4. Stitched data — `data/onedrive-analysis.json`

```json
{
  "generatedAt": "...",
  "totals": {
    "drivesWalked": 14,
    "files": 6420,
    "folders": 980,
    "bytesTotal": 18000000000,
    "filesClassified": 1840,
    "proposals": 220,
    "contracts": 88,
    "invoices": 412,
    "drawings": 380,
    "reports": 312,
    "spreadsheetsFinancial": 80,
    "externallyShared": 38
  },
  "filesByClassification": {
    "proposal":  [ /* file objects */ ],
    "contract":  [...],
    "invoice":   [...],
    "drawing":   [...],
    "report":    [...],
    "spreadsheet_financial": [...]
  },
  "duplicateGroups": [
    { "fingerprintHash": "...", "files": [
      { "path": "Maaz/Proposals/Aramco_v1.pdf" },
      { "path": "Maaz/Customers/Aramco/Proposals/Aramco_v1.pdf" }
    ]}
  ],
  "staleFiles": [
    { "path": "Maaz/Old Projects/Acme/Proposal_v3.docx", "lastModified": "2020-04-..." }
  ],
  "externalShares": [
    { "name": "Proposal_X.pdf", "sharedWith": ["external@…"], "scope": "anonymous", "linkExpiry": null }
  ],
  "findings": [
    { "severity": "high", "title": "9 proposal PDFs externally shared with anonymous links (no expiry)" },
    { "severity": "med",  "title": "14 duplicate proposal files (same name + size in multiple folders)" },
    { "severity": "med",  "title": "Maaz's drive has 280GB used; 60% in folders untouched 2y+" },
    { "severity": "low",  "title": "12 invoices not yet in SharePoint Contracts library" }
  ]
}
```

---

## 5. The document classifier (reused from stage 3)

Stage 3 already defined the regex classifier (`PROPOSAL_FILE`, etc.). Stage 4 reuses the same regex module. Output is a single merged `data/document-inventory.json` produced in stage 8 that combines SharePoint + OneDrive.

Customer-guess uses the same matching strategy: try filename → folder path → known-customer name match.

---

## 6. Findings + heuristics

| Severity | Finding | Detection |
|---|---|---|
| HIGH | Proposals/contracts shared externally with no expiry | Permissions scan |
| HIGH | Sensitive file (proposal/contract) labelled `Public` | Sensitivity label mismatch |
| MED | Duplicate file fingerprint across folders | Same name + size in multiple places |
| MED | Stale folders >2y, >100MB | Cleanup candidates |
| MED | Files with classification `unknown` larger than 5MB | Likely something important not yet classified |
| LOW | Single proposal with >10 versions in <30 days | Lots of revision = active deal, worth flagging for stage 9 |
| LOW | Files modified by user no longer in tenant | Ownership rot |

---

## 7. Pagination + parallelism

| Endpoint | Parallelism | Notes |
|---|---|---|
| `list-folder-files` | 6 folders parallel | Recursive |
| `get-drive-delta` | 1 stream per drive | Sequential pages |
| `list-drive-item-permissions` | 8 items parallel | Only for high-value classifications |
| `list-drive-item-versions` | 4 items parallel | Top-N proposals only |
| `search-onedrive-files` | 4 queries parallel | Independent |

---

## 8. Failure modes

| Case | Handling |
|---|---|
| Drive returns 404 on root | Likely an empty / unprovisioned drive; skip |
| Item with `package.type=oneNote` | Skip — those are OneNote notebooks handled by stage 7 |
| Item with `remoteItem` block | It's a shortcut to another drive; record as link, don't dereference |
| Very deep trees (>20 levels) | Cap recursion depth and surface in findings |
| Bytes-download attempted accidentally | Pullers should never call `download-bytes` unless explicitly enabled per file |

---

## 9. Acceptance criteria

- [ ] Every reachable drive walked; `tree-flat.json` exists per drive
- [ ] Document classifier produces realistic counts (Maaz spot-checks the top-50 classifications)
- [ ] Customer-guess accuracy on top-50 ≥80% (rest flagged for stage 8 manual)
- [ ] External-share findings reviewed — any HIGH-severity items have a follow-up action recorded
- [ ] No file body downloaded except for explicit opt-in items
- [ ] Duplicate detection surfaces at least one real duplicate group (Maaz confirms)
