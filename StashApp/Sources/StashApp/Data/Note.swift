import GRDB
import Foundation

struct ChecklistItem: Codable, Sendable, Equatable {
    var t: String
    var done: Bool
}

struct Note: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var body: String
    var color: String?
    var accent: String?
    var kind: NoteKind
    var items: [ChecklistItem]
    var onDesktop: Bool
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "notes"

    enum CodingKeys: String, CodingKey {
        case id, title, body, color, accent, kind, items
        case onDesktop = "on_desktop"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
