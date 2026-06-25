import Testing
import Foundation
@testable import StashApp

@Suite struct UsageAggregatorTests {

    private func makeRecord(
        timestamp: Date,
        sessionId: String = "sess-A",
        repoPath: String = "/Users/me/code/myproject",
        branch: String? = "main",
        model: String = "claude-opus-4-8",
        inputTokens: Int = 100,
        outputTokens: Int = 50
    ) -> UsageRecord {
        UsageRecord(
            timestamp: timestamp,
            sessionId: sessionId,
            repoPath: repoPath,
            branch: branch,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: 0,
            cacheReadTokens: 0
        )
    }

    // MARK: - todayTotals

    @Test func todayTotalsIncludesRecordsOnSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let todayRecord = makeRecord(timestamp: now, inputTokens: 200, outputTokens: 75)
        let totals = UsageAggregator.todayTotals([todayRecord], now: now, calendar: calendar)
        #expect(totals.input == 200)
        #expect(totals.output == 75)
    }

    @Test func todayTotalsExcludesYesterdayRecords() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let yesterday = now.addingTimeInterval(-86_400)
        let records = [
            makeRecord(timestamp: now, inputTokens: 300, outputTokens: 100),
            makeRecord(timestamp: yesterday, inputTokens: 999, outputTokens: 999)
        ]
        let totals = UsageAggregator.todayTotals(records, now: now, calendar: calendar)
        #expect(totals.input == 300)
        #expect(totals.output == 100)
    }

    @Test func todayTotalsEmptyWhenNoRecordsToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let yesterday = now.addingTimeInterval(-86_400)
        let records = [makeRecord(timestamp: yesterday)]
        let totals = UsageAggregator.todayTotals(records, now: now, calendar: calendar)
        #expect(totals.input == 0)
        #expect(totals.output == 0)
    }

    @Test func todayTotalsSumsMultipleRecords() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let records = [
            makeRecord(timestamp: now, inputTokens: 100, outputTokens: 10),
            makeRecord(timestamp: now, inputTokens: 200, outputTokens: 20),
            makeRecord(timestamp: now, inputTokens: 300, outputTokens: 30)
        ]
        let totals = UsageAggregator.todayTotals(records, now: now, calendar: calendar)
        #expect(totals.input == 600)
        #expect(totals.output == 60)
    }

    // MARK: - sessions

    @Test func sessionsGroupsBySessionId() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let t1 = now.addingTimeInterval(-60)
        let t2 = now.addingTimeInterval(-30)
        let records = [
            makeRecord(timestamp: t1, sessionId: "sess-A", inputTokens: 100, outputTokens: 10),
            makeRecord(timestamp: t2, sessionId: "sess-A", inputTokens: 200, outputTokens: 20)
        ]
        let result = UsageAggregator.sessions(records, now: now, activeWithin: 3600)
        #expect(result.count == 1)
        #expect(result[0].sessionId == "sess-A")
        #expect(result[0].input == 300)
        #expect(result[0].output == 30)
    }

    @Test func sessionsFirstSeenAndLastSeenAreCorrect() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let t1 = now.addingTimeInterval(-120)
        let t2 = now.addingTimeInterval(-60)
        let t3 = now.addingTimeInterval(-30)
        let records = [
            makeRecord(timestamp: t2, sessionId: "sess-A"),
            makeRecord(timestamp: t1, sessionId: "sess-A"),
            makeRecord(timestamp: t3, sessionId: "sess-A")
        ]
        let result = UsageAggregator.sessions(records, now: now, activeWithin: 3600)
        #expect(result.count == 1)
        #expect(result[0].firstSeen == t1)
        #expect(result[0].lastSeen == t3)
    }

    @Test func sessionsRepoIsLastPathComponent() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let record = makeRecord(timestamp: now, repoPath: "/Users/me/code/myproject")
        let result = UsageAggregator.sessions([record], now: now, activeWithin: 3600)
        #expect(result.count == 1)
        #expect(result[0].repo == "myproject")
    }

    @Test func sessionsBranchIsFromMostRecentRecord() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let t1 = now.addingTimeInterval(-60)
        let t2 = now.addingTimeInterval(-30)
        let records = [
            makeRecord(timestamp: t1, sessionId: "sess-A", branch: "old-branch"),
            makeRecord(timestamp: t2, sessionId: "sess-A", branch: "new-branch")
        ]
        let result = UsageAggregator.sessions(records, now: now, activeWithin: 3600)
        #expect(result[0].branch == "new-branch")
    }

    @Test func sessionsExcludesOlderThanActiveWithin() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let recentTime = now.addingTimeInterval(-100)
        let oldTime = now.addingTimeInterval(-7200)
        let records = [
            makeRecord(timestamp: recentTime, sessionId: "sess-recent"),
            makeRecord(timestamp: oldTime, sessionId: "sess-old")
        ]
        let result = UsageAggregator.sessions(records, now: now, activeWithin: 3600)
        #expect(result.count == 1)
        #expect(result[0].sessionId == "sess-recent")
    }

    @Test func sessionsSortedByLastSeenDescending() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let t1 = now.addingTimeInterval(-300)
        let t2 = now.addingTimeInterval(-60)
        let records = [
            makeRecord(timestamp: t1, sessionId: "sess-old"),
            makeRecord(timestamp: t2, sessionId: "sess-new")
        ]
        let result = UsageAggregator.sessions(records, now: now, activeWithin: 3600)
        #expect(result.count == 2)
        #expect(result[0].sessionId == "sess-new")
        #expect(result[1].sessionId == "sess-old")
    }

    @Test func sessionsTotalTokens() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let record = makeRecord(timestamp: now, inputTokens: 400, outputTokens: 100)
        let result = UsageAggregator.sessions([record], now: now, activeWithin: 3600)
        #expect(result[0].totalTokens == 500)
    }

    // MARK: - status

    @Test func statusIsRunningWhenLessThan120Seconds() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let lastSeen = now.addingTimeInterval(-119)
        #expect(UsageAggregator.status(lastSeen: lastSeen, now: now) == .running)
    }

    @Test func statusIsRunningAtExactlyZeroSeconds() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(UsageAggregator.status(lastSeen: now, now: now) == .running)
    }

    @Test func statusIsWaitingAt121Seconds() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let lastSeen = now.addingTimeInterval(-121)
        #expect(UsageAggregator.status(lastSeen: lastSeen, now: now) == .waiting)
    }

    @Test func statusIsWaitingAt899Seconds() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let lastSeen = now.addingTimeInterval(-899)
        #expect(UsageAggregator.status(lastSeen: lastSeen, now: now) == .waiting)
    }

    @Test func statusIsIdleAt900Seconds() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let lastSeen = now.addingTimeInterval(-900)
        #expect(UsageAggregator.status(lastSeen: lastSeen, now: now) == .idle)
    }

    @Test func statusIsIdleWhenVeryOld() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let lastSeen = now.addingTimeInterval(-86_400)
        #expect(UsageAggregator.status(lastSeen: lastSeen, now: now) == .idle)
    }
}
