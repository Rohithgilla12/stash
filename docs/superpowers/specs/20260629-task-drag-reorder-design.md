# Task drag-reorder — design

**Date:** 2026-06-29
**Status:** Approved (pre-implementation)
**Slice:** Tasks daily-driver, follow-up to v0.3.6

## Goal

Let the user manually order tasks by dragging, with the order persisted and
shared across every filtered view. This is the deferred piece of the "Today
triage" powerup — the other triage parts (default-to-today, midnight rollover,
overdue surfacing, reschedule) shipped in v0.3.6.

## Decisions (locked with user)

- **One global order.** Every task has a single manual position. Each filtered
  list (Today / Upcoming / All) shows its tasks in that shared order; dragging a
  task in Today also moves it in All. One source of truth, no per-view state.
- **New tasks go to the top** of the manual order — preserves today's
  newest-first feel and makes a just-added task immediately visible.
- **Storage:** a single `INTEGER order_index` column, renumbered on drop. Lists
  are personal-sized (dozens of rows), so a full renumber per drop is cheap and
  avoids floating-point fractional-index drift.
- **Drag UI:** SwiftUI `List` + `.onMove` in the full Tasks window — native
  drag, keyboard reorder, and accessibility for free.

## Schema

New migration `v10_task_order` (app, `Data/Database.swift`):

```
ALTER TABLE tasks ADD COLUMN order_index INTEGER;
-- backfill so the current newest-first order is preserved on upgrade
UPDATE tasks SET order_index = -created_at WHERE order_index IS NULL;
```

`order_index` is nullable in SQLite (can't add a NOT NULL column without a
default to an existing table cleanly); the backfill sets every existing row, and
all new writes set it explicitly. `TaskItem` gains `var orderIndex: Int64?`
mapped to `order_index`.

Mirror the column in `mcp-server/src/db.ts`'s `CREATE TABLE tasks` to keep the
app↔server contract in sync. (Note: that file's `CREATE TABLE` already lacks
`due_at`, a pre-existing drift — out of scope here, but worth a separate fix.)

## Sort

`TasksStore.all()` and the `ValueObservation` in `TasksViewModel` change from
`ORDER BY created_at DESC` to:

```
ORDER BY order_index ASC, created_at DESC
```

Ascending `order_index` with the `-created_at` backfill yields newest-first for
un-reordered lists, matching today's behaviour.

## New tasks

`TasksStore.create` sets `order_index = (SELECT MIN(order_index) FROM tasks) - 1`
(or a sensible default when the table is empty) so the task lands at the top.
Computed inside the same write transaction.

## Reorder (global order, filtered-view safe)

The drag happens inside a filtered view (e.g. Today shows a subset). The pure
helper makes the result correct without per-view state:

```
reorderedGlobal(global: [TaskItem], visibleNewOrder: [TaskItem.ID]) -> [TaskItem.ID]
```

Algorithm:
1. `global` = all tasks in current `order_index ASC` order.
2. `visibleNewOrder` = the IDs of the visible list after `.onMove` rearranges it.
3. Walk `global`; each slot currently held by a visible task is filled with the
   next ID from `visibleNewOrder` (consumed in order). Non-visible tasks keep
   their slots.
4. The result is the new global ID order.

The view model then renumbers `order_index = 0,1,2,…` over the new global order
and persists changed rows in one transaction.

Worked example — global `[A,B,C,D,E]`, Today shows `[A,C,E]`, user drags C above
A → `visibleNewOrder = [C,A,E]` → new global `[C,A,B,D,E]`.

## UI

- **Full Tasks window** (`Tasks/TasksWindow.swift`): convert `taskListContent`
  from `ScrollView`+`LazyVStack` to a `List` with `.onMove`. Use
  `.listStyle(.plain)`, `.listRowSeparator(.hidden)`, and the existing row
  background so the look matches the current rows. `.onMove` calls the view
  model reorder with the visible tasks' new order. Works in every filter.
- **Popover Today list** (`Tasks/TodosTab.swift`): unchanged this slice — a
  menu-bar popover is a poor place for drag. Optional follow-up.

## Testing

- `reorderedGlobal` (pure): move up, move down, move within a filtered subset
  (non-visible positions preserved), and a no-op move.
- Migration `v10_task_order`: backfill preserves newest-first ordering.
- `create`: a new task receives the minimum `order_index` (lands at top).
- Existing 268 tests stay green.

## Risk

Converting the window list to `List` may shift row insets/separators slightly;
mitigated with `.plain` style, hidden separators, and the existing row
background. No behavioural risk to the reorder logic, which is unit-tested in
isolation from SwiftUI.

## Out of scope

- Drag-reorder inside the popover Today list.
- Inbox-vs-Today distinction.
- MCP `create_task` defaulting-to-today / `#tag` parsing (server-side).
