# Connecting the Stash MCP server

The Stash MCP server lets an AI assistant (Claude, Claude Code, Cursor, etc.) read
and write your Stash data — create/list/complete/update **tasks**, add **notes**, and
**search clipboard** history — so it can plan your day. It talks to the **same
database** the Stash app uses (`~/Library/Application Support/Stash/stash.db`), so
anything the assistant creates shows up in the app instantly.

**Tools exposed:** `create_task`, `list_tasks`, `complete_task`, `update_task`,
`add_note`, `search_clipboard`. ("Generate my day" = the assistant calls `create_task`
once per task — there's no separate tool.)

---

## Step 0 — Build the server (once)

```bash
cd /Users/rohithgilla/github.com/Rohithgilla12/stash/mcp-server
npm install
npm run build          # compiles TypeScript → dist/server.js
```

This produces `dist/server.js`. Re-run `npm run build` after pulling changes.

> The full path you'll reference below is:
> `/Users/rohithgilla/github.com/Rohithgilla12/stash/mcp-server/dist/server.js`

---

## Claude Code (CLI)

The easiest path — one command:

```bash
claude mcp add stash -- node /Users/rohithgilla/github.com/Rohithgilla12/stash/mcp-server/dist/server.js
```

Then verify:

```bash
claude mcp list          # should show "stash"
```

Inside a session, run `/mcp` to see the server + its tools, then just ask:
*"Use stash to generate my day"* or *"add a note in stash about …"*.

- **Scope:** add `-s user` (available everywhere) or `-s project` (this repo only).
  Default is local to the current project.
- **Remove:** `claude mcp remove stash`.

---

## Claude Desktop (Mac app)

1. Open the config file (create it if missing):
   `~/Library/Application Support/Claude/claude_desktop_config.json`
2. Add the server under `mcpServers`:

```json
{
  "mcpServers": {
    "stash": {
      "command": "node",
      "args": [
        "/Users/rohithgilla/github.com/Rohithgilla12/stash/mcp-server/dist/server.js"
      ]
    }
  }
}
```

3. **Fully quit and reopen** Claude Desktop. The tools appear under the 🔌/tools
   menu in the composer. If it doesn't connect, check `node --version` (needs Node 18+)
   and that `dist/server.js` exists.

---

## Cursor

Add to `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (per-project), same shape:

```json
{
  "mcpServers": {
    "stash": {
      "command": "node",
      "args": ["/Users/rohithgilla/github.com/Rohithgilla12/stash/mcp-server/dist/server.js"]
    }
  }
}
```

Then enable **stash** in Cursor → Settings → MCP.

---

## Any other MCP client (VS Code, Windsurf, Zed, …)

They all use the same **stdio** launch contract — point the client at:

- **command:** `node`
- **args:** `["…/stash/mcp-server/dist/server.js"]`

…in whatever config file that tool uses for `mcpServers`. No env vars or ports needed;
it communicates over stdio and opens the shared SQLite DB directly.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "server failed to start" | Run `node …/dist/server.js` manually — it should sit waiting on stdio (Ctrl-C to exit). If it errors, re-run `npm run build`. |
| Tools don't appear | Restart the client fully (Desktop/Cursor cache the server list). |
| Changes don't show in the app | Both read the same `stash.db`; make sure the app isn't pointed at a different `STASH_DB_DIR`. |
| `node: command not found` | Install Node 18+ (`brew install node`) and use an absolute path to `node` in `command` if needed (`which node`). |
