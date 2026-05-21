@echo off
setlocal
set MS365_MCP_CLIENT_ID=8af91ea7-8d04-448d-8eb0-f75158882322
set MS365_MCP_TENANT_ID=cf0ad54b-3205-47d0-876c-1ae307871b5b
set MS365_MCP_TOKEN_CACHE_PATH=C:\Users\ASUS\.config\ms365-mcp\.token-cache.json
set MS365_MCP_SELECTED_ACCOUNT_PATH=C:\Users\ASUS\.config\ms365-mcp\.selected-account.json
set LOG_LEVEL=debug

echo CLIENT_ID=%MS365_MCP_CLIENT_ID%
echo TENANT_ID=%MS365_MCP_TENANT_ID%
echo TOKEN_CACHE_PATH=%MS365_MCP_TOKEN_CACHE_PATH%
echo ---

call npx -y @softeria/ms-365-mcp-server --login -v 2>&1
echo --- EXIT %ERRORLEVEL% ---
endlocal
