import Flutter
import UserNotifications

// MARK: - Stream Handlers & Notification Delegate
// Separated from NativeWorkmanagerPlugin.swift to reduce God Object complexity.

// MARK: - FlutterStreamHandler

extension NativeWorkmanagerPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
                self.eventSink = events

        // Platform Limitation: Kotlin SharedFlow not directly compatible with Swift
        // Note: Kotlin SharedFlow doesn't conform to Swift's AsyncSequence protocol, preventing
        // direct iteration in Swift. This is a known Kotlin/Native interop limitation.
        //
        // Workaround: Events are emitted through native callbacks instead of SharedFlow subscription.
        // Native workers and KMP scheduler call emitTaskEvent() directly, which then forwards
        // events to the Flutter event sink. This provides equivalent functionality.
        //
        // Status: This is a documented Kotlin/Swift interop workaround that achieves the same result.
        Task { [weak self] in
            guard let self = self else { return }
            // Placeholder - actual events come through native callbacks
            NativeLogger.d("EventSink registered - listening for task events")
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - Progress Stream Handler

class ProgressStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: NativeWorkmanagerPlugin?

    init(plugin: NativeWorkmanagerPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Set progress sink on plugin
        plugin?.progressSink = events
        
        // Also forward updates from ProgressReporter (used by non-download workers)
        ProgressReporter.shared.onProgress = { [weak plugin] dict in
            plugin?.emitRichProgress(dict)
        }
        
        NativeLogger.d("ProgressStreamHandler: Progress sink registered")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.progressSink = nil
        ProgressReporter.shared.onProgress = nil
        NativeLogger.d("ProgressStreamHandler: Progress sink cancelled")
        return nil
    }
}

// MARK: - UNUserNotificationCenterDelegate (interactive notification buttons)

@available(iOS 13.0, *)
extension NativeWorkmanagerPlugin: UNUserNotificationCenterDelegate {

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let catId = response.notification.request.content.categoryIdentifier
        guard catId == DownloadNotificationManager.categoryId else {
            // Forward to previous delegate (app's own handler) for non-NWM notifications
            if let prev = previousNotificationDelegate,
               prev.responds(to: #selector(userNotificationCenter(_:didReceive:withCompletionHandler:))) {
                prev.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
            } else {
                completionHandler()
            }
            return
        }

        let notifId = response.notification.request.identifier
        guard notifId.hasPrefix("nwm_dl_") else {
            completionHandler()
            return
        }
        let taskId = String(notifId.dropFirst("nwm_dl_".count))

        switch response.actionIdentifier {
        case DownloadNotificationManager.pauseActionId:
            // Pause: cancel the running Swift Task + update persistent status
            stateQueue.async(flags: .barrier) {
                self.activeTasks[taskId]?.cancel()
                self.activeTasks.removeValue(forKey: taskId)
                self.taskStates[taskId] = .paused
            }
            taskStore?.updateStatus(taskId: taskId, status: "paused")
            DownloadNotificationManager.dismiss(taskId: taskId)
            NativeLogger.d("Notification Pause tapped for task '\(taskId)'")

        case DownloadNotificationManager.cancelActionId:
            // Cancel: same as programmatic cancel
            if #available(iOS 13.0, *) {
                cleanupTempFiles(forTaskId: taskId)
            }
            stateQueue.async(flags: .barrier) {
                self.activeTasks[taskId]?.cancel()
                self.activeTasks.removeValue(forKey: taskId)
                self.taskStates[taskId] = .cancelled
                self.taskNotifTitles.removeValue(forKey: taskId)
                self.taskAllowPause.removeValue(forKey: taskId)
            }
            taskStore?.updateStatus(taskId: taskId, status: "cancelled")
            DownloadNotificationManager.dismiss(taskId: taskId)
            NativeLogger.d("Notification Cancel tapped for task '\(taskId)'")

        default:
            break
        }
        completionHandler()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Forward non-NWM notifications to previous delegate
        if notification.request.content.categoryIdentifier != DownloadNotificationManager.categoryId {
            if let prev = previousNotificationDelegate,
               prev.responds(to: #selector(userNotificationCenter(_:willPresent:withCompletionHandler:))) {
                prev.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
                return
            }
        }
        // NWM notifications: show banner + list even in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list])
        } else {
            completionHandler([.alert])
        }
    }
}
