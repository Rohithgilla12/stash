import Testing
import Foundation
import GRDB
@testable import StashApp

// MARK: - Pure filter tests (nonisolated static, no MainActor needed)

@Test func testMatchesFilterToday() {
    let todayTask = TaskItem(
        id: "t1", title: "Today task", done: false, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let tomorrowTask = TaskItem(
        id: "t2", title: "Tomorrow task", done: false, priority: nil,
        due: .Tomorrow, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let doneTodayTask = TaskItem(
        id: "t3", title: "Done today", done: true, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )

    #expect(TasksViewModel.matchesFilter(todayTask, .today) == true)
    #expect(TasksViewModel.matchesFilter(tomorrowTask, .today) == false)
    #expect(TasksViewModel.matchesFilter(doneTodayTask, .today) == false)
}

@Test func testMatchesFilterUpcoming() {
    let tomorrowTask = TaskItem(
        id: "t1", title: "Tomorrow", done: false, priority: nil,
        due: .Tomorrow, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let upcomingTask = TaskItem(
        id: "t2", title: "Upcoming", done: false, priority: nil,
        due: .Upcoming, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let doneTomorrowTask = TaskItem(
        id: "t3", title: "Done tomorrow", done: true, priority: nil,
        due: .Tomorrow, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let todayTask = TaskItem(
        id: "t4", title: "Today", done: false, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )

    #expect(TasksViewModel.matchesFilter(tomorrowTask, .upcoming) == true)
    #expect(TasksViewModel.matchesFilter(upcomingTask, .upcoming) == true)
    #expect(TasksViewModel.matchesFilter(doneTomorrowTask, .upcoming) == false)
    #expect(TasksViewModel.matchesFilter(todayTask, .upcoming) == false)
}

@Test func testMatchesFilterDone() {
    let doneTask = TaskItem(
        id: "t1", title: "Done", done: true, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let notDoneTask = TaskItem(
        id: "t2", title: "Not done", done: false, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )

    #expect(TasksViewModel.matchesFilter(doneTask, .done) == true)
    #expect(TasksViewModel.matchesFilter(notDoneTask, .done) == false)
}

@Test func testMatchesFilterAll() {
    let todayTask = TaskItem(
        id: "t1", title: "Today", done: false, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let tomorrowTask = TaskItem(
        id: "t2", title: "Tomorrow", done: false, priority: nil,
        due: .Tomorrow, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let upcomingTask = TaskItem(
        id: "t3", title: "Upcoming", done: false, priority: nil,
        due: .Upcoming, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
    let doneTask = TaskItem(
        id: "t4", title: "Done", done: true, priority: nil,
        due: .Today, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )

    #expect(TasksViewModel.matchesFilter(todayTask, .all) == true)
    #expect(TasksViewModel.matchesFilter(tomorrowTask, .all) == true)
    #expect(TasksViewModel.matchesFilter(upcomingTask, .all) == true)
    #expect(TasksViewModel.matchesFilter(doneTask, .all) == false)
}

// MARK: - Due-bucket tests (nonisolated static, no MainActor needed)

@Test func testDueBucketDefaultsToTodayWhenNoDate() {
    // A quick task with no parsed date should land in Today, not Upcoming,
    // so it is visible the moment it is created (the default view is Today).
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(TasksViewModel.dueBucket(for: nil, now: now) == .Today)
}

@Test func testDueBucketClassifiesRelativeDates() {
    let cal = Calendar.current
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let laterToday = cal.date(byAdding: .hour, value: 3, to: now)!
    let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
    let nextWeek = cal.date(byAdding: .day, value: 7, to: now)!

    #expect(TasksViewModel.dueBucket(for: laterToday, now: now) == .Today)
    #expect(TasksViewModel.dueBucket(for: tomorrow, now: now) == .Tomorrow)
    #expect(TasksViewModel.dueBucket(for: nextWeek, now: now) == .Upcoming)
}

// MARK: - Effective-due / rollover tests (nonisolated static, no MainActor needed)

private func datedTask(id: String, dueAtMsAgoDays days: Int, storedDue: TaskDue, from now: Date) -> TaskItem {
    let date = Calendar.current.date(byAdding: .day, value: days, to: now)!
    return TaskItem(
        id: id, title: id, done: false, priority: nil,
        due: storedDue, dueAt: Int64(date.timeIntervalSince1970 * 1000),
        project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 1, updatedAt: 1
    )
}

@Test func testEffectiveDueRollsOverdueIntoToday() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    // Task was filed as "Tomorrow" days ago; its real date is now in the past.
    let stale = datedTask(id: "overdue", dueAtMsAgoDays: -2, storedDue: .Tomorrow, from: now)
    #expect(TasksViewModel.effectiveDue(stale, now: now) == .Today)
    #expect(TasksViewModel.matchesFilter(stale, .today, now: now) == true)
    #expect(TasksViewModel.matchesFilter(stale, .upcoming, now: now) == false)
}

@Test func testEffectiveDueClassifiesDatedTasksByRealDate() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let tomorrow = datedTask(id: "tom", dueAtMsAgoDays: 1, storedDue: .Today, from: now)
    let future = datedTask(id: "fut", dueAtMsAgoDays: 5, storedDue: .Today, from: now)
    #expect(TasksViewModel.effectiveDue(tomorrow, now: now) == .Tomorrow)
    #expect(TasksViewModel.effectiveDue(future, now: now) == .Upcoming)
}

@Test func testEffectiveDueIsStickyForDatelessTasks() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let dateless = TaskItem(
        id: "d1", title: "no date", done: false, priority: nil,
        due: .Today, dueAt: nil, project: "Inbox", tags: [], repeatRule: nil,
        subs: [], source: .you, createdAt: 1, updatedAt: 1
    )
    #expect(TasksViewModel.effectiveDue(dateless, now: now) == .Today)
}

// MARK: - Reschedule helper tests

@Test func testNextWeekendFromWeekday() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    // 2023-11-15 is a Wednesday.
    let wed = cal.date(from: DateComponents(year: 2023, month: 11, day: 15))!
    let sat = TasksViewModel.nextWeekend(from: wed, calendar: cal)
    #expect(cal.component(.weekday, from: sat) == 7) // Saturday
    #expect(cal.dateComponents([.day], from: wed, to: sat).day == 3)
}

@Test func testNextWeekendWhenAlreadyWeekend() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    // 2023-11-18 is a Saturday.
    let sat = cal.date(from: DateComponents(year: 2023, month: 11, day: 18))!
    #expect(TasksViewModel.nextWeekend(from: sat, calendar: cal) == sat)
}

// MARK: - Reordered-global tests (filtered-view drag reordering)

@Test func testReorderedGlobalMovesWithinFullList() {
    let global = ["A", "B", "C", "D", "E"]
    // Today shows A,C,E; user drags C above A → C,A,E
    let result = TasksViewModel.reorderedGlobal(global: global, visibleNewOrder: ["C", "A", "E"])
    #expect(result == ["C", "B", "A", "D", "E"])
}

@Test func testReorderedGlobalPreservesNonVisible() {
    let global = ["A", "B", "C", "D"]
    // Visible is B,D; reorder to D,B. A and C keep their slots.
    let result = TasksViewModel.reorderedGlobal(global: global, visibleNewOrder: ["D", "B"])
    #expect(result == ["A", "D", "C", "B"])
}

@Test func testReorderedGlobalNoOp() {
    let global = ["A", "B", "C"]
    let result = TasksViewModel.reorderedGlobal(global: global, visibleNewOrder: ["A", "C"])
    #expect(result == ["A", "B", "C"])
}

// MARK: - Live observation test

@Test func testLiveObservation() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    try await store.create(title: "Observe me", due: .Today, now: 1_000_000, id: "obs1")
    let vm = await TasksViewModel(db: db.pool, store: store)
    await vm.startObserving()
    var ok = false
    for _ in 0..<40 {
        if await vm.tasks.contains(where: { $0.id == "obs1" }) { ok = true; break }
        try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(ok)
}
