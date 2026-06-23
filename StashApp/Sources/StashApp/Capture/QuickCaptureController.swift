import AppKit
import Carbon
import SwiftUI

@MainActor final class QuickCaptureController {
    var onSave: (String, Bool) -> Void = { _, _ in }

    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private var panel: KeyablePanel?
    private var hotKey: GlobalHotKey?

    private func ensurePanel() -> KeyablePanel {
        if let p = panel { return p }
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.level = .floating
        panel = p
        return p
    }

    func show() {
        let p = ensurePanel()
        let view = QuickCaptureView(
            onSave: { [weak self] text, isTask in
                self?.onSave(text, isTask)
                self?.hide()
            },
            onClose: { [weak self] in self?.hide() }
        )
        p.contentView = NSHostingView(rootView: view)
        p.setContentSize(NSSize(width: 520, height: 150))

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.minX + (sf.width - 520) / 2
            let y = sf.minY + sf.height * 0.67
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func registerHotKey() {
        hotKey = GlobalHotKey(keyCode: 8, modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.show()
        }
    }

    func unregisterHotKey() {
        hotKey = nil
    }
}
