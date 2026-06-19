# Stash Slice 8 — AI tab real data (Claude Code transcripts)

**Goal:** Replace the AI tab's USAGE and ACTIVE SESSIONS empty-states with REAL data read from local Claude Code transcripts (`~/.claude/projects/**/*.jsonl`). No API keys, no network — all local, verifiable.

## Data source (verified)
Each assistant message line in a transcript JSONL has: `timestamp` (ISO8601 Z), `sessionId`, `cwd` (repo path), `gitBranch`, and `message.usage { input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens }`, `message.model` (e.g. `claude-opus-4-8`).

## Decisions (made autonomously)
- **USAGE THIS CYCLE → "today"**: show REAL Claude tokens used today (sum of `input_tokens + output_tokens` across all sessions; cache_read/creation shown separately or folded into input — pick: display `<input>↑ <output>↓` today, plus a bar). Do NOT invent a quota %  (we don't know the user's plan limit) — show real counts; the bar is scaled to a soft daily reference (documented as approximate) OR relative to the busiest session. Keep "Codex" / "Stash AI" rows as honest "Not connected" (no data source) so the 3-row layout matches the design without lying.
- **ACTIVE SESSIONS**: one row per recent Claude Code session (transcript modified in the last ~6h), showing repo (basename of `cwd`) · `gitBranch`, a status dot (running if last activity < 2 min, waiting < 15 min, else idle), total tokens for that session, and elapsed (now − first message). Sort by most-recent activity; cap to ~6 rows.
- Reading the user's own local transcripts into their own app; nothing leaves the machine.
- Performance: only scan files with mtime within the window; only parse lines containing `"usage"`; do it OFF the main thread; refresh on tab appear + a periodic timer (~30s).

## Global Constraints
Same as prior slices. Swift Testing; full suite; `xcodegen generate`; commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`; no banner comments; reuse Tokens. `@MainActor` VM; file IO off-main.

---

### Task A1: UsageRecord + UsageAggregator (pure, TDD)
**Files:** Create `AI/UsageRecord.swift`, `AI/UsageAggregator.swift`; Test `Tests/StashAppTests/UsageAggregatorTests.swift`.
- `struct UsageRecord: Sendable, Equatable { let timestamp: Date; let sessionId: String; let repoPath: String; let branch: String?; let model: String; let inputTokens: Int; let outputTokens: Int }` (fold cache_read+cache_creation into `inputTokens`, or add a `cacheTokens` field — keep it simple: `inputTokens` = input + cache_read + cache_creation; `outputTokens` = output).
- `enum UsageAggregator`:
  - `static func todayTotals(_ records: [UsageRecord], now: Date, calendar: Calendar) -> (input: Int, output: Int)` — sum records whose timestamp is the same calendar day as `now`.
  - `struct SessionSummary: Sendable, Equatable { let sessionId: String; let repo: String; let branch: String?; let input: Int; let output: Int; let firstSeen: Date; let lastSeen: Date }` and `var totalTokens: Int { input + output }`.
  - `static func sessions(_ records: [UsageRecord], now: Date, activeWithin: TimeInterval) -> [SessionSummary]` — group by sessionId, sum tokens, min/max timestamps, keep only sessions with `lastSeen >= now - activeWithin`, sorted by `lastSeen` desc. `repo` = last path component of `repoPath`.
  - `static func status(lastSeen: Date, now: Date) -> SessionStatus` where `enum SessionStatus { case running, waiting, idle }` (running < 120s, waiting < 900s, else idle).
Tests: today filter (records yesterday excluded); session grouping sums + min/max + repo basename + activeWithin filter + sort order; status thresholds. PURE (inject `now`/calendar). RED→GREEN→commit `feat(app): add usage aggregator`.

---

### Task A2: ClaudeTranscriptReader + AIViewModel + AITab wiring (TDD reader; build + verify)
**Files:** Create `AI/ClaudeTranscriptReader.swift`, `AI/AIViewModel.swift`; modify `AI/AITab.swift`, `App/AppEnvironment.swift`; Test `Tests/StashAppTests/ClaudeTranscriptReaderTests.swift`.
- `struct ClaudeTranscriptReader: Sendable { let baseDir: URL; init(baseDir: URL = default ~/.claude/projects) }`:
  - `func read(modifiedWithin: TimeInterval, now: Date) -> [UsageRecord]` — enumerate `baseDir/*/*.jsonl` whose mtime >= now - modifiedWithin; for each, read line-by-line; parse only lines containing `"usage"`; decode the needed fields (timestamp, sessionId, cwd, gitBranch, message.model, message.usage.*) into `UsageRecord`; skip malformed lines. Use `JSONDecoder` with a focused Codable struct (ignore the rest), or `JSONSerialization` for robustness against schema drift (prefer JSONSerialization — the transcript schema is external/unstable).
  Make it testable: in the test, write a tiny fixture dir with 2 fake `<proj>/<id>.jsonl` files containing a couple of usage lines + non-usage lines, call `read`, assert the parsed records (counts, tokens, repo, branch). Use a temp dir as `baseDir`.
- `@MainActor @Observable final class AIViewModel { var todayInput = 0; var todayOutput = 0; var sessions: [UsageAggregator.SessionSummary] = []; init(reader: ClaudeTranscriptReader); func refresh() async (reads off main via Task.detached/`await` on a background reader call, then aggregates, then assigns on main); func start() (refresh + a ~30s repeating refresh) }`. The file scan must NOT block the main thread — do the `reader.read(...)` inside a `Task.detached` or `await withCheckedContinuation` on a background queue; aggregation is cheap.
- `AI/AITab.swift`: take an `AIViewModel` (pass from AppEnvironment); USAGE card shows a real "Claude" row — `formatted(todayInput)`↑ `formatted(todayOutput)`↓ today + a bar (scaled to a soft reference, e.g. fraction of `max(todayInput+todayOutput, someFloor)`), and "Codex"/"Stash AI" rows as dim "Not connected". ACTIVE SESSIONS shows `model.sessions` rows: repo · branch, a status dot (green/amber/gray via `UsageAggregator.status`), `totalTokens` formatted, and elapsed (now − firstSeen) — or "No active sessions" if empty. `.task { await model.start() }` on the tab. Keep the MCP card unchanged.
- `AppEnvironment`: construct `AIViewModel(reader: ClaudeTranscriptReader())`; expose it; (no need to start at launch — the tab's `.task` starts it when first shown). Route `AITab(model: env.aiViewModel)` in StashApp.swift.
- Number formatting helper: `1234 -> "1.2K"`, `1_200_000 -> "1.2M"`.

**Verification:** build + full suite green (A1 + reader tests). Then LIVE: launch, open the AI tab, screenshot — confirm a real "Claude" usage number appears (compare against `python3` manual sum: today output ≈ 199,846 tokens at probe time, will have grown) and that ACTIVE SESSIONS lists real recent sessions (repo · branch). Controller verifies the on-screen numbers are plausibly correct vs a fresh manual sum.
Commit `feat(app): wire AI tab to real Claude Code usage + sessions`.

## Notes
- Prefer `JSONSerialization` in the reader (transcript schema is external/unstable; tolerate missing fields).
- Cap work: only recent files, only `"usage"` lines, off-main. The tab refreshes ~30s.
- Honest display: real Claude numbers; Codex/Stash AI clearly "Not connected"; no invented quota %.
