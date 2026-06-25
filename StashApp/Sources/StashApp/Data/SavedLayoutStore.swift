import Foundation
import GRDB

actor SavedLayoutStore {
    private let pool: any DatabaseWriter
    init(pool: any DatabaseWriter) { self.pool = pool }
    func all() throws -> [SavedLayout] {
        try pool.read { try SavedLayout.order(Column("created_at"), Column("id")).fetchAll($0) }
    }
    func upsert(_ layout: SavedLayout) throws { try pool.write { try layout.save($0) } }
    func delete(id: String) throws { try pool.write { try SavedLayout.deleteOne($0, key: id) } }
}
