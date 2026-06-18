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
        guard let best = candidates.max(by: { $0.trigger.count < $1.trigger.count }) else {
            return nil
        }
        return (best.trigger.count, resolve(best, now: now))
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
