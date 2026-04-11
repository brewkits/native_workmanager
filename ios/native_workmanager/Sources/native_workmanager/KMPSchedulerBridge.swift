import Foundation
import KMPWorkManager

/// Helper class to bridge Flutter method calls to KMP BackgroundTaskScheduler.
/// Converts Flutter arguments to KMP types and handles async scheduler calls.
class KMPSchedulerBridge {

    /// Enqueue a task using KMP BackgroundTaskScheduler
    static func enqueue(
        scheduler: BackgroundTaskScheduler,
        taskId: String,
        triggerMap: [String: Any],
        workerClassName: String,
        constraintsMap: [String: Any]?,
        inputJson: String?,
        policyString: String?,
        completion: @escaping (Result<ScheduleResult, Error>) -> Void
    ) {
        // Parse trigger
        guard let trigger = parseTrigger(from: triggerMap) else {
            completion(.failure(NSError(
                domain: "KMPSchedulerBridge",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid trigger configuration"]
            )))
            return
        }

        // Parse constraints
        let constraints = parseConstraints(from: constraintsMap)

        // Parse existing policy
        let policy = parseExistingPolicy(from: policyString)

        // Call KMP scheduler (async)
        // Note: KMP suspend functions are exposed as async callbacks in Swift
        scheduler.enqueue(
            id: taskId,
            trigger: trigger,
            workerClassName: workerClassName,
            constraints: constraints,
            inputJson: inputJson,
            policy: policy
        ) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let scheduleResult = result {
                completion(.success(scheduleResult))
            } else {
                completion(.failure(NSError(
                    domain: "KMPSchedulerBridge",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown scheduler error"]
                )))
            }
        }
    }

    /// Parse TaskTrigger from Flutter map
    private static func parseTrigger(from map: [String: Any]) -> TaskTrigger? {
        let triggerType = map["type"] as? String ?? "oneTime"

        switch triggerType {
        case "oneTime":
            let delayMs = (map["initialDelayMs"] as? NSNumber)?.int64Value ?? 0
            return TaskTriggerOneTime(initialDelayMs: delayMs)

        case "periodic":
            guard let intervalMs = (map["intervalMs"] as? NSNumber)?.int64Value else {
                return nil
            }
            let flexMs = (map["flexMs"] as? NSNumber)?.int64Value
            return TaskTriggerPeriodic(
                intervalMs: intervalMs,
                flexMs: flexMs != nil ? KotlinLong(value: flexMs!) : nil
            )

        case "exact":
            guard let scheduledTimeMs = (map["scheduledTimeMs"] as? NSNumber)?.int64Value else {
                return nil
            }
            return TaskTriggerExact(atEpochMillis: scheduledTimeMs)

        case "windowed":
            // iOS supports windowed via earliestBeginDate; `latest` is advisory only.
            guard let earliestMs = (map["earliestMs"] as? NSNumber)?.int64Value,
                  let latestMs = (map["latestMs"] as? NSNumber)?.int64Value else {
                return nil
            }
            return TaskTriggerWindowed(earliest: earliestMs, latest: latestMs)

        default:
            // Android-only triggers (contentUri, batteryOkay, batteryLow, deviceIdle, storageLow)
            // return nil — caller will surface "Invalid trigger configuration" to Dart.
            return nil
        }
    }

    /// Parse Constraints from Flutter map.
    /// Every field sent by Dart's Constraints.toMap() is honoured here.
    private static func parseConstraints(from map: [String: Any]?) -> Constraints {
        let requiresNetwork = map?["requiresNetwork"] as? Bool ?? false
        let requiresCharging = map?["requiresCharging"] as? Bool ?? false
        let isHeavyTask = map?["isHeavyTask"] as? Bool ?? false

        let qos: Qos
        switch (map?["qos"] as? String)?.lowercased() {
        case "utility":         qos = .utility
        case "userinitiated":   qos = .userinitiated
        case "userinteractive": qos = .userinteractive
        default:                qos = .background
        }

        let exactAlarmBehavior: ExactAlarmIOSBehavior
        switch (map?["exactAlarmIOSBehavior"] as? String)?.lowercased() {
        case "attemptbackgroundrun": exactAlarmBehavior = .attemptBackgroundRun
        case "throwerror":           exactAlarmBehavior = .throwError
        default:                     exactAlarmBehavior = .showNotification
        }

        // requiresUnmeteredNetwork (WiFi-only) is not supported by BGTaskScheduler.
        // iOS only supports requiresNetworkConnectivity (any network). Log a warning so
        // developers are not surprised when a task runs on cellular despite the constraint.
        if map?["requiresUnmeteredNetwork"] as? Bool == true {
            NativeLogger.d("WARNING: requiresUnmeteredNetwork is not supported on iOS. " +
                           "BGTaskScheduler only supports binary network connectivity — the task " +
                           "will run on any available network including cellular.")
        }
        // systemConstraints, allowWhileIdle, backoffPolicy, backoffDelayMs are Android-only.
        return Constraints(
            requiresNetwork: requiresNetwork,
            requiresUnmeteredNetwork: false,
            requiresCharging: requiresCharging,
            allowWhileIdle: false,
            qos: qos,
            isHeavyTask: isHeavyTask,
            backoffPolicy: .exponential,
            backoffDelayMs: 30000,
            systemConstraints: [],
            exactAlarmIOSBehavior: exactAlarmBehavior,
            extras: [:]
        )
    }

    /// Parse ExistingPolicy from Flutter string
    private static func parseExistingPolicy(from string: String?) -> ExistingPolicy {
        guard let string = string else {
            return .replace
        }

        switch string.lowercased() {
        case "keep":
            return .keep
        case "replace":
            return .replace
        default:
            return .replace
        }
    }

    /// Convert ScheduleResult to Flutter result string
    static func scheduleResultToString(_ result: ScheduleResult) -> String {
        // ScheduleResult is an enum in Kotlin, check its name property
        let resultName = String(describing: result)
        if resultName.contains("ACCEPTED") {
            return "ACCEPTED"
        } else if resultName.contains("REJECTED") {
            return "REJECTED_OS_POLICY"
        } else if resultName.contains("THROTTLED") {
            return "THROTTLED"
        } else {
            return "ACCEPTED" // Default to accepted
        }
    }
}
