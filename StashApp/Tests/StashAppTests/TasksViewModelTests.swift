import Testing
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
