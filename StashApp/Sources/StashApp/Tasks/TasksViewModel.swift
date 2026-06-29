import GRDB
import Foundation

enum TaskFilter: String, CaseIterable, Sendable {
    case today, upcoming, all, done
}

/// Where a "reschedule" action moves a task.
enum RescheduleTarget: Sendable, Equatable {
    case today, tomorrow, weekend, on(Date), clear
}

@MainActor
@Observable
final class TasksViewModel {
    var tasks: [TaskItem] = []
    var filter: TaskFilter = .today
    var onTasksChanged: (([TaskItem]) -> Void)?

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

    /// The bucket a task belongs in *right now*. Tasks with a real `dueAt` are
    /// classified against the current date so the lists roll over at midnight —
    /// anything due today or earlier (overdue) surfaces in Today. Dateless tasks
    /// stay sticky on the bucket they were filed under (defaults to Today).
    nonisolated static func effectiveDue(_ t: TaskItem, now: Date = Date()) -> TaskDue {
        guard let ms = t.dueAt else { return t.due ?? .Today }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let cal = Calendar.current
        if cal.startOfDay(for: date) <= cal.startOfDay(for: now) { return .Today }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        if cal.isDate(date, inSameDayAs: tomorrow) { return .Tomorrow }
        return .Upcoming
    }

    nonisolated static func matchesFilter(_ t: TaskItem, _ f: TaskFilter, now: Date = Date()) -> Bool {
        switch f {
        case .today:
            return effectiveDue(t, now: now) == .Today && !t.done
        case .upcoming:
            let e = effectiveDue(t, now: now)
            return (e == .Tomorrow || e == .Upcoming) && !t.done
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
                    self.onTasksChanged?(rows)
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
        var dueAtMs = parsed.dueAt.map { Int64($0.timeIntervalSince1970 * 1000) }
        if dueAtMs == nil, let rule = parsed.repeatRule {
            if let anchor = TaskRecurrence.firstAnchor(rule: rule, from: nowDate) {
                dueAtMs = Int64(anchor.timeIntervalSince1970 * 1000)
            }
        }
        let due = Self.dueBucket(for: dueAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }, now: nowDate)
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

    /// Buckets a parsed due date. A task with no date defaults to Today so it is
    /// visible the moment it is created (the default Tasks view is Today).
    nonisolated static func dueBucket(for date: Date?, now: Date) -> TaskDue {
        guard let date else { return .Today }
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return .Today }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        if cal.isDate(date, inSameDayAs: tomorrow) { return .Tomorrow }
        return .Upcoming
    }

    /// The Saturday of the current weekend (today if it is already the weekend).
    nonisolated static func nextWeekend(from date: Date, calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: date)  // 1=Sun … 7=Sat
        if weekday == 7 || weekday == 1 { return date }         // already the weekend
        return calendar.date(byAdding: .day, value: 7 - weekday, to: date) ?? date
    }

    /// Moves a task to a new day. Concrete days get a noon `dueAt` (so reminders
    /// don't fire at midnight) and a freshly-computed bucket; `.clear` drops the
    /// date and returns it to the sticky Today list.
    func reschedule(_ task: TaskItem, to target: RescheduleTarget) async {
        var t = task
        let now = Date()
        let cal = Calendar.current
        let day: Date?
        switch target {
        case .today:    day = now
        case .tomorrow: day = cal.date(byAdding: .day, value: 1, to: now)
        case .weekend:  day = Self.nextWeekend(from: now, calendar: cal)
        case .on(let d): day = d
        case .clear:    day = nil
        }
        if let day {
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? cal.startOfDay(for: day)
            t.dueAt = Int64(noon.timeIntervalSince1970 * 1000)
            t.due = Self.dueBucket(for: noon, now: now)
        } else {
            t.dueAt = nil
            t.due = .Today
        }
        try? await store.upsert(t)
    }

    func toggle(_ task: TaskItem) async {
        let markingDone = !task.done
        try? await store.setDone(id: task.id, done: markingDone)
        if markingDone, let next = TaskRecurrence.spawnNext(from: task, now: Date()) {
            try? await store.upsert(next)
        }
    }

    func delete(_ task: TaskItem) async {
        try? await store.delete(id: task.id)
    }
}
