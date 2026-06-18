import Testing
import GRDB
@testable import StashApp

private func mk(_ id: String, _ text: String, pinned: Bool = false, at: Int64) -> ClipItem {
    ClipItem(id: id, kind: .text, text: text, app: nil, pinned: pinned,
             createdAt: at, title: text, previewPath: nil)
}

@Test func insertAndFetch() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "one", at: 1))
    let all = try await store.all()
    #expect(all.count == 1)
    #expect(all.first?.text == "one")
}

@Test func dedupSkipsIdenticalNewest() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "dup", at: 1))
    try await store.insert(mk("b", "dup", at: 2))
    #expect(try await store.all().count == 1)
}

@Test func capTrimsOldestNonPinned() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool, cap: 2)
    try await store.insert(mk("a", "1", at: 1))
    try await store.insert(mk("b", "2", at: 2))
    try await store.insert(mk("c", "3", at: 3))
    let all = try await store.all()
    #expect(all.count == 2)
    #expect(!all.contains { $0.id == "a" })
}

@Test func pinnedSurvivesCap() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool, cap: 1)
    try await store.insert(mk("a", "keep", pinned: true, at: 1))
    try await store.insert(mk("b", "2", at: 2))
    try await store.insert(mk("c", "3", at: 3))
    let all = try await store.all()
    #expect(all.contains { $0.id == "a" })
}

@Test func setPinnedToggles() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "x", at: 1))
    try await store.setPinned(id: "a", pinned: true)
    #expect(try await store.all().first?.pinned == true)
}
