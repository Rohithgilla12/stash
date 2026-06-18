import GRDB
import Foundation

struct ChecklistItem: Codable, Sendable, Equatable {
    var t: String
    var done: Bool

    init(t: String, done: Bool) {
        self.t = t
        self.done = done
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        t = try c.decode(String.self, forKey: .t)
        if let b = try? c.decode(Bool.self, forKey: .done) {
            done = b
        } else {
            done = (try c.decode(Int.self, forKey: .done)) != 0
        }
    }
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
