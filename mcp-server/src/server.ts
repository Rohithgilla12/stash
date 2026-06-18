#!/usr/bin/env node
/**
 * Stash MCP server.
 * Exposes the user's tasks / notes / clipboard to Claude & Claude Code over stdio.
 * Backed by the same SQLite DB the native macOS app reads, so anything Claude
 * creates appears live in the app (and vice-versa).
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { randomUUID } from "node:crypto";
import { db, rowToTask, type TaskRow } from "./db.js";

const now = () => Date.now();
const server = new McpServer({ name: "stash-mcp", version: "0.1.0" });

/* ---------------------------------------------------------------- create_task */
server.registerTool(
  "create_task",
  {
    title: "Create task",
    description:
      "Create a to-do in Stash. Use this (one call per task) when planning the user's day. " +
      "Default `due` to 'Today' for same-day work.",
    inputSchema: {
      title: z.string().describe("Task title, e.g. 'Review onboarding copy'"),
      due: z.enum(["Today", "Tomorrow", "Upcoming"]).default("Today"),
      priority: z.enum(["high", "med", "low"]).optional(),
      tags: z.array(z.string()).default([]).describe("e.g. ['eng','design']"),
      project: z.string().default("Inbox"),
      repeat: z.enum(["Daily", "Weekdays", "Weekly"]).optional(),
      subtasks: z.array(z.string()).default([]),
    },
  },
  async ({ title, due, priority, tags, project, repeat, subtasks }) => {
    const id = randomUUID();
    const t = now();
    db.prepare(
      `INSERT INTO tasks (id,title,done,priority,due,project,tags,repeat,subs,source,created_at,updated_at)
       VALUES (?,?,0,?,?,?,?,?,?,'claude',?,?)`
    ).run(
      id, title, priority ?? null, due, project,
      JSON.stringify(tags), repeat ?? null,
      JSON.stringify(subtasks.map((s) => ({ t: s, done: false }))),
      t, t
    );
    return {
      content: [{ type: "text", text: `Created “${title}” (${due}${priority ? `, ${priority}` : ""}) [${id}]` }],
    };
  }
);

/* ----------------------------------------------------------------- list_tasks */
server.registerTool(
  "list_tasks",
  {
    title: "List tasks",
    description: "List tasks, optionally filtered by smart list, project, or tag. Returns JSON.",
    inputSchema: {
      filter: z.enum(["today", "upcoming", "all", "done"]).default("all"),
      project: z.string().optional(),
      tag: z.string().optional(),
    },
  },
  async ({ filter, project, tag }) => {
    const rows = db.prepare("SELECT * FROM tasks ORDER BY created_at DESC").all() as TaskRow[];
    let tasks = rows.map(rowToTask);
    if (filter === "today") tasks = tasks.filter((x) => x.due === "Today" && !x.done);
    else if (filter === "upcoming") tasks = tasks.filter((x) => (x.due === "Tomorrow" || x.due === "Upcoming") && !x.done);
    else if (filter === "done") tasks = tasks.filter((x) => x.done);
    else tasks = tasks.filter((x) => !x.done);
    if (project) tasks = tasks.filter((x) => x.project === project);
    if (tag) tasks = tasks.filter((x) => x.tags.includes(tag));
    return { content: [{ type: "text", text: JSON.stringify(tasks, null, 2) }] };
  }
);

/* ------------------------------------------------------------- complete_task */
server.registerTool(
  "complete_task",
  {
    title: "Complete task",
    description: "Mark a task done (or undone).",
    inputSchema: { id: z.string(), done: z.boolean().default(true) },
  },
  async ({ id, done }) => {
    const r = db.prepare("UPDATE tasks SET done=?, updated_at=? WHERE id=?").run(done ? 1 : 0, now(), id);
    return { content: [{ type: "text", text: r.changes ? `Task ${id} marked ${done ? "done" : "open"}` : `No task ${id}` }] };
  }
);

/* --------------------------------------------------------------- update_task */
server.registerTool(
  "update_task",
  {
    title: "Update task",
    description: "Update fields of an existing task. Only provided fields change.",
    inputSchema: {
      id: z.string(),
      title: z.string().optional(),
      due: z.enum(["Today", "Tomorrow", "Upcoming"]).optional(),
      priority: z.enum(["high", "med", "low"]).optional(),
      project: z.string().optional(),
      tags: z.array(z.string()).optional(),
    },
  },
  async (a) => {
    const r = db.prepare("SELECT * FROM tasks WHERE id=?").get(a.id) as TaskRow | undefined;
    if (!r) return { content: [{ type: "text", text: `No task ${a.id}` }], isError: true };
    db.prepare(
      `UPDATE tasks SET title=?, due=?, priority=?, project=?, tags=?, updated_at=? WHERE id=?`
    ).run(
      a.title ?? r.title, a.due ?? r.due, a.priority ?? r.priority,
      a.project ?? r.project, a.tags ? JSON.stringify(a.tags) : r.tags, now(), a.id
    );
    return { content: [{ type: "text", text: `Updated ${a.id}` }] };
  }
);

/* ------------------------------------------------------------------ add_note */
server.registerTool(
  "add_note",
  {
    title: "Add note",
    description: "Create a note in Stash.",
    inputSchema: { title: z.string(), body: z.string().default("") },
  },
  async ({ title, body }) => {
    const id = randomUUID();
    db.prepare("INSERT INTO notes (id,title,body,updated_at) VALUES (?,?,?,?)").run(id, title, body, now());
    return { content: [{ type: "text", text: `Note “${title}” added [${id}]` }] };
  }
);

/* ----------------------------------------------------------- search_clipboard */
server.registerTool(
  "search_clipboard",
  {
    title: "Search clipboard",
    description: "Search the user's clipboard history by text. Returns JSON.",
    inputSchema: { query: z.string(), limit: z.number().int().default(10) },
  },
  async ({ query, limit }) => {
    const rows = db
      .prepare("SELECT id,kind,text,app,created_at FROM clipboard WHERE text LIKE ? ORDER BY created_at DESC LIMIT ?")
      .all(`%${query}%`, limit);
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }
);

/* ---------------------------------------------------------------------- boot */
const transport = new StdioServerTransport();
await server.connect(transport);
