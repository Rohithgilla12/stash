import GRDB
import Foundation

enum TaskFilter: String, CaseIterable, Sendable {
    case today, upcoming, all, done
}

@MainActor
@Observable
final class TasksViewModel {
    var tasks: [TaskItem] = []
    var filter: TaskFilter = .today

    private let db: any DatabaseWriter
    private let store: TasksStore
    private var observationTask: Task<Void, Never>?

    init(db: any DatabaseWriter, store: TasksStore) {
        self.db = db
        self.store = store
    }

    var visible: [TaskItem] {
        tasks.filter { TasksViewModel.matchesFilter($0, filter) }
    }

    nonisolated static func matchesFilter(_ t: TaskItem, _ f: TaskFilter) -> Bool {
        switch f {
        case .today:
            return t.due == .Today && !t.done
        case .upcoming:
            return (t.due == .Tomorrow || t.due == .Upcoming) && !t.done
        case .done:
            return t.done
        case .all:
            return !t.done
        }
    }

    func startObserving() {
        guard observationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try TaskItem.order(Column("created_at").desc, Column("id").desc).fetchAll(db)
        }
        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await rows in observation.values(in: self.db) {
                    self.tasks = rows
                }
            } catch {
                #if DEBUG
                print("TasksViewModel observation error:", error)
                #endif
            }
        }
    }

    func add(_ rawTitle: String) async {
        let title = rawTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let id = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try? await store.create(title: title, due: .Today, now: now, id: id)
    }

    func toggle(_ task: TaskItem) async {
        try? await store.setDone(id: task.id, done: !task.done)
    }

    func delete(_ task: TaskItem) async {
        try? await store.delete(id: task.id)
    }
}
