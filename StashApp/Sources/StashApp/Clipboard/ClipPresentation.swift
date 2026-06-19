import SwiftUI

enum ClipPresentation {

    struct Style {
        let icon: String
        let tint: Color
        let label: String
    }

    static func style(for item: ClipItem) -> Style {
        switch item.kind {
        case .image:
            return Style(icon: "photo", tint: Tokens.imageColor, label: "IMAGE")
        case .link:
            return Style(icon: "link", tint: Tokens.linkColor, label: "LINK")
        case .text:
            if detectedColor(in: item.text) != nil {
                let swatchColor = detectedColor(in: item.text) ?? Tokens.textColor
                return Style(icon: "circle.fill", tint: swatchColor, label: "COLOR")
            }
            if isCodeish(item.text) {
                return Style(icon: "chevron.left.forwardslash.chevron.right", tint: Tokens.codeColor, label: "CODE")
            }
            return Style(icon: "text.alignleft", tint: Tokens.textColor, label: "TEXT")
        }
    }

    static func metaLine(for item: ClipItem, now: Date = Date()) -> String {
        let timestamp = relativeTime(from: Date(timeIntervalSince1970: TimeInterval(item.createdAt) / 1000), to: now)
        let size = sizeDescription(for: item)
        return [timestamp, item.app, size].compactMap { $0 }.joined(separator: " · ")
    }

    static func detectedColor(in text: String?) -> Color? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }

        let hex6 = /^#?([0-9A-Fa-f]{6})$/
        let hex3 = /^#?([0-9A-Fa-f]{3})$/

        if let match = text.wholeMatch(of: hex6) {
            return Color(hex: String(match.1))
        }

        if let match = text.wholeMatch(of: hex3) {
            let s = String(match.1)
            let expanded = s.map { "\($0)\($0)" }.joined()
            return Color(hex: expanded)
        }

        return nil
    }

    private static func isCodeish(_ text: String?) -> Bool {
        guard let text else { return false }
        let codeSignals = ["{", ";", "func ", "=>", "->", "import ", "class ", "struct ", "const ", "let ", "var "]
        let signalCount = codeSignals.filter { text.contains($0) }.count
        if signalCount >= 2 { return true }
        let lines = text.components(separatedBy: "\n")
        if lines.count >= 3 {
            let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
            if indented.count >= 2 { return true }
        }
        return false
    }

    private static func sizeDescription(for item: ClipItem) -> String? {
        switch item.kind {
        case .image:
            return "image"
        case .text, .link:
            guard let text = item.text else { return nil }
            let count = text.count
            return "\(count) char\(count == 1 ? "" : "s")"
        }
    }

    private static func relativeTime(from date: Date, to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }

        let days = seconds / 86400
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days)d" }
        if days < 30 { return "\(days / 7)w" }
        return "\(days / 30)mo"
    }
}
