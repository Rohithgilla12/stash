import Foundation
import Observation

@MainActor
@Observable
final class AIViewModel {
    var todayInput: Int = 0
    var todayOutput: Int = 0
    var sessions: [UsageAggregator.SessionSummary] = []
    var loaded: Bool = false
    var now: Date = Date()

    var daily: [UsageAggregator.DayBucket] = []
    var byModel: [UsageAggregator.ModelBucket] = []
    var todayCost: Double = 0.0
    var cost30d: Double = 0.0
    var tokens30d: Int = 0
    var latestTokens: Int = 0

    enum LimitsState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable(String)
    }
    var limitsState: LimitsState = .idle
    var limits: ClaudeLimits? = nil

    private let reader: ClaudeTranscriptReader
    private var refreshTask: Task<Void, Never>?

    init(reader: ClaudeTranscriptReader) {
        self.reader = reader
    }

    func refresh() async {
        let capturedReader = reader
        let n = Date()
        let records = await Task.detached {
            capturedReader.read(modifiedWithin: 6 * 3600, now: n)
        }.value

        let totals = UsageAggregator.todayTotals(records, now: n)
        todayInput = totals.input
        todayOutput = totals.output
        sessions = UsageAggregator.sessions(records, now: n, activeWithin: 6 * 3600)
        self.now = n
        loaded = true
    }

    func loadUsage() async {
        let capturedReader = reader
        let n = Date()
        let records = await Task.detached {
            capturedReader.read(modifiedWithin: 31 * 24 * 3600, now: n)
        }.value

        daily = UsageAggregator.daily(records, days: 30, now: n)
        byModel = UsageAggregator.byModel(records)
        todayCost = UsageAggregator.cost(records, since: Calendar.current.startOfDay(for: n), now: n)
        cost30d = UsageAggregator.cost(records, since: nil, now: n)
        tokens30d = records.reduce(0) { $0 + $1.totalTokens }
        latestTokens = UsageAggregator.sessions(records, now: n, activeWithin: 86400).first?.totalTokens ?? 0
        self.now = n
    }

    func refreshLimits() async {
        limitsState = .loading
        let result = await ClaudeLimitsClient().fetch()
        switch result {
        case .success(let l):
            limits = l
            limitsState = .loaded
        case .failure(let e):
            limits = nil
            limitsState = .unavailable(errorReason(e))
        }
    }

    private func errorReason(_ error: ClaudeLimitsError) -> String {
        switch error {
        case .noToken:     return "Sign in to Claude Code"
        case .http(let c): return "HTTP \(c)"
        case .network:     return "No connection"
        case .decode:      return "Unavailable"
        }
    }

    func start() async {
        guard refreshTask == nil else { return }
        refreshTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await refresh()
            }
        }
    }
}
