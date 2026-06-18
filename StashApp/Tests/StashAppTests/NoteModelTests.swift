import Testing
import GRDB
@testable import StashApp

@Test func noteRoundTripsWithItems() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    var n = Note(id: "n1", title: "Groceries", body: "", color: "#fdf0c2", accent: "#c8642f",
                 kind: .todo, items: [ChecklistItem(t: "milk", done: false), ChecklistItem(t: "eggs", done: true)],
                 onDesktop: false, createdAt: 1, updatedAt: 1)
    try q.write { try n.insert($0) }
    let got = try q.read { try Note.fetchOne($0, key: "n1") }
    #expect(got?.title == "Groceries")
    #expect(got?.kind == .todo)
    #expect(got?.items.count == 2)
    #expect(got?.items[1].done == true)
}

@Test func notesMigrationAddsColumnsLosslessly() throws {
    let q = try DatabaseQueue()
    try q.write { db in
        try db.execute(sql: """
            CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', color TEXT, updated_at INTEGER NOT NULL);
            INSERT INTO notes (id,title,body,color,updated_at) VALUES ('a','hi','b',NULL,5);
        """)
    }
    try StashDatabase.migrator().migrate(q)
    let cols = try q.read { try $0.columns(in: "notes").map(\.name) }
    #expect(Set(cols).isSuperset(of: ["id","title","body","color","updated_at","kind","items","accent","on_desktop","created_at"]))
    let still = try q.read { try Note.fetchOne($0, key: "a") }
    #expect(still?.title == "hi")
    #expect(still?.kind == .text)
}
