import Testing
import GRDB
@testable import StashApp

private func mk(_ id: String, _ text: String, pinned: Bool = false, at: Int64) -> ClipItem {
    ClipItem(id: id, kind: .text, text: text, app: nil, pinned: pinned,
             createdAt: at, title: text, previewPath: nil)
}

private func mkImage(_ id: String, previewPath: String, at: Int64) -> ClipItem {
    ClipItem(id: id, kind: .image, text: nil, app: nil, pinned: false,
             createdAt: at, title: "Image", previewPath: previewPath)
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

@Test func trimReturnsEvictedPreviewPaths() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool, cap: 1)
    try await store.insert(mkImage("a", previewPath: "/tmp/x/a_thumb.png", at: 1))
    let evicted = try await store.insert(mk("b", "two", at: 2))
    _ = try await store.insert(mk("c", "three", at: 3))
    #expect(evicted.contains("/tmp/x/a_thumb.png"))
}

@Test func deleteRemovesOneItem() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "first", at: 1))
    try await store.insert(mk("b", "second", at: 2))
    try await store.delete(id: "a")
    let all = try await store.all()
    #expect(all.count == 1)
    #expect(all.first?.id == "b")
}

@Test func clearUnpinnedLeavesOnlyPinned() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "pinned-item", pinned: true, at: 1))
    try await store.insert(mk("b", "unpinned-item", at: 2))
    try await store.clearUnpinned()
    let all = try await store.all()
    #expect(all.count == 1)
    #expect(all.first?.id == "a")
}

@Test func clearAllRemovesEverything() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "first", at: 1))
    try await store.insert(mk("b", "second", at: 2))
    try await store.clearAll()
    #expect(try await store.all().isEmpty)
}
