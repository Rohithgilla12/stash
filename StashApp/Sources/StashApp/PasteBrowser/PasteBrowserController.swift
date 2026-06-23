import AppKit
import Carbon
import SwiftUI

@MainActor
final class PasteBrowserController {

    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private var panel: KeyablePanel?
    private var hotKey: GlobalHotKey?
    private weak var previousApp: NSRunningApplication?

    var itemsProvider: () -> [ClipItem] = { [] }
    var onPin: (ClipItem) -> Void = { _ in }
    var onDelete: (ClipItem) -> Void = { _ in }

    func registerHotKey() {
        hotKey = GlobalHotKey(keyCode: 9, modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.toggle()
        }
    }

    func unregisterHotKey() { hotKey = nil }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    // Reuse a single panel across opens so re-triggering the hotkey is reliable.
    private func ensurePanel() -> KeyablePanel {
        if let panel { return panel }
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 300),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.level = .floating
        // Agent app: do NOT auto-hide on deactivate (it can self-dismiss before
        // it's even shown). Dismiss explicitly via Esc / Enter / re-pressing ⌃⌥V.
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel = p
        return p
    }

    private func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        let p = ensurePanel()

        // Fresh SwiftUI view each open → fresh selection/search state.
        let view = PasteBrowserView(
            items: itemsProvider(),
            onPaste: { [weak self] item in self?.paste(item) },
            onPin: { [weak self] item in self?.onPin(item) },
            onDelete: { [weak self] item in self?.onDelete(item) },
            onClose: { [weak self] in self?.hide() }
        )
        p.contentView = NSHostingView(rootView: view)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let w = min(1100, visible.width * 0.86)
        let h: CGFloat = 300
        let x = visible.minX + (visible.width - w) / 2
        let y = visible.minY + visible.height * 0.18
        p.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func paste(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if item.kind == .image, let path = item.previewPath, let img = NSImage(contentsOfFile: path) {
            pb.writeObjects([img])
        } else {
            pb.setString(item.text ?? "", forType: .string)
        }

        hide()

        // Reactivate the app that was focused before the panel opened, then
        // synthesize Cmd-V. Auto-paste is best-effort (needs Accessibility);
        // the item is on the clipboard regardless.
        previousApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) else { return }
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return }
            up.flags = .maskCommand
            up.post(tap: .cghidEventTap)
        }
    }

    func hide() {
        panel?.orderOut(nil)
        previousApp?.activate()
    }
}
