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
            let flexMs = (map["flexIntervalMs"] as? NSNumber)?.int64Value
            return TaskTriggerPeriodic(
                intervalMs: intervalMs,
                flexMs: flexMs != nil ? KotlinLong(value: flexMs!) : nil
            )

        case "exact":
            guard let scheduledTimeMs = (map["scheduledTimeMs"] as? NSNumber)?.int64Value else {
                return nil
            }
            return TaskTriggerExact(atEpochMillis: scheduledTimeMs)

        default:
            return nil
        }
    }

    /// Parse Constraints from Flutter map
    private static func parseConstraints(from map: [String: Any]?) -> Constraints {
        let requiresNetwork = map?["requiresNetwork"] as? Bool ?? false
        let requiresCharging = map?["requiresCharging"] as? Bool ?? false
        let isHeavyTask = map?["isHeavyTask"] as? Bool ?? false

        // System constraints are not currently mapped from Flutter
        // Default to empty set
        let systemConstraints: Set<SystemConstraint> = []

        return Constraints(
            requiresNetwork: requiresNetwork,
            requiresUnmeteredNetwork: false,
            requiresCharging: requiresCharging,
            allowWhileIdle: false,
            qos: .background,
            isHeavyTask: isHeavyTask,
            backoffPolicy: .exponential,
            backoffDelayMs: 30000,
            systemConstraints: systemConstraints,
            exactAlarmIOSBehavior: .showNotification
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
