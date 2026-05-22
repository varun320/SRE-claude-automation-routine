# SRE Proposal Structure — canonical

> **Authoritative source.** This document is the verbatim canonical SRE proposal structure as defined in `SulfurProposals/SulfurProposals/Instructions.txt`. Sections 6 (Term), 7 (Technical Information), and 9 (Professional Liability) contain verbatim text that must NOT be paraphrased — they are SRE's standard legal and commercial boilerplate.

---

## 1. Summary Letter

Write a succinct summary in **two short paragraphs**:

- **Paragraph 1**: Describe the client's problem, how they approached us, and what solutions were decided.
- **Paragraph 2**: Introduce the attached proposal briefly, mentioning key highlights.

---

## 2. Background

Provide a **single paragraph** outlining the client's background, focusing on their processes and identifying problems clearly. Mention all relevant equipment and streams to fully explain the issue and operations.

---

## 3. Process Overview

In **two paragraphs**, delve deeper into the client's chemical process. Explain it clearly and include process parameters provided by the client.

---

## 4. Project Scope

In **one paragraph**, clearly state all deliverables and project outcomes based on the provided data. Follow this with a well-organized table listing all project deliverables, with estimated completion times.

| Deliverable | Description | Estimated Time |
|---|---|---|
| Example Deliverable 1 | Detailed description here | XX days |
| Example Deliverable 2 | Detailed description here | XX days |

---

## 5. Onsite Visit and Sampling (if applicable)

If testing and analysis are required onsite, provide all necessary details, including streams to be tested and a proposed daily schedule. Use a format similar to the provided example.

Required elements:

- Daily schedule (typically 6-8 days, hour-by-hour for each)
- Streams to be tested with sample point and frequency
- Personnel involved (which SRE engineers, which client side)
- Equipment to be set up onsite (GC, sample manifold, etc.)
- Safety briefing notes (H₂S, hot work permit, SCBA requirement)

---

## 6. Term and Additional Information

Use the exact text below for consistency, only modifying the client name if required:

### Plant Data

A log of all necessary process data (flows, temperatures, pressures) will be recorded throughout the test period.

- Mechanical drawings for equipment (reaction furnace, condensers, converters, etc.) may be required to create the simulation model.
- DCS screenshots of the amine regenerator overhead conditions will be needed for calculating water content in acid gases.
- DCS data of the amine system will be needed to assess unit performance since the last health check.
- A Data Request Sheet will summarize required parameters during the pre-test meeting.

### Gas Plant Responsibilities

Tailor the following bullet points for the client, ensuring relevance:

- Full cooperation by operations staff for collecting plant data and ensuring safe sampling of acid gas streams.
- Access to clean power supply (110V or 220V) and 4 meters of lab/bench space with fume hood for waste disposal.
- Provide a bottle of UHP (99.999% pure) Helium for chromatograph operations.
- Ensure laboratory glassware and other required equipment are available.
- Two 30-minute SCBA units (or alternatives if provided by the client) for sampling process streams.
- Sample points must be accessible and free from interference (e.g., railings).
- Other test requirements will be determined based on the scope of work.

---

## 7. Technical Information

**This section remains unchanged for every proposal.**

### Gas Chromatograph Calibration

All SRE chromatographs are calibrated regularly with certified, up-to-date calibration standards, ensuring the highest accuracy available. These gases are referred to as 'protocol' or 'primary' standards.

### Gas Components Analyzed

The following components are analyzed in each process stream:

| Component | Analyzed in Process Stream |
|---|---|
| H₂, SO₂, Toluene | C₂H₄, nC₄, Methyl Mercaptan |
| Ar, CS₂, Benzene | iC₄, COS, Ethyl Mercaptan |
| (Additional analysis available on request) | |

### Process Simulation Software

Symmetry™ provides accurate, robust, and cost-effective process simulation solutions to predict the behavior of process units and plants. It is a reliable partner in modeling processes in the oil and gas, refining, and chemical industries. Key processes like natural gas sweetening, Claus plants, and tail gas treatment are simulated efficiently without the need for special workarounds.

---

## 8. Payment Terms

Include the exact text below, adapting the payment terms for each client:

> An invoice will be submitted upon completion of onsite work, payable within 30 days. For clients with payment terms over 45 days, a 4% interest charge will be applied. Any work exceeding 10 hours per shift incurs an overtime rate of USD $650 per hour. Cancellations before mobilization incur no costs; cancellations post-mobilization cost USD $6,500 plus any non-recoverable expenses.

| Payment Term | Condition | Amount |
|---|---|---|
| Onsite Overtime | Work exceeding 10 hours per shift | USD $650/hour |
| Extension | Per client request | USD $6,500/day |
| Delay Standby | Per delay caused onsite | USD $2,000/day |

---

## 9. Professional Liability

Ensure the following text is included and adapted to the client's specifics:

> All SRE employees are covered internationally by the Workers' Compensation Board of Alberta, Canada, and have up-to-date H2S Alive, First Aid, WHMIS, and TDG certification. SRE holds $5,000,000.00 in general liability coverage and $1,000,000.00 in professional liability. SRE implements a drug and alcohol policy and safety program that adheres to industry standards.

---

## Style notes

- **Tone**: technical, precise, professional. The audience is a process engineer or plant manager, not a marketer.
- **Voice**: use first-person plural ("we will measure...", "our team has...") for SRE actions; third-person for client.
- **Numbers**: spell out dollar amounts in full at first mention (USD $6,500), then numerals after. Use SI units; convert ambiguous units explicitly.
- **Citations**: bracket technical claims with `[Cite: <library-doc-name>]` during draft, expand to full footnote on final.
- **Verbatim blocks**: sections 6, 7, 9 contain text that MUST appear verbatim. Editing them creates legal/commercial inconsistency across proposals.
- **Length**: typical SRE proposal is 6-12 pages. Onsite proposals tend longer due to schedule + safety detail.

---

## Common adaptations

- **Tender format (Qatar Mushtaryat, Kuwait K-Tendering)**: prepend a tender cover page with reference number + bid validity + currency. Add appendices for vendor registration documents.
- **AIMS-bridged**: add a note in §1 that the work is being executed via AIMS as the local partner. AIMS handles client billing; SRE handles technical delivery.
- **Repeat customer**: shorten §2 (background) since they know us. Expand §4 (scope) since they expect detail.
- **Confidential / sale-process customer**: defer entirely — this skill is not the right path for those proposals. Escalate to operator.
