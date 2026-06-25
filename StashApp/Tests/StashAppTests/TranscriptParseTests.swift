import Testing
import Foundation
@testable import StashApp

@Suite struct TranscriptParseTests {

    private func makeFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    @Test func parsesAllCacheFieldsSeparately() throws {
        let fmt = makeFormatter()
        let ts = "2024-01-15T10:00:00.000Z"
        let line = """
        {"timestamp":"\(ts)","sessionId":"s1","cwd":"/repo/myproject","gitBranch":"main","message":{"model":"claude-opus-4-8","usage":{"input_tokens":100,"cache_creation_input_tokens":40,"cache_read_input_tokens":60,"output_tokens":25}}}
        """

        let record = ClaudeTranscriptReader.parseRecord(line: line, formatter: fmt)

        let r = try #require(record)
        #expect(r.rawInputTokens == 100)
        #expect(r.cacheCreationTokens == 40)
        #expect(r.cacheReadTokens == 60)
        #expect(r.outputTokens == 25)
        #expect(r.inputTokens == 200)
        #expect(r.totalTokens == 225)
        #expect(r.model == "claude-opus-4-8")
        #expect(r.sessionId == "s1")
        #expect(r.repoPath == "/repo/myproject")
        #expect(r.branch == "main")
    }

    @Test func returnsNilForLineWithoutUsage() {
        let fmt = makeFormatter()
        let line = """
        {"timestamp":"2024-01-15T10:00:00.000Z","sessionId":"s1","type":"user","message":{"role":"user","content":"hello"}}
        """
        #expect(ClaudeTranscriptReader.parseRecord(line: line, formatter: fmt) == nil)
    }
}
