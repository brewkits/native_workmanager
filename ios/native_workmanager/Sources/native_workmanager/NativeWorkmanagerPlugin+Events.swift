import Flutter
import UIKit
import UserNotifications

// MARK: - Event Emission & Debug Notifications
// Separated from NativeWorkmanagerPlugin.swift to reduce God Object complexity.
// Contains event emission to Flutter, progress reporting, and debug notifications.

extension NativeWorkmanagerPlugin {

    // MARK: - Event Emission

    /// Emit a "started" lifecycle event when a worker begins execution.
    ///
    /// Called from `executeWorkerSync` before the first attempt so that
    /// `ObservabilityConfig.onTaskStart` fires reliably for all tasks —
    /// including fast workers that never emit a progress update.
    func emitTaskStarted(taskId: String, workerType: String) {
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = "running"
            self.taskStartTimes[taskId] = Date()
        }
        if #available(iOS 13.0, *) {
            taskStore?.updateStatus(taskId: taskId, status: "running", resultData: nil)
        }
        let event: [String: Any] = [
            "taskId": taskId,
            "isStarted": true,
            "workerType": workerType,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }

    func emitTaskEvent(taskId: String, success: Bool, message: String?, resultData: [String: Any]? = nil) {
        // Update task state
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = success ? "success" : "failed"
        }

        // Persist status change to SQLite store
        if #available(iOS 13.0, *) {
            let resultJson: String? = resultData.flatMap { data in
                (try? JSONSerialization.data(withJSONObject: data))
                    .flatMap { String(data: $0, encoding: .utf8) }
            }
            taskStore?.updateStatus(
                taskId: taskId,
                status: success ? "success" : "failed",
                resultData: resultJson
            )


            // Show download completion/failure notification if enabled for this task
            let notifTitle: String? = stateQueue.sync { taskNotifTitles[taskId] }
            if let title = notifTitle {
                stateQueue.async(flags: .barrier) {
                    self.taskNotifTitles.removeValue(forKey: taskId)
                    self.taskAllowPause.removeValue(forKey: taskId)
                }
                if success {
                    DownloadNotificationManager.showCompleted(taskId: taskId, title: title, fileName: nil)
                } else {
                    DownloadNotificationManager.showFailed(taskId: taskId, title: title, error: message ?? "Download failed")
                }
            }
        }

        ProgressReporter.shared.clearTask(taskId)

        // Show debug notification if enabled
        if debugMode && isDebugBuild() {
            showDebugNotification(taskId: taskId, success: success, message: message)
        }

        // Always emit event to Dart (v2.3.0+: includes resultData)
        var event: [String: Any] = [
            "taskId": taskId,
            "success": success,
            "message": message as Any,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        if !success {
            event["errorCode"] = Self.deriveErrorCode(message)
        }

        if let data = resultData {
            event["resultData"] = data
        }

        // Ensure event is emitted on the main thread
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }

    /// Derive a structured error-code string from a worker failure message.
    ///
    /// Mirrors the Kotlin `deriveErrorCode()` helper in the Android plugin so that
    /// the same `NativeWorkManagerError` enum values are produced on both platforms.
    static func deriveErrorCode(_ message: String?) -> String {
        guard let msg = message else { return "UNKNOWN" }
        let lower = msg.lowercased()
        if msg.hasPrefix("HTTP 4") || msg.hasPrefix("http 4") { return "HTTP_CLIENT_ERROR" }
        if msg.hasPrefix("HTTP 5") || msg.hasPrefix("http 5") { return "HTTP_SERVER_ERROR" }
        if lower.contains("timeout") { return "TIMEOUT" }
        if lower.contains("network") || lower.contains("connect") ||
           lower.contains("socket") || lower.contains("unreachable") { return "NETWORK_ERROR" }
        if lower.contains("disk space") || lower.contains("insufficient") ||
           lower.contains("no space") { return "INSUFFICIENT_STORAGE" }
        if lower.contains("not found") || lower.contains("no such file") ||
           lower.contains("does not exist") { return "FILE_NOT_FOUND" }
        if lower.contains("unsafe") || lower.contains("ssrf") ||
           lower.contains("security") { return "SECURITY_VIOLATION" }
        if lower.contains("cancel") { return "CANCELLED" }
        return "WORKER_EXCEPTION"
    }

    func emitProgress(taskId: String, progress: Int, message: String?) {
        // Show download progress notification if enabled for this task
        if #available(iOS 13.0, *) {
            let notifTitle: String? = stateQueue.sync { taskNotifTitles[taskId] }
            if let title = notifTitle {
                let allowPause: Bool = stateQueue.sync { taskAllowPause[taskId] ?? true }
                DownloadNotificationManager.showProgress(
                    taskId: taskId,
                    title: title,
                    progress: Double(progress),
                    message: message,
                    allowPause: allowPause
                )
            }
        }

        // FlutterEventSink must be called on the main thread
        DispatchQueue.main.async {
            self.progressSink?([
                "taskId": taskId,
                "progress": progress,
                "message": message as Any
            ])
        }
    }

    /// Emit a rich progress event from a pre-built dict (taskId + progress already included).
    /// Used by BackgroundSessionManager's richProgressDelegate to forward bytes/speed/ETA to Flutter.
    func emitRichProgress(_ dict: [String: Any]) {
        if #available(iOS 13.0, *),
           let taskId = dict["taskId"] as? String,
           let progress = dict["progress"] as? Int {
            let notifTitle: String? = stateQueue.sync { taskNotifTitles[taskId] }
            if let title = notifTitle {
                let allowPause: Bool = stateQueue.sync { taskAllowPause[taskId] ?? true }
                DownloadNotificationManager.showProgress(
                    taskId: taskId,
                    title: title,
                    progress: Double(progress),
                    message: dict["message"] as? String,
                    allowPause: allowPause
                )
            }
        }
        DispatchQueue.main.async {
            self.progressSink?(dict)
        }
    }

    // MARK: - Debug Mode Helpers

    func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                NativeLogger.d("Notification permissions granted for debug mode")
            } else if let error = error {
                NativeLogger.w("Notification permissions denied: \(error.localizedDescription)")
            }
        }
    }

    private func showDebugNotification(taskId: String, success: Bool, message: String?) {
        // FIX H3: Read and remove taskStartTimes under the state lock to prevent data races.
        // emitTaskEvent (which calls this) can be called from multiple threads.
        let startTime: Date? = stateQueue.sync { taskStartTimes[taskId] }
        stateQueue.async(flags: .barrier) { self.taskStartTimes.removeValue(forKey: taskId) }
        let executionTime: String
        if let startTime = startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            executionTime = String(format: "%.0fms", elapsed * 1000)
        } else {
            executionTime = "N/A"
        }

        let title = success ? "✅ Task Completed: \(taskId)" : "❌ Task Failed: \(taskId)"
        var body = "Execution time: \(executionTime)"
        if let message = message {
            body += "\n\(message)"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "debug_\(taskId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NativeLogger.e("Error showing debug notification: \(error.localizedDescription)")
            }
        }
    }
}
