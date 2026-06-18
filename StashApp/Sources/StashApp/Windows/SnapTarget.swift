import Foundation

enum SnapTarget: String, CaseIterable, Identifiable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftThird
    case centerThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case fullScreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .rightTwoThirds: return "Right Two Thirds"
        case .fullScreen: return "Full Screen"
        }
    }

    var hotkey: String {
        switch self {
        case .leftHalf: return "⌃⌥←"
        case .rightHalf: return "⌃⌥→"
        case .topHalf: return "⌃⌥↑"
        case .bottomHalf: return "⌃⌥↓"
        case .topLeft: return "⌃⌥U"
        case .topRight: return "⌃⌥I"
        case .bottomLeft: return "⌃⌥J"
        case .bottomRight: return "⌃⌥K"
        case .leftThird: return "⌃⌥D"
        case .centerThird: return "⌃⌥F"
        case .rightThird: return "⌃⌥G"
        case .leftTwoThirds: return "⌃⌥E"
        case .rightTwoThirds: return "⌃⌥T"
        case .fullScreen: return "⌃⌥↩"
        }
    }

    var group: String {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            return "Halves"
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return "Quarters"
        case .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds:
            return "Thirds"
        case .fullScreen:
            return "Full Screen"
        }
    }
}
