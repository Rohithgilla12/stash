import Testing
import GRDB
@testable import StashApp

@Test func testSeedPopulatesSix() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let now: Int64 = 1_000_000
    try await store.seedDefaultsIfEmpty(now: now)
    let all = try await store.all()
    #expect(all.count == 6)
}

@Test func testSeedIsIdempotent() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let now: Int64 = 1_000_000
    try await store.seedDefaultsIfEmpty(now: now)
    try await store.seedDefaultsIfEmpty(now: now)
    let all = try await store.all()
    #expect(all.count == 6)
}

@Test func testAllOrdering() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    try await store.upsert(Snippet(trigger: ":z", label: "Z", expand: "z", dynamic: nil, createdAt: 1))
    try await store.upsert(Snippet(trigger: ":a", label: "A", expand: "a", dynamic: nil, createdAt: 2))
    let all = try await store.all()
    #expect(all.map(\.trigger) == [":a", ":z"])
}

@Test func testUpsertAndDelete() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    try await store.upsert(Snippet(trigger: ":hi", label: "Hi", expand: "Hello!", dynamic: nil, createdAt: 1))
    let before = try await store.all()
    #expect(before.count == 1)
    try await store.delete(trigger: ":hi")
    let after = try await store.all()
    #expect(after.isEmpty)
}
