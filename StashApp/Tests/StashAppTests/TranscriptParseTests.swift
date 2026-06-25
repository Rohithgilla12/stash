import Testing
import Foundation
@testable import StashApp

@Suite struct TranscriptParseTests {

    let fmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

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
