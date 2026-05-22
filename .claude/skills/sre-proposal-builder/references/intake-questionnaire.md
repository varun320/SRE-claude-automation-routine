# Proposal Intake Questionnaire

Walk through these with the operator before drafting. 10–15 minutes typically.

The goal is to extract enough specificity that the draft doesn't read as generic. A proposal that says "we will analyze your sulfur unit" is useless; one that says "we will sample acid gas at AG-101 and AG-102, run RF temperature measurement via the IR pyrometer port, and produce a Symmetry™ model calibrated to your last 90 days of DCS data" is credible.

---

## 1. Client identity

1. **Full legal client name** (as it should appear on the proposal cover)
2. **Region** (NA / KSA / UAE / Qatar / Kuwait / Bahrain / Oman / EU / Other)
3. **Primary technical contact** — name, email, role
4. **Commercial contact** — if different from technical (often AP/finance for AR/billing)
5. **Routing** — direct to client, or via AIMS as the ME local partner?
6. **Repeat customer?** — yes/no. If yes, prior proposal reference + year.

## 2. The work itself

7. **The problem in client's own words** — verbatim quote from RFQ / inquiry email / call notes. Don't paraphrase yet.
8. **What did they explicitly ask for?** — a study? Sampling? Training? Audit? Revamp? Capital project?
9. **Equipment in scope** — list every named unit/stream the proposal needs to mention (RF, SRU-1, SRU-2, TGTU, amine regen, sour-water stripper, etc.)
10. **Process parameters available** — flows, temperatures, pressures, compositions, last 90d DCS data, prior reports?

## 3. Execution shape

11. **Onsite, remote, or hybrid?** — drives §5 inclusion and significantly affects payment structure
12. **Estimated duration** — total project days, onsite days separately
13. **Number of SRE personnel** — engineers traveling, lab tech support, project manager
14. **Sample plan** — streams to be tested, sample points, frequency, special analyses (mercaptans? COS? amines?)
15. **Deliverables sought** — report? Symmetry™ model? training course? recommendations + costs? compliance documentation?

## 4. Commercial

16. **Quoted total OR rate structure preference** — fixed-price, time-and-materials, or hybrid?
17. **Payment terms** — standard 30-day or customer-specific (longer-term invoicing, milestone billing)?
18. **Currency** — USD default; CAD for Canadian; QAR / SAR / AED if client requires local invoicing
19. **Timing constraints** — hard start/end dates? Tender deadline? Plant turnaround date?
20. **AIMS commercial role** — if AIMS-bridged: who invoices the client (AIMS or SRE)? Who pays SRE (AIMS or direct)?

## 5. Soft signals

21. **Their stated motivation** — emissions compliance? Cost optimization? Plant reliability? Capacity expansion? (Shapes §1 framing.)
22. **Who else is bidding?** — if known. Affects how aggressively the credibility section needs to lean.
23. **Prior conversations to reference** — webinar attendance? Past meeting transcripts (Pocket)? Prior SRE call recording? Cite if substantive.
24. **Sensitivities** — anything operator knows about the client's politics, internal blockers, or commercial pain points that should subtly shape the proposal.
25. **Confidentiality flags** — is this customer on a confidential list (sale-process, M&A target)? STOP if yes.

---

## Decision tree based on answers

| If… | Then… |
|---|---|
| Question 7 has no clear problem statement | Halt. Go back to the operator and get the actual RFQ/inquiry quote. Don't fabricate. |
| Question 11 = onsite | Section 5 of proposal is mandatory. Add 1-2 days to estimated timeline for travel. Quote $650/hr overtime + $2k/day standby. |
| Question 11 = remote | Section 5 is omitted. Payment shifts to deliverable-milestone-based often. |
| Question 5 = AIMS-bridged | Add AIMS routing note in §1. Subject-line + email cover routes via AIMS contact (bader@ for ME, shameem@ for KSA, etc.). |
| Question 6 = repeat customer | Shorten §2 (background). Reference prior project: "Following our 2023 work on Train 3 RF temperature measurement…" |
| Question 15 mentions "training" | Cite Operations Handbook_Rev3.pdf in §4. Include curriculum outline. |
| Question 15 mentions "Symmetry™ model" | Mention Symmetry in §3 + §7. Add data request sheet to §6. |
| Question 25 = confidential customer | STOP. Escalate. This skill is not the right path. |

---

## Output of intake

After all 25 answered, produce a single JSON block the drafting step consumes:

```json
{
  "client": { "name": "Q-Chem", "region": "Qatar", "technical_contact": "Sanjay Bhatt (...@qchem.com.qa)", "commercial_contact": "Bader Ansari (bader@aimsgt.com)", "routing": "AIMS", "repeat": true, "prior_ref": "2024 cooler study" },
  "problem": "verbatim quote of client problem...",
  "ask": "study + training",
  "equipment": ["SRU-1", "SRU-2", "AGRU regen"],
  "process_params": ["last 90d DCS provided", "RF temperature data from 2024 study"],
  "execution": { "shape": "hybrid", "duration_days": 45, "onsite_days": 6, "personnel": ["Dharmesh", "Maaz", "1 lab tech"] },
  "sample_plan": { "streams": ["AG-101", "AG-102", "TG-201"], "frequency": "4x daily for 4 days" },
  "deliverables_sought": ["Symmetry model", "Performance report", "1-week training course"],
  "commercial": { "structure": "fixed-price + onsite hourly rate", "currency": "USD", "terms": "30-day", "aims_role": "AIMS invoices client; SRE invoices AIMS" },
  "timing": { "deadline": "2026-08-15 tender submission", "start_target": "2026-09-01" },
  "soft_signals": { "motivation": "compliance + cost reduction", "competing_bidders_known": false, "prior_conversations": "Maaz-Sanjay call 2026-05-13; QChem RFQ thread"},
  "confidentiality_flag": false
}
```

This JSON becomes the input to the section-by-section drafting step.
