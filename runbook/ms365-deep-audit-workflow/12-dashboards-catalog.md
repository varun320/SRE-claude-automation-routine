# Stage 10 — Dashboards Catalog

**Purpose.** Specify the HTML dashboards the audit ships. Each dashboard is a **single self-contained HTML file with the data inlined** (same pattern as GHL: payload embedded in a `<script>` block, dark-theme CSS in `<style>`, drill-down interaction via vanilla JS — no backend required).

**Pre-requisite.** Stages 8 + 9 produced `customer-360.json`, `sales-pipeline.json`, `ar-aging.json`, the various `*-analysis.json` files, and `findings.json`.

**Output.** A `dashboards/` directory with 7 HTML files + an `index.html` sub-hub.

**Design language.** Match GHL dashboards exactly — Inter font, `#3CD49D` accent, `#0c0c0f` background, sticky tabs, click-to-drill, modal contact views. Maaz already understands the visual idiom from the GHL audit (referenced in the session). Borrowing the look means no re-learn.

**Implementation.** Each dashboard is one Python generator: takes a JSON path, writes an HTML file. Pattern matches GHL's `build_*.py` exactly — payload inlined via `__DATA_PLACEHOLDER__` replacement.

---

## The 7 dashboards

### 1. `ms365-account-overview.html` — the front door

**Audience.** Maaz first-glance. "What does my business look like?"

**Sections (tabs):**
- **Headline metrics:** total customers, active customers, open proposals, total proposed value, AR outstanding, hours-spent-per-week trailing
- **Findings:** the heuristic anomaly list from `findings.json`, grouped by severity (HIGH | MED | LOW), each clickable to drill into the relevant entity
- **Pipelines:** SharePoint CRM-candidate lists (rendered as kanban stage-bars; values per stage)
- **Activity heatmap:** mail + meetings combined, by day, last 90d
- **Cleanup roll-up:** dead folders, dead rules, dormant sites, orphan docs (link to the Cleanup Report dashboard)

**Drill-in:** every metric/finding clicks through to a deeper dashboard.

---

### 2. `ms365-customer-360.html` — the canonical unified view

**Audience.** Maaz daily. The dashboard he opens before any customer touchpoint.

**Sections (tabs):**
- **Customers** — sortable + filterable table of every customer record. Columns: name, category, engagement, signals (icons for mail/cal/teams/docs/tasks), last touch, open proposal, open AR. Click any row → modal with the full narrative note + all signals + every backlink (mail thread, calendar event, document, transcript, note section).
- **Pipelines** — click a customer's stage → list of customers in that stage
- **Forms / Surveys** — N/A on MS365 (placeholder; possibly SharePoint forms in the future)
- **Calendars** — click any calendar → list of customers booked on it
- **Tags** — Outlook categories + contact categories used; click → list of customers
- **Sources** — domains list with per-source signal totals

**Filters:**
- By category (hot/warm/cooling/...)
- By region (NA / ME / Other)
- By engagement score range
- By "has open proposal"
- By "has open AR"
- By search (name / email / domain / tag)

**The modal** (per-customer 360 view):
- Synthesized narrative note (the headline)
- People (every contact at the customer)
- Mail summary + clickable thread list
- Meetings summary + clickable event list (with transcript link if present)
- Documents (proposals/contracts/invoices) with classification + last-modified
- Tasks (active + overdue)
- Notebook sections
- Findings specific to this customer
- All cross-link to the other dashboards (e.g. clicking a doc opens the Document Library dashboard at that file)

---

### 3. `ms365-sales-pipeline.html` — deals + AR

**Audience.** Maaz for R10/R12 (Pipeline Hygiene + AR Aging).

**Sections (tabs):**
- **Kanban board** — every deal as a card on its stage column; card shows customer + title + value + age; click → deal modal
- **Stage table** — same data flat
- **AR Aging** — bucketed (0–30 / 30–60 / 60–90 / 90+) by customer, with original invoice attachment links
- **Forecast** — value-weighted by stage probability (per `client-config.yaml :: stage_probabilities`)
- **Movements** — deals that moved stages in the last 30/60/90 days

**The deal modal:**
- Title, customer, owner, stage, value
- Evidence trail (the chronological list of signals)
- Linked mail thread, calendar events, docs
- Predicted next action + due date
- Findings specific to this deal

---

### 4. `ms365-communications-heatmap.html` — comms graph

**Audience.** Maaz weekly review (R8 Weekly Planning + R25 Monthly Time Review).

**Sections (tabs):**
- **Per-customer comms** — table of every customer, mail in/out, meeting count, time spent, last reply
- **Day-of-week / hour heatmap** — when Maaz emails + meets, with out-of-hours highlighted
- **Response time** — Maaz's typical reply latency, split by sender importance
- **Internal vs external** — % of comms going to each
- **Stale contacts** — people Maaz used to talk to but hasn't in 90+ days

---

### 5. `ms365-document-library.html` — proposals/contracts/invoices

**Audience.** R9 (Sale-Process Memo) + R22 (doc-room readiness).

**Sections (tabs):**
- **All documents** — flat table with class, customer, source (SharePoint/OneDrive/Teams), size, last-modified
- **By classification** — tabs for Proposals / Contracts / Invoices / Drawings / Reports / Templates / Other
- **By customer** — folder-style grouping
- **Duplicates** — files with the same fingerprint across folders
- **External shares** — files shared externally; expiry status; sensitivity label
- **Stale files** — proposals/contracts not modified in 12+ months

**Per-doc modal:**
- Filename, classification, customer guess
- Path(s) — all locations the file exists
- Permissions / sharing
- Version history (if pulled)
- Cross-link to the customer's record + any related mail thread

---

### 6. `ms365-time-allocation.html` — where the time goes

**Audience.** R2 (Daily Setup), R4 (Daily Close), R25 (Monthly Time Review).

**Sections (tabs):**
- **By customer** — hours per customer per week / month
- **By category** — internal_recurring / customer_meeting / focus / personal / out_of_hours
- **By day of week** — bar chart of total hours
- **Weekly OS adherence** — actual time-in-slot vs planned slot from `SRE Claude Routines - Execution Plan.md` Day Clock
- **Recurring meeting hygiene** — dead recurrences, skipped 1:1s
- **Out-of-hours load** — meetings after 19:00, weekend events, late-night emails

---

### 7. `ms365-cleanup-report.html` — what to delete/archive

**Audience.** Quarterly hygiene pass (analogous to the GHL cleanup report).

**Sections (tabs):**
- **Tags / categories** — Outlook categories used <3 times in 2yr
- **Mail folders** — folders with 0 messages in 2yr, dead rules
- **SharePoint sites** — sites dormant 12mo+
- **SharePoint lists** — lists with no items modified in 12mo
- **Document duplicates** — fingerprint groups
- **OneDrive stale folders** — folders untouched 2y+
- **Teams channels** — channels with 0 messages 6m+
- **Chats** — orphan chats (deleted user)
- **Planner / ToDo** — dormant plans, stale tasks
- **OneNote** — dormant notebooks + sections

Each row has a checkbox (per the GHL cleanup pattern). Checkboxes are local-only — they do NOT trigger deletion through this dashboard. The dashboard is a planning artifact; an explicit, separate `execute_cleanup.py` (modeled on GHL's) would be a future stage if/when Maaz wants automated execution.

---

### 8. `index.html` — the sub-hub

A small landing page with cards linking to all 7 dashboards. Headline shows: client name, audit date, total customers, total open proposals + value, AR outstanding. Mirrors the GHL `_client_hub_html` pattern.

---

## Shared interaction patterns

| Behavior | Description |
|---|---|
| **Sticky toolbar** | Selected-count + "Print/PDF" button stay visible while scrolling |
| **Filter chips** | Inline filters under each tab; clicking toggles `.on` class |
| **Sortable table headers** | Click to toggle asc/desc |
| **Modal overlays** | Click row → modal; Esc closes; click overlay closes |
| **Empty-state messaging** | "Nothing in this category. ✓" — friendly |
| **Print stylesheet** | `@media print` rules so Cmd+P produces a clean PDF (Maaz uses this for meetings) |
| **Search input** | Top of each tab; live-filters the visible rows |

---

## Build pipeline

Each dashboard is a Python generator following the GHL template exactly:

```python
HTML_TEMPLATE = """<!DOCTYPE html>...
<script>const DATA = __DATA_PLACEHOLDER__;
... vanilla JS, no frameworks ...
</script></html>"""

def main():
    data = json.loads(Path(args.data).read_text())
    payload = json.dumps(data, separators=(",", ":"), default=str).replace("</", "<\\/")
    html = HTML_TEMPLATE.replace("__DATA_PLACEHOLDER__", payload).replace("__CLIENT_NAME__", data["client"])
    Path(args.out).write_text(html)
```

When implemented, generators live under `lib/build_*.py` mirroring the GHL `lib/build_ghl_*.py` set.

---

## Sizes + performance

| Dashboard | Approx data size | Browser perf target |
|---|---|---|
| account-overview | <500 KB | <500ms render |
| customer-360 | 1–10 MB (the big one) | <1s render on 500-customer dataset |
| sales-pipeline | <2 MB | <500ms |
| comms-heatmap | <1 MB | <500ms |
| document-library | <3 MB | <1s on 5k docs |
| time-allocation | <500 KB | <500ms |
| cleanup-report | <1 MB | <500ms |

If a payload pushes beyond 10 MB, switch to **lazy modal data loading** — keep the table thin, load the per-customer modal payload from a sibling JSON file on demand. This is exactly the pattern needed when MS365 customer count + signal density gets bigger than GHL's typical dataset.

---

## Acceptance criteria

- [ ] All 8 HTML files (7 dashboards + sub-hub) generate without error
- [ ] Each file opens correctly in a browser with no network calls (fully self-contained)
- [ ] Maaz can complete his daily review in <10 min using customer-360 + sales-pipeline
- [ ] Cmd+P produces a usable PDF on each dashboard
- [ ] No CSS/JS dependencies on external CDNs that would break offline
- [ ] Accent + dark-theme color values match the GHL set exactly
- [ ] Cross-links between dashboards open the right anchor / modal
