import Foundation
import Flutter

extension NativeWorkmanagerPlugin {

    internal func handleOfflineQueueEnqueue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let queueId = args["queueId"] as? String,
              let entryMap = args["entry"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        let taskId = entryMap["taskId"] as? String ?? ""
        let workerClassName = entryMap["workerClassName"] as? String ?? ""
        let workerConfig = entryMap["workerConfig"] as? [String: Any]
        let retryPolicy = entryMap["retryPolicy"] as? [String: Any]

        NativeLogger.d("📥 Enqueuing to native OfflineQueue '\(queueId)': \(taskId)")

        if #available(iOS 13.0, *) {
            let configJson = workerConfig.flatMap { dict -> String? in
                let sanitized = TaskStore.sanitizeConfig(dict)
                guard let data = try? JSONSerialization.data(withJSONObject: sanitized as Any),
                      let s = String(data: data, encoding: .utf8) else { return nil }
                return s
            }
            
            let retryPolicyJson = retryPolicy.flatMap { dict -> String? in
                guard let data = try? JSONSerialization.data(withJSONObject: dict),
                      let s = String(data: data, encoding: .utf8) else { return nil }
                return s
            }

            OfflineQueueStore.shared.enqueue(
                queueId: queueId,
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: configJson,
                retryPolicy: retryPolicyJson
            )
            
            // Trigger processing
            processOfflineQueue()
        }

        result(nil)
    }

    @available(iOS 13.0, *)
    internal func processOfflineQueue() {
        // Atomically check-and-set the guard flag to prevent concurrent invocations.
        // sync(flags: .barrier) on the concurrent stateQueue drains all readers first,
        // then executes exclusively — giving us a safe compare-and-swap.
        var shouldProcess = false
        stateQueue.sync(flags: .barrier) {
            if !self._offlineQueueProcessing {
                self._offlineQueueProcessing = true
                shouldProcess = true
            }
        }
        guard shouldProcess else { return }

        Task {
            defer {
                self.stateQueue.async(flags: .barrier) { self._offlineQueueProcessing = false }
            }

            let entries = OfflineQueueStore.shared.getNextEntries(limit: 10)
            if entries.isEmpty { return }

            NativeLogger.d("🔄 processOfflineQueue: Processing \(entries.count) entries")

            for entry in entries {
                let success = await executeOfflineEntry(entry)
                if success {
                    OfflineQueueStore.shared.delete(id: entry.id)
                    NativeLogger.d("✅ OfflineQueue: Task \(entry.taskId) moved to execution")
                }
            }
        }
    }

    @available(iOS 13.0, *)
    private func executeOfflineEntry(_ entry: OfflineQueueStore.QueueRecord) async -> Bool {
        // Build config
        guard let configData = entry.workerConfig?.data(using: .utf8),
              let workerConfig = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
            return false
        }

        if entry.workerClassName.contains("HttpDownloadWorker") {
            // BackgroundSessionManager handles network waiting and partial-file resume
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                BackgroundSessionManager.shared.download(
                    taskId: entry.taskId,
                    config: workerConfig
                ) { result in
                    switch result {
                    case .success: continuation.resume(returning: true)
                    case .failure: continuation.resume(returning: true) // Enqueued; remove from offline queue
                    }
                }
            }
        }

        // For all other worker types, execute synchronously via the standard path
        let result = await executeWorkerSync(
            taskId: entry.taskId,
            workerClassName: entry.workerClassName,
            workerConfig: workerConfig,
            qos: "background"
        )
        return result.success
    }
}
