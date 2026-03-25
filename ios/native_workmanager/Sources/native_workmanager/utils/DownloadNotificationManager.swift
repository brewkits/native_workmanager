import Foundation
import UserNotifications

/// Manages user-facing download progress notifications on iOS.
///
/// iOS constraints:
/// - Background URLSession downloads do NOT support real-time progress in notifications
///   (the app is suspended; only system-triggered wakeups work).
/// - When the app IS active (foreground) we can show a progress-style notification update.
/// - The most reliable slot is a completion / failure notification — always shown.
///
/// Usage: set `showNotification: true` in the worker config. The plugin layer
/// calls `showProgress`, `showCompleted`, or `showFailed` at the right moments.
@available(iOS 13.0, *)
struct DownloadNotificationManager {

    static let categoryId   = "NWM_DOWNLOAD"
    static let pauseActionId  = "NWM_PAUSE"
    static let cancelActionId = "NWM_CANCEL"

    // MARK: - Permission

    /// Request notification permission (call once during initialize).
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            NSLog("DownloadNotificationManager: notification permission %@", granted ? "granted" : "denied")
        }
    }

    // MARK: - Category registration (Pause + Cancel action buttons)

    /// Register the NWM_DOWNLOAD notification category with interactive action buttons.
    /// Must be called before any notifications are displayed (ideally at plugin init time).
    static func registerCategory() {
        let pauseAction = UNNotificationAction(
            identifier: pauseActionId,
            title: "Pause",
            options: []
        )
        let cancelAction = UNNotificationAction(
            identifier: cancelActionId,
            title: "Cancel",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [pauseAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )
        // Merge with any existing categories rather than replacing all of them
        UNUserNotificationCenter.current().getNotificationCategories { existing in
            var updated = existing.filter { $0.identifier != categoryId }
            updated.insert(category)
            UNUserNotificationCenter.current().setNotificationCategories(updated)
        }
    }

    // MARK: - Progress (foreground best-effort)

    /// Show or update a progress notification.
    /// On iOS this is best-effort: notification may not update in real time during background.
    static func showProgress(taskId: String, title: String, progress: Double, message: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message ?? String(format: "%.0f%%", progress)
        content.categoryIdentifier = categoryId

        // Replace any existing notification for this taskId
        let request = UNNotificationRequest(
            identifier: "nwm_dl_\(taskId)",
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { NSLog("DownloadNotificationManager showProgress error: %@", error.localizedDescription) }
        }
    }

    // MARK: - Completion

    static func showCompleted(taskId: String, title: String, fileName: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = fileName.map { "Downloaded: \($0)" } ?? "Download complete"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "nwm_dl_\(taskId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func showFailed(taskId: String, title: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Failed: \(error)"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: "nwm_dl_\(taskId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Dismiss

    static func dismiss(taskId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["nwm_dl_\(taskId)"])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: ["nwm_dl_\(taskId)"])
    }
}
