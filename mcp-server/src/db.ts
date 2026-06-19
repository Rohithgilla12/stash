import Database from "better-sqlite3";
import { homedir } from "node:os";
import { join } from "node:path";
import { mkdirSync } from "node:fs";

// The SQLite file is the single source of truth shared with the native Stash app.
// Override the location with STASH_DB (full path) or STASH_DB_DIR (directory).
const dir =
  process.env.STASH_DB_DIR ??
  join(homedir(), "Library", "Application Support", "Stash");
mkdirSync(dir, { recursive: true });

export const db = new Database(process.env.STASH_DB ?? join(dir, "stash.db"));
db.pragma("journal_mode = WAL"); // safe concurrent reads/writes with the app

db.exec(`
CREATE TABLE IF NOT EXISTS tasks (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  done       INTEGER NOT NULL DEFAULT 0,
  priority   TEXT,                       -- 'high' | 'med' | 'low' | NULL
  due        TEXT,                       -- 'Today' | 'Tomorrow' | 'Upcoming'
  project    TEXT NOT NULL DEFAULT 'Inbox',
  tags       TEXT NOT NULL DEFAULT '[]', -- JSON string[]
  repeat     TEXT,                       -- 'Daily' | 'Weekdays' | 'Weekly' | NULL
  subs       TEXT NOT NULL DEFAULT '[]', -- JSON {t,done}[]
  source     TEXT NOT NULL DEFAULT 'you',-- 'you' | 'claude'
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS notes (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL DEFAULT '',
  color      TEXT,
  updated_at INTEGER NOT NULL,
  kind       TEXT NOT NULL DEFAULT 'text',   -- 'text' | 'todo'
  items      TEXT NOT NULL DEFAULT '[]',     -- JSON [{t,done}] for todo notes
  accent     TEXT,
  on_desktop INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS clipboard (
  id             TEXT PRIMARY KEY,
  kind           TEXT NOT NULL,              -- 'text' | 'link' | 'image' | ...
  text           TEXT,
  app            TEXT,
  pinned         INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL,
  title          TEXT,                       -- display label (link title / filename / first line)
  preview_path   TEXT,                       -- sidecar file for image/GIF thumbnails
  app_bundle_id  TEXT                        -- source app bundle identifier
);
CREATE TABLE IF NOT EXISTS snippets (
  trigger    TEXT PRIMARY KEY,
  label      TEXT NOT NULL,
  expand     TEXT,
  dynamic    TEXT,
  created_at INTEGER NOT NULL DEFAULT 0
);
`);

export type TaskRow = {
  id: string; title: string; done: number;
  priority: string | null; due: string | null; project: string;
  tags: string; repeat: string | null; subs: string; source: string;
  created_at: number; updated_at: number;
};

export function rowToTask(r: TaskRow) {
  return {
    id: r.id,
    title: r.title,
    done: !!r.done,
    priority: r.priority,
    due: r.due,
    project: r.project,
    tags: JSON.parse(r.tags) as string[],
    repeat: r.repeat,
    subtasks: JSON.parse(r.subs) as { t: string; done: boolean }[],
    source: r.source,
  };
}
