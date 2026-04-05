import Flutter
import UIKit

// MARK: - Cancel / Tag / Pause / Resume / Misc handlers
// Implements method-channel endpoints missing from the base NativeWorkmanagerPlugin.

extension NativeWorkmanagerPlugin {

    // MARK: - cancelAll

    func handleCancelAll(result: @escaping FlutterResult) {
        // Cancel every tracked Swift Task.
        stateQueue.sync(flags: .barrier) {
            activeTasks.values.forEach { $0.cancel() }
            activeTasks.removeAll()
            taskStates.removeAll()
            taskTags.removeAll()
        }

        if #available(iOS 13.0, *) {
            // Cancel any live background-session downloads individually.
            let allRecords = taskStore?.allTasks() ?? []
            for record in allRecords {
                BackgroundSessionManager.shared.cancel(taskId: record.taskId)
                taskStore?.updateStatus(taskId: record.taskId, status: "cancelled")
            }
            BGTaskSchedulerManager.shared.cancelAllTasks()
        }
        result(nil)
    }

    // MARK: - cancelByTag

    func handleCancelByTag(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let tag = args["tag"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "tag required", details: nil))
            return
        }

        var taskIdsToCancel: [String] = []
        stateQueue.sync(flags: .barrier) {
            taskIdsToCancel = taskTags.compactMap { $0.value == tag ? $0.key : nil }
            for taskId in taskIdsToCancel {
                activeTasks[taskId]?.cancel()
                activeTasks.removeValue(forKey: taskId)
                taskStates[taskId] = "cancelled"
                taskTags.removeValue(forKey: taskId)
            }
        }

        if #available(iOS 13.0, *) {
            // Also cancel any tasks with this tag persisted in the store
            // (covers tasks that already started and were removed from in-memory taskTags).
            let persistedIds = taskStore?.allTasks()
                .filter { $0.tag == tag }
                .map { $0.taskId } ?? []
            let allIds = Set(taskIdsToCancel + persistedIds)
            for taskId in allIds {
                BackgroundSessionManager.shared.cancel(taskId: taskId)
                taskStore?.updateStatus(taskId: taskId, status: "cancelled")
                stateQueue.async(flags: .barrier) {
                    self.activeTasks[taskId]?.cancel()
                    self.activeTasks.removeValue(forKey: taskId)
                    self.taskStates[taskId] = "cancelled"
                    self.taskTags.removeValue(forKey: taskId)
                }
            }
        }
        result(nil)
    }

    // MARK: - getTasksByTag

    func handleGetTasksByTag(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let tag = args["tag"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "tag required", details: nil))
            return
        }

        // In-memory tag map.
        var ids: [String] = stateQueue.sync {
            taskTags.compactMap { $0.value == tag ? $0.key : nil }
        }

        // Also check persisted store for tasks that survived hot restarts.
        // Exclude cancelled/completed tasks — those are no longer "active" for this tag.
        if #available(iOS 13.0, *) {
            let activePersisted = taskStore?.allTasks()
                .filter { $0.tag == tag && $0.status != "cancelled" && $0.status != "completed" && $0.status != "failed" }
                .map { $0.taskId } ?? []
            for id in activePersisted where !ids.contains(id) {
                ids.append(id)
            }
        }
        result(ids)
    }

    // MARK: - getAllTags

    func handleGetAllTags(result: @escaping FlutterResult) {
        var tags: Set<String> = stateQueue.sync {
            Set(taskTags.values)
        }
        if #available(iOS 13.0, *) {
            taskStore?.allTasks()
                .compactMap { $0.tag }
                .forEach { tags.insert($0) }
        }
        result(Array(tags))
    }

    // MARK: - pause

    func handlePause(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId required", details: nil))
            return
        }

        if #available(iOS 13.0, *) {
            // Try pausing a background URL-session download.
            BackgroundSessionManager.shared.pause(taskId: taskId) { [weak self] paused in
                self?.stateQueue.async(flags: .barrier) {
                    self?.taskStates[taskId] = "paused"
                }
                self?.taskStore?.updateStatus(taskId: taskId, status: "paused")
                result(nil)
            }
        } else {
            stateQueue.async(flags: .barrier) { self.taskStates[taskId] = "paused" }
            result(nil)
        }
    }

    // MARK: - resume

    func handleResume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId required", details: nil))
            return
        }

        if #available(iOS 13.0, *) {
            guard let record = taskStore?.task(taskId: taskId),
                  !record.workerClassName.isEmpty else {
                // Nothing to resume — succeed silently.
                result(nil)
                return
            }
            var workerConfig: [String: Any] = [:]
            if let configJson = record.workerConfig,
               let data = configJson.data(using: String.Encoding.utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                workerConfig = parsed
            }
            taskStore?.updateStatus(taskId: taskId, status: "pending")
            stateQueue.async(flags: .barrier) { self.taskStates[taskId] = "pending" }
            Task { [weak self] in
                await self?.executeWorkerSync(
                    taskId: taskId,
                    workerClassName: record.workerClassName,
                    workerConfig: workerConfig,
                    qos: "background"
                )
            }
        } else {
            stateQueue.async(flags: .barrier) { self.taskStates[taskId] = "pending" }
        }
        result(nil)
    }

    // MARK: - getServerFilename

    func handleGetServerFilename(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGS", message: "url required", details: nil))
            return
        }
        let headers = args["headers"] as? [String: String] ?? [:]
        let timeoutMs = (args["timeoutMs"] as? Int) ?? 30_000

        Task {
            var req = URLRequest(url: url, timeoutInterval: Double(timeoutMs) / 1000.0)
            req.httpMethod = "HEAD"
            headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                var filename: String? = nil
                if let http = resp as? HTTPURLResponse,
                   let disposition = http.value(forHTTPHeaderField: "Content-Disposition") {
                    for part in disposition.components(separatedBy: ";") {
                        let trimmed = part.trimmingCharacters(in: .whitespaces)
                        if trimmed.lowercased().hasPrefix("filename=") {
                            filename = String(trimmed.dropFirst("filename=".count))
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                            break
                        }
                    }
                }
                result(filename)
            } catch {
                result(FlutterError(code: "GET_FILENAME_ERROR",
                                    message: error.localizedDescription,
                                    details: nil))
            }
        }
    }

    // MARK: - openFile

    func handleOpenFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
            return
        }
        let fileURL = URL(fileURLWithPath: filePath)
        DispatchQueue.main.async { [weak self] in
            self?.docController = UIDocumentInteractionController(url: fileURL)
            guard let vc = UIApplication.shared.keyWindow?.rootViewController else {
                result(FlutterError(code: "OPEN_FILE_ERROR",
                                    message: "No root view controller",
                                    details: nil))
                return
            }
            let presented = self?.docController?.presentOpenInMenu(
                from: .zero, in: vc.view, animated: true) ?? false
            if presented {
                result(nil)
            } else {
                result(FlutterError(code: "OPEN_FILE_ERROR",
                                    message: "No app found to open file",
                                    details: nil))
            }
        }
    }
}
