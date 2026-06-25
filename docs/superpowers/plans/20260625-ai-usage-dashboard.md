# AI Usage Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A CodexBar-style Usage view in Stash's AI tab — on-device cost + token analytics from local Claude Code logs, plus experimental live Session/Weekly subscription meters via the Claude OAuth usage endpoint.

**Architecture:** Build on the AI tab's EXISTING infra (`ClaudeTranscriptReader` → `[UsageRecord]` → `UsageAggregator`, surfaced by `AIViewModel`/`AITab`). Add a pricing table, un-fold cache tokens for accurate cost, add per-day/per-model rollups, an experimental OAuth limits client, and a `Usage` segment in the AI tab. Pure logic (pricing, parsing, aggregation, response decoding) is unit-tested; I/O + UI are build- + launch-verified.

**Tech Stack:** Swift 6 (strict concurrency, `@MainActor`/actor), SwiftUI + AppKit, Foundation (URLSession, `security` CLI for Keychain), Swift Testing.

## Global Constraints

- **Claude only**; OAuth-token meters method ONLY (no browser-cookie / CLI-PTY fallbacks). Multi-provider out of scope.
- Meters endpoint is **undocumented** → label **"experimental"** and **degrade gracefully** (missing token / non-200 / decode failure ⇒ hide meters, keep the local dashboard working). Never crash on it.
- Cost is **estimated at published API rates** — a checked-in price table that needs occasional manual updates; say so in the footnote copy.
- On-device: read the user's own `~/.claude` logs + the Claude Code OAuth token from Keychain; send the token ONLY to `api.anthropic.com` over HTTPS; never store/log it elsewhere.
- Swift 6 strict concurrency — **build + tests are NOT sufficient; launch-run the built app** each task that touches runtime (async fetch, Keychain subprocess) — a prior off-main `@MainActor` closure shipped a launch crash.
- No banner comments. No employer name ("fusang"). Reuse `Tokens`/`Typography`/`Components`. `cd StashApp && xcodegen generate` before building. Release build: `xcodebuild -scheme StashApp -configuration Release -derivedDataPath .build-release build CODE_SIGNING_ALLOWED=NO`. Suite: `xcodebuild test -scheme StashApp -destination 'platform=macOS' -derivedDataPath .build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "Test run with"` (was 233). Commit trailer (MUST end every msg): `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`. Plain `git commit`. Don't git add the generated Info.plist.

**Existing types (consume; do not recreate):**
- `UsageRecord` (`AI/UsageRecord.swift`): `timestamp, sessionId, repoPath, branch, model, inputTokens, outputTokens` — currently `inputTokens` = raw input + cache-creation + cache-read (folded). Task 2 un-folds this.
- `ClaudeTranscriptReader` (`AI/ClaudeTranscriptReader.swift`): `read(modifiedWithin:now:) -> [UsageRecord]` globbing `~/.claude/projects/**/*.jsonl`. JSONL shape: `obj.timestamp` (ISO8601 w/ fractional seconds), `obj.sessionId`, `obj.cwd`, `obj.gitBranch`, `obj.message.model`, `obj.message.usage.{input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens}`.
- `UsageAggregator` (`AI/UsageAggregator.swift`): `todayTotals`, `sessions`, `status`, `SessionSummary`.
- `AIViewModel` (`AI/AIViewModel.swift`, `@MainActor @Observable`): `todayInput/todayOutput`, `sessions`, `loaded`, `now`, `refresh()`, `start()`.
- `AITab` (`AI/AITab.swift`): `AITab(model: AIViewModel, assistant: AIAssistant, env: AppEnvironment)`; instantiated in `StashApp.swift` `case .ai:`.

---

### Task 1: UsagePricing (pure, tested)

**Files:** Create `StashApp/Sources/StashApp/AI/UsagePricing.swift`; Test `StashApp/Tests/StashAppTests/UsagePricingTests.swift`.

**Interfaces:** Produces `UsagePricing.cost(input:output:cacheWrite:cacheRead:model:) -> Double` (USD) + `ModelRate`.

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import StashApp

@Suite struct UsagePricingTests {
    @Test func opusCostMatchesRates() {
        // opus-4.x rates: in $15, out $75, cacheWrite $18.75, cacheRead $1.50 per 1M
        let c = UsagePricing.cost(input: 1_000_000, output: 1_000_000, cacheWrite: 1_000_000, cacheRead: 1_000_000, model: "claude-opus-4-8")
        #expect(abs(c - (15 + 75 + 18.75 + 1.50)) < 0.001)
    }
    @Test func sonnetCheaperThanOpus() {
        let o = UsagePricing.cost(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0, model: "claude-opus-4-8")
        let s = UsagePricing.cost(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0, model: "claude-sonnet-4-6")
        #expect(s < o)
    }
    @Test func unknownModelUsesFallbackNotZero() {
        #expect(UsagePricing.cost(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0, model: "mystery") > 0)
    }
}
```

- [ ] **Step 2: Run → fails** (no `UsagePricing`).

- [ ] **Step 3: Implement `UsagePricing.swift`**
```swift
import Foundation

struct ModelRate: Sendable {
    let input: Double, output: Double, cacheWrite: Double, cacheRead: Double  // USD per 1M tokens
}

enum UsagePricing {
    // Published API rates (USD / 1M tokens). NOTE: update when Anthropic changes pricing.
    static let opus   = ModelRate(input: 15,  output: 75,  cacheWrite: 18.75, cacheRead: 1.50)
    static let sonnet = ModelRate(input: 3,   output: 15,  cacheWrite: 3.75,  cacheRead: 0.30)
    static let haiku  = ModelRate(input: 0.80, output: 4,  cacheWrite: 1.0,   cacheRead: 0.08)

    static func rate(for model: String) -> ModelRate {
        let m = model.lowercased()
        if m.contains("opus")   { return opus }
        if m.contains("haiku")  { return haiku }
        if m.contains("sonnet") { return sonnet }
        return sonnet // sensible fallback for unknown/new models
    }

    static func cost(input: Int, output: Int, cacheWrite: Int, cacheRead: Int, model: String) -> Double {
        let r = rate(for: model)
        let m = 1_000_000.0
        return Double(input)/m*r.input + Double(output)/m*r.output
             + Double(cacheWrite)/m*r.cacheWrite + Double(cacheRead)/m*r.cacheRead
    }
}
```

- [ ] **Step 4: Run → passes.** Clean Release build succeeds.
- [ ] **Step 5: Commit** — `git add … && git commit -m "feat(app): UsagePricing table + per-model cost"`

---

### Task 2: Un-fold cache tokens in UsageRecord + reader (refactor existing) + tested line-parser

**Files:** Modify `AI/UsageRecord.swift`, `AI/ClaudeTranscriptReader.swift`, `AI/UsageAggregator.swift`, `AI/AIViewModel.swift` (+ `AI/AITab.swift` only if it reads removed fields). Test: `StashApp/Tests/StashAppTests/TranscriptParseTests.swift`.

**Interfaces:** `UsageRecord` gains `cacheCreationTokens: Int`, `cacheReadTokens: Int`; `inputTokens` becomes RAW input; add `var totalTokens: Int { inputTokens + cacheCreationTokens + cacheReadTokens + outputTokens }`. Reader exposes a pure `static func parseRecord(line: String, formatter: ISO8601DateFormatter) -> UsageRecord?`.

- [ ] **Step 1: Extend `UsageRecord.swift`**
```swift
struct UsageRecord: Sendable, Equatable {
    let timestamp: Date
    let sessionId: String
    let repoPath: String
    let branch: String?
    let model: String
    let inputTokens: Int          // raw input (no cache)
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int { inputTokens + cacheCreationTokens + cacheReadTokens + outputTokens }
}
```

- [ ] **Step 2: Write the failing test** — `TranscriptParseTests.swift` (sample line uses the REAL shape)
```swift
import Testing
import Foundation
@testable import StashApp

@Suite struct TranscriptParseTests {
    let fmt: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()

    @Test func parsesAssistantUsageLine() {
        let line = #"{"timestamp":"2026-06-18T13:13:30.257Z","sessionId":"S1","cwd":"/x/stash","gitBranch":"main","type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":100,"output_tokens":20,"cache_creation_input_tokens":5,"cache_read_input_tokens":7}}}"#
        let r = ClaudeTranscriptReader.parseRecord(line: line, formatter: fmt)
        #expect(r?.inputTokens == 100)
        #expect(r?.outputTokens == 20)
        #expect(r?.cacheCreationTokens == 5)
        #expect(r?.cacheReadTokens == 7)
        #expect(r?.totalTokens == 132)
        #expect(r?.model == "claude-opus-4-8")
        #expect(r?.sessionId == "S1")
    }
    @Test func ignoresLinesWithoutUsage() {
        #expect(ClaudeTranscriptReader.parseRecord(line: #"{"type":"user","timestamp":"2026-06-18T13:13:30.257Z"}"#, formatter: fmt) == nil)
    }
}
```

- [ ] **Step 3: Run → fails** (no `parseRecord`; record shape mismatch).

- [ ] **Step 4: Refactor `ClaudeTranscriptReader.swift`** — extract the per-line body into `static func parseRecord(line:formatter:) -> UsageRecord?` storing the FOUR token fields separately (`inputTokens = input_tokens` raw, plus `cacheCreationTokens`, `cacheReadTokens`, `outputTokens`). Have the file-walking `read(...)` call `parseRecord` per line. (Keep the `line.contains("\"usage\"")` fast-skip + the mtime filter.)

- [ ] **Step 5: Adapt `UsageAggregator` + `AIViewModel`** so the codebase compiles and existing displays stay sensible:
  - `UsageAggregator.todayTotals`: keep returning `(input, output)` but compute `input` as `inputTokens + cacheCreationTokens + cacheReadTokens` (so the existing "today" number is unchanged from before the refactor). `sessions` `SessionSummary.input` likewise = raw input + cache (preserve current display). This keeps existing UI identical; the new COST path (Task 3) uses the raw split fields directly.
  - `AIViewModel`: no signature change needed if `todayTotals` semantics are preserved.

- [ ] **Step 6: Run tests → pass** (new parse tests + existing suite). Clean Release build succeeds. **Launch-run** (the reader is used at runtime): record crash-report count, run the Release app 6s, confirm alive + no new crash, pkill.

- [ ] **Step 7: Commit** — `git commit -m "refactor(app): split cache tokens in UsageRecord + testable transcript parser"`

---

### Task 3: Dashboard aggregations (pure, tested)

**Files:** Modify `AI/UsageAggregator.swift`; Test `StashApp/Tests/StashAppTests/UsageAggregatorDashboardTests.swift`.

**Interfaces:** Produces `UsageAggregator.DayBucket {day: Date; tokens: Int; cost: Double}`, `ModelBucket {model: String; tokens: Int; cost: Double}`, and:
- `static func daily(_ records:[UsageRecord], days: Int, now: Date, calendar: Calendar = .current) -> [DayBucket]` — one bucket per day for the last `days` days (oldest→newest, zero-filled), `cost` via `UsagePricing`.
- `static func byModel(_ records:[UsageRecord]) -> [ModelBucket]` — grouped, sorted by cost desc.
- `static func cost(_ records:[UsageRecord], since: Date?, now: Date) -> Double` — Σ cost of records with `timestamp >= since` (nil = all).

- [ ] **Step 1: Write the failing tests**
```swift
import Testing
import Foundation
@testable import StashApp

@Suite struct UsageAggregatorDashboardTests {
    let cal = Calendar(identifier: .gregorian)
    func rec(_ day: Int, model: String = "claude-opus-4-8", input: Int = 1_000_000, output: Int = 0) -> UsageRecord {
        let ts = cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 12))!
        return UsageRecord(timestamp: ts, sessionId: "S", repoPath: "/x", branch: nil, model: model,
                           inputTokens: input, outputTokens: output, cacheCreationTokens: 0, cacheReadTokens: 0)
    }
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 18))! }

    @Test func dailyZeroFillsAndBuckets() {
        let buckets = UsageAggregator.daily([rec(10), rec(10), rec(8)], days: 7, now: now, calendar: cal)
        #expect(buckets.count == 7)                                  // one per day
        #expect(buckets.last?.tokens == 2_000_000)                   // today: two records
        #expect(buckets.first(where: { cal.component(.day, from: $0.day) == 9 })?.tokens == 0) // zero-fill
    }
    @Test func byModelSortedByCostDesc() {
        let m = UsageAggregator.byModel([rec(10, model: "claude-sonnet-4-6"), rec(10, model: "claude-opus-4-8")])
        #expect(m.first?.model.contains("opus") == true)             // opus pricier ⇒ first
    }
    @Test func costSinceFilters() {
        let all = UsageAggregator.cost([rec(10), rec(1)], since: nil, now: now)
        let recent = UsageAggregator.cost([rec(10), rec(1)], since: cal.date(from: DateComponents(year: 2026, month: 6, day: 5))!, now: now)
        #expect(recent < all)
    }
}
```

- [ ] **Step 2: Run → fails.**
- [ ] **Step 3: Implement** the three functions + structs in `UsageAggregator` (use `UsagePricing.cost(input: r.inputTokens, output: r.outputTokens, cacheWrite: r.cacheCreationTokens, cacheRead: r.cacheReadTokens, model: r.model)`; `daily` builds `days` day-buckets via `calendar.startOfDay` arithmetic, zero-filled, oldest→newest).
- [ ] **Step 4: Run → passes.** Clean Release build succeeds.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): per-day + per-model usage rollups with cost"`

---

### Task 4: Experimental limits client (Keychain token + OAuth endpoint + tested decoder)

**Files:** Create `AI/ClaudeLimitsClient.swift`; Test `StashApp/Tests/StashAppTests/ClaudeLimitsDecodeTests.swift`.

**Interfaces:** Produces `ClaudeLimits` (`session/weekly/sonnet: UsageWindow?`, where `UsageWindow {label: String; percentLeft: Double; resetsAt: Date?}`), a PURE `static func decodeLimits(from data: Data, now: Date) throws -> ClaudeLimits`, and `actor ClaudeLimitsClient { func fetch() async -> Result<ClaudeLimits, ClaudeLimitsError> }`.

> **Step 0 (capture the real response shape FIRST — do NOT guess the schema):** run
> `TOKEN=$(security find-generic-password -s 'Claude Code-credentials' -w | python3 -c "import json,sys;print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])"); curl -s https://api.anthropic.com/api/oauth/usage -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20" | python3 -m json.tool | tee /tmp/usage-sample.json`
> and read `/tmp/usage-sample.json`. Write `decodeLimits` + the test fixture to match the ACTUAL keys/sub-fields (`five_hour`, `seven_day`, `seven_day_sonnet`, `extra_usage`, and whatever the used/limit/reset fields are really called). If the call fails (expired/again-undocumented), proceed with a best-guess decoder but make it tolerant (all fields optional) and note it in the report.

- [ ] **Step 1: Capture the sample** (Step 0). Record the real JSON in the report.
- [ ] **Step 2: Write the failing decode test** — feed the captured JSON (or a representative subset) as `Data` to `ClaudeLimits.decodeLimits(from:now:)` and assert `session?.percentLeft`, `weekly?.percentLeft`, and a `resetsAt` parse, using values from the real sample.
- [ ] **Step 3: Run → fails.**
- [ ] **Step 4: Implement** `decodeLimits` (tolerant `Codable`/`JSONSerialization` mapping of `five_hour`→session, `seven_day`→weekly, `seven_day_sonnet`→sonnet; derive `percentLeft` from the real utilization/remaining field; parse reset timestamps), plus `ClaudeLimitsClient.fetch()`:
  - read token: `Process` running `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`, parse JSON `claudeAiOauth.accessToken`; fallback to `~/.claude/.credentials.json`. If absent → `.failure(.noToken)`.
  - `URLSession` GET the endpoint with the two headers; non-200 → `.failure(.http(code))`; decode → `.success`. Catch all → `.failure(.decode)`/`.failure(.network)`. NEVER throw to the caller; NEVER log the token.
- [ ] **Step 5: Run → passes.** Clean Release build + suite.
- [ ] **Step 6: Commit** — `git commit -m "feat(app): experimental Claude OAuth usage limits client + decoder"`

---

### Task 5: Usage view + view model + AITab segmented + launch-run

**Files:** Create `AI/UsageView.swift` (+ small subviews); modify `AI/AIViewModel.swift` (or add `AI/UsageViewModel.swift`), `AI/AITab.swift`. (No `StashApp.swift` change — `AITab` already receives what it needs.)

**Interfaces:** Consumes Tasks 1–4. Produces a `Usage` segment in the AI tab.

- [ ] **Step 1: View model** — add to `AIViewModel` (or a new `@MainActor @Observable UsageViewModel`): `var daily: [UsageAggregator.DayBucket]`, `var byModel: [UsageAggregator.ModelBucket]`, `var todayCost: Double`, `var cost30d: Double`, `var tokens30d: Int`, `var latestTokens: Int`, `var limits: ClaudeLimits?`, `var limitsState: LimitsState (idle/loading/unavailable(String)/loaded)`. A `func loadUsage()` that (a) reads records via `ClaudeTranscriptReader` (e.g. last 30 days, off-main) and computes the rollups, (b) `func refreshLimits() async` that calls `ClaudeLimitsClient.fetch()` and sets `limits`/`limitsState` on the main actor (guard the off-main→main hop like the existing observers — no off-main `@MainActor` closure).
- [ ] **Step 2: `UsageView.swift`** — sections top→bottom: **meters** (only `if let limits`, else a quiet "Live limits unavailable — experimental" row): Session/Weekly/Sonnet bars (`% left` + "resets in …"); **cost** (Today $ · 30d $); **tokens** (30d · latest); **histogram** (a row of bars from `daily`, terracotta, height ∝ tokens); **top model** + a small per-`byModel` cost list; footnote "Estimated from local Claude logs at API rates." Reuse existing bar/section styling; small sub-views (CI type-check). A **Refresh** button → `refreshLimits()` + reload.
- [ ] **Step 3: AITab segmented control** — add a `@State private var mode: Mode = .chat` (enum `chat`/`usage`) and a segmented Picker at the top of `AITab`'s body; show the existing chat UI for `.chat` and `UsageView` for `.usage`. Trigger `loadUsage()`/`refreshLimits()` on first switch to `.usage` (and on `.onAppear` if `.usage`).
- [ ] **Step 4: Build + suite + LAUNCH-RUN** — clean Release build → SUCCEEDED; suite (233 + new) pass; launch-run: record crash count, run Release app 6s, alive + no new crash, pkill. Paste evidence.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): AI-tab Usage dashboard (cost, tokens, histogram, experimental meters)"`

---

## Final verification (after all tasks)
- Clean Release build + full suite green (233 + UsagePricing + TranscriptParse + UsageAggregatorDashboard + ClaudeLimitsDecode tests).
- Launch-run (Debug + Release): alive, zero new crash reports.
- Manual: AI tab → Usage → cost/tokens/histogram/top-model render from real logs; meters populate from the OAuth endpoint, OR degrade to "unavailable" cleanly (kill networking / rename the Keychain item to test the failure path).
- Note: the price table + the undocumented meters endpoint are maintenance items; meters are labeled experimental.
