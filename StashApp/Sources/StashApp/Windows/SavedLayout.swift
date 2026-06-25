import GRDB
import Foundation

struct LayoutEntry: Codable, Sendable, Equatable {
    let bundleId: String
    let appName: String
    let x: Double; let y: Double; let width: Double; let height: Double  // AX global coords
    let displayIndex: Int
    var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct SavedLayout: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var entriesJSON: String
    var hotkeyKeyCode: Int?
    var hotkeyModifiers: Int?
    var createdAt: Int64

    static let databaseTableName = "saved_layouts"
    enum CodingKeys: String, CodingKey {
        case id, name
        case entriesJSON = "entries_json"
        case hotkeyKeyCode = "hotkey_key_code"
        case hotkeyModifiers = "hotkey_modifiers"
        case createdAt = "created_at"
    }

    var entries: [LayoutEntry] {
        (try? JSONDecoder().decode([LayoutEntry].self, from: Data(entriesJSON.utf8))) ?? []
    }
    static func encode(_ entries: [LayoutEntry]) -> String {
        guard let data = try? JSONEncoder().encode(entries),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}
