import Foundation

struct PaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let kind: String
    let run: @MainActor () -> Void
}
