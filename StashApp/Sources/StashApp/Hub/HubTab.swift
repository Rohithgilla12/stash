enum HubTab: String, CaseIterable, Identifiable {
    case clipboard, notes, todos, focus, snippets, windows, ai
    var id: String { rawValue }
    var label: String {
        switch self {
        case .clipboard: "Clipboard"
        case .notes: "Notes"
        case .todos: "To-dos"
        case .focus: "Focus"
        case .snippets: "Snippets"
        case .windows: "Windows"
        case .ai: "AI"
        }
    }
}
