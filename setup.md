ms365 MCP — config

  Claude Code CLI (one-liner — recommended):

  # macOS / Linux
  claude mcp add ms365 -s user -- npx -y @softeria/ms-365-mcp-server --org-mode

  # Windows (PowerShell or cmd) — cmd /c wrapper is required
  claude mcp add ms365 -s user -- cmd /c "npx -y @softeria/ms-365-mcp-server --org-mode"

  Claude Desktop / manual JSON (paste into the mcpServers block of claude_desktop_config.json — Settings → Developer → Edit Config):

  {
    "mcpServers": {
      "ms365": {
        "command": "npx",
        "args": ["-y", "@softeria/ms-365-mcp-server", "--org-mode"]
      }
    }
  }

  On Windows, if npx isn't resolved directly, use:

  {
    "mcpServers": {
      "ms365": {
        "command": "cmd",
        "args": ["/c", "npx", "-y", "@softeria/ms-365-mcp-server", "--org-mode"]
      }
    }
  }

  Prereqs

  - Node.js ≥ 20
        "args": ["/c", "npx", "-y", "@softeria/ms-365-mcp-server", "--org-mode"]
      }
    }
  }

  Prereqs

  - Node.js ≥ 20
  - Restart Claude Code / Claude Desktop after adding

  First-run auth (device code flow)

  After install, in a chat:
  1. Call the login tool — it returns a URL + device code
  2. Open the URL in a browser, paste the code, sign in with the work/school account
  3. Call verify-login to confirm

  Tokens are cached in the OS credential store (keytar) with a file fallback.

  Notes for them:
  - --org-mode enables Teams, SharePoint, shared mailboxes, user management (work/school accounts). Drop the flag for personal MSA accounts.
  - For multiple Microsoft accounts on the same machine, run npx @softeria/ms-365-mcp-server --login per account; tool calls then accept an account parameter.