import GRDB

actor ClipboardStore {
    private let pool: any DatabaseWriter
    private let cap: Int

    init(pool: any DatabaseWriter, cap: Int = 200) {
        self.pool = pool
        self.cap = cap
    }

    func newest() throws -> ClipItem? {
        try pool.read { db in
            try ClipItem.order(Column("created_at").desc).fetchOne(db)
        }
    }

    func insert(_ item: ClipItem) throws {
        if let last = try newest(),
           last.kind == item.kind, last.text == item.text, last.title == item.title {
            return
        }
        try pool.write { db in
            try item.insert(db)
            try Self.trim(db, cap: cap)
        }
    }

    func setPinned(id: String, pinned: Bool) throws {
        _ = try pool.write { db in
            try ClipItem.filter(key: id).updateAll(db, Column("pinned").set(to: pinned))
        }
    }

    func all() throws -> [ClipItem] {
        try pool.read { db in
            try ClipItem
                .order(Column("pinned").desc, Column("created_at").desc)
                .fetchAll(db)
        }
    }

    private static func trim(_ db: Database, cap: Int) throws {
        try db.execute(sql: """
            DELETE FROM clipboard
            WHERE pinned = 0 AND id NOT IN (
              SELECT id FROM clipboard WHERE pinned = 0
              ORDER BY created_at DESC LIMIT ?)
            """, arguments: [cap])
    }
}
