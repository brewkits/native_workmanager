import Foundation
import UIKit
import KMPWorkManager

/**
 * Central processor for background commands (from Push or MethodChannel).
 */
@available(iOS 13.0, *)
enum CommandProcessor {

    static func handleDirectRemoteCommand(command: [String: Any]) async -> Bool {
        guard let action = command["action"] as? String,
              let data = command["data"] as? [String: Any] else {
            return false
        }

        NativeLogger.d("📡 Processing direct command: \(action)")

        switch action {
        case "enqueue_task":
            let taskId = data["taskId"] as? String ?? UUID().uuidString
            guard let workerClassName = data["workerClassName"] as? String else { return false }
            let workerConfig = data["workerConfig"] as? [String: Any] ?? [:]
            
            return await executeWorkerStateless(
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: workerConfig
            )
        case "enqueue_chain":
            let steps = data["steps"] as? [[Any]] ?? []
            let chainName = data["name"] as? String ?? "remote_chain"
            
            return await executeChainStateless(
                steps: steps,
                chainName: chainName
            )
        case "offline_queue_enqueue":
            let queueId = data["queueId"] as? String ?? "default"
            guard let entry = data["entry"] as? [String: Any],
                  let taskId = entry["taskId"] as? String,
                  let workerClassName = entry["workerClassName"] as? String else { return false }
            
            let workerConfig = entry["workerConfig"] as? [String: Any]
            let retryPolicy = entry["retryPolicy"] as? [String: Any]
            
            let configJson = workerConfig.flatMap { try? JSONSerialization.data(withJSONObject: $0) }.flatMap { String(data: $0, encoding: .utf8) }
            let retryPolicyJson = retryPolicy.flatMap { try? JSONSerialization.data(withJSONObject: $0) }.flatMap { String(data: $0, encoding: .utf8) }

            OfflineQueueStore.shared.enqueue(
                queueId: queueId,
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: configJson,
                retryPolicy: retryPolicyJson
            )
            return true
        default:
            return false
        }
    }

    static func executeChainStateless(steps: [[Any]], chainName: String) async -> Bool {
        guard !steps.isEmpty else { 
            NativeLogger.w("⚠️ Command 'enqueue_chain' REJECTED: Steps list is empty")
            return false 
        }
        
        let chainId = "\(chainName)_\(UUID().uuidString)"
        let chainStateManager = ChainStateManager.shared
        
        // SEC-001: Ensure UIApplication.shared is called on Main Thread
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        await MainActor.run {
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemoteChain_\(chainId)") {
                NativeLogger.w("Remote chain background task '\(chainId)' expired!")
            }
        }
        
        defer {
            if bgTask != .invalid {
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(bgTask)
                }
            }
        }

        do {
            let initialState = try ChainStateManager.createInitialState(
                chainId: chainId,
                chainName: chainName,
                stepsData: steps
            )
            try await chainStateManager.saveChainState(initialState)
            
            for (stepIndex, _) in steps.enumerated() {
                guard let state = try await chainStateManager.loadChainState(chainId: chainId) else { break }
                let stepTasks = state.steps[stepIndex]
                
                let previousStepData = try await chainStateManager.getPreviousStepResult(
                    chainId: chainId,
                    currentStepIndex: stepIndex
                )
                
                var stepSucceeded = true
                
                await withTaskGroup(of: (success: Bool, data: [String: Any]? ).self) { group in
                    for task in stepTasks {
                        var workerConfig = task.workerConfig.mapValues { $0.value }
                        if let previousData = previousStepData {
                            workerConfig = substituteTemplates(in: workerConfig, with: previousData)
                        }
                        
                        group.addTask {
                            let success = await executeWorkerStateless(
                                taskId: task.taskId,
                                workerClassName: task.workerClassName,
                                workerConfig: workerConfig
                            )
                            return (success, nil)
                        }
                    }
                    
                    for await taskResult in group {
                        if !taskResult.success {
                            stepSucceeded = false
                        }
                    }
                }
                
                if !stepSucceeded {
                    try await chainStateManager.markChainFailed(chainId: chainId)
                    return false
                }
                
                try await chainStateManager.saveStepResult(chainId: chainId, stepIndex: stepIndex, resultData: nil)
                try await chainStateManager.advanceToNextStep(chainId: chainId)
            }
            
            try await chainStateManager.markChainCompleted(chainId: chainId)
            return true
        } catch {
            NativeLogger.e("executeChainStateless error: \(error.localizedDescription)")
            return false
        }
    }

    static func executeWorkerStateless(taskId: String,
                                      workerClassName: String,
                                      workerConfig: [String: Any]) async -> Bool {
        if workerClassName.contains("HttpDownloadWorker") {
            return await withCheckedContinuation { continuation in
                BackgroundSessionManager.shared.download(
                    taskId: taskId,
                    config: workerConfig
                ) { result in
                    switch result {
                    case .success: continuation.resume(returning: true)
                    case .failure: continuation.resume(returning: false)
                    }
                }
            }
        }

        guard let worker = IosWorkerFactory.createWorker(className: workerClassName) else {
            NativeLogger.w("executeWorkerStateless: unknown worker class '\(workerClassName)'")
            return false
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: workerConfig),
              let inputJson = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        do {
            let result = try await worker.doWork(input: inputJson, env: WorkerEnvironment(progressListener: nil, isCancelled: { KotlinBoolean(bool: false) }))
            return result.success
        } catch {
            NativeLogger.e("executeWorkerStateless '\(taskId)': \(error.localizedDescription)")
            return false
        }
    }

    static func substituteTemplates(in config: [String: Any], with values: [String: Any]) -> [String: Any] {
        var result = config
        for (key, value) in config {
            if let strValue = value as? String {
                result[key] = substituteString(strValue, with: values)
            } else if let dictValue = value as? [String: Any] {
                result[key] = substituteTemplates(in: dictValue, with: values)
            } else if let arrayValue = value as? [[String: Any]] {
                result[key] = arrayValue.map { substituteTemplates(in: $0, with: values) }
            }
        }
        return result
    }

    static func substituteString(_ template: String, with values: [String: Any]) -> String {
        var result = template
        for (key, value) in values {
            let placeholder = "{{\(key)}}"
            if result.contains(placeholder) {
                result = result.replacingOccurrences(of: placeholder, with: "\(value)")
            }
        }
        if let data = values["data"] as? [String: Any] {
            for (key, value) in data {
                let placeholder = "{{\(key)}}"
                if result.contains(placeholder) {
                    result = result.replacingOccurrences(of: placeholder, with: "\(value)")
                }
            }
        }
        return result
    }
}
