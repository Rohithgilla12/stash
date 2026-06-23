import Foundation
import UserNotifications

@MainActor
final class TaskReminderScheduler {

    func authorizationStatus() async -> UNAuthorizationStatus {
        // Extract the Sendable status inside the callback — UNNotificationSettings
        // itself is non-Sendable and can't cross the actor boundary (strict concurrency).
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Complete",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "TASK_DUE",
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func sync(_ tasks: [TaskItem]) async {
        guard await authorizationStatus() == .authorized else { return }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let now = Date()
        // macOS limits pending notifications to ~64; scheduling the 60 soonest to leave headroom
        let scheduled = tasks
            .filter { TaskReminderScheduler.shouldSchedule($0, now: now) }
            .sorted { ($0.dueAt ?? 0) < ($1.dueAt ?? 0) }
            .prefix(60)

        for task in scheduled {
            guard let dueAt = task.dueAt else { continue }

            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = "Due " + TaskQuickParse.formatDue(
                Date(timeIntervalSince1970: Double(dueAt) / 1000),
                now: now
            )
            content.sound = .default
            content.categoryIdentifier = "TASK_DUE"

            let components = TaskReminderScheduler.dueComponents(for: dueAt, calendar: .current)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: task.id,
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated static func dueComponents(for dueAt: Int64, calendar: Calendar) -> DateComponents {
        let date = Date(timeIntervalSince1970: Double(dueAt) / 1000)
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    nonisolated static func shouldSchedule(_ task: TaskItem, now: Date) -> Bool {
        guard !task.done, let dueAt = task.dueAt else { return false }
        return Double(dueAt) / 1000 > now.timeIntervalSince1970
    }
}
