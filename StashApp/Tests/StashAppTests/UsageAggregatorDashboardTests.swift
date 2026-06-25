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
