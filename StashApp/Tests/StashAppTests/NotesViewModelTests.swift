import Testing
@testable import StashApp

@Test func startObservingPopulatesNotes() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = NotesStore(pool: db.pool)
    _ = try await store.create(now: 1, id: "n1")
    let vm = await NotesViewModel(db: db, store: store)
    await vm.startObserving()
    var ok = false
    for _ in 0..<40 { if await vm.notes.contains(where: { $0.id == "n1" }) { ok = true; break }; try? await Task.sleep(for: .milliseconds(50)) }
    #expect(ok)
}
