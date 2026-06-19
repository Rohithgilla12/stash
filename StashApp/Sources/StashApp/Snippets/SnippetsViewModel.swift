import Foundation
import GRDB

@MainActor
@Observable
final class SnippetsViewModel {
    var snippets: [Snippet] = [] {
        didSet { onSnippetsChanged?(snippets) }
    }
    var demoText: String = ""
    var lastExpanded: String?

    var expanderEnabled: Bool {
        didSet {
            let requested = expanderEnabled
            let actual = onExpanderToggled?(requested) ?? requested
            UserDefaults.standard.set(actual, forKey: "expanderEnabled")
            // If the install failed, revert the toggle to reflect the real state.
            // The recursive didSet will also compute actual == false, and since the
            // hook returns false == newValue the guard below prevents a third pass.
            if actual != requested {
                expanderEnabled = actual
            }
        }
    }

    var onExpanderToggled: ((Bool) -> Bool)?
    var onSnippetsChanged: (([Snippet]) -> Void)?

    private let db: any DatabaseWriter
    private let store: SnippetsStore
    private var observationTask: Task<Void, Never>?

    init(db: any DatabaseWriter, store: SnippetsStore) {
        self.db = db
        self.store = store
        self.expanderEnabled = UserDefaults.standard.bool(forKey: "expanderEnabled")
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
        do {
            try await store.seedDefaultsIfEmpty(now: now)
        } catch {
            #if DEBUG
            print("SnippetsViewModel seed error:", error)
            #endif
        }
    }

    func onDemoChange() {
        let current = demoText
        guard let result = ExpansionEngine.expanded(buffer: current, snippets: snippets, now: Date()),
              result.text != current else { return }
        demoText = result.text
        lastExpanded = result.expandedTrigger
    }

    func insert(_ s: Snippet) {
        guard !s.trigger.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            do {
                try await store.upsert(s)
            } catch {
                #if DEBUG
                print("SnippetsViewModel insert error:", error)
                #endif
            }
        }
    }

    func update(_ s: Snippet) {
        Task {
            do {
                try await store.upsert(s)
            } catch {
                #if DEBUG
                print("SnippetsViewModel update error:", error)
                #endif
            }
        }
    }

    func delete(_ s: Snippet) {
        Task {
            do {
                try await store.delete(trigger: s.trigger)
            } catch {
                #if DEBUG
                print("SnippetsViewModel delete error:", error)
                #endif
            }
        }
    }
}
