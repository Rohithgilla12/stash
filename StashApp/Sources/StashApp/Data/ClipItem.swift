import GRDB

struct ClipItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var kind: ClipKind
    var text: String?
    var app: String?
    var pinned: Bool
    var createdAt: Int64
    var title: String?
    var previewPath: String?

    static let databaseTableName = "clipboard"

    enum CodingKeys: String, CodingKey {
        case id, kind, text, app, pinned
        case createdAt = "created_at"
        case title
        case previewPath = "preview_path"
    }
}
