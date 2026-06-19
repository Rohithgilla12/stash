import Testing
import GRDB
import Foundation
@testable import StashApp

@Test func migratorCreatesClipboardWithNewColumns() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    let cols = try q.read { db in try db.columns(in: "clipboard").map(\.name) }
    #expect(Set(cols).isSuperset(of: ["id","kind","text","app","pinned","created_at","title","preview_path","app_bundle_id"]))
}

@Test func migratorUpgradesNodeStyleTableWithoutDataLoss() throws {
    let q = try DatabaseQueue()
    // Simulate the Node server's original CREATE (no title/preview_path).
    try q.write { db in
        try db.execute(sql: """
            CREATE TABLE clipboard (
              id TEXT PRIMARY KEY, kind TEXT NOT NULL, text TEXT, app TEXT,
              pinned INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
            INSERT INTO clipboard (id,kind,text,app,pinned,created_at)
              VALUES ('a','text','hello','Safari',0,123);
        """)
    }
    try StashDatabase.migrator().migrate(q)
    let cols = try q.read { db in try db.columns(in: "clipboard").map(\.name) }
    #expect(cols.contains("title"))
    #expect(cols.contains("preview_path"))
    let still = try q.read { try ClipItem.fetchOne($0, key: "a") }
    #expect(still?.text == "hello")
}
