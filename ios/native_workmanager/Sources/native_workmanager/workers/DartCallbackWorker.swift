import Foundation

/// Dart callback worker for iOS.
///
/// Executes Dart code in a background isolate using FlutterEngineManager.
/// Provides Mode 2 execution (Dart workers) for complex business logic
/// that requires Flutter plugins or Dart-specific functionality.
///
/// **Configuration JSON:**
/// ```json
/// {
///   "callbackId": "myCallback",        // For logging/debugging
///   "callbackHandle": 12345678,        // ✅ Serializable handle (REQUIRED)
///   "input": "{\"key\":\"value\"}",    // Optional: JSON input string
///   "timeoutMs": 300000,               // Optional: Timeout (default: 5 minutes)
///   "autoDispose": true                // Optional: Kill engine immediately after completion (default: false)
/// }
/// ```
///
/// **Performance:**
/// - Cold start (first execution): 500-1000ms + callback time
/// - Warm start (cached engine): 100-200ms + callback time
/// - Memory: 30-50MB when engine active
///
/// **Use Cases:**
/// - Complex Dart business logic
/// - Access to Flutter plugins (database, etc.)
/// - State management operations
/// - Custom data processing
class DartCallbackWorker: IosWorker {

    // MARK: - Singleton

    static let shared = DartCallbackWorker()

    private init() {}

    // MARK: - Configuration

    private static let defaultTimeoutMs: Int64 = 300_000 // 5 minutes

    struct Config: Codable {
        let callbackId: String       // For logging/debugging
        let callbackHandle: Int64    // ✅ Serializable handle (REQUIRED)
        let input: String?
        let timeoutMs: Int64?
        let autoDispose: Bool?       // ✅ NEW: Aggressive disposal flag

        var timeoutSeconds: TimeInterval {
            TimeInterval((timeoutMs ?? DartCallbackWorker.defaultTimeoutMs) / 1000)
        }

        var shouldAutoDispose: Bool {
            autoDispose ?? false
        }
    }

    // MARK: - Worker Implementation

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("DartCallbackWorker: Error - Empty or null input")
            return WorkerResult.failure(message: "Empty or null input")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            print("DartCallbackWorker: Error - Invalid UTF-8 encoding")
            return WorkerResult.failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("DartCallbackWorker: Error parsing JSON config: \(error)")
            return WorkerResult.failure(message: "Error parsing JSON config: \(error.localizedDescription)")
        }

        print("DartCallbackWorker: Executing callback '\(config.callbackId)' (handle: \(config.callbackHandle), autoDispose: \(config.shouldAutoDispose))")

        let startTime = Date()
        let engineWasAlive = FlutterEngineManager.shared.isEngineAlive

        // ✅ FIXED: Execute callback via FlutterEngineManager with callbackHandle
        // The callbackHandle enables cross-isolate execution
        do {
            let result = try await FlutterEngineManager.shared.executeDartCallback(
                callbackHandle: config.callbackHandle,  // ✅ Pass serializable handle
                input: config.input,
                timeoutSeconds: config.timeoutSeconds,
                disposeImmediately: config.shouldAutoDispose // ✅ NEW: Aggressive disposal flag
            )

            let executionTime = Date().timeIntervalSince(startTime)

            if result {
                if engineWasAlive {
                    print("DartCallbackWorker: Success (warm start) - \(Int(executionTime * 1000))ms")
                } else {
                    print("DartCallbackWorker: Success (cold start) - \(Int(executionTime * 1000))ms")
                }
                return WorkerResult.success(message: "Callback returned true")
            } else {
                print("DartCallbackWorker: Failed - Callback returned false")
                return WorkerResult.failure(message: "Callback returned false")
            }
        } catch {
            let executionTime = Date().timeIntervalSince(startTime)
            print("DartCallbackWorker: Error - \(error.localizedDescription) (\(Int(executionTime * 1000))ms)")
            return WorkerResult.failure(message: "Execution error: \(error.localizedDescription)")
        }
    }
}
