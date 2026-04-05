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

    static let categoryId             = "NWM_DOWNLOAD"
    static let categoryIdNoPause      = "NWM_DOWNLOAD_NO_PAUSE"
    static let pauseActionId          = "NWM_PAUSE"
    static let cancelActionId         = "NWM_CANCEL"
    static let threadIdentifier       = "nwm_downloads"

    // MARK: - Template substitution

    /// Replace well-known template variables in a notification string.
    ///
    /// Supported tokens:
    /// - `{filename}`     — last path component of the downloaded file
    /// - `{progress}`     — progress percentage (e.g. "42%")
    /// - `{numFinished}`  — number of completed downloads in a batch
    /// - `{numTotal}`     — total downloads in a batch
    static func applyTemplate(
        _ template: String,
        filename: String? = nil,
        progress: Double = 0,
        numFinished: Int = 0,
        numTotal: Int = 0
    ) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{filename}", with: filename ?? "")
        result = result.replacingOccurrences(of: "{progress}", with: String(format: "%.0f%%", progress))
        result = result.replacingOccurrences(of: "{numFinished}", with: "\(numFinished)")
        result = result.replacingOccurrences(of: "{numTotal}", with: "\(numTotal)")
        return result
    }

    // MARK: - Permission

    /// Request notification permission (call once during initialize).
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            NSLog("DownloadNotificationManager: notification permission %@", granted ? "granted" : "denied")
        }
    }

    // MARK: - Category registration (Pause + Cancel action buttons)

    /// Register notification categories:
    /// - `NWM_DOWNLOAD`          — has Pause + Cancel action buttons
    /// - `NWM_DOWNLOAD_NO_PAUSE` — has only Cancel action button
    ///
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

        let categoryWithPause = UNNotificationCategory(
            identifier: categoryId,
            actions: [pauseAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )
        let categoryNoPause = UNNotificationCategory(
            identifier: categoryIdNoPause,
            actions: [cancelAction],
            intentIdentifiers: [],
            options: []
        )

        // Merge with any existing categories rather than replacing all of them
        UNUserNotificationCenter.current().getNotificationCategories { existing in
            var updated = existing.filter {
                $0.identifier != categoryId && $0.identifier != categoryIdNoPause
            }
            updated.insert(categoryWithPause)
            updated.insert(categoryNoPause)
            UNUserNotificationCenter.current().setNotificationCategories(updated)
        }
    }

    // MARK: - Progress (foreground best-effort)

    /// Show or update a progress notification.
    ///
    /// - Parameters:
    ///   - taskId:     Unique task identifier (used as notification identifier).
    ///   - title:      Notification title. May contain template variables.
    ///   - progress:   Download progress 0–100.
    ///   - message:    Optional body text. May contain template variables.
    ///   - filename:   Optional filename for template substitution.
    ///   - allowPause: When `false`, the Pause action button is omitted from the notification.
    ///                 Defaults to `true`.
    ///
    /// On iOS this is best-effort: notification may not update in real time during background.
    static func showProgress(
        taskId: String,
        title: String,
        progress: Double,
        message: String? = nil,
        filename: String? = nil,
        allowPause: Bool = true
    ) {
        let resolvedTitle   = applyTemplate(title, filename: filename, progress: progress)
        let rawBody         = message ?? String(format: "%.0f%%", progress)
        let resolvedBody    = applyTemplate(rawBody, filename: filename, progress: progress)

        let content = UNMutableNotificationContent()
        content.title = resolvedTitle
        content.body = resolvedBody
        content.categoryIdentifier = allowPause ? categoryId : categoryIdNoPause
        content.threadIdentifier = threadIdentifier

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
        content.title = applyTemplate(title, filename: fileName)
        content.body = fileName.map { "Downloaded: \($0)" } ?? "Download complete"
        content.sound = .default
        content.threadIdentifier = threadIdentifier

        let request = UNNotificationRequest(
            identifier: "nwm_dl_\(taskId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func showFailed(taskId: String, title: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = applyTemplate(title)
        content.body = "Failed: \(error)"
        content.sound = .defaultCritical
        content.threadIdentifier = threadIdentifier

        let request = UNNotificationRequest(
            identifier: "nwm_dl_\(taskId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Group Summary

    /// Show (or update) a summary notification that iOS uses as the thread header
    /// when multiple NWM download notifications are collapsed together.
    static func showGroupSummary(activeCount: Int, completedCount: Int) {
        guard activeCount > 0 || completedCount > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Downloads"
        content.body = "\(activeCount) active, \(completedCount) completed"
        content.threadIdentifier = threadIdentifier
        let request = UNNotificationRequest(identifier: "nwm_group_summary", content: content, trigger: nil)
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
