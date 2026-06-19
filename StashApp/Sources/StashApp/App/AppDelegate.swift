import AppKit

/// Receives `stash://` URL opens (from `open stash://…`, Karabiner, Shortcuts,
/// Raycast, etc.) and forwards them to the live AppEnvironment.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppEnvironment.shared?.handleDeeplink(url)
        }
    }
}
