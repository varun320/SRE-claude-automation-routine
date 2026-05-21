# Stage 5 — Microsoft Teams Audit

**Purpose.** Pull every Teams surface the operator participates in — joined teams, channels, channel messages, 1:1 + group chats, online meetings, and (where available) meeting recordings + transcripts. The transcripts in particular unlock the **single highest-value content type in the whole audit**: the actual words spoken on sales calls, technical reviews, and AIMS sessions.

**Pre-requisite.** Stage 1 complete; teams + channels + chat IDs enumerated.

**Output.** Raw channel + chat message bodies, online-meeting record cross-linked to calendar events, transcripts saved as plain text for stage-8/9 classification.

**Safety.** Chats and channel messages can contain confidential commentary (pricing decisions, personnel issues). Same rule as mail: stays local, no upload. Transcripts are particularly sensitive — flag in the dashboard, gate body display behind an explicit reveal click.

**Run time.** 10–40 minutes; the recording/transcript downloads are the dominant cost.

---

## 1. What we extract — and why each piece matters

| Extraction | Used by | Business question |
|---|---|---|
| Channel messages (text) | Customer 360, Sales Pipeline | Real-time deal conversations the org has on accounts |
| Channel messages (file attachments) | Document Library | Proposals/drawings dropped in chat, not in SharePoint |
| 1:1 chat messages | Comms graph, Customer 360 | Maaz ↔ Ashley/Ron commentary on specific customers |
| Group chat membership | Customer 360 | "AIMS deal" group chat → all members linked to the deal |
| Online-meeting records | Calendar cross-link | Tie scheduled meetings to actual recorded calls |
| Meeting recordings | (link only) | Reference for future stage that may transcribe externally |
| Meeting transcripts | Sales Pipeline, R3 / R10 / R20 | Stage classification + decision capture from real spoken content |
| Meeting attendance records | Time Allocation | Who actually showed vs RSVPed |
| Pinned chat messages | Comms hygiene | Probably the canonical "where the team lives" surface |

---

## 2. Teams structure

```
Tenant
├── Teams (joined by operator)
│   └── Channels (Standard | Private | Shared)
│       └── Messages
│           └── Replies
│       └── Files folder (mirrors SharePoint document library)
│       └── Tabs (apps pinned to channel)
├── Chats (1:1 and group; not part of any Team)
│   └── Messages
│       └── Hosted contents (images, etc.)
└── Online Meetings (with optional recording + transcript)
    └── Attendance reports
    └── Recording (binary)
    └── Transcript (VTT or plain)
```

---

## 3. Per-team pull plan

For each team enumerated in stage 1:

### 3.1 Team metadata
- `get-team` — name, description, visibility, members, createdDateTime

### 3.2 Channels
- `list-team-channels` — already cached from stage 1; re-validate
- For each channel:
  - `get-team-channel` — full metadata
  - `list-channel-tabs` — record tabs (Planner, Wiki, custom apps) for hygiene insight
  - `get-channel-files-folder` — reference to the channel's SharePoint folder; cross-link to stage 3

### 3.3 Channel messages (the big pull)

For each channel:
- `list-channel-messages` paginated (`$top=50`)
- For each message with `replyCount > 0`, also fetch `list-channel-message-replies`

Capture per message:
- `id, etag, from, createdDateTime, lastModifiedDateTime, body.content, body.contentType, importance, attachments, mentions, reactions, channelIdentity, eventDetail`
- Strip HTML to plain text for body classification, keep raw HTML for dashboard render
- `attachments` are file refs into SharePoint — record the path for cross-link

---

## 4. Chats pull plan

`list-chats` already gave us chat IDs in stage 1. For each chat:

### 4.1 Chat metadata
- `get-chat` — topic (if any), members, chatType (oneOnOne | group | meeting), lastUpdatedDateTime

### 4.2 Members
- `list-chat-members` — for groupchats, the member list is itself a customer-360 signal (e.g. an external email in the chat → customer link)

### 4.3 Messages
- `list-chat-messages` paginated
- `list-pinned-chat-messages` for the chat — pins often == canonical references
- For messages with replies: `list-chat-message-replies`
- For meeting-chat messages, the chat is auto-created by the calendar invite and contains call commentary — cross-link to the online meeting + calendar event

---

## 5. Online meetings + recordings + transcripts

### 5.1 Meeting list
- `list-online-meetings` paginated. Each meeting has a `joinUrl` we cross-link to the calendar events from stage 2B.

### 5.2 Per-meeting
- `get-online-meeting` — full record
- `get-meeting-attendance-report` + `list-meeting-attendance-records` — who actually attended, for how long
- `list-meeting-recordings` — recording metadata (URL, durationSeconds)
- `list-meeting-transcripts` — transcript metadata

### 5.3 Transcripts (the high-value content)
- `get-meeting-transcript-content` per transcript → save as `transcripts-<meetingId>.txt`

These are the **highest-leverage artifacts in the audit**:
- For sales calls: stage 9 classifies pricing discussions, decision moments, objection language
- For technical reviews: extract decisions + action items for the Project Tracker
- For AIMS bi-weekly: capture commitments to the bookkeeper + AR follow-ups

### 5.4 Recordings
- We only capture metadata (URL, size, duration). Bytes are NOT downloaded by default — they're huge, and the transcript captures the substance. Operator can opt-in per meeting via `download-bytes` against the recording URL.

---

## 6. Output JSON shape

```
raw/teams/
├── teams-joined.json                    # (cached from stage 1)
├── team-<teamId>.json                   # team metadata
├── channels-<teamId>.json
├── channel-<channelId>-tabs.json
├── channel-<channelId>-messages.json    # paginated merge
├── channel-<channelId>-replies.json     # keyed by parentMessageId

raw/chats/
├── chats-summary.json                   # cached from stage 1
├── chat-<chatId>-metadata.json
├── chat-<chatId>-members.json
├── chat-<chatId>-messages.json
├── chat-<chatId>-pinned.json
└── chat-<chatId>-replies.json

raw/meetings/
├── online-meetings.json                 # all known online meetings
├── meeting-<meetingId>.json
├── attendance-<meetingId>.json
├── recordings-<meetingId>.json          # metadata only by default
└── transcripts-<meetingId>.txt          # body, if available
```

Element schemas (representative):

**Channel message:**
```json
{
  "id": "175...",
  "channelId": "19:...",
  "teamId": "...",
  "from": { "user": { "displayName": "Ashley", "id": "..." } },
  "createdDateTime": "...",
  "body": { "contentType": "html", "content": "..." },
  "bodyPlainText": "Ashley says: 'Aramco came back with...'",
  "mentions": [{ "id": 0, "displayName": "Maaz", "userId": "..." }],
  "attachments": [
    { "id": "...", "contentType": "reference",
      "contentUrl": "https://...sharepoint.com/...Proposal_Aramco_v4.pdf",
      "name": "Proposal_Aramco_v4.pdf" }
  ],
  "reactions": [{ "reactionType": "like", "user": "...", "createdDateTime": "..." }],
  "replyCount": 4,
  "externalParticipants": []
}
```

**Online meeting:**
```json
{
  "id": "...",
  "joinUrl": "https://teams.microsoft.com/...",
  "joinWebUrl": "...",
  "subject": "AIMS bi-weekly",
  "startDateTime": "...",
  "endDateTime": "...",
  "organizer": { ... },
  "participants": [...],
  "calendarEventId": "matched via joinUrl",
  "hasRecording": true,
  "hasTranscript": true,
  "transcriptPath": "raw/meetings/transcripts-<id>.txt",
  "recordingUrl": "https://...graph...",
  "attendanceRecorded": true,
  "totalAttendees": 5,
  "totalDurationMinutes": 42
}
```

---

## 7. Stitched data — `data/teams-analysis.json`

```json
{
  "generatedAt": "...",
  "totals": {
    "teamsJoined": 3,
    "channels": 18,
    "channelMessages2yr": 4820,
    "chats": 47,
    "chatMessages2yr": 7180,
    "onlineMeetings2yr": 412,
    "meetingsWithTranscript": 218,
    "meetingsWithRecording": 240
  },
  "channelActivity": [
    { "channelId": "...", "teamName": "SRE Operations", "channelName": "General",
      "messages2yr": 1240, "lastMessage": "2026-05-19", "isActive": true,
      "topPosters": [ { "name": "Maaz", "count": 480 } ] }
  ],
  "chatActivity": [
    { "chatId": "...", "chatType": "oneOnOne", "partner": "Ashley",
      "messages2yr": 1280, "lastMessage": "...", "isActive": true }
  ],
  "externalParticipantsInChats": [
    { "chatId": "...", "partner": "m.alxxxx@aramco.com", "messages": 84,
      "linkedCustomerDomain": "aramco.com" }
  ],
  "meetings": {
    "byCustomer": [
      { "customerDomain": "aramco.com", "meetings": 14,
        "totalMinutes": 540, "transcriptsAvailable": 9 }
    ],
    "withoutTranscript": [ /* meetingIds */ ],
    "shortMeetings": [ /* <10min — sometimes accidental */ ],
    "longMeetings": [ /* >2h — review for split */ ]
  },
  "documentDropsInChat": [
    { "chatId": "...", "fileName": "Proposal_Aramco_v4.pdf",
      "sharepointPath": "...", "alreadyInDocInventory": true }
  ],
  "findings": [
    { "severity": "high", "title": "18 sales-call meetings with no transcript captured", "items": [...] },
    { "severity": "med",  "title": "4 channels with 0 messages in 6 months", "items": [...] },
    { "severity": "med",  "title": "23 docs dropped in chat that don't exist in the SharePoint Proposals library", "items": [...] },
    { "severity": "low",  "title": "2 chats with deleted external users (orphan chats)", "items": [...] }
  ]
}
```

---

## 8. Findings + heuristics

| Severity | Finding |
|---|---|
| HIGH | Sales/technical-review meeting with no transcript (data loss for stage 9) |
| HIGH | Channel with active external members in a deal not on the CRM list |
| MED | Channel dormant 6m+, recommend archive |
| MED | Chat with deleted user (orphan) |
| MED | Document dropped only in chat, never landed in SharePoint Proposals library — risk of being lost |
| LOW | Pinned message older than 1y — likely stale pin |
| LOW | Meeting recording with 0 attendance recorded — likely no-show |

---

## 9. Pagination + parallelism

| Endpoint | Parallelism | Notes |
|---|---|---|
| `list-channel-messages` | 1 stream per channel; 4 channels parallel | Heavy channels go slow |
| `list-channel-message-replies` | 4 parallel per parent batch | Only when `replyCount>0` |
| `list-chat-messages` | 1 stream per chat; 6 chats parallel | |
| `list-online-meetings` | 1 stream | Date-paginated |
| `get-meeting-transcript-content` | 4 parallel | Plain text save |
| `list-meeting-recordings` | 4 parallel | Metadata only |

---

## 10. Failure modes

| Case | Handling |
|---|---|
| Token lacks `Chat.Read` | Skip chats; channel pull still works |
| Token lacks `OnlineMeetings.Read` | Skip meeting metadata; channel + chat still work |
| Token lacks `OnlineMeetingTranscript.Read.All` | Transcripts unavailable — surface as a HIGH-severity gap |
| Tenant has not enabled transcripts | All meetings show `hasTranscript=false`; surface as policy info |
| Message body is `<systemEventMessage>` (user added/removed) | Tag and skip from classification |
| Very large channels with 10k+ messages | Use date-window pagination |
| Hosted-content references in chat (inline images) | Skip body download; record URL only |

---

## 11. Cross-references this stage creates

- Channel/chat `attachments` → SharePoint library cross-link → stage 3
- Online meeting `joinUrl` → calendar event → stage 2B
- Chat members → customer 360 join key → stage 8
- Transcripts → sales pipeline classifier → stage 9

---

## 12. Acceptance criteria

- [ ] Every joined team's channels enumerated and messages pulled
- [ ] Every chat enumerated; for in-scope chats, messages pulled
- [ ] Online meetings cross-linked to calendar events (≥80% match rate; remainder flagged)
- [ ] Available transcripts saved as `.txt`
- [ ] No recording bytes downloaded unless explicit opt-in
- [ ] Findings reviewed; HIGH-severity transcript gaps logged for follow-up
- [ ] No body bytes uploaded externally
