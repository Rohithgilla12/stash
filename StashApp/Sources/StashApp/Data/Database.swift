import GRDB
import Foundation

enum AppPaths {
    static func baseDir() -> URL {
        if let dir = ProcessInfo.processInfo.environment["STASH_DB_DIR"] {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        return FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Stash", isDirectory: true)
    }
    static func dbURL() -> URL {
        if let p = ProcessInfo.processInfo.environment["STASH_DB"] {
            return URL(fileURLWithPath: p)
        }
        return baseDir().appendingPathComponent("stash.db")
    }
    static func cacheDir() -> URL {
        baseDir().appendingPathComponent("clip-cache", isDirectory: true)
    }
}

struct StashDatabase: Sendable {
    let pool: any DatabaseWriter

    init(path: String) throws {
        let isMemory = path == ":memory:"
        if isMemory {
            let queue = try DatabaseQueue()
            try Self.migrator().migrate(queue)
            pool = queue
        } else {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path).deletingLastPathComponent(),
                withIntermediateDirectories: true)
            var config = Configuration()
            config.prepareDatabase { db in try db.execute(sql: "PRAGMA journal_mode = WAL") }
            let dbPool = try DatabasePool(path: path, configuration: config)
            try Self.migrator().migrate(dbPool)
            pool = dbPool
        }
    }

    static func migrator() -> DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_clipboard") { db in
            if try !db.tableExists("clipboard") {
                try db.create(table: "clipboard") { t in
                    t.column("id", .text).primaryKey()
                    t.column("kind", .text).notNull()
                    t.column("text", .text)
                    t.column("app", .text)
                    t.column("pinned", .integer).notNull().defaults(to: 0)
                    t.column("created_at", .integer).notNull()
                }
            }
        }
        m.registerMigration("v2_clip_previews") { db in
            let cols = try db.columns(in: "clipboard").map(\.name)
            if !cols.contains("title") { try db.alter(table: "clipboard") { $0.add(column: "title", .text) } }
            if !cols.contains("preview_path") { try db.alter(table: "clipboard") { $0.add(column: "preview_path", .text) } }
        }
        m.registerMigration("v3_notes_fields") { db in
            if try !db.tableExists("notes") {
                try db.create(table: "notes") { t in
                    t.column("id", .text).primaryKey()
                    t.column("title", .text).notNull()
                    t.column("body", .text).notNull().defaults(to: "")
                    t.column("color", .text)
                    t.column("updated_at", .integer).notNull().defaults(to: 0)
                }
            }
            let cols = try db.columns(in: "notes").map(\.name)
            if !cols.contains("kind") { try db.alter(table: "notes") { $0.add(column: "kind", .text).notNull().defaults(to: "text") } }
            if !cols.contains("items") { try db.alter(table: "notes") { $0.add(column: "items", .text).notNull().defaults(to: "[]") } }
            if !cols.contains("accent") { try db.alter(table: "notes") { $0.add(column: "accent", .text) } }
            if !cols.contains("on_desktop") { try db.alter(table: "notes") { $0.add(column: "on_desktop", .integer).notNull().defaults(to: 0) } }
            if !cols.contains("created_at") { try db.alter(table: "notes") { $0.add(column: "created_at", .integer).notNull().defaults(to: 0) } }
        }
        m.registerMigration("v4_tasks") { db in
            if try !db.tableExists("tasks") {
                try db.create(table: "tasks") { t in
                    t.column("id", .text).primaryKey()
                    t.column("title", .text).notNull()
                    t.column("done", .integer).notNull().defaults(to: 0)
                    t.column("priority", .text)
                    t.column("due", .text)
                    t.column("project", .text).notNull().defaults(to: "Inbox")
                    t.column("tags", .text).notNull().defaults(to: "[]")
                    t.column("repeat", .text)
                    t.column("subs", .text).notNull().defaults(to: "[]")
                    t.column("source", .text).notNull().defaults(to: "you")
                    t.column("created_at", .integer).notNull()
                    t.column("updated_at", .integer).notNull()
                }
            }
        }
        return m
    }
}
