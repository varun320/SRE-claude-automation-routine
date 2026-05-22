# AIMS routing map

When SRE works with Middle East customers, the relationship is typically bridged via AIMS Global Technology (`@aimsgt.com`). The audit surfaced 13+ AIMS contacts; each owns a specific customer or country track.

This file maps customer → AIMS bridge contact. When drafting emails to ME-bridged customers, the email goes to the AIMS contact, NOT direct to the end-customer (unless operator explicitly overrides).

---

## Country-level routing

| Country / Region | Primary AIMS contact | Email |
|---|---|---|
| KSA (Saudi Arabia) | Shameem (lead) + Maaz Khan + Ali Albader (for Aramco-RTR specifically) | `shameem@aimsgt.com`, `maaz@aimsgt.com`, `ali.albader@aimsgt.com` |
| Qatar | Bader Ansari + Vahib Saleem | `bader@aimsgt.com`, `vahibsaleem@aimsgt.com` |
| UAE (ADNOC) | Sateesh D + Ravi Srinivas + Girish (AIMS) | `sateeshd@aimsgt.com`, `Ravi.Srinivas@aimsgt.com`, `girish@aimsgt.com` |
| Kuwait | (uncertain — confirm with operator; no clear AIMS lead surfaced in audit) | TBD |
| Oman | Muhammad Bilal + Hameed | `muhammadbilal@aimsgt.com`, `hameed@aimsgt.com` |
| Bahrain (BSE/BAPCO) | TBD — confirm with operator | TBD |
| Cross-ME (general) | Naveed Hussain + Ahmad Patel | `naveed.hussain@aimsgt.com`, `ahmad.patel@aimsgt.com` |
| AIMS Finance (year-end audits + AR confirmations) | Mohammed Fazal, Junaid Muhammad E | `fazal@aimsgt.com`, `junaid@aimsgt.com` |
| AIMS Senior / Shareholder bridge | Zaheer Juddy | `zaheerjuddy@aimsgt.com` |
| Technical / general | Mohammed Yunus | `yunus@aimsgt.com` |

---

## Customer-level routing

For specific customers seen in the audit:

| Customer | Region | AIMS bridge | Notes |
|---|---|---|---|
| Saudi Aramco (RTR — Ras Tanura) | KSA | Ali Albader (`ali.albader@aimsgt.com`) | RTR project = 2025180. Multiple AIMS attendees on calls (Shameem, Maaz Khan, Naveed). |
| Saudi Aramco (general) | KSA | Shameem (`shameem@aimsgt.com`) | Other Aramco sites route through Shameem; confirm site contact per project. |
| ADNOC (Habshan, Ruwais, RSGP) | UAE | Sateesh D + Ravi Srinivas | Sateesh organizes Amine Expert calls; Ravi on RTR-style technical reviews. |
| Q-Chem | Qatar | Bader Ansari (`bader@aimsgt.com`) | Verified pattern: "DRAFT for your approval - QChem (Sanjay Bhatt): <topic>" → Bader |
| Petro-Rabigh | KSA | Naveed Hussain + Ali Albader | Pre-Meet held May 20 2026; both attended. |
| Qatar Energy | Qatar | Bader Ansari | Vendor registration + tender prep route via Bader. |
| KNPC (MAA Sulfur Block Units, project 2025207) | Kuwait | Naveed Hussain (per calendar evidence) | TSA + budgetary proposal correspondence. |
| SATORP (LTSA Sulfur Services) | KSA | Ali Albader | LTSA scope route via Ali (project 2024239). |
| JIGPC | KSA/Kuwait | TBD — confirm with operator | Paired with KNPC track. |
| Tüpraş | Turkey | Not AIMS-bridged | Direct SRE relationship. AR reconciliation thread is via Ashley + Maaz direct, not via AIMS. |
| INERCO | Spain | Not AIMS-bridged | Direct SRE-INERCO partnership. Contact via direct emails (gchiapetta@inerco.com, aalvarado@inerco.com, afjimenez@inerco.com). |
| KOC | Kuwait | TBD — RFP-2103367 came via direct inbound; confirm with operator | |
| Mellitah / Dolphin | Libya | TBD — confirm | March 2026 next-steps meeting held; routing not clear yet. |
| CSV Midstream | Canada | Not AIMS-bridged | Direct (roger.henault@csvmidstream.com). |
| Phillips 66 (Rodeo) | USA | Not AIMS-bridged | Direct. RFQ received May 2026. |
| WE Soda | n/a | Not AIMS-bridged | Direct (Brendon.Weidner@wesoda.com). |
| Envent | Canada | Not AIMS-bridged | Direct (adam.ruickbie@envent.com). |
| PrismTeck | n/a | VENDOR (not customer) | Sales Accelerator vendor; treat differently. |

---

## Routing rules

### Rule 1 — ME customer = AIMS bridge by default

If the customer is in the ME region and has an AIMS contact in the map above, the email goes to the AIMS contact as primary recipient.

- **To**: AIMS bridge contact
- **CC**: AIMS senior (Shameem or Zaheer Juddy depending on stakes)
- **CC** (optional): SRE internal owner (Dharmesh, Talha, Ron, etc.) — for awareness
- **End-customer**: NOT cc'd at draft / approval stage. Only added when final and AIMS has explicitly approved.

### Rule 2 — North America customer = direct

If the customer is in NA and there's no AIMS bridge, email goes direct.

- **To**: Customer technical contact
- **CC**: SRE internal owner (Ron for BD, Chuck for US-region accounts, Dharmesh for engineering)

### Rule 3 — Year-end audit / AR confirmations = AIMS Finance

Year-end balance confirmation requests and AR reconciliations from auditors typically come in via AIMS Finance contacts.

- **To**: `fazal@aimsgt.com` OR `junaid@aimsgt.com` (whoever sent the original)
- **CC**: `ashleyh@sulfurrecovery.com` (Ashley handles AR ops)

### Rule 4 — When in doubt, route via AIMS for ME

If the customer is ME but no specific AIMS contact is mapped, default to:
- **To**: `shameem@aimsgt.com` (KSA-anchor) or `naveed.hussain@aimsgt.com` (general ME)
- **CC**: SRE internal owner

Surface the routing uncertainty to the operator so they can confirm.

### Rule 5 — Sale-process / DD-related = never via this skill

If the email touches sale process, due diligence, M&A, or any confidential customer/advisor/buyer, halt. Sale-process correspondence does NOT route via this skill.

---

## Override syntax

If the operator wants to override the default routing (e.g., go direct to client without AIMS), they should say explicitly:

> "Draft this direct to <customer-contact>, skip AIMS"

Without that explicit instruction, default to the routing map.

---

## Updates

This map gets stale. The AIMS team membership shifts. New customers come in. Refresh quarterly by:

1. Pull latest AIMS contacts from the audit's `customer_touch_2yr` data
2. Cross-check with operator (who's still active at AIMS, who's left)
3. Update the country-level + customer-level tables
4. Note the last-updated date below

**Last updated**: 2026-05-22 (from audit `audits/sre-2026-05-21/`)
