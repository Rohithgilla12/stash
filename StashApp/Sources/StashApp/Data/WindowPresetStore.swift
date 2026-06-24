import Foundation
import GRDB

actor WindowPresetStore {
    private let pool: any DatabaseWriter

    init(pool: any DatabaseWriter) {
        self.pool = pool
    }

    func all() throws -> [WindowPreset] {
        try pool.read { db in
            try WindowPreset.order(Column("created_at").desc, Column("id").desc).fetchAll(db)
        }
    }

    func upsert(_ preset: WindowPreset) throws {
        try pool.write { try preset.save($0) }
    }

    func delete(id: String) throws {
        try pool.write { try WindowPreset.deleteOne($0, key: id) }
    }
}
