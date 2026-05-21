# Stage 2A — Outlook Mail Audit

**Purpose.** Reconstruct the customer + project relationship graph from email — because for SRE, email IS the CRM. This is the single highest-information stage in the whole audit.

**Pre-requisite.** Stage 1 complete; `client-config.yaml` defines naming conventions + in-scope mailboxes.

**Window.** 2 years (configurable). Adjust per mailbox if needed (e.g. shared mailbox might have shorter retention).

**Output.** Raw messages (metadata + body OR metadata-only depending on config), a sender/recipient graph, attachment inventory, mail-rules + folder activity inventory.

**Safety.** Email bodies are pulled ONLY for mailboxes listed in `in_scope_mailboxes_full`. For all other users, this stage is a no-op (their mail is read in stage 4–5 indirectly via attachments/chats only). Body content stays local; nothing leaves the audit run directory.

**Run time estimate.** 15–60 minutes depending on Maaz's mailbox depth. Mail is the dominant cost of the whole audit.

---

## 1. What we extract — and why each piece matters

| Extraction | Used by | Business question it answers |
|---|---|---|
| Sender + recipient list per message | Customer 360, Comms Heatmap | Who do we talk to, how often? |
| External domain frequency | Customer 360 | Who are our customers, ranked by communication volume? |
| Subject-line keyword classification | Sales Pipeline | Which threads are about a proposal? An invoice? AR follow-up? |
| Attachments — name, size, mimeType | Document Library, Sales Pipeline | Which threads contain a proposal PDF? An invoice? A drawing? |
| Thread density per external domain | Customer 360 | Is this customer hot, warm, cooling, ghosted? |
| Last inbound from each external domain | Customer 360 | When did they last reply? (Reply-rate is the strongest engagement signal.) |
| Mail folder placement | Cleanup Report | Is this customer in "Archive" / "Lost" / "Won" / a project folder? |
| Mail rules + their target folders | Cleanup Report | Are there dead rules pointing at unused folders? |
| Maaz's typical response time | Time Allocation, R3 | How fast does Maaz reply, by sender importance? |
| Out-of-hours emailing | Time Allocation, R4 | Are evenings/weekends being eaten by reactive email? |

---

## 2. Per-mailbox pull plan

For each mailbox in `client-config.yaml :: in_scope_mailboxes_full`:

### 2.1 Folder tree (cached from stage 1)

Use the folder tree to:
- Skip clearly-archive folders unless explicitly included (e.g. "Archive 2018", "Old", "Junk")
- Identify customer-specific folders (e.g. "Customers/Saudi Aramco") — these become a hint signal for stage-8 join

### 2.2 Folder-level metadata scan

For every active folder, capture totals only (no messages):
- `unreadItemCount`
- `totalItemCount`
- `wellKnownName` if any

This is one call per folder via `list-mail-folders`. Cheap; surfaces dead folders cheaply.

### 2.3 Message metadata pull (the big one)

Use `list-mail-folder-messages` per folder, OR for efficiency `list-mail-messages` across the whole mailbox with `receivedDateTime ge 2 years ago`. Default to the latter.

Request shape per page:
- `$select=id,subject,from,toRecipients,ccRecipients,bccRecipients,sender,receivedDateTime,sentDateTime,conversationId,hasAttachments,bodyPreview,importance,isRead,isDraft,parentFolderId,internetMessageId,categories,flag`
- `$top=100` (page size)
- `$filter=receivedDateTime ge 2024-05-22T00:00:00Z` (computed from window)
- Pagination via `@odata.nextLink`

**We pull METADATA + `bodyPreview` ONLY by default.** Full bodies are pulled lazily in stage 8/9 ONLY for messages classified as needing a body (proposals, AR replies, etc.) — saves 90%+ of bytes.

### 2.4 Attachment metadata pull

For every message with `hasAttachments=true`, call `list-mail-attachments`:
- `$select=id,name,contentType,size,isInline`
- Don't download bytes by default — only for classified-important attachments later.

### 2.5 Delta-link capture

After the initial pull, save the `@odata.deltaLink` from `list-mail-folder-messages-delta`. Future runs use it for incremental refresh.

### 2.6 Mail rules

`list-mail-rules` → save as-is. Used in the cleanup report.

### 2.7 Mailbox settings

Already pulled in stage 1; re-reference here. Working hours + timezone feed time-allocation.

---

## 3. Output JSON shape

```
raw/mail/<userId>/
├── folder-tree.json                # from stage 1 — copied for self-containment
├── folder-stats.json               # per-folder totalItemCount + unreadItemCount
├── messages-page-0001.json         # paginated raw
├── messages-page-0002.json
├── ...
├── messages-flat.json              # post-merge: every message, metadata only
├── attachments-flat.json           # per-message attachment metadata
├── delta-link.json                 # for incremental runs
├── mail-rules.json
└── conversations.json              # grouped by conversationId
```

`messages-flat.json` element schema:
```json
{
  "id": "AAMkA...",
  "internetMessageId": "<...@...>",
  "subject": "Proposal — Saudi Aramco — Train 4 SRU revamp",
  "conversationId": "AAQk...",
  "parentFolderId": "...",
  "parentFolderPath": "Inbox/Customers/Saudi Aramco",
  "from": { "name": "Mohammed Al-...", "address": "m.alxxxx@aramco.com" },
  "to": [{ "name": "Maaz Ahmed Shareef", "address": "maaz@sulfurrecovery.com" }],
  "cc": [],
  "receivedDateTime": "...",
  "sentDateTime": "...",
  "importance": "normal",
  "isRead": true,
  "isDraft": false,
  "hasAttachments": true,
  "bodyPreview": "Maaz, attached is...",
  "categories": ["NA", "Hot"],
  "flag": { "flagStatus": "notFlagged" },
  "direction": "inbound",
  "externalDomain": "aramco.com",
  "attachments": [
    { "id": "...", "name": "Proposal_Aramco_Train4_2026-05-20.pdf",
      "contentType": "application/pdf", "size": 4283910 }
  ]
}
```

Note `direction` + `externalDomain` are computed by the puller (not from Graph) using `client-config.yaml :: primary_domain`.

---

## 4. The stitched data layer

After raw pulls, the synthesizer writes `data/mail-analysis.json`:

```json
{
  "generatedAt": "...",
  "window": { "start": "2024-05-22", "end": "2026-05-22" },
  "totals": {
    "messages": 18420,
    "inbound": 8410,
    "outbound": 10010,
    "uniqueExternalDomains": 187,
    "uniqueExternalSenders": 412,
    "messagesWithAttachments": 3210,
    "attachmentsTotal": 4180
  },
  "domains": [
    {
      "domain": "aramco.com",
      "messages": 412,
      "inbound": 198,
      "outbound": 214,
      "firstSeen": "2024-09-12",
      "lastSeen": "2026-05-19",
      "lastInbound": "2026-05-19",
      "lastOutbound": "2026-05-19",
      "category": "hot",
      "subjects": [
        { "preview": "Proposal — Train 4 …", "lastSeen": "...", "msgCount": 14 },
        ...
      ],
      "people": [
        { "name": "Mohammed Al-...", "address": "...", "messages": 102 }
      ],
      "attachmentsByType": { "pdf": 14, "xlsx": 3, "docx": 5 },
      "folderPlacements": { "Inbox/Customers/Saudi Aramco": 380, "Inbox": 32 }
    },
    ...
  ],
  "people": [
    { "name": "...", "address": "...", "domain": "...", "messages": 102, "isInternal": false }
  ],
  "subjectClassifications": {
    "proposal": [ /* msgIds */ ],
    "invoice":  [ /* msgIds */ ],
    "ar_followup": [ /* msgIds */ ],
    "meeting_request": [ /* msgIds */ ],
    "nda": [ /* msgIds */ ],
    "rfp_rfq": [ /* msgIds */ ]
  },
  "responseTimes": {
    "median_inbound_to_first_reply_minutes": 142,
    "median_outbound_to_inbound_minutes": 240,
    "p90_inbound_to_first_reply_minutes": 2160
  },
  "outOfHours": {
    "messagesAfter20Local": 1840,
    "messagesBeforeWorkingHours": 980,
    "weekendMessages": 612
  },
  "folderActivity": [
    { "path": "Inbox/Customers/Saudi Aramco", "messages2yr": 412, "isActive": true },
    { "path": "Inbox/Old Projects/Acme 2019", "messages2yr": 0, "isActive": false }
  ],
  "deadRules": [
    { "id": "...", "displayName": "Move Acme → Archive", "lastTriggered": null,
      "targetFolderMessages2yr": 0 }
  ],
  "openQuestions": [
    "Domain 'gmail.com' has 240 inbound messages but no obvious customer mapping — flag as personal or unclassified?",
    "12 messages with subject 'INV-####' but no attachment — possible AR follow-ups without attached invoice?"
  ]
}
```

---

## 5. Subject classifier

The classifier runs as a Python regex pass over every message subject + bodyPreview. Patterns come from `client-config.yaml :: naming_conventions`. Default starter patterns:

```python
PROPOSAL    = re.compile(r'\b(proposal|quote|quotation|bid)\b', re.I)
INVOICE     = re.compile(r'\b(invoice|inv[\s\-]?\d{3,}|billing|payment\s+request)\b', re.I)
AR_FOLLOWUP = re.compile(r'\b(overdue|payment\s+(reminder|status)|past\s+due|aging|outstanding)\b', re.I)
NDA         = re.compile(r'\b(nda|non[\s\-]?disclosure|confidentiality\s+agreement)\b', re.I)
RFP_RFQ     = re.compile(r'\b(rfp|rfq|request\s+for\s+(proposal|quotation|information)|tender)\b', re.I)
MEETING_REQ = re.compile(r'\b(can we (meet|schedule|set up)|available (next|this)|meeting\s+request)\b', re.I)
WON_LOST    = re.compile(r'\b(awarded|congratulat|we have selected|we\'ve chosen|we have decided|regret|not selected|other vendor)\b', re.I)
```

**These should be tuned per-client** during stage 0. Operator review of the classifier output is a hard checkpoint.

---

## 6. Findings the stage surfaces (heuristics)

Each appears in `data/mail-analysis.json :: findings` and rolls up into stage-10's Cleanup dashboard:

| Severity | Finding | How detected |
|---|---|---|
| HIGH | External domains with 10+ outbound + 0 inbound in 90d | Likely "we keep reaching out, they don't reply" |
| HIGH | Proposal threads >30d old with no follow-up outbound | Open deal gone quiet |
| HIGH | Invoice threads >60d with no inbound "paid" reply | Open AR |
| MED | Folders with 0 messages in 2yr but referenced by an active rule | Dead-rule / dead-folder pair |
| MED | Same proposal attachment name reused across customers | Template reuse — flag for the document inventory |
| MED | Internal-only email pairs eating >2h/week | Hidden meeting candidate |
| LOW | Senders the operator never replies to but who message regularly | Newsletter / noise candidates |
| LOW | Categories used <3 times in 2yr | Dead category list |

---

## 7. Failure + edge cases

| Case | Handling |
|---|---|
| Token only has `Mail.Read` not `Mail.Read.Shared` | Skip shared mailboxes; note in `openQuestions` |
| `400 Bad Request` on `$filter` | Use ISO-8601 with `Z` suffix exactly; Graph rejects timezone-naive strings |
| `$search` + `$filter` together | Forbidden by Graph. Use one or the other per call; if both needed, post-filter in Python |
| Some messages return as `eventMessage` (calendar invites) | Tag with `messageClass="invite"` so they don't pollute the deal-classifier |
| Very long bodyPreview cuts off | Acceptable — we don't classify on full body in this stage |
| Attachments >150MB | Skip download; record metadata only |

---

## 8. Acceptance criteria

- [ ] Every in-scope mailbox has `messages-flat.json` covering the configured window
- [ ] `attachments-flat.json` complete (metadata, NOT bytes)
- [ ] `mail-analysis.json` written; totals tally with raw counts
- [ ] Subject classifier results spot-checked against 10 known-true examples Maaz provides
- [ ] Response-time medians are sane (i.e. not 0, not infinity)
- [ ] `delta-link.json` saved for incremental future runs
- [ ] No body bytes downloaded except where explicit opt-in flag was set
- [ ] Open questions resolved or documented
