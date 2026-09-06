# Memos

Memos runs as the private, quick-capture notes service in the local `notes`
namespace. Access it through the canonical gateway and Kepos:

- Web and MCP: `http://memos.localhost:17480`
- MCP endpoint: `http://memos.localhost:17480/mcp`

The deployment is intentionally small: one Memos replica, SQLite, and one
retained host-path volume. It is pinned to Memos 0.29.1 because Moe Memos 2.0.4
lists that server version as compatible.

## Deploy

```bash
nh os switch . -H wsl

just notes-diff
just notes-deploy
just notes-status
just kepos-status
```

The WSL rebuild is required before the first deploy. It creates the host data
directory, installs the Kepos service, and adds the local hostname used by the
gateway.

The persistent data lives at `/var/lib/kosmos-k3s/notes/memos`. The directory
contains the SQLite database and attachments. Back up the whole directory; do
not treat the retained PV as a backup.

## First account and Android

Open `http://memos.localhost:17480` after deployment. The first registered user
becomes the administrator. Keep public registration and public memo visibility
disabled for a personal instance.

Install Moe Memos from F-Droid or Google Play and connect it to the same URL.
Before upgrading Memos, confirm that the installed Moe Memos release supports
the target server version.

## Codex MCP

Create a separate personal access token in Memos user settings. Keep it out of
the repository, then expose it to Codex as `MEMOS_MCP_TOKEN` and add:

```toml
[mcp_servers.memos]
url = "http://memos.localhost:17480/mcp"
bearer_token_env_var = "MEMOS_MCP_TOKEN"
enabled_tools = [
  "list_memos",
  "get_memo",
  "search_memos",
  "create_memo",
  "update_memo",
  "list_memo_comments",
  "create_memo_comment",
  "list_tags",
  "list_attachments",
  "get_attachment",
]
```

These are the tool names exposed by Memos 0.29.1. Memos 0.30 renamed its MCP
tools, so update the allowlist when the pinned server version changes. Check the
active tools with `/mcp` in Codex after connecting. Do not enable delete tools
by default.
