import Testing
import GRDB
@testable import StashApp

@Suite struct WindowPresetStoreTests {
    private func makeStore() throws -> (StashDatabase, WindowPresetStore) {
        let db = try StashDatabase(path: ":memory:")
        let store = WindowPresetStore(pool: db.pool)
        return (db, store)
    }

    private func samplePreset(id: String = "p1", name: String = "Half Left", createdAt: Int64 = 1_000_000) -> WindowPreset {
        WindowPreset(
            id: id,
            name: name,
            widthMode: .percent,
            width: 0.5,
            heightMode: .percent,
            height: 1.0,
            anchor: .left,
            xOffset: 0,
            yOffset: 0,
            displayMode: "active",
            displayIndex: 0,
            hotkeyKeyCode: nil,
            hotkeyModifiers: nil,
            createdAt: createdAt
        )
    }

    @Test func upsertAndAll() async throws {
        let (_, store) = try makeStore()
        let preset = samplePreset()
        try await store.upsert(preset)
        let all = try await store.all()
        #expect(all.count == 1)
        #expect(all.first?.id == "p1")
        #expect(all.first?.name == "Half Left")
        #expect(all.first?.widthMode == .percent)
        #expect(all.first?.width == 0.5)
        #expect(all.first?.anchor == .left)
    }

    @Test func roundTrip() async throws {
        let (_, store) = try makeStore()
        let original = samplePreset(id: "rt1")
        try await store.upsert(original)
        let fetched = try await store.all()
        #expect(fetched.first == original)
    }

    @Test func deleteRemovesPreset() async throws {
        let (_, store) = try makeStore()
        try await store.upsert(samplePreset(id: "del1"))
        try await store.delete(id: "del1")
        let all = try await store.all()
        #expect(all.isEmpty)
    }

    @Test func orderingByCreatedAtAsc() async throws {
        let (_, store) = try makeStore()
        try await store.upsert(samplePreset(id: "pa", name: "First", createdAt: 100))
        try await store.upsert(samplePreset(id: "pb", name: "Second", createdAt: 200))
        let all = try await store.all()
        #expect(all.map(\.id) == ["pa", "pb"])
    }

    @Test func upsertUpdatesExisting() async throws {
        let (_, store) = try makeStore()
        var preset = samplePreset(id: "upd1")
        try await store.upsert(preset)
        preset.name = "Updated Name"
        try await store.upsert(preset)
        let all = try await store.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "Updated Name")
    }
}
