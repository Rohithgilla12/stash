import Testing
import GRDB
@testable import StashApp

@Suite struct SavedLayoutTests {
    @Test func entriesRoundTrip() {
        let e = [LayoutEntry(bundleId: "com.apple.Safari", appName: "Safari", x: 0, y: 0, width: 800, height: 600, displayIndex: 0)]
        let l = SavedLayout(id: "1", name: "Work", entriesJSON: SavedLayout.encode(e), hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: 1)
        #expect(l.entries == e)
    }

    private func makeStore() throws -> SavedLayoutStore {
        let q = try DatabaseQueue()
        try q.write { db in
            try db.create(table: "saved_layouts") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("entries_json", .text).notNull().defaults(to: "[]")
                t.column("hotkey_key_code", .integer)
                t.column("hotkey_modifiers", .integer)
                t.column("created_at", .integer).notNull()
            }
        }
        return SavedLayoutStore(pool: q)
    }

    private func sample(id: String = "l1", name: String = "Work", createdAt: Int64 = 1_000) -> SavedLayout {
        SavedLayout(id: id, name: name, entriesJSON: "[]", hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: createdAt)
    }

    @Test func upsertAndAll() async throws {
        let store = try makeStore()
        try await store.upsert(sample())
        let all = try await store.all()
        #expect(all.count == 1)
        #expect(all.first?.id == "l1")
        #expect(all.first?.name == "Work")
    }

    @Test func deleteRemovesLayout() async throws {
        let store = try makeStore()
        try await store.upsert(sample(id: "del1"))
        try await store.delete(id: "del1")
        let all = try await store.all()
        #expect(all.isEmpty)
    }

    @Test func orderingByCreatedAtAsc() async throws {
        let store = try makeStore()
        try await store.upsert(sample(id: "la", name: "First", createdAt: 100))
        try await store.upsert(sample(id: "lb", name: "Second", createdAt: 200))
        let all = try await store.all()
        #expect(all.map(\.id) == ["la", "lb"])
    }

    @Test func upsertUpdatesExisting() async throws {
        let store = try makeStore()
        var layout = sample(id: "upd1")
        try await store.upsert(layout)
        layout.name = "Updated"
        try await store.upsert(layout)
        let all = try await store.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "Updated")
    }
}
