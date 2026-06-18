import SwiftUI
import AppKit

extension OpenWindowAction {
    /// Opens one of the app's `Window` scenes from the menu-bar hub.
    ///
    /// Stash runs as an agent (`LSUIElement`) app with an `.accessory`
    /// activation policy, so `Window` scenes will not materialize from
    /// `openWindow` unless the app is activated first. Always go through this
    /// to open the Notes/Tasks windows.
    @MainActor func openActivating(id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        self(id: id)
    }
}
