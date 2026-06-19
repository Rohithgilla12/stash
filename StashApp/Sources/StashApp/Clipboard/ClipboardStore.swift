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
            try ClipItem.order(Column("created_at").desc, Column("id").desc).fetchOne(db)
        }
    }

    @discardableResult
    func insert(_ item: ClipItem) throws -> [String] {
        if let last = try newest(),
           last.kind == item.kind, last.text == item.text, last.title == item.title {
            return []
        }
        return try pool.write { db in
            try item.insert(db)
            return try Self.trim(db, cap: cap)
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
                .order(Column("pinned").desc, Column("created_at").desc, Column("id").desc)
                .fetchAll(db)
        }
    }

    func delete(id: String) throws {
        _ = try pool.write { db in
            try ClipItem.deleteOne(db, key: id)
        }
    }

    func clearAll() throws {
        _ = try pool.write { db in
            try db.execute(sql: "DELETE FROM clipboard")
        }
    }

    func clearUnpinned() throws {
        _ = try pool.write { db in
            try db.execute(sql: "DELETE FROM clipboard WHERE pinned = 0")
        }
    }

    private static func trim(_ db: Database, cap: Int) throws -> [String] {
        let predicate = """
            pinned = 0 AND id NOT IN (
              SELECT id FROM clipboard WHERE pinned = 0
              ORDER BY created_at DESC, id DESC LIMIT \(cap))
            """
        let doomed = try String.fetchAll(db, sql:
            "SELECT preview_path FROM clipboard WHERE preview_path IS NOT NULL AND \(predicate)")
        try db.execute(sql: "DELETE FROM clipboard WHERE \(predicate)")
        return doomed
    }
}
