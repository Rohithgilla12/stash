import Foundation
import GRDB

@MainActor
@Observable
final class SnippetsViewModel {
    var snippets: [Snippet] = []
    var demoText: String = ""
    var lastExpanded: String?

    private let db: any DatabaseWriter
    private let store: SnippetsStore
    private var observationTask: Task<Void, Never>?

    init(db: any DatabaseWriter, store: SnippetsStore) {
        self.db = db
        self.store = store
    }

    func startObserving() {
        guard observationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try Snippet.order(Column("trigger").asc).fetchAll(db)
        }
        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await rows in observation.values(in: self.db) {
                    self.snippets = rows
                }
            } catch {
                #if DEBUG
                print("SnippetsViewModel observation error:", error)
                #endif
            }
        }
    }

    func seed() async {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try? await store.seedDefaultsIfEmpty(now: now)
    }

    func onDemoChange() {
        guard let result = ExpansionEngine.expanded(buffer: demoText, snippets: snippets, now: Date()) else { return }
        demoText = result.text
        lastExpanded = result.expandedTrigger
    }

    func insert(_ s: Snippet) {
        let resolved = ExpansionEngine.resolve(s, now: Date())
        demoText += resolved
    }
}
