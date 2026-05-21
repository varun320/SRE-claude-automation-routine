# Stage 2C — Outlook Contacts + People Audit

**Purpose.** Capture the **explicit** Rolodex (Outlook contacts) AND the **implicit** people graph that Graph already infers (`relevant-people`, `trending-insights`). Then reconcile against the senders/attendees graph from stages 2A + 2B.

**Pre-requisite.** Stage 1 complete; stages 2A + 2B run for richest reconciliation.

**Output.** A unified people table: every external person we've corresponded with, in any form, with everything we know about them.

**Safety.** Contact records may include personal phone numbers + addresses. Standard read-only metadata rules apply.

**Run time.** <5 minutes — contact lists are small.

---

## 1. Why this stage matters

Most companies have a **massive blind spot**: the explicit Outlook Contacts list is often 5–10× SMALLER than the implicit "people you actually talk to" graph. SRE will be no different. This stage surfaces:
- Who's in Maaz's Rolodex AND active → known good
- Who's in the Rolodex but NOT active → dormant contacts (cleanup candidate, possibly re-engagement)
- Who's active but NOT in the Rolodex → the long tail of customers/prospects who never got formally captured

For the Customer 360 stitch, **the implicit graph is the source of truth** — contacts are just a quality-of-life enrichment for names + phone numbers.

---

## 2. What we pull

### 2.1 Outlook Contacts

| Pull | MCP tool | Notes |
|---|---|---|
| Contact folders | `list-contact-folders` (cached from stage 1) | Top-level + child folders via `create-contact-child-folder` listing |
| Child folders | `list-contact-folder-child-folders` | If nested |
| Contacts per folder | `list-contact-folder-contacts` paginated | Or `list-outlook-contacts` for the default folder |
| Per-contact detail | `get-outlook-contact` | Only for contacts where the list-call response is truncated |

Capture `$select=id,displayName,givenName,surname,companyName,jobTitle,emailAddresses,businessPhones,mobilePhone,businessAddress,categories,createdDateTime,lastModifiedDateTime`.

### 2.2 Relevant people (implicit graph)

Graph already maintains a "relevant people" ranking based on Maaz's communication patterns. Pull it:
- `list-relevant-people` — top ~50 people across mail + meetings + chats

The response includes a `relevanceScore` field — capture for ranking later.

### 2.3 Trending insights

- `list-trending-insights` — files Maaz is co-collaborating on with various people; informative for the customer 360 doc inventory.

### 2.4 Categories on contacts

Whatever color/text categories Maaz uses ("VIP", "Customer", "Prospect", "Vendor") get captured per contact. Stage 8 uses these as a hint signal.

---

## 3. Output JSON shape

```
raw/contacts/<userId>/
├── contact-folders.json
├── contacts-flat.json            # every contact across every folder
├── relevant-people.json
└── trending-insights.json
```

`contacts-flat.json` element schema (canonical):
```json
{
  "id": "...",
  "displayName": "...",
  "givenName": "...",
  "surname": "...",
  "companyName": "...",
  "jobTitle": "...",
  "emails": [{ "address": "...", "name": "..." }],
  "phones": { "business": ["..."], "mobile": "..." },
  "businessAddress": { "street": "...", "city": "...", "country": "..." },
  "categories": ["Customer", "NA"],
  "folderPath": "Contacts/Customers",
  "createdDateTime": "...",
  "lastModifiedDateTime": "...",
  "primaryDomain": "aramco.com"
}
```

---

## 4. Stitched data — `data/people-analysis.json`

```json
{
  "generatedAt": "...",
  "totals": {
    "outlookContacts": 314,
    "relevantPeopleReturned": 50,
    "uniquePeopleAcrossAllSources": 412,
    "contactsInRolodex": 314,
    "contactsActive2yr": 218,
    "contactsDormant2yr": 96,
    "activeButNotInRolodex": 194
  },
  "people": [
    {
      "address": "m.alxxxx@aramco.com",
      "domain": "aramco.com",
      "displayName": "Mohammed Al-…",
      "companyName": "Saudi Aramco",
      "jobTitle": "Senior Process Engineer",
      "phones": { "mobile": "+966…" },
      "categories": ["Customer", "NA"],
      "sources": {
        "outlookContact": true,
        "relevantPeople": true,
        "mailSenders2yr": 102,
        "mailRecipients2yr": 98,
        "meetingAttendee2yr": 14
      },
      "lastSeen": "2026-05-19",
      "relevanceScore": 0.94,
      "isInternal": false,
      "isInRolodex": true,
      "isActive": true,
      "stalenessDays": 3
    }
  ],
  "dormantInRolodex": [
    { "address": "...", "displayName": "...", "lastSeen": "2022-08-04", "daysSinceLastSeen": 1380,
      "categories": ["Vendor"], "recommendation": "archive" }
  ],
  "activeNotInRolodex": [
    { "address": "...", "domain": "...", "messages2yr": 28, "meetings2yr": 4,
      "recommendation": "add to contacts; categorize as Prospect" }
  ],
  "findings": [
    { "severity": "med", "title": "194 active correspondents not in Outlook Contacts",
      "items": [ /* top-30 sample */ ] },
    { "severity": "low", "title": "96 contacts dormant 2+ years", "items": [ /* sample */ ] },
    { "severity": "low", "title": "12 contacts have no companyName set", "items": [...] },
    { "severity": "low", "title": "8 contact pairs with same name + different email (possible dup)", "items": [...] }
  ]
}
```

---

## 5. Reconciliation logic (the heart of the stage)

For each person we encounter across any source:
1. **Key by lowercased primary email.** If a person has multiple emails (work + personal), all keys point to the same canonical record.
2. **Sources tracked**: `outlookContact`, `relevantPeople`, `mailSenders2yr`, `mailRecipients2yr`, `meetingAttendee2yr`, `teamsChatMember`, `sharepointEditor`.
3. **`isActive`** = appears in any source within the configured window.
4. **`isInRolodex`** = present in `outlookContacts`.
5. **`stalenessDays`** = days since `lastSeen` across ALL sources.
6. **Companies inferred from domain** when `companyName` empty in Outlook (e.g. `@aramco.com` → "Saudi Aramco").
7. **Internal flag** from `client-config.yaml :: primary_domain` membership.

---

## 6. Findings + heuristics

| Severity | Finding |
|---|---|
| HIGH | Active high-volume correspondent (>20 msgs in 90d) with NO Outlook contact and no name in any other source — likely a noisy alias or a contact Maaz needs to add |
| MED | Rolodex contact dormant 2+ years — propose archive (don't auto-delete) |
| MED | Customers with multiple inactive contacts (e.g. old champions who left) and no active contact — re-engagement risk |
| LOW | Contact pairs with same display name but different email — possible duplicates |
| LOW | Contact with no `companyName` AND no inferable domain — orphan record |
| LOW | Categories used in contacts that don't appear in `client-config.yaml :: known taxonomies` — flag for taxonomy alignment |

---

## 7. Acceptance criteria

- [ ] Every contact folder enumerated
- [ ] `contacts-flat.json` matches Outlook's contact count
- [ ] `relevant-people.json` + `trending-insights.json` saved
- [ ] `people-analysis.json` reconciles: count of `activeNotInRolodex` + count of `contactsActive2yr` ≤ `uniquePeopleAcrossAllSources`
- [ ] Spot-check 5 known people: classification (customer/prospect/internal/vendor) is correct
- [ ] Domain → companyName inference accurate for the top-20 customers
- [ ] Output usable as the people-side input to stage 8 customer-360 join
