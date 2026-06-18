import Testing
import GRDB
@testable import StashApp

@Test func testVMLiveObservation() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let vm = await SnippetsViewModel(db: db.pool, store: store)
    await vm.startObserving()
    var iterations = 0
    while await vm.snippets.isEmpty == false && iterations < 20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        iterations += 1
    }
    try await store.upsert(Snippet(trigger: ":obs", label: "Obs", expand: "observed", dynamic: nil, createdAt: 1))
    var found = false
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if await vm.snippets.contains(where: { $0.trigger == ":obs" }) {
            found = true
            break
        }
    }
    #expect(found)
}

@Test @MainActor func testOnDemoChangeExpandsShrug() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let vm = SnippetsViewModel(db: db.pool, store: store)
    try await store.upsert(Snippet(trigger: ":shrug", label: "Shrug", expand: nil, dynamic: "shrug", createdAt: 1))
    await vm.startObserving()
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if !vm.snippets.isEmpty { break }
    }
    vm.demoText = "hello :shrug"
    vm.onDemoChange()
    #expect(vm.demoText.hasSuffix("¯\\_(ツ)_/¯"))
    #expect(vm.lastExpanded == ":shrug")
}
