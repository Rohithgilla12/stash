import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum Tokens {
    static let accent = Color(hex: "#c8642f")
    static let panelFill = Color(.sRGB, red: 252/255, green: 250/255, blue: 246/255, opacity: 0.93)
    static let textPrimary = Color(hex: "#2c2925")
    static let textSecondary = Color(hex: "#6b655c")
    static let textTertiary = Color(hex: "#9a948a")
    static let priorityHigh = accent
    static let priorityMed = Color(hex: "#d8a13a")
    static let priorityLow = Color(hex: "#b3a99b")
    static let panelRadius: CGFloat = 16
    static let rowRadius: CGFloat = 9
    static let panelWidth: CGFloat = 456
    static let panelHeight: CGFloat = 560
    static let contentMaxHeight: CGFloat = 600
    static let thumbSize = CGSize(width: 58, height: 38)

    static let hairline = Color(hex: "#2c2925").opacity(0.06)
    static let rowHover = Color(hex: "#2c2925").opacity(0.04)
    static let rowSelected = accent.opacity(0.10)
    static let surface = Color(.sRGB, red: 1, green: 0.996, blue: 0.99, opacity: 0.6)

    static let linkColor = Color(hex: "#5b86b8")
    static let imageColor = Color(hex: "#8a6db0")
    static let codeColor = Color(hex: "#5f7a8a")
    static let textColor = Color(hex: "#9a8c7a")

    static let running = Color(hex: "#3fa45b")
    static let waiting = Color(hex: "#d8a13a")
    static let idle = Color(hex: "#a39a8c")
}
