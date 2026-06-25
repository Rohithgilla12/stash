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
}
