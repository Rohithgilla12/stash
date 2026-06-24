@preconcurrency import ApplicationServices
import AppKit

// WindowSnapper moves the focused window of the last active non-Stash app to a
// snap target using the macOS Accessibility API (AXUIElement).
//
// Coordinate systems:
//   AppKit: bottom-left origin per display; NSScreen.visibleFrame is in AppKit space.
//   AX:     top-left origin of the primary display (y increases downward, globally).
//
// Conversion: ScreenGeometry.axFrame(fromAppKit:primaryHeight:) flips AppKit rects
// into AX space. WindowLayout works with whatever origin rect you supply; we feed it
// the visible area expressed in AX coordinates so the output frame is ready to pass
// directly to AXUIElementSetAttributeValue.

@MainActor
final class WindowSnapper {

    private(set) var lastActiveApp: NSRunningApplication?

    var isTrusted: Bool { AXIsProcessTrusted() }

    var targetAppName: String? { lastActiveApp?.localizedName }

    init() {
        // Seed with current frontmost if it is not Stash itself.
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = front
        }

        // Track the most recently active non-Stash app so that snapping from
        // the popover (where Stash is frontmost) still reaches the right target.
        // queue: .main guarantees the closure runs on the main thread; we then
        // use MainActor.assumeIsolated to satisfy Swift 6 strict concurrency
        // without an async hop — the OperationQueue.main guarantee makes it safe.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard
                    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.bundleIdentifier != Bundle.main.bundleIdentifier
                else { return }
                self?.lastActiveApp = app
            }
        }
    }

    func snap(_ target: SnapTarget) {
        guard AXIsProcessTrusted() else {
            AccessibilityAuthorizer.requestOnce()
            return
        }

        // Prefer lastActiveApp (set before the popover opened); fall back to
        // frontmostApplication only when it is genuinely not Stash.
        let app: NSRunningApplication?
        if let last = lastActiveApp, last.bundleIdentifier != Bundle.main.bundleIdentifier {
            app = last
        } else {
            let front = NSWorkspace.shared.frontmostApplication
            app = (front?.bundleIdentifier != Bundle.main.bundleIdentifier) ? front : nil
        }
        guard let app else { return }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        let windowErr = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard windowErr == .success, let windowRef else { return }
        let window = windowRef as! AXUIElement

        // Use the primary screen to derive the AX coordinate origin.
        // For v1 we snap into NSScreen.main's usable area; multi-display is a follow-up.
        guard let screen = NSScreen.main else { return }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        // visibleFrame is in AppKit coords (bottom-left origin).
        // Convert to AX space (top-left origin of the primary display).
        let visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: primaryHeight)

        // WindowLayout produces a frame in the same coordinate system as its input rect.
        // We supply visibleAX so the output is already in AX global coordinates.
        let frame = WindowLayout.frame(for: target, in: visibleAX, gap: 8)

        var point = frame.origin
        var size = frame.size

        guard
            let axPoint = AXValueCreate(.cgPoint, &point),
            let axSize  = AXValueCreate(.cgSize,  &size)
        else { return }

        let posErr = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPoint)
        let sizeErr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        #if DEBUG
        if posErr != .success || sizeErr != .success {
            print("WindowSnapper: set frame partial — pos \(posErr.rawValue), size \(sizeErr.rawValue)")
        }
        #endif
    }
}
