import Foundation
import GRDB

actor SnippetsStore {
    private let pool: any DatabaseWriter

    init(pool: any DatabaseWriter) {
        self.pool = pool
    }

    func all() throws -> [Snippet] {
        try pool.read { db in
            try Snippet.order(Column("trigger").asc).fetchAll(db)
        }
    }

    func upsert(_ snippet: Snippet) throws {
        try pool.write { try snippet.save($0) }
    }

    func delete(trigger: String) throws {
        try pool.write { try Snippet.deleteOne($0, key: trigger) }
    }

    func seedDefaultsIfEmpty(now: Int64) throws {
        let count = try pool.read { db in try Snippet.fetchCount(db) }
        guard count == 0 else { return }
        let defaults: [Snippet] = [
            Snippet(trigger: ":sig",   label: "Signature",  expand: "— Rohith",              dynamic: nil,     createdAt: now),
            Snippet(trigger: ":addr",  label: "Address",    expand: "123 Main St, City, ST",  dynamic: nil,     createdAt: now),
            Snippet(trigger: ":ty",    label: "Thank you!", expand: "Thank you!",              dynamic: nil,     createdAt: now),
            Snippet(trigger: ":cal",   label: "Calendar",   expand: "Let's find a time: ",     dynamic: nil,     createdAt: now),
            Snippet(trigger: ":date",  label: "Date",       expand: nil,                       dynamic: "date",  createdAt: now),
            Snippet(trigger: ":shrug", label: "Shrug",      expand: nil,                       dynamic: "shrug", createdAt: now),
        ]
        try pool.write { db in
            for s in defaults { try s.save(db) }
        }
    }
}
