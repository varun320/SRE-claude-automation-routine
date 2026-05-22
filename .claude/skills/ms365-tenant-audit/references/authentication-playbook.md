# Authentication playbook — MS-365 MCP server

The single most common failure mode for the first audit run against a new tenant is authentication. This file documents the recipe that actually works on Windows + PowerShell, and the failure modes that look successful but aren't.

## What works

1. **One Entra app per audit shop** (not per client). Multi-tenant + personal MSA app type. Public client flow ON.
2. **Standalone `--login` from cmd.exe (NOT inline PowerShell `$env:`)**. The polling process needs to own the entire device-code window.
3. **File-based token cache** at a stable path. Set `MS365_MCP_TOKEN_CACHE_PATH` and `MS365_MCP_SELECTED_ACCOUNT_PATH` in **both** the standalone login env AND Claude's MCP env in `~/.claude.json` so they read/write the same file.

## Entra app registration

Required settings:

| Setting | Value |
|---|---|
| Name | (your choice, e.g. "AI Audit") |
| Supported account types | "Accounts in any organizational directory and personal Microsoft accounts" (multi-tenant + MSA) |
| Platform | "Mobile and desktop applications" with redirect URI `https://login.microsoftonline.com/common/oauth2/nativeclient` |
| Authentication → Advanced settings → **Allow public client flows** | **Yes** ← critical |
| API permissions (delegated) | At minimum: `User.Read`, `User.Read.All`, `Mail.Read`, `Mail.ReadBasic`, `Calendars.Read`, `Calendars.Read.Shared`, `Files.Read.All`, `Sites.Read.All`, `Group.Read.All`, `Team.ReadBasic.All`, `Channel.ReadBasic.All`, `Chat.Read`, `Notes.Read.All`, `Tasks.Read`, `MailboxSettings.Read`, `Contacts.Read` |
| Admin consent | Granted by a tenant admin |

The 1-minute fix when login fails with `invalid_client`:

```
https://portal.azure.com → App registrations → <your app> → Authentication
→ scroll to Advanced settings → "Allow public client flows" → Yes → Save
```

## Claude's MCP config (`~/.claude.json`)

```json
"mcpServers": {
  "ms365": {
    "type": "stdio",
    "command": "cmd",
    "args": ["/c", "npx -y @softeria/ms-365-mcp-server --org-mode"],
    "env": {
      "MS365_MCP_CLIENT_ID": "<your-app-client-id>",
      "MS365_MCP_TENANT_ID": "<client-tenant-id-or-common>",
      "MS365_MCP_TOKEN_CACHE_PATH": "C:\\Users\\<you>\\.config\\ms365-mcp\\.token-cache.json",
      "MS365_MCP_SELECTED_ACCOUNT_PATH": "C:\\Users\\<you>\\.config\\ms365-mcp\\.selected-account.json"
    }
  }
}
```

Use `common` for `TENANT_ID` if the app is multi-tenant and the operator's home tenant ID isn't known yet. Use the specific tenant GUID once known.

**Do NOT set `MS365_MCP_CLIENT_SECRET`.** Public client flows do not use a secret. If present, Microsoft may refuse the device-code grant.

## The .bat (Windows) login recipe

The single thing that goes wrong on Windows is shell quoting. Bash mangles `$env:` PowerShell syntax; cmd.exe mangles `cmd /c "set X=Y && ..."`. The reliable path is a `.bat` file invoked from cmd.exe.

See `templates/ms365-login.bat.template` — copy it, set CLIENT_ID + TENANT_ID + cache paths, then:

```bash
cmd //c 'C:\full\path\to\ms365-login.bat'
```

(Forward-slash `cmd //c` and MSYS-style single-quoted path is the form Bash on Windows accepts.)

This launches the standalone CLI, prints a device code, and polls Microsoft. The operator enters the code at https://login.microsoft.com/device, signs in, and accepts consent. The CLI writes the token cache and exits 0. Subsequent `mcp__ms365__verify-login` from Claude returns `{"success": true, ...}`.

## Why Claude's MCP login is unreliable

In testing, calling `mcp__ms365__login` directly from Claude returns a device code, the operator signs in, browser shows "you have signed in to the application", and yet `verify-login` returns false. Hypothesis: Claude's MCP child process state isn't reliably preserved across tool calls — the polling loop for the device-code grant doesn't survive between the `login` call and subsequent calls. The standalone `--login` works because its polling owns the entire flow end-to-end.

The same token cache file is read by both processes, so the standalone login transfers correctly to Claude's MCP on next call. This is the recommended path.

## Verification

After login, run from Claude:

```
mcp__ms365__verify-login
```

Expected:

```json
{"success": true, "message": "Login successful", "userData": {"displayName": "...", "userPrincipalName": "..."}}
```

If `userPrincipalName` doesn't match the operator you expected, do NOT proceed — you're authenticated as the wrong account. Run `mcp__ms365__remove-account` and re-login.

Then run:

```
mcp__ms365__list-accounts
```

Confirms the cached account is the right one and marked default.

## Token expiry

The MCP server refreshes tokens automatically via the refresh token in the cache. If the operator's password changes, the refresh token may revoke and the next call returns `{"success": false, "message": "token expired"}`. Re-run `ms365-login.bat`.

For long-running audits (> 1 hour of Graph calls), the access-token-vs-refresh-token cycle should be transparent. If you hit 401s mid-audit, the cache file may have a stale refresh token — re-login.

## Cleanup

To revoke local access (e.g., after handing the audit back):

```
mcp__ms365__remove-account
```

Or delete the cache files:

```
del C:\Users\<you>\.config\ms365-mcp\.token-cache.json
del C:\Users\<you>\.config\ms365-mcp\.selected-account.json
```

The Entra app stays registered — that's fine, it's per-shop not per-client.
