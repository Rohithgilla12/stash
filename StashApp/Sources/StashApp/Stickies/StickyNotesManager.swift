import AppKit
import Carbon
import SwiftUI

@MainActor
final class StickyNotesManager {
    private var windows: [String: NSWindow] = [:]
    private var orderedIDs: [String] = []
    private(set) var visible = true
    private var hotKey: GlobalHotKey?

    private let onToggleItem: (Note, Int) -> Void
    private let onOpenNote: (Note) -> Void

    init(onToggleItem: @escaping (Note, Int) -> Void, onOpenNote: @escaping (Note) -> Void) {
        self.onToggleItem = onToggleItem
        self.onOpenNote = onOpenNote
    }

    func sync(notes: [Note]) {
        let desktop = notes.filter { $0.onDesktop }
        let desktopIDs = Set(desktop.map { $0.id })

        for id in Array(windows.keys) where !desktopIDs.contains(id) {
            windows[id]?.close()
            windows.removeValue(forKey: id)
            orderedIDs.removeAll { $0 == id }
        }

        for note in desktop {
            if let existing = windows[note.id] {
                if let hosting = existing.contentView as? NSHostingView<StickyNoteView> {
                    hosting.rootView = makeView(for: note)
                }
            } else {
                orderedIDs.append(note.id)
                let index = orderedIDs.count - 1
                let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
                let size = CGSize(width: 220, height: 220)
                let frame = StickyLayout.frame(index: index, in: screen, size: size)

                let window = NSWindow(
                    contentRect: frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.level = .floating
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
                window.isMovableByWindowBackground = true
                window.collectionBehavior = [.canJoinAllSpaces, .stationary]
                window.contentView = NSHostingView(rootView: makeView(for: note))
                window.alphaValue = visible ? 1 : 0
                window.orderFrontRegardless()
                windows[note.id] = window
            }
        }
    }

    func toggleVisibility() {
        visible.toggle()
        let target: CGFloat = visible ? 1 : 0
        for window in windows.values {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                window.animator().alphaValue = target
            }
        }
    }

    func registerHotKey() {
        hotKey = GlobalHotKey(keyCode: 49, modifiers: UInt32(optionKey)) { [weak self] in
            self?.toggleVisibility()
        }
    }

    private func makeView(for note: Note) -> StickyNoteView {
        StickyNoteView(
            note: note,
            onToggleItem: { [weak self] idx in
                guard let self else { return }
                var updated = note
                guard idx < updated.items.count else { return }
                updated.items[idx].done.toggle()
                updated.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
                self.onToggleItem(updated, idx)
            },
            onOpen: { [weak self] in
                self?.onOpenNote(note)
            }
        )
    }
}
