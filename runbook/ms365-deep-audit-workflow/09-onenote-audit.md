# Stage 7 — OneNote Audit

**Purpose.** Inventory OneNote notebooks across personal + SharePoint surfaces. Identify dormant knowledge AND active per-customer notebooks. OneNote is usually where the GENUINELY UNSTRUCTURED operator knowledge lives — call notes, technical references, drafts.

**Pre-requisite.** Stage 1 (notebook list).

**Output.** Notebook → section → page tree with last-modified timestamps + size. Page bodies are NOT pulled by default — opt-in for top-value notebooks only.

**Safety.** Page content often has customer-specific operating-intel. Same local-only rules.

**Run time.** <10 minutes for inventory only; +30 min if body content is opted-in.

---

## 1. What we extract

| Extraction | Used by | Why |
|---|---|---|
| Notebook name + owner + lastModified | Cleanup | Dead notebook detection |
| Sections per notebook | Customer 360 | Sections often == customer or project names |
| Pages per section | Time-to-knowledge | Where the live notes are |
| Page lastModifiedDateTime | Activity heatmap | What's a live reference vs a dead one |
| (Opt-in) page body | Sales Pipeline, R3 | Substance of meeting notes, decision capture |
| Cross-link to SharePoint site notebooks | Cleanup | Site-hosted notebooks often the most-used |

---

## 2. Pull plan

### 2.1 Personal notebooks
- `list-onenote-notebooks` (cached from stage 1)
- For each notebook:
  - `list-onenote-notebook-sections` — sections
  - `list-onenote-section-groups` — section groups (folders of sections)
  - For each section: `list-onenote-section-pages` — pages with metadata only

### 2.2 SharePoint-hosted notebooks
- For each SharePoint site walked in stage 3, `list-sharepoint-site-onenote-notebooks`
- For each notebook: `list-sharepoint-site-onenote-notebook-sections`, then pages similarly

### 2.3 (Opt-in) page body extraction
For pages flagged as high-value (active section, customer-named section, recently modified):
- `get-onenote-page-content` returns HTML → strip to plain text for classifier
- Save as `pages-content-<pageId>.txt`

### 2.4 SharePoint OneNote page contents
- `get-sharepoint-site-onenote-page-content` — same shape

---

## 3. Output JSON shape

```
raw/onenote/
├── notebooks.json                       # all visible notebooks (personal + SP)
├── sections-<notebookId>.json
├── pages-<sectionId>.json               # metadata only
└── pages-content-<pageId>.txt           # opt-in body only
```

`notebooks.json` element:
```json
{
  "id": "...",
  "displayName": "SRE Operations Notebook",
  "userRole": "Owner",
  "isShared": true,
  "createdDateTime": "...",
  "lastModifiedDateTime": "...",
  "isInSharePoint": true,
  "siteId": "...",
  "sectionCount": 12,
  "pageCount": 184
}
```

Page metadata element:
```json
{
  "id": "...",
  "title": "Aramco call - 2026-05-15 - decision: SRU bypass option",
  "createdDateTime": "...",
  "lastModifiedDateTime": "...",
  "level": 0,
  "order": 0,
  "contentUrl": "https://...",
  "sectionId": "...",
  "notebookId": "..."
}
```

---

## 4. Stitched data — `data/onenote-analysis.json`

```json
{
  "generatedAt": "...",
  "totals": {
    "notebooks": 4,
    "notebooksActive12mo": 2,
    "notebooksDormant": 2,
    "sections": 38,
    "pages": 412,
    "pagesActive90d": 24,
    "pagesContentExtracted": 0
  },
  "byNotebook": [
    {
      "notebookId": "...",
      "displayName": "SRE Operations Notebook",
      "isActive": true,
      "lastPageModified": "2026-05-20",
      "sectionsAsLikelyCustomers": [
        "Aramco", "ADNOC", "Cenovus", "AIMS commitments"
      ],
      "pagesPerSection": [
        { "sectionName": "Aramco", "pages": 28, "lastModified": "..." }
      ]
    }
  ],
  "findings": [
    { "severity": "med", "title": "1 notebook (Old Projects) dormant 3 years — recommend archive" },
    { "severity": "low", "title": "2 sections inside SRE Operations Notebook share names with proposal files in OneDrive (knowledge-source vs deliverable confusion)" }
  ]
}
```

---

## 5. Section-as-customer heuristic

Whenever a section name matches:
- A known customer name from `client-config.yaml`
- A discovered external domain from stage 2A
- A customer in the SharePoint Jobs Tracker

…tag the section as `isCustomerSection=true`. Stage 8 uses these as evidence that "Maaz takes notes on this customer" — a strong engagement signal.

---

## 6. Findings + heuristics

| Severity | Finding |
|---|---|
| HIGH | Active customer in mail/calendar but no notebook section (no operational notes) — risk to handoff |
| MED | Notebook dormant 2y+ — archive candidate |
| MED | Section named after a customer that's been classified `lost` for >1y — stale notes |
| LOW | Pages with very long titles (>140 chars) — probably copied chunks of text |
| LOW | Section with only 1 page — orphan section |

---

## 7. Pagination + parallelism

| Endpoint | Parallelism | Notes |
|---|---|---|
| `list-onenote-notebooks` | 1 | Small |
| `list-onenote-notebook-sections` | 4 parallel | One per notebook |
| `list-onenote-section-pages` | 6 parallel | One per section |
| `get-onenote-page-content` | 4 parallel | Opt-in only |

---

## 8. Failure modes

| Case | Handling |
|---|---|
| Notebook in a site we can't access | 403; skip; log |
| Section group nesting >3 levels | Cap depth; flag |
| Page content returns malformed HTML | Best-effort strip; log to findings |
| Token lacks `Notes.Read.All` | Personal notebooks only |

---

## 9. Acceptance criteria

- [ ] All visible notebooks enumerated
- [ ] Sections + pages metadata captured for every notebook
- [ ] `byNotebook.sectionsAsLikelyCustomers` matches Maaz's expectation
- [ ] Findings reviewed
- [ ] No page bodies pulled except opt-in
