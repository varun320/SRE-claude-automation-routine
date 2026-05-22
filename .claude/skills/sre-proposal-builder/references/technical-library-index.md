# SRE Technical Library — index + citation guide

The library lives in the per-project SulfurProposals directory:

```
<project>/SulfurProposals/SulfurProposals/database/
```

21 PDFs as of 2025-10. This index catalogues each, with the topics it covers and the proposal sections where it makes a credible citation.

---

## Fundamentals (cite for §2 Background or §3 Process Overview)

| File | What it covers | Cite when |
|---|---|---|
| `M22 Sulfur Recovery.pdf` | API M22 — canonical sulfur recovery reference manual | Any proposal needs a "fundamentals" anchor; safe baseline citation |
| `2015_001 Fundamentals of sulfur recovery.pdf` | Sulfur recovery fundamentals primer | When client is new to SRU operation (training proposals) |
| `Fundamentals-of-Natural-Gas-Processing 2nd Edition.pdf` | Upstream gas processing context | When proposal touches amine + sour gas treatment, not just SRU |

## Claus chemistry & operation (cite for §3 Process Overview, §4 Scope)

| File | What it covers | Cite when |
|---|---|---|
| `Improving_Claus_Sulfur.pdf` | Claus efficiency improvement methods | Any optimization / debottlenecking proposal |
| `LRGCC 2003 New Insights into the Claus Thermal Stage, Chemistry and Temperatures.pdf` | Thermal stage chemistry deep dive | Furnace temperature studies, performance issues |
| `LRGCC 2000 Hydrocarbon Destruction In the Claus Reaction Furnace.pdf` | HC destruction kinetics in furnace | Acid gas with significant HC content; soot formation issues |
| `LRGCC 2003 Modified Claus Sulfur Recovery Unit Equipment.pdf` | Modified Claus equipment design | New unit design or major revamp |
| `LRGCC 2012 How Hot is Your Reaction Furnace.pdf` | RF temperature measurement and impact | Proposal involves RF temperature measurement (very common) |
| `2015-05 Unload the SRU to reduce plugging problems and operating costs.pdf` | SRU loading optimization | Plugging / pressure-drop issues; operating-cost reduction proposals |

## TGTU (Tail Gas Treatment Unit) (cite for proposals touching tail gas)

| File | What it covers | Cite when |
|---|---|---|
| `2021-03 Brimstone TGTU principles.pdf` | Brimstone TGTU technology overview | Any TGTU proposal · the canonical TGTU citation |
| `Options-for-Handling-Vent-Gases-in-Sulfur.pdf` | Vent-gas handling options for sulfur plants | Vent gas / emissions reduction proposals |

## Emissions, environmental, compliance (cite for §1 Summary, §2 Background)

| File | What it covers | Cite when |
|---|---|---|
| `Global SOx Emission Cap.pdf` | SOx emission regulation landscape | Compliance-driven proposals; emissions reduction motivation |
| `Best Management Practices for Facility Flare Reduction.pdf` | Flare reduction BMPs | Flare-stack work; refinery-wide emissions proposals |
| `Liquid or Solid Sulfur Product Specifications.pdf` | Sulfur product spec reference | Product-quality-driven proposals; downstream offtake issues |

## Project lifecycle & lessons learned (cite for §2 Background or §5 Onsite Plan)

| File | What it covers | Cite when |
|---|---|---|
| `SRU & TGTU project execution and startup lessons learned from owner and licensor perspective.pdf` | Project execution case studies | Capital project proposals · "we've seen this before" credibility |
| `Operations Handbook_Rev3.pdf` | Operations handbook template | Operator training proposals · O&M support contracts |

## SRE-specific credibility documents (cite in §1 Summary or §2 Background)

| File | What it covers | Cite when |
|---|---|---|
| `SRE services.pdf` | SRE services brochure / capability statement | Every proposal · always cite as "see attached SRE services brochure" |
| `SRE Work Experience - 150 Recent Projects - 2022.pdf` | SRE 150-project portfolio | When customer is new to SRE · prove track record |
| `Webinar FAQs.pdf` | Common webinar Q&A | When proposal followed a webinar attendance |

---

## Citation conventions

In the draft, use bracketed inline citations:

```
The reaction furnace temperature has a first-order impact on hydrocarbon destruction
[Cite: LRGCC 2000 Hydrocarbon Destruction] and Claus conversion efficiency
[Cite: LRGCC 2003 New Insights into the Claus Thermal Stage].
```

On final, expand to a Bibliography section at the end of the proposal:

```
References
1. LRGCC 2000 — "Hydrocarbon Destruction In the Claus Reaction Furnace"
2. LRGCC 2003 — "New Insights into the Claus Thermal Stage, Chemistry and Temperatures"
3. SRE Services Brochure (attached)
4. SRE 150 Recent Projects (2022) — selected case studies
```

---

## Anti-patterns — never do these

- **Don't invent citations.** Every citation MUST point to a file that actually exists in the library directory. If a technical claim has no library backing, leave it as plain prose without the `[Cite: ...]` tag — or mark it `[CITATION NEEDED]` for the operator to resolve.
- **Don't over-cite.** A proposal with citations on every sentence reads as defensive. Target 4-8 citations per proposal — enough to ground the technical claims, not so many it becomes academic.
- **Don't cite irrelevant papers.** A proposal about amine optimization shouldn't cite the LRGCC 2012 RF temperature paper just because it's prestigious. Match the citation to the claim.
- **Don't paraphrase the verbatim blocks.** Sections 6, 7, 9 of the proposal structure contain verbatim text. Library citations belong in sections 1–5.
- **Don't expose the library file path** in the customer-facing proposal. The library is internal reference material; the customer sees author/year/title only.

---

## When the library isn't available

If the local `SulfurProposals/database/` directory isn't reachable (e.g., the skill is running in a different project or on a different machine), the proposal can still be drafted — but:

- Skip the `[Cite: ...]` inline tags
- Add a `library_status: not_available` field to the draft frontmatter
- Surface a one-line note to the operator: "Technical library not accessible — citations not added. Operator must add citations during review."
