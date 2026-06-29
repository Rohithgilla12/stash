import Testing
import GRDB
@testable import StashApp

@Test func testCreateAndAll() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    let now: Int64 = 1_000_000
    let task = try await store.create(title: "Buy milk", due: .Today, now: now, id: "t1")
    #expect(task.id == "t1")
    #expect(task.title == "Buy milk")
    #expect(task.due == .Today)
    #expect(task.done == false)
    #expect(task.project == "Inbox")
    #expect(task.source == .you)
    #expect(task.tags == [])
    #expect(task.subs == [])
    #expect(task.createdAt == now)
    #expect(task.updatedAt == now)
    let all = try await store.all()
    #expect(all.count == 1)
    #expect(all.first?.id == "t1")
}

@Test func testSetDoneToggles() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    try await store.create(title: "Write tests", due: .Tomorrow, now: 1, id: "t2")
    try await store.setDone(id: "t2", done: true)
    let allAfterTrue = try await store.all()
    #expect(allAfterTrue.first?.done == true)
    try await store.setDone(id: "t2", done: false)
    let allAfterFalse = try await store.all()
    #expect(allAfterFalse.first?.done == false)
}

@Test func testDelete() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    try await store.create(title: "Delete me", due: .Upcoming, now: 1, id: "t3")
    try await store.delete(id: "t3")
    let all = try await store.all()
    #expect(all.isEmpty)
}

@Test func testOrdering() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    try await store.create(title: "First created", due: .Today, now: 100, id: "ta")
    try await store.create(title: "Second created", due: .Today, now: 200, id: "tb")
    let all = try await store.all()
    #expect(all.map(\.id) == ["tb", "ta"])
}

@Test func testOrderingFollowsOrderIndex() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    // Insert with explicit order_index out of created_at order.
    try await store.upsert(TaskItem(
        id: "low", title: "low", done: false, priority: nil, due: .Today,
        dueAt: nil, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 100, updatedAt: 100, orderIndex: 5))
    try await store.upsert(TaskItem(
        id: "high", title: "high", done: false, priority: nil, due: .Today,
        dueAt: nil, project: "Inbox", tags: [], repeatRule: nil, subs: [],
        source: .you, createdAt: 200, updatedAt: 200, orderIndex: -3))
    let all = try await store.all()
    #expect(all.map(\.id) == ["high", "low"]) // -3 before 5
}

@Test func testCreatePutsNewTaskAtTop() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    let first = try await store.create(title: "first", due: .Today, now: 100, id: "f")
    let second = try await store.create(title: "second", due: .Today, now: 200, id: "s")
    #expect(second.orderIndex! < first.orderIndex!)
    let all = try await store.all()
    #expect(all.map(\.id) == ["s", "f"]) // newest at top
}

@Test func testReorderRenumbers() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = TasksStore(pool: db.pool)
    try await store.create(title: "a", due: .Today, now: 1, id: "a")
    try await store.create(title: "b", due: .Today, now: 2, id: "b")
    try await store.create(title: "c", due: .Today, now: 3, id: "c")
    try await store.reorder(idsInOrder: ["a", "b", "c"])
    let all = try await store.all()
    #expect(all.map(\.id) == ["a", "b", "c"])
    #expect(all.map(\.orderIndex) == [0, 1, 2])
}
