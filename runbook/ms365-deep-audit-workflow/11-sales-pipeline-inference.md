# Stage 9 — Sales Pipeline Inference

> **⚠️ DECISION OVERRIDE 2026-05-26:** Where this stage references R9 as "Sale-Process Memo" or links sales-pipeline output to sale-process tracking, that framing is superseded. R9's purpose (weekly written memo of the highest-stakes file) remains valid but its topic is no longer assumed to be the sale. See [`docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10`](../../docs/decisions/2026-05-26-maaz-phase1-decisions.md#d10).

**Purpose.** Reconstruct a sales pipeline — prospect → proposal → won/lost stages with values + dates — even though SRE has no CRM. Combine the explicit signal from the SharePoint Jobs Tracker (if it exists) with the implicit signals from mail + documents + meetings.

**Pre-requisite.** Stage 8 (`customer-360.json`) complete.

**Output.** `data/sales-pipeline.json` — every detected deal with stage, value, owner, age, last-touch, predicted next-action. Plus an AR aging extract.

**Safety.** Reads local JSONs only + (optionally, gated) downloads PDF/XLSX bytes for OCR'ing invoices/proposals. The optional OCR pass is the one place where the audit calls `download-bytes` against actual file content.

**Run time.** 5 min (without OCR) or 15–30 min (with OCR pass on top-50 high-value docs).

---

## 1. Why this is the hardest stage

In GHL, an opportunity has `pipelineStageId`, `monetaryValue`, `status`. Done.

In MS365 we have to GUESS — and we have to guess defensibly. The synthesizer's job is to fuse three sources of evidence with a clear precedence order:

1. **Explicit CRM source** — if the SharePoint Jobs Tracker has a row matching a customer, that row's `Stage` + `Value` + `Owner` + `DueDate` is treated as authoritative. (Stage 3 already detected this list.)
2. **Document evidence** — if a proposal/contract/invoice PDF exists in the customer's `documents` array, that's an evidence point with a date.
3. **Communication evidence** — subject classifications + bodyPreview + meeting transcript fragments.

Each deal has a **provenance trail** stored in the output so Maaz can sanity-check.

---

## 2. The deal record

```json
{
  "id": "aramco.com::train-4-sru-revamp",          // synthesized
  "customerKey": "aramco.com",
  "customerName": "Saudi Aramco",
  "title": "Train 4 SRU revamp",                    // derived from subject pattern or CRM row
  "stage": "Proposal Sent",
  "stageSource": "sharepoint:Jobs Tracker:row 37",
  "stageConfidence": 0.95,
  "value": 850000,
  "valueSource": "sharepoint:Jobs Tracker:row 37",
  "currency": "USD",
  "owner": "Maaz Ahmed Shareef",
  "firstSignal": "2025-12-04",                       // earliest evidence date
  "firstSignalEvidence": "mail::Re: Pre-bid call Train 4 SRU",
  "proposalSentDate": "2026-05-20",
  "proposalSentEvidence": "mail::outbound to aramco.com with attachment Proposal_Aramco_Train4_2026-05-20.pdf",
  "proposalAttachmentRef": "raw/mail/maaz/.../attachments-flat.json#att-1234",
  "lastTouchDate": "2026-05-19",
  "lastTouchEvidence": "calendar::Saudi Aramco bi-weekly review",
  "ageDays": 168,
  "predictedNextAction": "Send follow-up — 7 days since proposal, no inbound",
  "predictedNextActionDue": "2026-05-27",
  "evidenceTrail": [
    { "date": "2025-12-04", "source": "mail",     "summary": "First inbound from aramco.com — Pre-bid call request" },
    { "date": "2025-12-08", "source": "calendar", "summary": "Pre-bid call held — 60 min, 3 attendees" },
    { "date": "2026-01-15", "source": "sharepoint", "summary": "Row added to Jobs Tracker — Stage: Qualified" },
    { "date": "2026-04-02", "source": "onedrive", "summary": "Proposal_Aramco_Train4_v1.docx created" },
    { "date": "2026-05-20", "source": "mail",     "summary": "Proposal sent outbound — Proposal_Aramco_Train4_2026-05-20.pdf" }
  ],
  "findings": [
    { "severity": "low", "title": "Proposal sent but no follow-up cadence scheduled" }
  ]
}
```

---

## 3. Stage inference logic (when there's NO Jobs Tracker row)

When a customer has no explicit CRM row, the synthesizer infers stage from signal patterns. This is **fuzzy** — every inferred stage has a `stageConfidence` field <1.0 and the evidence trail is mandatory.

| Inferred stage | Trigger pattern | Confidence ceiling |
|---|---|---|
| `lead` | First inbound from new external domain, no meeting yet | 0.7 |
| `qualified` | Met once + ≥1 outbound followup OR inbound asks for proposal | 0.65 |
| `proposal_sent` | Outbound mail with proposal-class attachment to customer | 0.85 |
| `negotiation` | After `proposal_sent`, ≥2 back-and-forth replies + commercial language detected ("revised price", "scope", "terms") | 0.55 |
| `verbal_yes` | Inbound with words "go ahead", "approved", "let's proceed" within 30d of proposal | 0.65 |
| `contract_signed` | Contract-class file appears in inbox/OneDrive/SharePoint within 60d of `verbal_yes` | 0.85 |
| `in_execution` | Project folder activity OR recurring meeting starts AFTER `contract_signed` | 0.7 |
| `won_invoiced` | Invoice-class outbound + inbound "thank you / payment / received" | 0.85 |
| `lost` | Explicit lost language inbound ("regret", "decided to go with another vendor", "not awarded") | 0.95 |
| `lost_silent` | Proposal sent + 120d no inbound + no other activity | 0.5 |
| `unknown` | Doesn't match | 0.3 |

These thresholds get tuned per-client during stage 0. Maaz's review is mandatory before stage 9's output is treated as decision-grade.

---

## 4. Value inference

Value precedence:
1. **SharePoint Jobs Tracker `Value` column** — authoritative
2. **OCR'd invoice PDF** — extract the line "Total: $X,XXX,XXX"
3. **OCR'd proposal PDF** — extract "Project value", "Total proposal value", etc.
4. **Mail body regex** — `\$([\d,]+(?:\.\d+)?)\s*(?:USD|CAD|million|M)` in the deal's thread
5. **`null`** — surfaced as a finding

The OCR pass is the only stage that downloads file bytes. It's gated:
- Off by default
- Per-config: enable only for `proposal` + `invoice` + `contract` classes
- Top-N files per customer to limit cost
- Uses MS365's `download-bytes` to fetch, then a local OCR library (e.g. `pypdf` for text PDFs, `tesseract` only as fallback for scanned)

---

## 5. AR aging extract

The synthesizer derives `data/ar-aging.json` from invoice-class signals:

```json
{
  "generatedAt": "...",
  "asOfDate": "2026-05-22",
  "totals": {
    "totalAR": 482000,
    "currency": "USD",
    "invoicesOpen": 14,
    "invoicesOverdue30": 8,
    "invoicesOverdue60": 4,
    "invoicesOverdue90": 2
  },
  "byCustomer": [
    {
      "customerKey": "aramco.com", "customerName": "Saudi Aramco",
      "openInvoices": [
        { "id": "INV-1042", "amount": 220000, "issued": "2026-03-01",
          "dueDate": "2026-04-01", "daysOverdue": 51,
          "originalEmailId": "...", "attachmentPath": "..." }
      ],
      "totalOpen": 220000,
      "oldestOverdueDays": 51,
      "lastReminderSent": "2026-04-15",
      "lastInboundFromCustomer": "2026-04-10"
    }
  ]
}
```

Detection of "paid":
- Inbound from customer with words "paid", "remittance", "payment", "transfer reference"
- OR explicit mail rule that moves invoices to "Paid" folder
- OR if a bookkeeper account is in scope: forwarded "paid" notification

Otherwise the invoice stays "open" until Maaz manually confirms.

---

## 6. Findings

| Severity | Finding |
|---|---|
| HIGH | Proposal sent, >30d, no follow-up scheduled OR no inbound reply |
| HIGH | Invoice overdue >60d, no reminder sent in 14d |
| HIGH | Active deal in CRM with `stageSource=sharepoint` but no matching mail/cal evidence — possibly a phantom row |
| HIGH | Active deal in mail/cal but no SharePoint row — pipeline gap |
| MED | Deal age >365d in `proposal_sent` stage — should be reclassified |
| MED | OCR failed to extract value from a proposal PDF — manual review |
| LOW | Deal title looks templated (no project-specific words) |

---

## 7. Output sizes

- `sales-pipeline.json` — typically <2 MB
- `ar-aging.json` — typically <500 KB
- OCR'd text dumps (if enabled) — `raw/ocr/<docId>.txt`, small per file

---

## 8. The bridge to routines

This stage's output directly powers:

- **R9 (Sale-Process Memo)** — uses `evidenceTrail` for the buyer-Q&A back-history
- **R10 (Pipeline Hygiene)** — surfaces `findings` of severity HIGH for triage
- **R12 (AR Aging + Cash Forecast)** — consumes `ar-aging.json` directly
- **R20 (Friday Top-5)** — ranks deals by value × ageDays × confidence
- **R26 (Quarterly Review)** — quarter-over-quarter pipeline movement

When these routines fire, they SHOULD NOT re-run the inference — they consume `sales-pipeline.json` written by this stage and trust it. The pipeline gets refreshed by re-running the audit (initially on-demand; eventually a scheduled `pipeline-refresh` routine).

---

## 9. Acceptance criteria

- [ ] Every customer in `customer-360.json` either has ≥1 deal OR an explicit "no deal" record
- [ ] Every Jobs Tracker row maps to a deal record (1:1, by Customer + Title)
- [ ] Inferred-stage deals each have an evidence trail with ≥2 dated entries
- [ ] AR aging totals reconcile with Maaz's mental model within ±10%
- [ ] OCR results spot-checked on 5 invoices, 5 proposals
- [ ] Findings reviewed for false positives
- [ ] Output JSON loadable into the Sales Pipeline dashboard without errors
