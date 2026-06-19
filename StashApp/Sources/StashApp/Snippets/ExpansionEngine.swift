import Foundation

enum ExpansionEngine {
    static func resolve(_ s: Snippet, now: Date) -> String {
        if let gen = s.dynamic {
            switch gen {
            case "date":
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .none
                return f.string(from: now)
            case "time":
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                return f.string(from: now)
            case "shrug":
                return "¯\\_(ツ)_/¯"
            default:
                return s.expand ?? ""
            }
        }
        return s.expand ?? ""
    }

    static func match(buffer: String, snippets: [Snippet], now: Date) -> (matchLength: Int, replacement: String)? {
        let candidates = snippets.filter { buffer.hasSuffix($0.trigger) }
        if let best = candidates.max(by: { $0.trigger.count < $1.trigger.count }) {
            return (best.trigger.count, resolve(best, now: now))
        }
        return emojiMatch(buffer)
    }

    static func emojiMatch(_ buffer: String) -> (matchLength: Int, replacement: String)? {
        guard buffer.hasSuffix(":") else { return nil }
        let withoutLast = buffer.dropLast()
        guard let openIdx = withoutLast.lastIndex(of: ":") else { return nil }
        let codeStart = withoutLast.index(after: openIdx)
        let code = String(withoutLast[codeStart...])
        guard !code.isEmpty else { return nil }
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "_+-"))
        guard code.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        let lower = code.lowercased()
        guard let emoji = EmojiShortcodes.map[lower] else { return nil }
        return (code.count + 2, emoji)
    }

    static func expanded(buffer: String, snippets: [Snippet], now: Date) -> (text: String, expandedTrigger: String)? {
        guard let (matchLen, replacement) = match(buffer: buffer, snippets: snippets, now: now) else {
            return nil
        }
        let prefix = String(buffer.dropLast(matchLen))
        let trigger = String(buffer.suffix(matchLen))
        return (prefix + replacement, trigger)
    }
}
