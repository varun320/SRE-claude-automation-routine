# Connector Smoke Tests

**Purpose:** Verify every connector the routines depend on works end-to-end before scheduling any agent. Run these manually in Claude Code whenever auth changes, the MCP server upgrades, or a routine starts failing for unclear reasons.

**Frequency:** On Phase 0 completion, after any MCP server upgrade, after Azure AD app changes, and any time more than one routine fails in a single day.

**Pass criteria:** Each prompt below returns real data within 30 seconds, no auth errors, no permission warnings.

---

## 1. Outlook Mail

```
Use ms365 to list my 3 most recent unread Outlook emails. Subjects and senders only. No bodies, no preview text.
```

**Expects:** Three items with `from` and `subject`. If the inbox has zero unread, ask for the 3 most recent emails of any state.

**Permissions used:** `Mail.ReadWrite`

---

## 2. Calendar

```
Use ms365 to show my next 5 calendar events with start time, end time, and subject. Local timezone (America/Edmonton).
```

**Expects:** Five events ordered by start time. Times shown in MST/MDT, not UTC.

**Permissions used:** `Calendars.ReadWrite`

---

## 3. Teams Chats

```
Use ms365 to list the 5 Teams chats I had most recent activity in, with the chat topic or participants and the last-message timestamp.
```

**Expects:** Five chat threads with timestamps. If you don't use Teams chat often, ask for any 3 chats regardless of recency.

**Permissions used:** `Chat.ReadWrite`

---

## 4. OneDrive Files

```
Use ms365 to list the top 10 files in my OneDrive root folder by last modified date. Name, size, last modified.
```

**Expects:** Ten files with metadata. Should include the SRE Project Tracker if it lives in OneDrive.

**Permissions used:** `Files.ReadWrite.All`

---

## 5. Project Tracker xlsx (depends on test 4)

```
Use ms365 to read the worksheet names from the SRE Project Tracker.xlsx in my OneDrive (search by name).
```

**Expects:** A list of worksheet names. If this fails, R11/R12/R13/R14 cannot work — they all depend on this file.

**Permissions used:** `Files.ReadWrite.All`

---

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| "Not authenticated" | Token expired | Re-run `ms365 login` |
| "Insufficient privileges" on one test only | Missing scope in Azure AD app | Add the permission listed above, grant admin consent, re-login |
| All four tests fail same way | MCP server crashed or env var lost | Restart Claude Code; check `MS365_MCP_CLIENT_ID` env var |
| Times shown in UTC, not MST | Account locale setting | Set Outlook account timezone to Mountain Time |
| Empty results when you know data exists | Wrong account selected | Run `ms365 list-accounts`, then switch with `account` parameter |

---

## Logbook

Append a line each time you run the full suite.

| Date | Tester | Result | Notes |
|---|---|---|---|
| 2026-05-20 | Maaz | PASS | All 5 read tests + write probe (Outlook draft create/delete). Custom Entra app registration, not Softeria default. M365 Connection Plan §4–§8 complete. |
