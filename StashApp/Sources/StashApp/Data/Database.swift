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
    let pool: DatabasePool

    init(path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        var config = Configuration()
        config.prepareDatabase { db in try db.execute(sql: "PRAGMA journal_mode = WAL") }
        pool = try DatabasePool(path: path, configuration: config)
        try Self.migrator().migrate(pool)
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
        return m
    }
}
