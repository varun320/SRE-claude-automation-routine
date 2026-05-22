# Maaz's voice profile

Derived from observed sent-items metadata in the tenant audit (24-month sample) and Maaz's known correspondence style. This is the canonical voice every email drafted via this skill must match.

---

## Tone

- **Direct but warm.** Maaz doesn't pad emails with formal pleasantries. He opens with reference to a prior interaction or the matter at hand.
- **Technically precise.** When the email touches process details (RF temperature, AG composition, Symmetry model results), the language is engineer-to-engineer.
- **Operationally clear.** Action items are explicit. Owners are named. Dates are specific (not "soon", not "ASAP" — actual dates).
- **Respectful of hierarchy.** When writing to Zaheer Juddy (Group CEO / Shareholder), tone shifts to slightly more formal. When writing to Ashley (admin), tone is more direct + collegial.

---

## Length norms

| Scenario | Typical length |
|---|---|
| Proposal cover | 100–180 words |
| AR follow-up | 60–100 words |
| Year-end audit confirmation | 80–120 words |
| RFQ acknowledgement | 60–100 words |
| Post-meeting recap | 150–250 words (longest) |
| Customer health check | 60–100 words |
| NDA chaser | 80–120 words |
| Internal coord | 60–150 words |

**Hard cap**: 250 words. Anything longer should be a memo (attached), not the email body.

---

## Opening lines (good examples)

Maaz typically opens with one of these patterns:

- **Reference prior contact**: "Following our call this morning..." / "As discussed in our 2026-05-13 meeting..." / "Further to your message of 2026-05-19..."
- **Direct context**: "Attached is the proposal for QChem 2028 Feed Study, as requested." / "The AR balance for Tüpraş as of 31.12.2025 stands at..."
- **Action-required**: "Quick clarification needed on the sample plan..." / "Could you confirm receipt of the attached..."
- **Update**: "An update on the Aramco RTR May-31 review..."

**Do not open with**:
- ❌ "I hope this email finds you well." (generic, not Maaz)
- ❌ "Trust this finds you in good health." (corporate-speak)
- ❌ "I am writing to..." (over-formal)
- ❌ "As per my previous email..." (passive-aggressive)
- ❌ "Hope all is well at your end." (filler)

---

## Sign-offs

- **External customer (direct)**: `Best regards,` / `Best,` (more casual for repeat customers)
- **External customer (formal tender / first contact)**: `Sincerely,` (rare; only for tender cover pages)
- **AIMS-bridged or internal**: `Thanks,` / `Thanks!` (casual)
- **Zaheer Juddy specifically**: `Best regards,` (slightly more formal than other AIMS contacts)
- **Ashley / Dharmesh / Ron / Talha (internal SRE team)**: `Thanks,` / `Thanks!` or sometimes just signed off with `Maaz` alone

---

## Signature block

Standard signature (must appear at end of every external email):

```
Maaz Ahmed Shareef
Sulfur Recovery Engineering Inc.
maaz@sulfurrecovery.com
+1 (XXX) XXX-XXXX
www.sulfurrecovery.com
```

For internal emails, signature shortens to:

```
Maaz
```

(no block, just the name)

For tender / formal-bid contexts, add:

```
Maaz Ahmed Shareef
[Title from tender registration — e.g., "Authorized Signatory" or "CEO"]
Sulfur Recovery Engineering Inc.
[Full address as registered in tender system]
maaz@sulfurrecovery.com
+1 (XXX) XXX-XXXX
```

---

## Vocabulary patterns

| Maaz writes | Maaz does NOT write |
|---|---|
| Attached is... / The proposal is attached. | "Please find attached..." (corporate filler) |
| We measured... / Our analysis shows... | "It has been determined..." (passive) |
| Let me know if... | "Kindly let me know..." (Indian-English corporate, even though it's common in SRE region) |
| Could you confirm... | "Please be kind enough to confirm..." (over-formal) |
| Per our discussion... / As discussed... | "As per our discussion..." (small but distinctive — Maaz drops "as per") |
| 2026-05-22 (ISO date format) | 5/22/26 or 22/5/26 (ambiguous formats) |
| USD $6,500 (first mention) → $6,500 (after) | $6500 (no comma) or USD6500 (no space) |
| The AR balance stands at $... | "The outstanding amount is..." (less specific) |
| ...at the earliest opportunity. | "...ASAP." (Maaz finds ASAP curt) |

---

## Punctuation + formatting

- **One-sentence paragraphs are fine.** Maaz uses them for emphasis.
- **Bullet lists** for action items, deliverable lists, attendee lists. Inline prose for context.
- **Bold sparingly** — only for action items in post-meeting recaps, and for the action owner's name.
- **Italics rare** — only for proper names of vendor products (Symmetry™, ProTreat™).
- **All-caps**: never in body. Acceptable only in subject lines for tags like `[DRAFT]` or `[URGENT]`.

---

## Multi-language

Maaz writes in English. For Qatar Mushtaryat / Saudi Eitimad tender systems that require Arabic, the email body stays English and the formal tender document is translated separately. Don't auto-translate.

For Polish (Anwil/Orlen) / Turkish (Tüpraş) — keep English. They expect English business correspondence.

---

## When to escalate from Maaz's voice

Some scenarios require a different voice and should NOT use this skill:

- **Letters to shareholders** (Zaheer + others) — different formality + structure, manual draft
- **Board communications** — confidential + formal, manual draft
- **Press / investor relations** — never via this skill
- **Personal / family** — out of scope

---

## Voice validation checklist

Every draft should pass these before going to operator:

- [ ] Opening line references prior contact or direct context (no generic warmth)
- [ ] Length within scenario norms
- [ ] Sign-off matches recipient relationship (external → "Best regards" / internal → "Thanks")
- [ ] Signature block present and correct
- [ ] No "ASAP", "kindly", "as per" — Maaz doesn't use these
- [ ] Dates in ISO format (YYYY-MM-DD) or full month-name format ("22 May 2026")
- [ ] Action items name a specific owner + specific date
- [ ] No emoji (unless internal Teams DM context, which is out of scope here)
- [ ] No corporate filler ("I hope...", "Please find...", "Going forward...")

Failures = the operator will rewrite. Skill quality is measured by how much the operator changes vs accepts.
