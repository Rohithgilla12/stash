# stash-mcp

MCP server for **Stash**. Lets Claude Desktop and Claude Code read & write the user's
tasks, notes, and clipboard history. It writes to the same SQLite database the native
macOS app uses, so anything Claude creates shows up live in the app.

## Tools exposed

| Tool | What it does |
|---|---|
| `create_task` | Add a to-do (title, due, priority, tags, project, repeat, subtasks) |
| `list_tasks` | List tasks filtered by `today` / `upcoming` / `all` / `done`, project, or tag |
| `complete_task` | Mark a task done / undone |
| `update_task` | Change fields on a task |
| `add_note` | Create a note |
| `search_clipboard` | Search clipboard history text |

> "Generate my day" is not a special tool — Claude simply calls `create_task` several
> times. That keeps the surface small and lets the model plan freely.

## Run it

```bash
cd mcp-server
npm install
npm run build      # compiles src → dist
npm start          # runs dist/server.js over stdio
# or, during development:
npm run dev        # tsx src/server.ts
```

The DB lives at `~/Library/Application Support/Stash/stash.db` by default.
Override with `STASH_DB=/path/to/stash.db` or `STASH_DB_DIR=/dir`.

## Register with Claude Code

From the project root (where `.mcp.json` lives), Claude Code auto-detects it. Or add explicitly:

```bash
claude mcp add stash -- node /ABS/PATH/design_handoff_stash/mcp-server/dist/server.js
# check it:
claude mcp list
```

Then in a Claude Code session: *"Plan my day in Stash"* → it calls `create_task` repeatedly.

## Register with Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "stash": {
      "command": "node",
      "args": ["/ABS/PATH/design_handoff_stash/mcp-server/dist/server.js"]
    }
  }
}
```

Restart Claude Desktop; the tools appear under the 🔌 (tools) menu.

## Notes for the implementer

- This is a working reference. For the shipping app, prefer launching the server as a
  child process of the Swift app (or bundling a Swift MCP server) so users never touch a terminal.
- `better-sqlite3` is a native module — rebuild against the Node/Electron ABI you ship with.
- The schema in `src/db.ts` is the contract between the app and the server. Keep them in sync.
