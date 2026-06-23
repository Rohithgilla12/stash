import AppKit
import SwiftUI

@MainActor
enum CommandPalette {

    static func items(
        env: AppEnvironment,
        openWindow: OpenWindowAction,
        dismiss: @escaping () -> Void,
        checkForUpdates: (() -> Void)?
    ) -> [PaletteItem] {
        var result: [PaletteItem] = []

        // Actions
        result.append(PaletteItem(
            id: "action-paste-browser",
            title: "Open Paste browser",
            subtitle: "Browse clipboard history",
            symbol: "doc.on.clipboard",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://paste")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-snap-left",
            title: "Snap window left",
            subtitle: "Move focused window to left half",
            symbol: "rectangle.lefthalf.filled",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://snap?target=leftHalf")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-snap-right",
            title: "Snap window right",
            subtitle: "Move focused window to right half",
            symbol: "rectangle.righthalf.filled",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://snap?target=rightHalf")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-snap-top",
            title: "Snap window top",
            subtitle: "Move focused window to top half",
            symbol: "rectangle.tophalf.filled",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://snap?target=topHalf")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-snap-bottom",
            title: "Snap window bottom",
            subtitle: "Move focused window to bottom half",
            symbol: "rectangle.bottomhalf.filled",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://snap?target=bottomHalf")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-snap-full",
            title: "Snap window full",
            subtitle: "Maximise focused window",
            symbol: "rectangle.fill",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://snap?target=full")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-stickies",
            title: "Toggle sticky notes",
            subtitle: "Show or hide desktop stickies",
            symbol: "note",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://stickies")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-expander",
            title: "Toggle text expander",
            subtitle: "Enable or disable text expansion",
            symbol: "keyboard",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://expander?state=toggle")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-new-note",
            title: "New note",
            subtitle: "Create a blank note",
            symbol: "square.and.pencil",
            kind: "action",
            run: { env.handleDeeplink(URL(string: "stash://note")!); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-quick-capture",
            title: "Quick Capture",
            subtitle: "Jot a note or task from anywhere",
            symbol: "square.and.pencil",
            kind: "action",
            run: { env.showQuickCapture(); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-clear-clip",
            title: "Clear clipboard history",
            subtitle: "Remove all unpinned clips",
            symbol: "trash",
            kind: "action",
            run: { Task { await env.viewModel.clearUnpinned() }; dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-notes-window",
            title: "Open Notes window",
            subtitle: "Bring up the Notes window",
            symbol: "note.text",
            kind: "action",
            run: { openWindow.openActivating(id: "notes"); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-tasks-window",
            title: "Open Tasks window",
            subtitle: "Bring up the Tasks window",
            symbol: "checkmark.square",
            kind: "action",
            run: { openWindow.openActivating(id: "tasks"); dismiss() }
        ))
        result.append(PaletteItem(
            id: "action-prefs",
            title: "Preferences…",
            subtitle: "Open Stash preferences",
            symbol: "gear",
            kind: "action",
            run: { openWindow.openActivating(id: "preferences"); dismiss() }
        ))
        if let checkForUpdates {
            result.append(PaletteItem(
                id: "action-update",
                title: "Check for Updates…",
                subtitle: "Look for a newer version",
                symbol: "arrow.down.circle",
                kind: "action",
                run: { checkForUpdates(); dismiss() }
            ))
        }

        // Clipboard items
        for item in Array(env.viewModel.items.prefix(50)) {
            let rawTitle = item.title ?? item.text ?? ""
            let title = String(rawTitle.prefix(80))
            let symbol: String
            switch item.kind {
            case .image: symbol = "photo"
            case .link:  symbol = "link"
            default:     symbol = "doc.on.clipboard"
            }
            result.append(PaletteItem(
                id: "clip-\(item.id)",
                title: title,
                subtitle: "Copy to clipboard",
                symbol: symbol,
                kind: "clip",
                run: { Task { await env.viewModel.copyBack(item) }; dismiss() }
            ))
        }

        // Notes
        for note in env.notesViewModel.notes {
            let title: String
            if !note.title.isEmpty {
                title = note.title
            } else if let first = note.body.components(separatedBy: .newlines).first, !first.isEmpty {
                title = first
            } else {
                title = "Untitled"
            }
            result.append(PaletteItem(
                id: "note-\(note.id)",
                title: title,
                subtitle: "Open note",
                symbol: "note.text",
                kind: "note",
                run: {
                    env.notesViewModel.selectedId = note.id
                    openWindow.openActivating(id: "notes")
                    dismiss()
                }
            ))
        }

        // Snippets
        for snippet in env.snippetsViewModel.snippets {
            let expandText = snippet.expand ?? snippet.label
            let subtitle = String(expandText.prefix(60))
            result.append(PaletteItem(
                id: "snippet-\(snippet.trigger)",
                title: snippet.trigger,
                subtitle: subtitle,
                symbol: "text.quote",
                kind: "snippet",
                run: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(snippet.expand ?? snippet.label, forType: .string)
                    dismiss()
                }
            ))
        }

        return result
    }

    nonisolated static func filter(_ items: [PaletteItem], query: String) -> [PaletteItem] {
        guard !query.isEmpty else {
            let actions   = items.filter { $0.kind == "action" }
            let clips     = items.filter { $0.kind == "clip" }
            let rest      = items.filter { $0.kind != "action" && $0.kind != "clip" }
            return actions + clips + rest
        }

        let q = query.lowercased()

        func isSubsequence(_ needle: String, in haystack: String) -> Bool {
            var hi = haystack.startIndex
            for ch in needle {
                guard let found = haystack[hi...].firstIndex(where: { $0 == ch }) else { return false }
                hi = haystack.index(after: found)
            }
            return true
        }

        struct Scored {
            let item: PaletteItem
            let isPrefix: Bool
            let firstMatchIndex: Int
            let titleLength: Int
        }

        var scored: [Scored] = []
        for item in items {
            let lower = item.title.lowercased()
            guard isSubsequence(q, in: lower) else { continue }
            let isPrefix = lower.hasPrefix(q)
            let firstMatchIndex = q.first.flatMap { first in
                lower.firstIndex(of: first)
                    .map { lower.distance(from: lower.startIndex, to: $0) }
            } ?? 0
            scored.append(Scored(
                item: item,
                isPrefix: isPrefix,
                firstMatchIndex: firstMatchIndex,
                titleLength: item.title.count
            ))
        }

        scored.sort {
            if $0.isPrefix != $1.isPrefix { return $0.isPrefix && !$1.isPrefix }
            if $0.firstMatchIndex != $1.firstMatchIndex { return $0.firstMatchIndex < $1.firstMatchIndex }
            return $0.titleLength < $1.titleLength
        }

        return scored.map(\.item)
    }
}
