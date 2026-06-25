import Foundation

enum SessionStatus: Sendable {
    case running, waiting, idle
}

enum UsageAggregator {

    struct SessionSummary: Sendable, Equatable {
        let sessionId: String
        let repo: String
        let branch: String?
        let input: Int
        let output: Int
        let firstSeen: Date
        let lastSeen: Date

        var totalTokens: Int { input + output }
    }

    static func todayTotals(
        _ records: [UsageRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> (input: Int, output: Int) {
        let filtered = records.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        let input = filtered.reduce(0) { $0 + $1.inputTokens + $1.cacheCreationTokens + $1.cacheReadTokens }
        let output = filtered.reduce(0) { $0 + $1.outputTokens }
        return (input, output)
    }

    static func sessions(
        _ records: [UsageRecord],
        now: Date,
        activeWithin: TimeInterval
    ) -> [SessionSummary] {
        let cutoff = now.addingTimeInterval(-activeWithin)

        var groups: [String: [UsageRecord]] = [:]
        for record in records {
            groups[record.sessionId, default: []].append(record)
        }

        var summaries: [SessionSummary] = []
        for (sessionId, sessionRecords) in groups {
            guard let lastSeen = sessionRecords.map(\.timestamp).max(),
                  lastSeen >= cutoff,
                  let firstSeen = sessionRecords.map(\.timestamp).min()
            else { continue }

            let mostRecent = sessionRecords.max(by: { $0.timestamp < $1.timestamp })
            let repo = (sessionRecords.first?.repoPath as NSString?)?.lastPathComponent ?? ""
            let branch = mostRecent?.branch

            let input = sessionRecords.reduce(0) { $0 + $1.inputTokens + $1.cacheCreationTokens + $1.cacheReadTokens }
            let output = sessionRecords.reduce(0) { $0 + $1.outputTokens }

            summaries.append(SessionSummary(
                sessionId: sessionId,
                repo: repo,
                branch: branch,
                input: input,
                output: output,
                firstSeen: firstSeen,
                lastSeen: lastSeen
            ))
        }

        return summaries.sorted { $0.lastSeen > $1.lastSeen }
    }

    static func status(lastSeen: Date, now: Date) -> SessionStatus {
        let elapsed = now.timeIntervalSince(lastSeen)
        if elapsed < 120 { return .running }
        if elapsed < 900 { return .waiting }
        return .idle
    }

    struct DayBucket: Sendable {
        let day: Date
        let tokens: Int
        let cost: Double
    }

    struct ModelBucket: Sendable {
        let model: String
        let tokens: Int
        let cost: Double
    }

    static func daily(
        _ records: [UsageRecord],
        days: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [DayBucket] {
        let today = calendar.startOfDay(for: now)

        var buckets: [DayBucket] = (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else { return nil }
            return DayBucket(day: day, tokens: 0, cost: 0)
        }

        for record in records {
            let recordDay = calendar.startOfDay(for: record.timestamp)
            guard let idx = buckets.firstIndex(where: { $0.day == recordDay }) else { continue }
            let existing = buckets[idx]
            let addedCost = UsagePricing.cost(
                input: record.inputTokens,
                output: record.outputTokens,
                cacheWrite: record.cacheCreationTokens,
                cacheRead: record.cacheReadTokens,
                model: record.model
            )
            buckets[idx] = DayBucket(
                day: existing.day,
                tokens: existing.tokens + record.totalTokens,
                cost: existing.cost + addedCost
            )
        }

        return buckets
    }

    static func byModel(_ records: [UsageRecord]) -> [ModelBucket] {
        var groups: [String: (tokens: Int, cost: Double)] = [:]
        for record in records {
            let recordCost = UsagePricing.cost(
                input: record.inputTokens,
                output: record.outputTokens,
                cacheWrite: record.cacheCreationTokens,
                cacheRead: record.cacheReadTokens,
                model: record.model
            )
            let existing = groups[record.model] ?? (tokens: 0, cost: 0)
            groups[record.model] = (tokens: existing.tokens + record.totalTokens, cost: existing.cost + recordCost)
        }

        return groups
            .map { ModelBucket(model: $0.key, tokens: $0.value.tokens, cost: $0.value.cost) }
            .sorted { $0.cost > $1.cost }
    }

    static func cost(_ records: [UsageRecord], since: Date?, now: Date) -> Double {
        let filtered = since.map { cutoff in records.filter { $0.timestamp >= cutoff } } ?? records
        return filtered.reduce(0.0) { sum, record in
            sum + UsagePricing.cost(
                input: record.inputTokens,
                output: record.outputTokens,
                cacheWrite: record.cacheCreationTokens,
                cacheRead: record.cacheReadTokens,
                model: record.model
            )
        }
    }
}
