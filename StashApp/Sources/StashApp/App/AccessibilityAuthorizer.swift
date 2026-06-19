@preconcurrency import ApplicationServices

/// Centralizes the Accessibility (AXIsProcessTrusted) permission prompt.
///
/// macOS shows the system "would like to control this computer" dialog every
/// time `AXIsProcessTrustedWithOptions(prompt:)` is called while the app is not
/// trusted. Window snapping and the text expander both need the permission, and
/// the snap hotkeys could fire it on every keypress — so we gate the prompt to
/// at most once per app launch. After the user grants access it persists for
/// this binary; before that, we ask exactly once instead of spamming.
@MainActor
enum AccessibilityAuthorizer {
    private static var didPrompt = false

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt at most once per launch, and only
    /// when not already trusted. Safe to call from any feature entry point.
    static func requestOnce() {
        guard !didPrompt, !AXIsProcessTrusted() else { return }
        didPrompt = true
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
