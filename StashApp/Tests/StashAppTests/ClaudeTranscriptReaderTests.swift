import Testing
import Foundation
@testable import StashApp

@Suite struct ClaudeTranscriptReaderTests {

    private func makeBaseDir() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeReaderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func parsesValidUsageLinesAndSkipsNonUsageAndMalformed() throws {
        let baseDir = try makeBaseDir()
        defer { cleanup(baseDir) }

        let projDir = baseDir.appendingPathComponent("proj1")
        try FileManager.default.createDirectory(at: projDir, withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_750_400_000)
        let t1 = now.addingTimeInterval(-300)
        let t2 = now.addingTimeInterval(-60)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let line1 = """
        {"timestamp":"\(fmt.string(from: t1))","sessionId":"sess-abc","cwd":"/Users/dev/myrepo","gitBranch":"main","message":{"model":"claude-opus-4-8","usage":{"input_tokens":100,"cache_creation_input_tokens":20,"cache_read_input_tokens":30,"output_tokens":50}}}
        """

        let line2 = """
        {"timestamp":"\(fmt.string(from: t2))","sessionId":"sess-abc","cwd":"/Users/dev/myrepo","gitBranch":"feat/x","message":{"model":"claude-opus-4-8","usage":{"input_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":10,"output_tokens":80}}}
        """

        let lineNonUsage = """
        {"timestamp":"\(fmt.string(from: t1))","sessionId":"sess-abc","type":"user","message":{"role":"user","content":"hello"}}
        """

        let lineMalformed = "not json at all {{{}"

        let content = [line1, lineNonUsage, lineMalformed, line2].joined(separator: "\n")
        let fileURL = projDir.appendingPathComponent("sess-abc.jsonl")
        try content.data(using: .utf8)!.write(to: fileURL)

        let reader = ClaudeTranscriptReader(baseDir: baseDir)
        let records = reader.read(modifiedWithin: 3600, now: now)

        #expect(records.count == 2)

        let sorted = records.sorted { $0.timestamp < $1.timestamp }

        #expect(sorted[0].sessionId == "sess-abc")
        #expect(sorted[0].repoPath == "/Users/dev/myrepo")
        #expect(sorted[0].branch == "main")
        #expect(sorted[0].inputTokens + sorted[0].cacheCreationTokens + sorted[0].cacheReadTokens == 150)
        #expect(sorted[0].outputTokens == 50)

        #expect(sorted[1].sessionId == "sess-abc")
        #expect(sorted[1].branch == "feat/x")
        #expect(sorted[1].inputTokens + sorted[1].cacheCreationTokens + sorted[1].cacheReadTokens == 210)
        #expect(sorted[1].outputTokens == 80)
    }

    @Test func skipsFilesWithOldMtime() throws {
        let baseDir = try makeBaseDir()
        defer { cleanup(baseDir) }

        let projDir = baseDir.appendingPathComponent("proj2")
        try FileManager.default.createDirectory(at: projDir, withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_750_400_000)
        let t = now.addingTimeInterval(-100)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let line = """
        {"timestamp":"\(fmt.string(from: t))","sessionId":"sess-old","cwd":"/repo","gitBranch":"main","message":{"model":"m","usage":{"input_tokens":500,"output_tokens":100}}}
        """

        let fileURL = projDir.appendingPathComponent("sess-old.jsonl")
        try line.data(using: .utf8)!.write(to: fileURL)

        let oldDate = now.addingTimeInterval(-7200)
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: fileURL.path
        )

        let reader = ClaudeTranscriptReader(baseDir: baseDir)
        let records = reader.read(modifiedWithin: 3600, now: now)

        #expect(records.isEmpty)
    }

    @Test func foldsAllCacheTokensIntoInputTokens() throws {
        let baseDir = try makeBaseDir()
        defer { cleanup(baseDir) }

        let projDir = baseDir.appendingPathComponent("proj3")
        try FileManager.default.createDirectory(at: projDir, withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_750_400_000)
        let t = now.addingTimeInterval(-60)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let line = """
        {"timestamp":"\(fmt.string(from: t))","sessionId":"sess-cache","cwd":"/repo","gitBranch":"dev","message":{"model":"m","usage":{"input_tokens":10,"cache_creation_input_tokens":40,"cache_read_input_tokens":50,"output_tokens":20}}}
        """

        let fileURL = projDir.appendingPathComponent("sess-cache.jsonl")
        try line.data(using: .utf8)!.write(to: fileURL)

        let reader = ClaudeTranscriptReader(baseDir: baseDir)
        let records = reader.read(modifiedWithin: 3600, now: now)

        #expect(records.count == 1)
        #expect(records[0].inputTokens + records[0].cacheCreationTokens + records[0].cacheReadTokens == 100)
        #expect(records[0].outputTokens == 20)
    }
}
