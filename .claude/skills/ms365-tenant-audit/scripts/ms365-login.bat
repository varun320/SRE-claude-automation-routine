@echo off
REM ============================================================
REM   MS365 MCP standalone device-code login
REM ============================================================
REM   Copy this file into the audit project, set CLIENT_ID + TENANT_ID
REM   (and optionally TOKEN_CACHE_PATH), then invoke from Claude as:
REM
REM       cmd //c 'C:\full\path\to\ms365-login.bat'
REM
REM   This starts the @softeria/ms-365-mcp-server in --login mode.
REM   The CLI prints a device code; the operator enters it at
REM   https://login.microsoft.com/device and signs in. The CLI polls
REM   until login succeeds, persists the token cache, and exits 0.
REM
REM   Claude's MCP picks up the same token cache on its next call,
REM   so subsequent mcp__ms365__verify-login returns success.
REM ============================================================

setlocal

REM ---------- REQUIRED: set per audit ----------
REM Application (client) ID from your Entra App Registration
set MS365_MCP_CLIENT_ID=REPLACE-WITH-YOUR-APP-CLIENT-ID

REM Tenant ID — use "common" for multi-tenant + MSA apps before
REM the client's home tenant is known. Once known, use the specific GUID.
set MS365_MCP_TENANT_ID=REPLACE-WITH-CLIENT-TENANT-ID-OR-common

REM ---------- OPTIONAL: cache paths ----------
REM File-based token cache. Must match the env in ~/.claude.json
REM so Claude's MCP server reads/writes the same file.
set MS365_MCP_TOKEN_CACHE_PATH=%USERPROFILE%\.config\ms365-mcp\.token-cache.json
set MS365_MCP_SELECTED_ACCOUNT_PATH=%USERPROFILE%\.config\ms365-mcp\.selected-account.json

REM Verbose logging — drop to "info" once stable
set LOG_LEVEL=debug

REM ---------- Pre-flight ----------
if not exist "%USERPROFILE%\.config\ms365-mcp" mkdir "%USERPROFILE%\.config\ms365-mcp"

echo CLIENT_ID=%MS365_MCP_CLIENT_ID%
echo TENANT_ID=%MS365_MCP_TENANT_ID%
echo TOKEN_CACHE_PATH=%MS365_MCP_TOKEN_CACHE_PATH%
echo SELECTED_ACCOUNT_PATH=%MS365_MCP_SELECTED_ACCOUNT_PATH%
echo ---

REM ---------- Run device-code login ----------
call npx -y @softeria/ms-365-mcp-server --login -v 2>&1

echo --- EXIT %ERRORLEVEL% ---
endlocal
