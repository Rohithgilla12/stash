import CoreGraphics
@preconcurrency import ApplicationServices
import AppKit

private func cgEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let port = SystemExpander._sharedTapPort {
            CGEvent.tapEnable(tap: port, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let expander = Unmanaged<SystemExpander>.fromOpaque(userInfo).takeUnretainedValue()
    nonisolated(unsafe) let ev = event
    MainActor.assumeIsolated {
        expander.handleKeyDown(ev)
    }

    return Unmanaged.passUnretained(event)
}

@MainActor
final class SystemExpander {
    nonisolated(unsafe) static var _sharedTapPort: CFMachPort?

    var snippets: [Snippet] = []

    private var buffer = KeystrokeBuffer()
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var enabled = false
    private var trustPollTask: Task<Void, Never>?

    @discardableResult
    func setEnabled(_ on: Bool) -> Bool {
        if on {
            guard !enabled else { return true }   // already running
            stopTrustPoll()
            installTap()
            // If the tap couldn't install (Accessibility not granted yet), poll for
            // the grant so the expander starts working without a relaunch once the
            // user flips it on in System Settings.
            if !enabled { startTrustPoll() }
        } else {
            stopTrustPoll()
            if enabled { tearDownTap() }
        }
        return enabled
    }

    private func startTrustPoll() {
        trustPollTask?.cancel()
        trustPollTask = Task { [weak self] in
            for _ in 0..<150 {   // ~5 min at 2s intervals
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                if AXIsProcessTrusted() {
                    self.installTap()
                    if self.enabled { return }
                }
            }
        }
    }

    private func stopTrustPoll() {
        trustPollTask?.cancel()
        trustPollTask = nil
    }

    private func installTap() {
        if !AXIsProcessTrusted() {
            AccessibilityAuthorizer.requestOnce()
            return
        }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: cgEventTapCallback,
            userInfo: selfPtr
        ) else {
            #if DEBUG
            print("[SystemExpander] tapCreate returned nil — Accessibility permission missing?")
            #endif
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        tapPort = port
        runLoopSource = source
        SystemExpander._sharedTapPort = port
        enabled = true
        buffer.reset()

        #if DEBUG
        print("[SystemExpander] CGEventTap installed (listen-only)")
        #endif
    }

    private func tearDownTap() {
        if let port = tapPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tapPort = nil
        runLoopSource = nil
        SystemExpander._sharedTapPort = nil
        enabled = false
        buffer.reset()

        #if DEBUG
        print("[SystemExpander] CGEventTap torn down")
        #endif
    }

    // Note: injected expansion text is re-observed by this listen-only tap; buffer.reset() after a match
    // means a replacement ending in a trigger could double-expand (bounded, not a loop). Acceptable for v1.
    func handleKeyDown(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch keyCode {
        case 51:
            buffer.backspace()
            return
        case 36, 48, 49, 53, 117, 123, 124, 125, 126:
            buffer.reset()
            return
        default:
            break
        }

        var actualLength = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &actualLength,
            unicodeString: &chars
        )

        guard actualLength > 0 else { return }
        let typed = String(decoding: chars.prefix(actualLength), as: UTF16.self)

        guard !typed.isEmpty else { return }

        buffer.append(typed)

        if let match = ExpansionEngine.match(buffer: buffer.value, snippets: snippets, now: Date()) {
            performExpansion(matchLength: match.matchLength, replacement: match.replacement)
            buffer.reset()
        }
    }

    private func performExpansion(matchLength: Int, replacement: String) {
        let deleteKeyCode: CGKeyCode = 51

        for _ in 0..<matchLength {
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: deleteKeyCode, keyDown: true) {
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: deleteKeyCode, keyDown: false) {
                up.post(tap: .cghidEventTap)
            }
        }

        usleep(1500)

        let utf16 = Array(replacement.utf16)
        if let insertEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
            insertEvent.keyboardSetUnicodeString(
                stringLength: utf16.count,
                unicodeString: utf16
            )
            insertEvent.post(tap: .cghidEventTap)
        }
        if let insertUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
            insertUp.keyboardSetUnicodeString(
                stringLength: utf16.count,
                unicodeString: utf16
            )
            insertUp.post(tap: .cghidEventTap)
        }
    }
}
