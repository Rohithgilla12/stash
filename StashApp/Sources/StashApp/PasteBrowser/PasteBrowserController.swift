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

    func registerHotKey() {
        hotKey = GlobalHotKey(keyCode: 9, modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let items = itemsProvider()

        let contentView = PasteBrowserView(
            items: items,
            onPaste: { [weak self] item in self?.paste(item) },
            onClose: { [weak self] in self?.hide() }
        )

        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let p = KeyablePanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovable = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.level = .floating
        p.hidesOnDeactivate = true
        p.contentView = hosting

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let panelWidth = min(1100, visible.width * 0.86)
        let panelHeight: CGFloat = 300
        let x = visible.minX + (visible.width - panelWidth) / 2
        let y = visible.minY + visible.height * 0.18

        p.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: false)

        self.panel = p

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func paste(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        if item.kind == .image, let path = item.previewPath {
            if let img = NSImage(contentsOfFile: path) {
                pb.writeObjects([img])
            }
        } else {
            pb.setString(item.text ?? "", forType: .string)
        }

        hide()
        previousApp?.activate(options: [])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) else { return }
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)

            guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return }
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }

    func hide() {
        panel?.orderOut(nil)
        previousApp?.activate(options: [])
    }
}
