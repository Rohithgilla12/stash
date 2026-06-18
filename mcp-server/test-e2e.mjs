// End-to-end check: drive the Stash MCP server over stdio, create a task,
// list tasks, and (the caller) confirm the row landed in the shared SQLite DB.
// Run: E2E_DB=/tmp/stash-e2e.db node test-e2e.mjs   (from mcp-server/)
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const dbPath = process.env.E2E_DB ?? "/tmp/stash-e2e.db";

const transport = new StdioClientTransport({
  command: "node",
  args: ["dist/server.js"],
  env: { ...process.env, STASH_DB: dbPath },
});

const client = new Client({ name: "stash-e2e", version: "1.0.0" }, { capabilities: {} });
await client.connect(transport);

const tools = await client.listTools();
console.log("TOOLS:", tools.tools.map((t) => t.name).join(", "));

const created = await client.callTool({
  name: "create_task",
  arguments: { title: "E2E plan item", due: "Today", priority: "high", tags: ["eng"] },
});
console.log("CREATE:", created.content.map((c) => c.text).join(" "));

const listed = await client.callTool({ name: "list_tasks", arguments: { filter: "today" } });
console.log("LIST_TODAY:", listed.content.map((c) => c.text).join("\n"));

await client.close();
console.log("E2E_OK");
