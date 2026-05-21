# Stage 0 — Discovery Questionnaire (PRE-FILLED)

**Status.** Every question below carries an **INFERRED ANSWER** derived from `SRE Claude Routines - Execution Plan.md` and standard practice in the sulfur-recovery / oil-and-gas EPC industry. Answers are tagged:

- 🟢 **CONFIRMED** — taken verbatim from the Execution Plan
- 🟡 **INFERRED** — strong evidence from the Execution Plan or industry context; Maaz reviews
- 🔴 **NEEDS MAAZ** — not derivable from sources; requires direct input

**Companion artifact.** `client-config.yaml.draft` (next to this file) contains the same answers in machine-readable form, ready to be edited and saved as `client-config.yaml`.

**Workflow.** Mohammad walks Maaz through this in ~20 min (not 30+). For every 🟡, Maaz says "yes/correct/change to X". For every 🔴, Maaz answers cold. Then save as `client-config.yaml`.

---

## 1. Tenant + Identity

**1.1 Primary domain(s).**
🔴 NEEDS MAAZ. Not stated in the Execution Plan. Best guess: `sulfurrecovery.com` or similar.

**1.2 People in scope for full mailbox + calendar reads.**
🟢 CONFIRMED → Maaz (the operator) only, by default. The Execution Plan is single-operator throughout.

**1.3 People in scope for directory-level metadata only** (name/role/group membership, no body access).
🟡 INFERRED → Everyone else in the tenant. SRE staff named in the Execution Plan that we'd expect to see in the directory:

| Name | Role from plan | Notes |
|---|---|---|
| **Maaz Ahmed Shareef** | CEO / GM | Primary operator |
| **Zaheer Juddy** | Group CEO / Shareholder | Receives the Friday WhatsApp update — external to SRE staff but inside the tenant directory likely |
| **Ashley** | Admin / HR / bank | Maaz's NA admin lead (Mon 1:1) |
| **Talha** | ME technical / conferences | |
| **Dharmesh** | Engineering | |
| **Utsav** | Technical writing | |
| **Inshan** | Qatar / Kuwait compliance | |
| **Ron** | BD / clients (NA-focused) | Forwarding target for client items |

**1.4 Shared mailboxes.**
🔴 NEEDS MAAZ. Common ones for an EPC firm of this size: `info@`, `ar@`, `tenders@`, `contracts@`. None mentioned explicitly in the Execution Plan.

**1.5 External users in the tenant (guests).**
🟡 INFERRED → AIMS partnership members may have guest access. Per Execution Plan, AIMS = Shameem, Naveed, Zaheer Juddy, Ali, Aslam, Fazal, Majid. Bookkeeper may also have guest access. Confirm during stage 1 enumeration.

**1.6 Personal accounts to EXCLUDE.**
🟢 CONFIRMED → Gmail + Google Calendar are personal/secondary per Execution Plan §"Connector Reality Check". Apple Notes + iMessages are personal capture only. **Out of scope for this MS365 audit.**

---

## 2. Customer + Vocabulary

**2.1 What's the unit of "customer"?**
🟡 INFERRED → **Company, identified by email domain.** Sulfur-recovery EPC sales are B2B to oil-and-gas operators / refiners — every customer is a company. Contacts roll up to companies.

**2.2 Known top customers (CONFIRMED from Execution Plan §R5 + AIMS country splits):**

| Customer | Region | Source | Likely domain hint |
|---|---|---|---|
| **Saudi Aramco** | KSA (NA HQ relationships) | R5, R22, R23 | `aramco.com` |
| **KNPC** (Kuwait National Petroleum Company) | KSA + Kuwait (Mon AIMS) | R5, R15a | `knpc.com.kw` |
| **Petro Rabigh** | KSA | R5 | `petrorabigh.com` |
| **Q-Chem** | Qatar (Wed AIMS) | R5, R12, R15d | `qchem.com.qa` |
| **QE-LNG** | Qatar | R5, R15d | `qe-lng.com` |
| **Mellitah / Dolphin** | Libya area | R5 | `mellitahog.ly` |
| **ADNOC / Habshan** | UAE (Tue AIMS) | R5, R15c | `adnoc.ae` |
| **Anwil / Orlen** | Poland (non-ME) | R5 | `anwil.pl`, `orlen.pl` |
| **Kanoo** | Bahrain | R5 | `kanoo.com` |
| **Baker Hughes (Libya)** | Libya | R5 | `bakerhughes.com` |
| **SATORP** | KSA | R5 | `satorp.com` |
| **Oryx GTL** | Qatar | R5 | `oryxgtl.com.qa` |

🟡 INFERRED ADDITIONS → Likely also active (industry standard for sulfur-recovery EPCs):
- Saudi Aramco HQ contacts: **Cobus, Bernedict Kheswa** (R22) — these are PEOPLE not companies but they're inside Aramco
- Caleb (R1 — "CSV bid Q from Caleb") — likely a customer-side contact, company unknown

**2.3 Known prospects / open deals.**
🔴 NEEDS MAAZ. Project Tracker .xlsx + ClickUp will reveal these during stages 3 and 6.

**2.4 Known LOST deals.**
🔴 NEEDS MAAZ. Same — discovery via Project Tracker.

**2.5 Naming conventions.**

| Convention | Pattern | Source |
|---|---|---|
| Calendar event tags | `[Client]`, `[AIMS]`, `[Buyer]` in titles | 🟢 R19 |
| Action Package filename | `Action Package [Month YYYY]` | 🟢 R1, R20 |
| Daily Log filename | `Daily Logs/[YYYY-MM-DD].md` | 🟢 R4 |
| Weekly Review filename | `Daily Logs/Weekly Review [date].md` | 🟢 R13 |
| Zaheer Update filename | `Daily Logs/Zaheer Update [date].md` | 🟢 R14 |
| Pre-meeting briefs | `Daily Logs/Pre-Meeting Briefs/[meeting].md` | 🟢 R19 |
| Subject-line for AR follow-up | invoice / payment / AP keywords | 🟢 R12 |
| Proposal subject pattern | 🟡 INFERRED `(?i)\bproposal\b` + customer name | industry standard |
| Invoice subject pattern | 🟡 INFERRED `(?i)\binv[-\s]?\d` or `\binvoice\b` | industry standard |
| RFQ pattern | 🟡 INFERRED `(?i)\b(rfq|rfp|tender|inquiry)\b` | industry standard |
| Contract / NDA pattern | 🟡 INFERRED `(?i)\b(nda|msa|contract|agreement)\b` | industry standard |

**2.6 Service taxonomy (product lines).**
🟡 INFERRED for a sulfur-recovery EPC of SRE's profile:
- **Capital projects** — new SRU build, train expansion, debottlenecking
- **Revamps** — existing-unit modifications (high-volume line)
- **Engineering studies** — performance audits, HAZOP, optimization
- **Field services** — startup/commissioning, troubleshooting
- **Training** — operator + engineering training
- **Catalyst / spare parts supply** — possibly
- **Sale process** — 🟢 the COMPANY is being sold (R9 + R23 references "buyer Q&A", "data room", "IM revision"). Treat the buyer + their advisors as a special "customer" record with private redaction.

**2.7 Geography taxonomy.**
🟢 CONFIRMED from Execution Plan + day clock:

| Region | Countries | When | AIMS bi-weekly slot |
|---|---|---|---|
| **NA** | Canada (HQ in Calgary), USA, Mexico likely | Calgary daytime 12:00–17:00 | n/a |
| **ME** | KSA, Kuwait, Oman, UAE, Qatar, Bahrain | Calgary evening 22:00–02:00 | KSA+Kuwait Mon, Oman Tue, UAE Wed, Qatar Thu |
| **Other** | Poland (Anwil/Orlen), Libya (Mellitah, Baker Hughes) | Ad-hoc | none |

---

## 3. Sales-cycle stage definitions

🟡 INFERRED for sulfur-recovery EPC sales-cycle norms. Maaz confirms.

| Stage | What it means | Earliest signal in MS365 |
|---|---|---|
| **Lead / Inquiry** | First contact, often via Squarespace form (R18), cold inbound, or AIMS introduction | inbound mail from new domain OR Squarespace form submission |
| **Qualified** | Discovery call held; we've established scope + technical fit | first calendar event with attendees from the domain |
| **RFQ / RFP received** | Customer has formally requested a proposal | inbound mail with `RFQ`/`RFP`/`Tender` keyword + attachment |
| **Proposal sent** | We've responded with our scope + price | outbound mail with `Proposal*` attachment to customer domain |
| **Clarifications / Q&A** | Customer is asking technical or commercial questions | back-and-forth threads on the proposal subject |
| **Verbal go-ahead** | Customer indicates intent to proceed | inbound with "we'd like to proceed", "PO is coming", etc. |
| **PO / Contract** | 🟡 INFERRED **PO receipt is the closing event** for B2B EPC | inbound with PO number, contract PDF appears |
| **In execution** | Project active; engineering hours running | ClickUp project active + weekly project review meetings |
| **Won / Invoiced** | First milestone invoice issued | outbound invoice email (R12 keywords) |
| **Lost** | Explicit "decided to go with another vendor" OR >180d silence after proposal | inbound with regret language OR 180d gap |
| **Dormant** | No activity 12mo+ | no signals for 12mo |

**3.5 What event closes a deal?**
🟡 INFERRED → **PO receipt.** Confirm with Maaz. Could also be signed contract / first invoice paid.

**3.6 What does "Top-5" mean (R20 / Friday Top-5)?**
🟢 CONFIRMED in part — Friday Top-5 (per Weekly OS §7) is **the personal-touch target** = "10 NA top-client touches, 5 ME top-client touches per week". The Friday Top-5 routine surfaces the customers needing a touch. Mix of revenue, recency, and pipeline value.

---

## 4. Where the data physically lives

**4.1 SharePoint sites actively used.**
🔴 NEEDS MAAZ + 🟡 discoverable during stage 1.

Inferred candidates based on team structure:
- `SRE Operations` (likely)
- `Project Delivery`
- `Business Development`
- `Compliance` (Inshan's domain)
- Per-customer or per-project sites possible

**4.2 Lists in SharePoint that act like a CRM.**
🟡 INFERRED → **Project Tracker .xlsx** (Excel file, not a list) is the AUTHORITATIVE source per R11, R12, R13, R14. Per stage 5, we should expect either:
- A SharePoint list mirroring the Project Tracker, OR
- The Project Tracker as a file in a document library

Either way: locate it during stage 5. If it's still the Excel file Maaz mentions, then:
- It contains AR Outstanding column 🟢 R12
- Active job count, RAG status, % complete 🟢 R13
- Possibly customer + contact list

**4.3 Document libraries that hold proposals/contracts.**
🟡 INFERRED → likely `Proposals`, `Contracts`, `Tenders`, `RFQs`, `Engineering Deliverables` folders inside the SRE Operations site. Standard structure.

**4.4 OneDrive folders that matter.**
🟢 CONFIRMED → `Documents/Claude/Projects/SRE General Manager/` is the operator's working directory. Contains:
- Action Package files (monthly) 🟢
- Task List 🟢
- Daily Logs/ folder 🟢
- Daily Logs/Pre-Meeting Briefs/ 🟢
- `Documents/Claude/Inbox/Contracts/` 🟢

**4.5 Teams channels actively used.**
🔴 NEEDS MAAZ + 🟡 discoverable. Inferred candidates:
- Internal SRE team channels (one per region or function)
- Possibly an AIMS-shared channel (if AIMS members are tenant guests)

**4.6 OneNote notebooks in active use.**
🔴 NEEDS MAAZ. Not explicitly mentioned in the Execution Plan. May or may not be a primary surface.

**4.7 Planner plans in active use.**
🔴 NEEDS MAAZ. Not explicitly mentioned. ClickUp appears to be the primary task surface, so Planner may be lightly used.

**4.8 ClickUp.**
🟢 CONFIRMED → Primary project + task tracker. **Out of MS365 scope** for this audit. R7 (CRM logging) and R10 (Pipeline Hygiene) update it, but the audit doesn't read it. A future ClickUp puller is on the post-audit skills backlog (`13-skills-extraction-plan.md`).

---

## 5. Revenue + financials

**5.1 Where invoice records live.**
🟡 INFERRED → **Project Tracker .xlsx** AR Outstanding column is the authoritative source (R12). Plus invoice attachments in mail threads. Q-Chem has a special invoice format (Item 44 of April Action Package).

**5.2 AR tracking.**
🟢 CONFIRMED → Project Tracker .xlsx + Outlook search for invoice/payment/AP threads (R12).

**5.3 Bank feeds.**
🔴 OFF LIMITS by default. Cash forecast (R12) is a manual entry by Maaz, not derived from a bank feed.

**5.4 Currency.**
🟡 INFERRED → **USD primary** (NA + ME oil-and-gas markets trade in USD); **CAD secondary** (Canadian payroll/AP). Multiple currency exposure likely. Confirm in Project Tracker schema.

**5.5 Average deal-size brackets.**
🟡 INFERRED for sulfur-recovery EPC industry:
- Small: <$100K (engineering study, short field service)
- Medium: $100K–$1M (mid-size revamp, training program, study + commissioning)
- Large: $1M–$10M+ (capital project, new SRU train)

Confirm with Maaz.

---

## 6. Time + cadence

**6.1 Standing recurring meetings.** 🟢 CONFIRMED from Day Clock + Weekly Overlay:

| Day | Time MT | Meeting |
|---|---|---|
| Mon | 14:05 | Ashley NA 1:1 |
| Tue | 14:05 | Sales 1:1 |
| Wed | 14:05 | Engineering standup |
| Thu | 14:05 | Bookkeeper |
| Fri | 14:05 | Top-5 |
| Sun bi-weekly | Mon 00:00 MT | AIMS KSA + Kuwait |
| Mon bi-weekly | Tue 00:00 MT | AIMS Oman |
| Tue bi-weekly | Wed 00:00 MT | AIMS UAE |
| Wed bi-weekly | Thu 00:00 MT | AIMS Qatar |

**6.2 Calendars beyond the primary.**
🔴 NEEDS MAAZ. Possibly a shared Engineering or Project calendar.

**6.3 Holidays + travel.**
🟢 CONFIRMED hard anchors that must NEVER be over-flagged as silence:
- **Prayers** (immovable): Fajr 05:20, Zuhr 14:00, Asr 19:00, Maghrib 21:00, Isha 22:15 — Calgary local
- **Friday Jumua** 14:00–15:30
- **Family time** 17:00–22:00 (excluding prayer slots)
- **Sleep** ~02:00–05:20

Out-of-office travel: not explicitly captured in the plan — 🔴 NEEDS MAAZ on how he logs it.

---

## 7. Confidentiality + redaction

**7.1 Customers/parties that must NOT appear in dashboards by name.**
🟢 CONFIRMED CONCERN → **The sale-of-company "Buyer" + advisors** are highly sensitive. Per R9, they're treated as a separate file. Dashboards should mask these by default. Operator can reveal via explicit flag.

🟡 INFERRED ADDITIONAL CONCERN → Aramco NDAs and Mushtaryat-registered Qatar tenders typically carry confidentiality clauses. Treat top-named customers as confidential-by-default in any externally-shared dashboard.

**7.2 Off-limit folders / sites.**
🟡 INFERRED → Sale-process docs (IM, data room, buyer Q&A) likely live in a special folder/site we should exclude from general dashboards.

**7.3 OK to record subject lines / sender names / attachment names?**
🟡 INFERRED YES for internal-use dashboards (local, Maaz-only). Mask in any externally-shared export.

**7.4 OK to OCR PDFs in stage 4?**
🔴 NEEDS MAAZ explicit consent. Default OFF.

---

## 8. Output preferences

**8.1 Where dashboards live.**
🟡 INFERRED → **Local on Maaz's machine** by default. Could optionally be delivered into the SRE General Manager OneDrive folder for cross-device access — confirm with Maaz.

**8.2 Time zone for dashboards.**
🟢 CONFIRMED → `America/Edmonton` (Calgary MT) per Weekly OS.

**8.3 Refresh cadence after first audit.**
🟡 INFERRED → **Weekly**, with a daily incremental delta. Aligns with the Friday Weekly Review cadence.

**8.4 Who else can see the dashboards.**
🟡 INFERRED → **Maaz only** by default. Zaheer gets the WhatsApp update (R14), not direct dashboard access. Ron/Ashley may benefit from per-customer slices later — defer until v2.

---

## 9. Known pain points (CAPTURED from Execution Plan)

From the Weekly OS rules + the routines named:

- 🟢 "Inbox closed outside the four windows" — reactive email eats deep-work time
- 🟢 "Pipeline lies to you on Friday's Weekly Review" without Tuesday hygiene (R10) — stale close dates, missing next-step, single-threaded relationships
- 🟢 "Compliance lapses block tendering" — Item 43 (Mushtaryat) blocks 2 other tenders
- 🟢 "Anwil NDA sat for weeks" — contract first-pass review is slow
- 🟢 "ME accounts forget who's accountable when there's a 24h+ logging gap" — same-night CRM logging required
- 🟢 "AR aging line by line" Thursday — needs to be pre-staged
- 🟢 Aramco HQ touchpoint gap — quarterly cadence required (R22)
- 🟢 Sale-process is the highest-stakes file — needs weekly written memo (R9)

These are the headline pain points the dashboards need to fix.

---

## 10. Sign-off

Once Maaz reviews this file, the inferred answers get promoted into `client-config.yaml` (see `client-config.yaml.draft` alongside this file).

**Estimated review time with Maaz:** 20 minutes (vs 45 cold) because every question already has a defensible draft.

**Stop criteria for the conversation:**
- All 🟡 INFERRED items confirmed or corrected
- All 🔴 NEEDS MAAZ items answered
- `client-config.yaml` saved at the audit-run root
- Stage 1 (tenant discovery) is then unblocked
