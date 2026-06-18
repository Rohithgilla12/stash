import Testing
import GRDB
@testable import StashApp

@Test func createReturnsNoteAndAllHasOne() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = NotesStore(pool: db.pool)
    let now: Int64 = 1_000_000
    let note = try await store.create(now: now, id: "n1")
    #expect(note.id == "n1")
    #expect(note.title == "")
    #expect(note.body == "")
    #expect(note.color == "#fdf0c2")
    #expect(note.accent == "#c8642f")
    #expect(note.kind == .text)
    #expect(note.items == [])
    #expect(note.onDesktop == false)
    #expect(note.createdAt == now)
    #expect(note.updatedAt == now)
    let all = try await store.all()
    #expect(all.count == 1)
}

@Test func upsertUpdatesTitle() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = NotesStore(pool: db.pool)
    var note = try await store.create(now: 1, id: "n2")
    note.title = "Hello"
    note.updatedAt = 2
    try await store.upsert(note)
    let all = try await store.all()
    #expect(all.count == 1)
    #expect(all.first?.title == "Hello")
}

@Test func deleteRemovesNote() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = NotesStore(pool: db.pool)
    try await store.create(now: 1, id: "n3")
    try await store.delete(id: "n3")
    let all = try await store.all()
    #expect(all.isEmpty)
}

@Test func allOrderedByUpdatedAtDesc() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = NotesStore(pool: db.pool)
    try await store.create(now: 1, id: "a")
    try await store.create(now: 3, id: "b")
    try await store.create(now: 2, id: "c")
    let all = try await store.all()
    #expect(all.map(\.id) == ["b", "c", "a"])
}
