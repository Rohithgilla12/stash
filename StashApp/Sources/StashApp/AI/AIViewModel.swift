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
