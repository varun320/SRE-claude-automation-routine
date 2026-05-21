# Stage 2B — Outlook Calendar Audit

**Purpose.** Capture every meeting in the configured window across all in-scope calendars; produce a per-customer time-allocation view; flag time leaks against the Weekly OS.

**Pre-requisite.** Stage 1 complete; calendars enumerated.

**Window.** 2 years backward + 6 months forward (configurable). The forward window matters — we need to see scheduled meetings to project time-allocation for routines R2 / R8.

**Output.** Raw events JSON, a synthesized time-allocation matrix, recurring-meeting detection, attendees graph for join-back to mail/Teams.

**Safety.** Calendar bodies (event descriptions) are often boring but occasionally contain confidential info (proposal numbers, financials). Treat same as mail bodies: metadata + bodyPreview default; full body opt-in.

**Run time.** 2–10 minutes.

---

## 1. What we extract — and why each piece matters

| Extraction | Used by | Business question |
|---|---|---|
| Event subject + start/end | Time Allocation, R2, R8 | Where is time literally going? |
| Attendees list | Customer 360, Comms graph | Who am I meeting with, how often? |
| `categories` field | Sales Pipeline | Maaz already uses categories — leverage them as stage tags |
| Recurring meeting series | Cleanup, Time Allocation | What's recurring vs ad-hoc? Recurrence pattern = standing cadence |
| Body preview | Sales Pipeline | "Pre-bid call", "Technical review", etc. |
| Location | Comms graph | Office / customer site / Teams / Zoom |
| Online meeting URL | Stage 5 Teams cross-link | Tie a calendar event to the Teams meeting record |
| Free/busy + showAs | Time Allocation | Time blocked but free = focus time |
| Reminders + responses | (later) | Did I actually attend? Did they accept? |

---

## 2. Per-calendar pull plan

For each calendar enumerated in stage 1 (Maaz's primary + any shared/team calendars in scope):

### 2.1 Calendar metadata

Cached from stage 1 — calendar ID, name, owner, color, time zone, can-edit/view permissions.

### 2.2 Event list (the big pull)

Use `get-calendar-view` over the configured range. This is the right endpoint — it expands recurrence into individual instances within the range, which is what we want for time-allocation math.

Request shape:
- `startDateTime=2024-05-22T00:00:00`
- `endDateTime=2026-11-22T00:00:00`
- `$select=id,subject,start,end,attendees,location,categories,bodyPreview,organizer,isCancelled,isOrganizer,isAllDay,showAs,sensitivity,onlineMeeting,onlineMeetingProvider,recurrence,seriesMasterId,type,iCalUId`
- `$top=100`
- Pagination via `@odata.nextLink`

`Prefer: outlook.timezone="America/Edmonton"` header for consistent local time.

### 2.3 Series master + recurrence pattern

For each instance where `seriesMasterId` is set, ALSO fetch the series master once via `get-specific-calendar-event`. Cache by `seriesMasterId` to avoid duplicate calls. Recurrence pattern (weekly Mon 14:05, etc.) gets stored in `data/calendar-analysis.json :: recurringSeries`.

### 2.4 Delta link

`list-calendar-view-delta` captures the delta token for incremental future runs.

### 2.5 Cross-link to online meetings

For events with `onlineMeeting.joinUrl`, parse the URL and try to match it to the records pulled in stage 5 (`list-online-meetings`). Provides the bridge to recordings + transcripts.

### 2.6 Attendees normalization

Attendees come with `{ type: "required|optional|resource", status, emailAddress: { name, address } }`. Normalize:
- Tag `isInternal` based on `client-config.yaml :: primary_domain`
- Tag `domain` for external attendees → join key for customer-360
- Tag `responseStatus` (accepted / declined / tentative / no-response)

---

## 3. Output JSON shape

```
raw/calendar/<userId>/
├── calendars.json              # one entry per calendar
├── events-<calId>-page-001.json
├── events-<calId>-page-002.json
├── ...
├── events-flat.json            # post-merge — all events across all calendars
├── series-masters.json         # keyed by seriesMasterId
└── delta-link.json
```

`events-flat.json` element schema:
```json
{
  "id": "...",
  "iCalUId": "...",
  "calendarId": "...",
  "calendarName": "Calendar",
  "subject": "Ashley NA — weekly 1:1",
  "bodyPreview": "...",
  "start": { "dateTime": "2026-05-19T14:05:00", "timeZone": "America/Edmonton" },
  "end":   { "dateTime": "2026-05-19T14:30:00", "timeZone": "America/Edmonton" },
  "durationMinutes": 25,
  "isAllDay": false,
  "isCancelled": false,
  "isOrganizer": true,
  "showAs": "busy",
  "sensitivity": "normal",
  "location": { "displayName": "Teams" },
  "onlineMeeting": { "joinUrl": "https://teams.microsoft.com/..." },
  "categories": ["NA", "Internal"],
  "organizer": { "name": "Maaz ...", "address": "maaz@..." },
  "attendees": [
    { "name": "Ashley ...", "address": "ashley@sulfurrecovery.com",
      "type": "required", "responseStatus": "accepted",
      "isInternal": true, "domain": "sulfurrecovery.com" }
  ],
  "seriesMasterId": "...",
  "recurrencePattern": { "type": "weekly", "interval": 1, "daysOfWeek": ["monday"] },
  "externalDomains": [],
  "internalAttendees": ["ashley@sulfurrecovery.com"],
  "classification": "internal_recurring_1_1"
}
```

`classification` is computed by the puller and is one of:
- `internal_recurring_1_1`
- `internal_recurring_group`
- `customer_meeting`
- `prospect_meeting`
- `sales_call`
- `technical_review`
- `internal_focus_block` (event with 0 attendees, marked busy)
- `personal_block` (sensitivity=private or category=personal)
- `out_of_office`
- `unknown`

The classifier uses subject regex + attendee composition + category. Patterns come from `client-config.yaml`.

---

## 4. The stitched data layer — `data/calendar-analysis.json`

```json
{
  "generatedAt": "...",
  "window": { "start": "2024-05-22", "end": "2026-11-22" },
  "totals": {
    "events": 1840,
    "uniqueExternalDomains": 92,
    "uniqueAttendees": 311,
    "hoursTotal": 980,
    "hoursInternal": 410,
    "hoursCustomer": 380,
    "hoursFocus": 110,
    "hoursOther": 80
  },
  "timeAllocation": {
    "byCustomer": [
      { "domain": "aramco.com", "hours": 41.5, "meetings": 23, "lastMet": "2026-05-19" },
      ...
    ],
    "byCategory": {
      "internal_recurring_1_1": 102,
      "customer_meeting": 380,
      "internal_focus_block": 110,
      ...
    },
    "byDayOfWeek": { "Mon": 230, "Tue": 180, ..., "Sun": 4 },
    "byHourLocal": { "06": 0, "07": 2, "08": 14, "09": 0, ..., "14": 180, ..., "23": 22 }
  },
  "recurringSeries": [
    { "id": "...", "subject": "Ashley NA — weekly 1:1", "pattern": "weekly Mon 14:05",
      "instances2yr": 84, "lastInstance": "2026-05-19", "nextInstance": "2026-05-26" }
  ],
  "outOfHours": {
    "afterDinnerEvents": 62,           // 19:00–22:00 local
    "lateNightEvents": 18,             // 22:00+
    "weekendEvents": 34
  },
  "findings": [
    { "severity": "med", "title": "9 cancelled meetings with Saudi Aramco in 60d", "evidence": [...] },
    { "severity": "med", "title": "12 standing 1:1s with Ashley, none in last 14d", "evidence": [...] },
    { "severity": "low", "title": "3 recurring meetings have 0 attendees besides Maaz — likely dead recurrences", "evidence": [...] }
  ]
}
```

---

## 5. Heuristic findings

| Severity | Finding | Detection |
|---|---|---|
| HIGH | Customer has 0 meetings in 90d but had >3 meetings in the prior 90d | Cooling signal |
| HIGH | Customer with proposal-class email but no meeting scheduled within 14d | Deal at risk of going cold |
| MED | Recurring meeting where >50% of last 8 instances were cancelled | Dead recurrence — propose deleting |
| MED | Internal recurring 1:1 broken for 30d+ | Cadence slip |
| MED | Maaz double-booked > X times | Calendar hygiene |
| LOW | Customer meeting without an online-meeting link in last 12mo | Offline-only customer; transcript not available |
| LOW | Meeting subject is the customer name only with no agenda | Subject-line hygiene |

---

## 6. Cross-references this stage creates

- Every external attendee `domain` becomes a **customer-360 join key**.
- Every `onlineMeeting.joinUrl` becomes a **Teams-meeting join key** (stage 5).
- Every `categories` value becomes a **stage tag** for stage 9 sales pipeline inference.
- Every recurring series ID becomes a **Weekly OS validation key** (compare planned vs actual cadence).

---

## 7. Pagination + parallelism

| Endpoint | Parallelism | Notes |
|---|---|---|
| `get-calendar-view` per calendar | 1 stream per calendar, up to 4 calendars in parallel | Each call paginated |
| `get-specific-calendar-event` for series masters | 6 parallel | Cache by seriesMasterId |
| `list-calendar-view-delta` | 1 per calendar | Run last; produces delta token |

---

## 8. Failure modes

| Case | Handling |
|---|---|
| Some events have `start.timeZone="tzone://Microsoft/Custom"` weirdness | Trust `start.dateTime` literal; let `Prefer:` header normalize |
| Events span a daylight-saving transition | Use UTC math for duration; display local TZ |
| Cancelled event still in cache | Include with `isCancelled=true`; classify as `cancelled`; exclude from time-allocation |
| All-day events | Count as 0 hours toward time-allocation (or per-config) |
| Shared-calendar permissions issue | Skip; surface in `openQuestions` |
| Recurring series exception (one modified instance) | The puller gets the modified instance in the view; OK |

---

## 9. Acceptance criteria

- [ ] `events-flat.json` covers the full window with no gaps
- [ ] `series-masters.json` populated for every distinct `seriesMasterId`
- [ ] `calendar-analysis.json :: timeAllocation` totals sum to within ±2% of raw event-duration sum
- [ ] Classifier results match Maaz's expectations on a 10-event spot-check
- [ ] Standing meetings from the Weekly OS (Ashley Mon, Sales 1:1 Tue, Eng Wed, Bookkeeper Thu, Top-5 Fri, AIMS bi-weekly) are correctly detected as recurring series
- [ ] Findings spot-checked for false positives
- [ ] Delta link saved
