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
        let raw = rawTitle.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let nowDate = Date()
        let parsed = TaskQuickParse.parse(raw, now: nowDate)
        let id = UUID().uuidString
        let nowMs = Int64(nowDate.timeIntervalSince1970 * 1000)
        let dueAtMs = parsed.dueAt.map { Int64($0.timeIntervalSince1970 * 1000) }
        let due = dueBucket(for: parsed.dueAt, now: nowDate)
        try? await store.create(
            title: parsed.title,
            due: due,
            now: nowMs,
            id: id,
            dueAt: dueAtMs,
            priority: parsed.priority,
            repeatRule: parsed.repeatRule
        )
    }

    private func dueBucket(for date: Date?, now: Date) -> TaskDue {
        guard let date else { return .Upcoming }
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return .Today }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        if cal.isDate(date, inSameDayAs: tomorrow) { return .Tomorrow }
        return .Upcoming
    }

    func toggle(_ task: TaskItem) async {
        try? await store.setDone(id: task.id, done: !task.done)
    }

    func delete(_ task: TaskItem) async {
        try? await store.delete(id: task.id)
    }
}
