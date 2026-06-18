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
