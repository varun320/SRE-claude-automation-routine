$ErrorActionPreference = 'Stop'

$env:MS365_MCP_CLIENT_ID = '8af91ea7-8d04-448d-8eb0-f75158882322'
$env:MS365_MCP_TENANT_ID = 'cf0ad54b-3205-47d0-876c-1ae307871b5b'
$env:MS365_MCP_TOKEN_CACHE_PATH = 'C:\Users\ASUS\.config\ms365-mcp\.token-cache.json'
$env:MS365_MCP_SELECTED_ACCOUNT_PATH = 'C:\Users\ASUS\.config\ms365-mcp\.selected-account.json'
$env:LOG_LEVEL = 'debug'

Write-Output ("CLIENT_ID=" + $env:MS365_MCP_CLIENT_ID)
Write-Output ("TENANT_ID=" + $env:MS365_MCP_TENANT_ID)
Write-Output ("TOKEN_CACHE_PATH=" + $env:MS365_MCP_TOKEN_CACHE_PATH)
Write-Output '---'

& npx -y '@softeria/ms-365-mcp-server' --login -v 2>&1
