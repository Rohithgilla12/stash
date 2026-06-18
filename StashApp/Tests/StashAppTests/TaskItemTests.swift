import Testing
import GRDB
@testable import StashApp

@Test func testRoundTrip() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    let item = TaskItem(
        id: "t1",
        title: "Write tests",
        done: false,
        priority: .high,
        due: .Today,
        project: "Inbox",
        tags: ["work", "eng"],
        repeatRule: "daily",
        subs: [ChecklistItem(t: "sub", done: false)],
        source: .claude,
        createdAt: 1_000_000,
        updatedAt: 1_000_001
    )
    try q.write { try item.insert($0) }
    let got = try q.read { try TaskItem.fetchOne($0, key: "t1") }
    #expect(got?.id == "t1")
    #expect(got?.title == "Write tests")
    #expect(got?.done == false)
    #expect(got?.priority == .high)
    #expect(got?.due == .Today)
    #expect(got?.project == "Inbox")
    #expect(got?.tags == ["work", "eng"])
    #expect(got?.repeatRule == "daily")
    #expect(got?.subs.count == 1)
    #expect(got?.subs[0].t == "sub")
    #expect(got?.subs[0].done == false)
    #expect(got?.source == .claude)
    #expect(got?.createdAt == 1_000_000)
    #expect(got?.updatedAt == 1_000_001)
}

@Test func testRawMCPSQLDecode() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    try q.write { db in
        try db.execute(sql: """
            INSERT INTO tasks (id, title, done, priority, due, project, tags, "repeat", subs, source, created_at, updated_at)
            VALUES ('mcp-1', 'Plan day', 0, 'high', 'Today', 'Inbox', '["eng","daily"]', 'weekly', '[{"t":"step1","done":0}]', 'claude', 1718700000, 1718700000)
        """)
    }
    let got = try q.read { db in
        try TaskItem.fetchOne(db, sql: "SELECT * FROM tasks WHERE id='mcp-1'")
    }
    #expect(got?.id == "mcp-1")
    #expect(got?.title == "Plan day")
    #expect(got?.source == .claude)
    #expect(got?.priority == .high)
    #expect(got?.tags == ["eng", "daily"])
    #expect(got?.subs.count == 1)
    #expect(got?.subs[0].t == "step1")
}
