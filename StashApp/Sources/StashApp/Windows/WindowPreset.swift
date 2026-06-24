import GRDB
import Foundation

enum PresetSizeMode: String, Codable, Sendable { case percent, points }

enum PresetAnchor: String, Codable, CaseIterable, Sendable {
    case center, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
}

// displayMode: "active" (display under the focused window) | "main" | "index" (the displayIndex-th NSScreen)
struct WindowPreset: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var widthMode: PresetSizeMode
    var width: Double          // percent → 0...1 fraction; points → literal pt
    var heightMode: PresetSizeMode
    var height: Double
    var anchor: PresetAnchor
    var xOffset: Double
    var yOffset: Double
    var displayMode: String    // "active" | "main" | "index"
    var displayIndex: Int      // used when displayMode == "index"
    var hotkeyKeyCode: Int?
    var hotkeyModifiers: Int?
    var createdAt: Int64

    static let databaseTableName = "window_presets"
}
