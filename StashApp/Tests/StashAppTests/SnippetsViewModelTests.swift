import Testing
import GRDB
@testable import StashApp

@Test @MainActor func testVMLiveObservation() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let vm = SnippetsViewModel(db: db.pool, store: store)
    vm.startObserving()
    var iterations = 0
    while vm.snippets.isEmpty && iterations < 20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        iterations += 1
    }
    try await store.upsert(Snippet(trigger: ":obs", label: "Obs", expand: "observed", dynamic: nil, createdAt: 1))
    var found = false
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if vm.snippets.contains(where: { $0.trigger == ":obs" }) {
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

@Test @MainActor func testUpdateChangesExpansionAndPersists() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let vm = SnippetsViewModel(db: db.pool, store: store)
    vm.startObserving()
    try await store.upsert(Snippet(trigger: ":hi", label: "Hi", expand: "Hello!", dynamic: nil, createdAt: 1))
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if !vm.snippets.isEmpty { break }
    }
    let updated = Snippet(trigger: ":hi", label: "Hi", expand: "Howdy!", dynamic: nil, createdAt: 1)
    vm.update(updated)
    var found = false
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if vm.snippets.first(where: { $0.trigger == ":hi" })?.expand == "Howdy!" {
            found = true
            break
        }
    }
    #expect(found)
    let all = try await store.all()
    #expect(all.first(where: { $0.trigger == ":hi" })?.expand == "Howdy!")
}

@Test @MainActor func testDeleteRemovesSnippet() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = SnippetsStore(pool: db.pool)
    let vm = SnippetsViewModel(db: db.pool, store: store)
    vm.startObserving()
    let snippet = Snippet(trigger: ":bye", label: "Bye", expand: "Goodbye!", dynamic: nil, createdAt: 1)
    try await store.upsert(snippet)
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if !vm.snippets.isEmpty { break }
    }
    vm.delete(snippet)
    var gone = false
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 50_000_000)
        if vm.snippets.isEmpty {
            gone = true
            break
        }
    }
    #expect(gone)
    let all = try await store.all()
    #expect(all.isEmpty)
}
