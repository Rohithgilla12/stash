import AppKit
import UserNotifications

/// Receives `stash://` URL opens (from `open stash://…`, Karabiner, Shortcuts,
/// Raycast, etc.) and forwards them to the live AppEnvironment.
/// Also acts as the UNUserNotificationCenterDelegate so banners show when the
/// app is frontmost, and the "Complete" action marks the task done.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        AppEnvironment.shared?.scheduler.registerCategories()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppEnvironment.shared?.handleDeeplink(url)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let taskId = response.notification.request.identifier
        let actionId = response.actionIdentifier
        if actionId == "COMPLETE_TASK" || actionId == UNNotificationDefaultActionIdentifier {
            Task { @MainActor in
                await AppEnvironment.shared?.completeTask(id: taskId)
            }
        }
        completionHandler()
    }
}
