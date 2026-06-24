# AI Usage Dashboard — Design Spec

**Date:** 2026-06-24
**Goal:** Add a CodexBar-style usage view to Stash's AI tab: on-device cost + token analytics parsed from local Claude Code logs, plus (experimental) live subscription session/weekly meters.
**Status:** Design from research dialogue; pending spec review → plan.

---

## Context

Stash's AI tab currently does "ask Claude via `claude -p` + quick actions" (the user removed the API key; uses the Claude Code CLI subscription). The user wants a usage/cost dashboard like **CodexBar** (a menu-bar app) in the AI tab.

Research findings (data sources):
- **Token/cost data** lives in **local Claude Code logs**: `~/.claude/projects/<project>/*.jsonl`, one JSONL per session. Each assistant message has a `usage` block (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`) + the `model`. Cost = tokens × published API rates ("estimated at API rates"). Fully on-device, no auth.
- **Subscription session/weekly limits** have **no official API** (Anthropic feature requests open). CodexBar's primary method is an undocumented but clean OAuth call (details below). Experimental — must degrade gracefully.

## Decisions (from dialogue)

| Decision | Choice |
|---|---|
| Scope | **Both** halves: local-logs dashboard **and** experimental subscription meters. |
| Meters method (v1) | **OAuth-token only** — read the Claude Code token from Keychain, call `api.anthropic.com/api/oauth/usage`. NOT the browser-cookie or CLI-PTY fallbacks (those are for non-CLI users; deferred). |
| Provider (v1) | **Claude only** (the user's setup). Multi-provider (Codex/Gemini) = future. |
| Meters fragility | Undocumented endpoint → label **"experimental"**, hide gracefully on any failure (missing token, non-200, parse error, expired). |

## Data sources (exact)

### Local logs (cost + tokens) — on-device, no auth
- Glob `~/.claude/projects/**/*.jsonl` (respect `CLAUDE_CONFIG_DIR` if set).
- For each line, parse JSON; for assistant messages with a `message.usage` block, read `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, the `model`, and the line's `timestamp`.
- Aggregate by **day** and by **model**.
- **Cost** = Σ (tokens × per-model API rate). Maintain a static price table (USD per 1M tokens, per model, separate input / output / cache-write / cache-read rates). This table needs occasional manual updates — flag it in code + the About copy ("estimated at API rates").

### Subscription meters (experimental) — OAuth token
- Read the Claude Code OAuth access token: macOS Keychain item service **`Claude Code-credentials`** (`security find-generic-password -s 'Claude Code-credentials' -w` returns JSON; extract the access token), with `~/.claude/.credentials.json` as fallback.
- `GET https://api.anthropic.com/api/oauth/usage` with headers `Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`.
- Response keys: `five_hour` → **Session**; `seven_day` → **Weekly**; `seven_day_sonnet` / `seven_day_opus` → model-specific weekly; `extra_usage` → overage spend/limit. Each window exposes a used/limit (→ % left) and a reset time (→ countdown).
- **Graceful degradation:** on missing token / non-200 / parse failure / expired, show "Live limits unavailable" (with a short reason) and keep the local-logs dashboard fully functional.

## UI (AI tab)

The AI tab gains a **Usage** view (a segmented toggle at the top of the AI tab: **Chat** | **Usage**, defaulting to whatever's sensible; or a header tab). The Usage view, top → bottom:
1. **Meters** (experimental, only when fetched): Session / Weekly / Sonnet horizontal bars — `% left` + "resets in …" + reserve where present. A subtle "experimental" affordance + a manual **Refresh**.
2. **Cost**: Today $ · 30-day $ (estimated). 
3. **Tokens**: 30-day total · latest session.
4. **Histogram**: per-day token (or cost) bars over ~30 days (reuse a simple bar style; warm terracotta).
5. **Top model** + a small per-model cost/token breakdown.
6. Footnote: "Estimated from local Claude logs at API rates."

Warm + adaptive tokens; reuse the app's chart/section styling. The local-logs sections render immediately (on-device); meters load async + degrade.

## Architecture

- `AI/ClaudeUsageLog.swift` — PURE parsing + aggregation: given file contents (or decoded lines), produce per-day + per-model token/cost rollups. Unit-tested with sample JSONL.
- `AI/UsagePricing.swift` — the static per-model price table + a pure `cost(tokens:model:)`. Unit-tested.
- `AI/ClaudeUsageReader.swift` (`@MainActor` or an actor) — globs the logs off-main, returns the rollup (uses the pure aggregator).
- `AI/ClaudeLimitsClient.swift` — reads the Keychain token + calls the OAuth usage endpoint; returns a typed `Limits` struct or an error. The response **decoder** is pure + unit-tested against a sample JSON.
- `AI/UsageView.swift` (+ small subviews: meters, stats, histogram) — the SwiftUI Usage view, fed by an `@Observable` view model that holds the rollup + the limits (+ loading/error state).
- Wire into the existing AI tab (segmented Chat/Usage).

## Security / privacy

- On-device parsing of the user's own logs; the OAuth token is read locally and sent ONLY to `api.anthropic.com`'s usage endpoint (the same host Claude Code uses) over HTTPS — never stored elsewhere, never logged. Non-sandboxed app already (can read `~/.claude` + run `security`).
- No employer name anywhere.

## Testing / verification

- Unit tests: the JSONL aggregator (sample lines → expected per-day/per-model tokens), the pricing (`cost(tokens:model:)`), and the OAuth-usage **response decoder** (sample JSON → `five_hour`/`seven_day`/percentages/resets).
- Clean Release build + suite green.
- **Launch-run the built app** (concurrency: async fetch + Keychain/subprocess) — no crash.
- Manual: open AI → Usage; confirm cost/tokens/histogram from real logs; confirm meters populate (or degrade cleanly if the endpoint/token fails).

## Out of scope (this plan)

- Browser-cookie and CLI-PTY meter fallbacks (OAuth-token method only for v1).
- Multi-provider (Codex / Gemini) tabs.
- Historical persistence/DB of usage (compute from logs live; logs are the source of truth).
- Auto-refresh timers beyond a manual Refresh + on-appear load (a gentle interval can be a follow-up).

## Open choices for the plan

1. Chat/Usage as a **segmented control** at the top of the AI tab (recommended) vs a separate hub tab.
2. Histogram metric: **tokens/day** (recommended, matches CodexBar) vs cost/day.
3. Price table location: a checked-in `UsagePricing` table (recommended) — accept that it needs manual updates when Anthropic changes rates.
