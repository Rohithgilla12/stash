import GRDB

struct Snippet: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var trigger: String
    var label: String
    var expand: String?
    var dynamic: String?
    var createdAt: Int64

    var id: String { trigger }

    static let databaseTableName = "snippets"

    enum CodingKeys: String, CodingKey {
        case trigger, label, expand, dynamic
        case createdAt = "created_at"
    }
}
