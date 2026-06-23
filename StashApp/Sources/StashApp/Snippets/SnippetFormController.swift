import AppKit
import SwiftUI

@MainActor final class SnippetFormController {
    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private var panel: KeyablePanel?

    private func ensurePanel() -> KeyablePanel {
        if let p = panel { return p }
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
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

    func present(
        fields: [SnippetField],
        onSubmit: @escaping ([String: String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let previousApp = NSWorkspace.shared.frontmostApplication
        let p = ensurePanel()

        let view = SnippetFormView(
            fields: fields,
            onSubmit: { [weak self] values in
                self?.hide()
                previousApp?.activate(options: [.activateIgnoringOtherApps])
                onSubmit(values)
            },
            onCancel: { [weak self] in
                self?.hide()
                previousApp?.activate(options: [.activateIgnoringOtherApps])
                onCancel()
            }
        )
        p.contentView = NSHostingView(rootView: view)

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let width: CGFloat = 480
            let x = sf.minX + (sf.width - width) / 2
            let y = sf.minY + sf.height * 0.67
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
