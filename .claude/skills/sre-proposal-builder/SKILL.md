---
name: sre-proposal-builder
description: Build engineering proposals for Sulfur Recovery Engineering (SRE) and analogous oil-and-gas EPC firms in their canonical proposal structure — Summary Letter, Background, Process Overview, Project Scope + Deliverables table, Onsite Visit Plan, Term & Additional Information, Technical Information, Payment Terms, Professional Liability. Cross-references SRE's technical library (20+ industry papers + SRE Work Experience + SRE Services brochure). Produces DRAFT output for operator review — never sends, never commits. Use when an operator says "draft a proposal for <customer>", when an RFQ comes in that needs a response, when adapting a prior proposal to a new customer, or when converting a webinar/conversation into a formal proposal.
---

# SRE Proposal Builder

Codifies the canonical SRE proposal authoring workflow — same structure used by Maaz's SulfurBot Proposals GPT, ported to a Claude skill so it composes with the audit + routine-author + email-drafter skills.

This skill is **draft-only**. It produces proposal content in the SRE structure, ready for operator review and editing. It never sends, never auto-saves to a customer-facing location, never bypasses the human-in-loop review.

---

## When to use

- Operator says *"draft a proposal for Q-Chem on the 2028 Feed Study"* or similar
- An RFQ landed in the operator's inbox and they want a first-pass response
- A customer-named meeting on the calendar (e.g., "Pre-Meet Petro-Rabigh") creates a proposal need
- Operator wants to adapt a prior proposal to a new customer (similar process, different parameters)
- Webinar Q&A or sales call → convert to a formal proposal
- Country compliance work (Qatar Mushtaryat, Kuwait K-Tendering) needs a tender-format proposal

## When NOT to use

- The user wants a one-off email (use `sre-email-drafter`)
- The user wants to send the proposal directly — this skill is draft-only; sending requires human review
- The user wants to redesign the proposal structure itself — this skill follows SRE's existing canonical structure
- Internal docs (meeting briefs, weekly memos) — use the appropriate routine instead

---

## Skill contents

```
~/.claude/skills/sre-proposal-builder/
├── SKILL.md                           ← this file
├── references/
│   ├── proposal-structure.md          ← canonical SRE Proposal Structure (verbatim from Instructions.txt)
│   ├── technical-library-index.md     ← catalog of the 20 reference PDFs · what each covers · when to cite
│   └── intake-questionnaire.md        ← 15-question intake form before drafting
└── templates/
    ├── proposal-skeleton.md.template  ← filled-in proposal scaffold
    └── deliverable-table.md.template  ← deliverables table format
```

---

## Pre-flight

Before drafting any proposal, confirm:

1. **Client identity** — full legal name, region, primary technical contact, AIMS-bridged or direct
2. **Source documents available** — the RFQ / inquiry email / prior call notes / Maaz's chat thread with operator that triggered the proposal. Without source material, the draft will be generic and useless.
3. **Technical library accessible** — the local SRE database lives at `<project>/SulfurProposals/SulfurProposals/database/`. Confirm it's reachable; if not, the draft can still proceed but technical citations will be weaker.
4. **Customer-specific patterns** — for repeat customers (Aramco, ADNOC, AIMS-bridged ME), check prior sent-items metadata or audit data for the customer's preferred subject-line format and routing.
5. **Confidentiality** — if this customer is on `client-config.confidentiality.confidential_customers` list (e.g., sale-process buyer), STOP. Confidential proposals need a different review path.

---

## Workflow

### Step 1 — Intake

Walk through `references/intake-questionnaire.md` with the operator (~10–15 min). Required answers:

- Client name + region + technical contact
- The problem (one paragraph in operator's own words)
- What the client asked for (verbatim from RFQ if available)
- Process equipment in scope (SRU? TGTU? Amine? Sour-water stripper? GC testing?)
- Streams to be tested / analyzed
- Onsite vs remote vs hybrid
- Deliverables sought (report? simulation? training? sampling campaign?)
- Estimated timeline
- Payment terms preference (standard SRE or customer-specific)
- AIMS bridge or direct?
- Any constraints from prior conversations (e.g., "they want it in tender format", "Sanjay Bhatt is the technical contact at QChem")

### Step 2 — Library cross-reference

Read `references/technical-library-index.md`. For each technical claim the proposal will make, identify which library document substantiates it. Examples:

- Claus chemistry claims → "LRGCC 2003 New Insights into the Claus Thermal Stage" + "Improving_Claus_Sulfur.pdf"
- Hydrocarbon destruction in furnace → "LRGCC 2000 Hydrocarbon Destruction In the Claus Reaction Furnace.pdf"
- TGTU reference → "2021-03 Brimstone TGTU principles.pdf"
- Vent gas handling → "Options-for-Handling-Vent-Gases-in-Sulfur.pdf"
- SRE credibility / past projects → "SRE Work Experience - 150 Recent Projects - 2022.pdf"
- General sulfur recovery fundamentals → "M22 Sulfur Recovery.pdf" + "2015_001 Fundamentals of sulfur recovery.pdf"
- Service catalog → "SRE services.pdf"

The library is a credibility anchor — every proposal should ground its technical claims in 2-4 references from this set. Do NOT invent citations; only cite documents that actually exist in the library.

### Step 3 — Draft each section in canonical order

Use `templates/proposal-skeleton.md.template` as the starting scaffold. The 9 canonical sections (full schema in `references/proposal-structure.md`):

1. **Summary Letter** — 2 paragraphs · client problem + solution + proposal highlights
2. **Background** — 1 paragraph · client processes + equipment + identified problem
3. **Process Overview** — 2 paragraphs · deeper chemical-process explanation + client-provided parameters
4. **Project Scope** — 1 paragraph + Deliverables table (`templates/deliverable-table.md.template`)
5. **Onsite Visit and Sampling** — only if applicable; daily schedule + streams to be tested
6. **Term and Additional Information** — Plant Data + Gas Plant Responsibilities (verbatim text, tailor bullets)
7. **Technical Information** — GC Calibration + Gas Components Analyzed table + Process Simulation Software (verbatim, unchanged)
8. **Payment Terms** — verbatim text, adapt amounts per customer
9. **Professional Liability** — verbatim text, adapt to client specifics

For each section, the canonical text in `references/proposal-structure.md` is authoritative. Sections 6, 7, 9 contain verbatim blocks that should not be paraphrased — they're SRE's standard legal/commercial boilerplate.

### Step 4 — Output as draft

Write to `<project>/proposals/<date>-<customer-slug>-<topic-slug>.md` with status: draft. Format is Markdown for easy editing; can be converted to .docx via Pandoc when operator approves.

Always include at the top of the draft:

```yaml
---
status: draft
customer: "Q-Chem"
customer_contact: "Sanjay Bhatt"
topic: "SGRU/SRU 2028 Feed Study and SRU/AGRU Training"
drafted_by: "Claude · sre-proposal-builder"
drafted_on: 2026-05-22
source_documents:
  - "Inbox thread <message-id> dated 2026-05-13"
  - "Pre-Meet calendar event on 2026-05-13"
library_citations:
  - "LRGCC 2003 New Insights into the Claus Thermal Stage"
  - "M22 Sulfur Recovery"
review_status: pending_operator_review
aims_routed_through: "bader@aimsgt.com"      # if AIMS-bridged
---
```

### Step 5 — Operator review checklist

Surface the draft to the operator with a 5-point review checklist:

- [ ] **Section 1 (Summary)** — does the problem statement match what the client actually told us?
- [ ] **Section 4 (Project Scope + Deliverables)** — are the deliverables, time-estimates, and counts realistic?
- [ ] **Section 5 (Onsite)** — if onsite, is the daily schedule feasible given travel + local logistics?
- [ ] **Section 8 (Payment)** — are the rates per customer's prior terms or do they need adjustment?
- [ ] **Technical citations** — do all citations point to documents that actually exist?

The operator either marks the draft `status: approved_for_send` (and a separate skill like `sre-email-drafter` produces the cover email), or edits inline and re-reviews.

---

## Safety rules

1. **Draft-only.** This skill produces files; it does not send, post, or commit anything. The output file always carries `status: draft` and `review_status: pending_operator_review`.
2. **No invented citations.** Only cite documents in the local `SulfurProposals/database/` directory. If a claim has no library backing, mark it `[CITATION NEEDED]` in the draft.
3. **No invented numbers.** Pricing, deliverable counts, timelines, and rates must come from operator-provided input or SRE's standard rates table (in `references/proposal-structure.md` §8). Never fabricate.
4. **No verbatim from confidential prior proposals.** If adapting a prior proposal, treat the prior as inspiration, not source. Re-derive the client-specific sections from new inputs.
5. **Confidential customer guard.** If `client-config.confidentiality.confidential_customers` matches the target client, halt and ask operator before proceeding.
6. **No customer-facing destination.** Output goes to `<project>/proposals/` — never directly to OneDrive, SharePoint, or any path that's auto-synced to a customer.

---

## Generalization notes

This skill is named `sre-proposal-builder` because it codifies SRE's specific structure (sulfur recovery, Claus, TGTU, amine systems, etc.). The methodology generalizes to any oil-and-gas EPC firm with a similar proposal format:

- Replace `references/proposal-structure.md` content with the client's canonical structure
- Replace the technical library catalog with the client's reference set
- Update intake questionnaire to the client's specific service lines
- Update the verbatim boilerplate sections (Payment Terms, Professional Liability) to the client's standard

For a non-EPC client (e.g., a SaaS proposal builder), the workflow shape is the same but the section list, technical library, and verbatim boilerplate all change. Fork the skill rather than parameterizing — the proposal structure IS the value, and trying to make it universal would dilute every variant.

---

## Quick-start invocation

When invoked, ask the operator three things and proceed:

1. **Which customer?** (name + region + technical contact)
2. **What did they ask for?** (one sentence + the source thread/event if available)
3. **Onsite, remote, or hybrid?** (drives §5 inclusion + payment structure)

Then walk the full intake questionnaire, draft each section in canonical order, and surface the draft at `<project>/proposals/<date>-<customer>-<topic>.md` with the operator review checklist.

End with a one-line summary: customer, draft file path, library citations used, what the operator should review first.
