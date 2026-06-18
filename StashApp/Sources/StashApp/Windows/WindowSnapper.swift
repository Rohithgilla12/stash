@preconcurrency import ApplicationServices
import AppKit

// WindowSnapper moves the focused window of the frontmost app to a snap target
// using the macOS Accessibility API (AXUIElement).
//
// Coordinate systems used here:
//   AppKit: bottom-left origin per display; NSScreen.visibleFrame is in AppKit space.
//   AX:     top-left origin of the primary display (y increases downward, globally).
//
// Conversion: ScreenGeometry.axFrame(fromAppKit:primaryHeight:) flips AppKit rects
// into AX space. WindowLayout works with whatever origin rect you supply; we feed it
// the visible area expressed in AX coordinates so the output frame is ready to pass
// directly to AXUIElementSetAttributeValue.

@MainActor
final class WindowSnapper {

    var isTrusted: Bool { AXIsProcessTrusted() }

    func ensureTrusted() {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func snap(_ target: SnapTarget) {
        guard AXIsProcessTrusted() else {
            ensureTrusted()
            return
        }

        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        let windowErr = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard windowErr == .success, let windowRef else { return }

        // Use the primary screen to derive the AX coordinate origin.
        // For v1 we snap into NSScreen.main's usable area; multi-display is a follow-up.
        guard let screen = NSScreen.main else { return }
        let primaryHeight = NSScreen.screens.first!.frame.height

        // visibleFrame is in AppKit coords (bottom-left origin).
        // Convert to AX space (top-left origin of the primary display).
        let visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: primaryHeight)

        // WindowLayout produces a frame in the same coordinate system as its input rect.
        // We supply visibleAX so the output is already in AX global coordinates.
        var frame = WindowLayout.frame(for: target, in: visibleAX, gap: 8)

        var point = frame.origin
        var size = frame.size

        guard
            let axPoint = AXValueCreate(.cgPoint, &point),
            let axSize  = AXValueCreate(.cgSize,  &size)
        else { return }

        let window = windowRef as! AXUIElement
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPoint)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
    }
}
