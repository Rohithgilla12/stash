import Foundation

struct SnippetField: Equatable {
    let name: String
    let label: String
}

enum SnippetTemplate {
    nonisolated static func fields(in template: String) -> [SnippetField] {
        var result: [SnippetField] = []
        var seen: Set<String> = []
        var cursorConsumed = false

        for token in tokenize(template) {
            guard case .placeholder(let raw) = token else { continue }
            let (name, rawLabel) = parsePlaceholder(raw)
            if isAutoPlaceholder(name) { continue }
            if name == "cursor" {
                if !cursorConsumed {
                    cursorConsumed = true
                }
                continue
            }
            if !seen.contains(name) {
                seen.insert(name)
                let label = rawLabel.isEmpty ? name : rawLabel
                result.append(SnippetField(name: name, label: label))
            }
        }
        return result
    }

    nonisolated static func render(
        _ template: String,
        values: [String: String],
        clipboard: String?,
        now: Date
    ) -> (text: String, cursorOffset: Int?) {
        var output = ""
        var cursorCharIndex: Int? = nil
        var cursorConsumed = false

        for token in tokenize(template) {
            switch token {
            case .literal(let s):
                output += s
            case .placeholder(let raw):
                let (name, label) = parsePlaceholder(raw)
                switch name {
                case "date":
                    output += resolveDate(label: label, now: now)
                case "time":
                    let f = DateFormatter()
                    f.dateFormat = "h:mm a"
                    output += f.string(from: now)
                case "clipboard":
                    output += clipboard ?? ""
                case "cursor":
                    if !cursorConsumed {
                        cursorConsumed = true
                        cursorCharIndex = output.count
                    } else {
                        output += values[name] ?? ""
                    }
                default:
                    output += values[name] ?? ""
                }
            case .stray(let s):
                output += s
            }
        }

        var cursorOffset: Int? = nil
        if let idx = cursorCharIndex {
            let charsAfter = output.count - idx
            if charsAfter > 0 {
                cursorOffset = charsAfter
            }
        }
        return (text: output, cursorOffset: cursorOffset)
    }

    private nonisolated static func resolveDate(label: String, now: Date) -> String {
        let cal = Calendar.current
        let defaultFormat = "MMM d, yyyy"

        if label.isEmpty {
            let f = DateFormatter()
            f.dateFormat = defaultFormat
            return f.string(from: now)
        }

        if label.hasPrefix("+"), let rest = parseOffset(label.dropFirst()) {
            let target = cal.date(byAdding: .day, value: rest, to: now) ?? now
            let f = DateFormatter()
            f.dateFormat = defaultFormat
            return f.string(from: target)
        }

        if label.hasPrefix("-"), let rest = parseOffset(label.dropFirst()) {
            let target = cal.date(byAdding: .day, value: -rest, to: now) ?? now
            let f = DateFormatter()
            f.dateFormat = defaultFormat
            return f.string(from: target)
        }

        let f = DateFormatter()
        f.dateFormat = label
        return f.string(from: now)
    }

    private nonisolated static func parseOffset(_ s: Substring) -> Int? {
        guard s.hasSuffix("d") else { return nil }
        return Int(s.dropLast())
    }

    private nonisolated static func isAutoPlaceholder(_ name: String) -> Bool {
        name == "date" || name == "time" || name == "clipboard"
    }

    private nonisolated static func parsePlaceholder(_ raw: String) -> (name: String, label: String) {
        if let colon = raw.firstIndex(of: ":") {
            let name = String(raw[raw.startIndex..<colon])
            let label = String(raw[raw.index(after: colon)...])
            return (name, label)
        }
        return (raw, "")
    }

    private enum Token {
        case literal(String)
        case placeholder(String)
        case stray(String)
    }

    private nonisolated static func tokenize(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var idx = s.startIndex
        var literalStart = idx

        while idx < s.endIndex {
            if s[idx] == "{" {
                if literalStart < idx {
                    tokens.append(.literal(String(s[literalStart..<idx])))
                }
                _ = idx
                s.formIndex(after: &idx)
                var inner = ""
                var found = false
                while idx < s.endIndex {
                    if s[idx] == "}" {
                        found = true
                        s.formIndex(after: &idx)
                        break
                    }
                    if s[idx] == "{" {
                        break
                    }
                    inner.append(s[idx])
                    s.formIndex(after: &idx)
                }
                if found && !inner.isEmpty {
                    tokens.append(.placeholder(inner))
                } else {
                    tokens.append(.stray("{"))
                    if !inner.isEmpty {
                        tokens.append(.literal(inner))
                    }
                    if !found {
                        // no closing brace — leave idx where it is
                    }
                }
                literalStart = idx
            } else {
                s.formIndex(after: &idx)
            }
        }

        if literalStart < s.endIndex {
            tokens.append(.literal(String(s[literalStart...])))
        }
        return tokens
    }
}
