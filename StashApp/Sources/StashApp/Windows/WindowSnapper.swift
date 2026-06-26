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
        guard let (window, currentAXFrame) = focusedWindow() else { return }

        guard let screen = resolveScreen(displayMode: "active", displayIndex: 0, windowAXFrame: currentAXFrame) else { return }
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: primaryH)
        let frame = WindowLayout.frame(for: target, in: visibleAX, gap: 8)
        setFrame(window, frame)
    }

    func snap(_ preset: WindowPreset) {
        guard AXIsProcessTrusted() else {
            AccessibilityAuthorizer.requestOnce()
            return
        }
        guard let (window, currentAXFrame) = focusedWindow() else { return }

        guard let screen = resolveScreen(
            displayMode: preset.displayMode,
            displayIndex: preset.displayIndex,
            windowAXFrame: currentAXFrame
        ) else { return }
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: primaryH)
        let frame = WindowLayout.frame(for: preset, in: visibleAX)
        setFrame(window, frame)
    }

    func moveToNextDisplay() {
        guard AXIsProcessTrusted() else {
            AccessibilityAuthorizer.requestOnce()
            return
        }
        guard let (window, currentAXFrame) = focusedWindow() else { return }

        let screens = NSScreen.screens
        guard screens.count > 1 else { return }

        let primaryH = screens.first?.frame.height ?? 0

        guard let currentScreen = resolveScreen(displayMode: "active", displayIndex: 0, windowAXFrame: currentAXFrame) else { return }

        let currentIndex = screens.firstIndex(of: currentScreen) ?? 0
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]

        let currentVisibleAX = ScreenGeometry.axFrame(fromAppKit: currentScreen.visibleFrame, primaryHeight: primaryH)
        let nextVisibleAX = ScreenGeometry.axFrame(fromAppKit: nextScreen.visibleFrame, primaryHeight: primaryH)

        // Preserve the window's fractional position and size within the screen's visible rect.
        let fracX = (currentVisibleAX.width > 0)
            ? (currentAXFrame.minX - currentVisibleAX.minX) / currentVisibleAX.width
            : 0
        let fracY = (currentVisibleAX.height > 0)
            ? (currentAXFrame.minY - currentVisibleAX.minY) / currentVisibleAX.height
            : 0
        let fracW = min(1.0, (currentVisibleAX.width  > 0) ? currentAXFrame.width  / currentVisibleAX.width  : 1)
        let fracH = min(1.0, (currentVisibleAX.height > 0) ? currentAXFrame.height / currentVisibleAX.height : 1)

        let newFrame = CGRect(
            x: nextVisibleAX.minX + fracX * nextVisibleAX.width,
            y: nextVisibleAX.minY + fracY * nextVisibleAX.height,
            width: fracW * nextVisibleAX.width,
            height: fracH * nextVisibleAX.height
        )
        setFrame(window, newFrame)
    }

    struct LayoutRecallSummary: Sendable { let placed: Int; let launched: Int; let skipped: Int }

    func recall(_ entries: [LayoutEntry]) async -> LayoutRecallSummary {
        guard AXIsProcessTrusted() else {
            AccessibilityAuthorizer.requestOnce()
            return LayoutRecallSummary(placed: 0, launched: 0, skipped: entries.count)
        }
        var placed = 0, launched = 0, skipped = 0
        for entry in entries {
            if let app = runningApp(entry.bundleId) {
                if place(entry, on: app) { placed += 1 } else { skipped += 1 }
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleId) {
                if let app = await launchAndWaitForWindow(url: url, bundleId: entry.bundleId),
                   place(entry, on: app) {
                    launched += 1
                } else { skipped += 1 }
            } else { skipped += 1 }
        }
        return LayoutRecallSummary(placed: placed, launched: launched, skipped: skipped)
    }

    func captureCurrentLayout() -> [LayoutEntry] {
        guard AXIsProcessTrusted() else { AccessibilityAuthorizer.requestOnce(); return [] }
        var entries: [LayoutEntry] = []
        for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular
            && app.bundleIdentifier != nil
            && app.bundleIdentifier != Bundle.main.bundleIdentifier {
            guard let (_, frame) = mainWindow(for: app) else { continue }
            entries.append(LayoutEntry(
                bundleId: app.bundleIdentifier!,
                appName: app.localizedName ?? app.bundleIdentifier!,
                x: frame.minX, y: frame.minY, width: frame.width, height: frame.height,
                displayIndex: displayIndex(forAXFrame: frame)
            ))
        }
        return entries
    }

    // MARK: - Private helpers

    private func mainWindow(for app: NSRunningApplication) -> (AXUIElement, CGRect)? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        let window: AXUIElement
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &windowRef) == .success,
           let windowRef {
            window = windowRef as! AXUIElement
        } else {
            var listRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &listRef) == .success,
                  let listRef else { return nil }
            let list = listRef as! CFArray
            guard CFArrayGetCount(list) > 0 else { return nil }
            let raw = CFArrayGetValueAtIndex(list, 0)!
            window = Unmanaged<AXUIElement>.fromOpaque(raw).takeUnretainedValue()
        }

        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

        return (window, CGRect(origin: point, size: size))
    }

    private func displayIndex(forAXFrame f: CGRect) -> Int {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return 0 }
        let primaryH = screens.first?.frame.height ?? 0
        var bestIndex = 0
        var bestArea: CGFloat = -1
        for (i, screen) in screens.enumerated() {
            let screenAX = ScreenGeometry.axFrame(fromAppKit: screen.frame, primaryHeight: primaryH)
            let overlap = screenAX.intersection(f)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func resolveApp() -> NSRunningApplication? {
        if let last = lastActiveApp, last.bundleIdentifier != Bundle.main.bundleIdentifier {
            return last
        }
        let front = NSWorkspace.shared.frontmostApplication
        return (front?.bundleIdentifier != Bundle.main.bundleIdentifier) ? front : nil
    }

    private func focusedWindow() -> (AXUIElement, CGRect)? {
        guard let app = resolveApp() else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return nil }
        let window = windowRef as! AXUIElement

        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

        return (window, CGRect(origin: point, size: size))
    }

    private func setFrame(_ window: AXUIElement, _ frame: CGRect) {
        var point = frame.origin
        var size = frame.size

        guard
            let axPoint = AXValueCreate(.cgPoint, &point),
            let axSize  = AXValueCreate(.cgSize,  &size)
        else { return }

        let posErr  = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPoint)
        let sizeErr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        #if DEBUG
        if posErr != .success || sizeErr != .success {
            print("WindowSnapper: set frame partial — pos \(posErr.rawValue), size \(sizeErr.rawValue)")
        }
        #endif
    }

    private func resolveScreen(displayMode: String, displayIndex: Int, windowAXFrame: CGRect?) -> NSScreen? {
        switch displayMode {
        case "main":
            return NSScreen.main
        case "index":
            let screens = NSScreen.screens
            guard displayIndex >= 0, displayIndex < screens.count else { return nil }
            return screens[displayIndex]
        default: // "active" — the screen whose AX frame overlaps the window the most
            guard let f = windowAXFrame else { return NSScreen.main }
            let primaryH = NSScreen.screens.first?.frame.height ?? 0
            return NSScreen.screens.max { a, b in
                let aAX = ScreenGeometry.axFrame(fromAppKit: a.frame, primaryHeight: primaryH)
                let bAX = ScreenGeometry.axFrame(fromAppKit: b.frame, primaryHeight: primaryH)
                let aOverlap = aAX.intersection(f)
                let bOverlap = bAX.intersection(f)
                let aArea = aOverlap.isNull ? 0 : aOverlap.width * aOverlap.height
                let bArea = bOverlap.isNull ? 0 : bOverlap.width * bOverlap.height
                return aArea < bArea
            } ?? NSScreen.main
        }
    }

    private func runningApp(_ bundleId: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
    }

    private func place(_ entry: LayoutEntry, on app: NSRunningApplication) -> Bool {
        guard let (window, _) = mainWindow(for: app) else { return false }
        guard let screen = resolveScreen(displayMode: "index", displayIndex: entry.displayIndex, windowAXFrame: nil)
                ?? NSScreen.main
                ?? NSScreen.screens.first
        else { return false }
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: primaryH)
        setFrame(window, WindowGeometry.clamp(entry.frame, to: visibleAX))
        return true
    }

    private func launchAndWaitForWindow(url: URL, bundleId: String) async -> NSRunningApplication? {
        let config = NSWorkspace.OpenConfiguration()
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
        for _ in 0..<16 {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return nil  // cancelled — exit immediately
            }
            if let app = runningApp(bundleId), mainWindow(for: app) != nil { return app }
        }
        return nil
    }
}
