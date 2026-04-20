import Flutter
import Foundation

/// Singleton Flutter Engine manager for iOS Dart workers.
///
/// Manages the lifecycle of a Flutter Engine used to execute Dart callbacks
/// in background tasks. Implements engine caching for performance:
/// - First execution (cold start): 500-1000ms
/// - Subsequent executions (cached): 100-200ms
///
/// **Thread Safety:** All public methods are thread-safe and can be called
/// from any queue/thread.
///
/// **Memory:** Engine consumes 30-50MB RAM when active. Designed for
/// auto-disposal after idle timeout (not yet implemented).
class FlutterEngineManager {

    // MARK: - Singleton

    static let shared = FlutterEngineManager()

    private init() {}

    // MARK: - Properties

    private var engine: FlutterEngine?
    private var methodChannel: FlutterMethodChannel?
    private var callbackHandle: Int64?
    private var registerPlugins: Bool = false
    
    private static let callbackHandleKey = "dev.brewkits.native_workmanager.callback_handle"
    private static let registerPluginsKey = "dev.brewkits.native_workmanager.register_plugins"

    private let queue = DispatchQueue(label: "dev.brewkits.flutter_engine_manager")
    private var isInitialized = false
    private var isInitializing = false
    private var initializationContinuations: [CheckedContinuation<Void, Error>] = []

    // Timeout for engine initialization and callback execution
    private static let initTimeoutSeconds: TimeInterval = 30
    private static let defaultCallbackTimeoutSeconds: TimeInterval = 300 // 5 minutes

    // Auto-disposal after idle timeout
    private var lastUsedTimestamp: Date?
    private static let idleTimeoutSeconds: TimeInterval = 300 // 5 minutes
    private var disposalWorkItem: DispatchWorkItem?

    // MARK: - Public API

    /// Set the callback handle from Dart side.
    ///
    /// Must be called during plugin initialization before executing any Dart callbacks.
    ///
    /// - Parameter handle: Callback handle from PluginUtilities.getCallbackHandle()
    func setCallbackHandle(_ handle: Int64) {
        queue.sync {
            self.callbackHandle = handle
            UserDefaults.standard.set(handle, forKey: FlutterEngineManager.callbackHandleKey)
            NativeLogger.d("✅ FlutterEngineManager: Callback handle registered and persisted: \(handle)")
        }
    }

    /// Set whether to automatically register plugins in the background engine.
    func setRegisterPlugins(_ enabled: Bool) {
        queue.sync {
            self.registerPlugins = enabled
            UserDefaults.standard.set(enabled, forKey: FlutterEngineManager.registerPluginsKey)
        }
    }

    /// Check if Flutter Engine is currently alive.
    var isEngineAlive: Bool {
        queue.sync {
            return engine != nil && isInitialized
        }
    }

    /// BRIDGE-006: Check if a Dart callback handle has been registered via setCallbackHandle().
    ///
    /// Returns false if initialize(callbackHandle:) was never called — in which case
    /// DartCallbackWorker tasks cannot execute and should be rejected at enqueue time
    /// rather than accepted and silently failing at runtime.
    var hasCallbackHandle: Bool {
        queue.sync {
            if callbackHandle == nil {
                let saved = UserDefaults.standard.object(forKey: FlutterEngineManager.callbackHandleKey) as? Int64
                if let s = saved {
                    self.callbackHandle = s
                }
            }
            if registerPlugins == false {
                self.registerPlugins = UserDefaults.standard.bool(forKey: FlutterEngineManager.registerPluginsKey)
            }
            return callbackHandle != nil
        }
    }

    /// Execute a Dart callback in the background isolate.
    ///
    /// This method ensures the engine is initialized, then invokes the specified
    /// Dart callback with the given input. Supports aggressive disposal to free memory immediately.
    ///
    /// - Parameters:
    ///   - callbackHandle: The callback handle from PluginUtilities.getCallbackHandle()
    ///   - input: JSON string input for the callback
    ///   - timeoutSeconds: Maximum time to wait for callback completion
    ///   - disposeImmediately: If true, engine is killed immediately after callback completes (saves ~50MB RAM)
    /// - Returns: true if callback succeeded, false otherwise
    /// - Throws: Errors related to engine initialization or timeout
    func executeDartCallback(
        callbackHandle: Int64,
        input: String?,
        timeoutSeconds: TimeInterval = defaultCallbackTimeoutSeconds,
        disposeImmediately: Bool = false
    ) async throws -> Bool {
        let startTime = Date()
        let wasEngineAlive = isEngineAlive

        // Ensure engine is initialized
        try await ensureEngineInitialized()

        let initTime = Date().timeIntervalSince(startTime)
        if !wasEngineAlive {
            print("FlutterEngineManager: Cold start - Engine initialized in \(Int(initTime * 1000))ms")
        } else {
            print("FlutterEngineManager: Warm start - Engine already alive")
        }

        // Execute callback with timeout
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            // Task 1: Execute callback
            group.addTask {
                try await self.invokeCallback(callbackHandle: callbackHandle, input: input)
            }

            // Task 2: Timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw FlutterEngineError.timeout
            }

            // Return first result (either success or timeout)
            guard let result = try await group.next() else {
                throw FlutterEngineError.unknown
            }

            group.cancelAll()

            let totalTime = Date().timeIntervalSince(startTime)
            print("FlutterEngineManager: Callback (handle: \(callbackHandle)) completed in \(Int(totalTime * 1000))ms")

            if disposeImmediately {
                print("FlutterEngineManager: Aggressively disposing engine to free RAM")
                dispose()
            } else {
                // Original behavior: Keep engine alive for 5 minutes
                queue.sync {
                    self.lastUsedTimestamp = Date()
                }
                scheduleDisposalCheck()
            }

            return result
        }
    }

    /// Dispose the Flutter Engine and free resources.
    ///
    /// WARNING: This will make next callback execution slow (cold start).
    /// Only call this if memory is critical.
    func dispose() {
        queue.sync {
            print("FlutterEngineManager: Disposing engine...")

            // Remove method channel handler before clearing reference to prevent handler retention
            methodChannel?.setMethodCallHandler(nil)
            methodChannel = nil

            engine = nil
            isInitialized = false

            disposalWorkItem?.cancel()
            disposalWorkItem = nil
            lastUsedTimestamp = nil

            print("FlutterEngineManager: Engine disposed")
        }
    }

    // MARK: - Private Methods

    /// Ensure Flutter Engine is initialized (thread-safe, async).
    private func ensureEngineInitialized() async throws {
        // Fast path: already initialized
        if isInitialized {
            return
        }
        
        // Load saved handle if memory-resident one is nil (e.g. after process relaunch)
        queue.sync {
            if self.callbackHandle == nil {
                let saved = UserDefaults.standard.object(forKey: FlutterEngineManager.callbackHandleKey) as? Int64
                if let s = saved {
                    self.callbackHandle = s
                    print("FlutterEngineManager: Restored callback handle from storage: \(s)")
                }
            }
        }

        // Slow path: need initialization
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                // Double-check after acquiring lock
                if self.isInitialized {
                    continuation.resume()
                    return
                }

                // If already initializing, queue this continuation
                if self.isInitializing {
                    self.initializationContinuations.append(continuation)
                    return
                }

                // Start initialization
                self.isInitializing = true
                self.initializationContinuations.append(continuation)

                // Perform initialization on main thread (required by Flutter)
                DispatchQueue.main.async {
                    self.performInitialization()
                }
            }
        }
    }

    /// Perform actual engine initialization (must be called on main thread).
    private func performInitialization() {
        guard let callbackHandle = self.callbackHandle else {
            let error = FlutterEngineError.noCallbackHandle
            completeInitialization(error: error)
            return
        }

        print("FlutterEngineManager: Initializing Flutter Engine...")

        // Create engine
        let engine = FlutterEngine(name: "native_workmanager_background")

        // Run with callback dispatcher entry point
        let callbackInfo = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        guard let callbackInfo = callbackInfo else {
            let error = FlutterEngineError.invalidCallbackHandle
            completeInitialization(error: error)
            return
        }

        let success = engine.run(withEntrypoint: callbackInfo.callbackName,
                                libraryURI: callbackInfo.callbackLibraryPath)

        if !success {
            let error = FlutterEngineError.engineStartFailed
            completeInitialization(error: error)
            return
        }
        
        // Plugin Registration: If enabled, call GeneratedPluginRegistrant.
        // This is safe because on iOS, the registrant is a class that exists
        // in the host app and is discoverable at runtime if present.
        if self.registerPlugins {
            if let registrant = NSClassFromString("GeneratedPluginRegistrant") as? NSObject.Type {
                let selector = NSSelectorFromString("registerWithRegistry:")
                if registrant.responds(to: selector) {
                    registrant.perform(selector, with: engine)
                    NativeLogger.d("🔌 FlutterEngineManager: Registered plugins via GeneratedPluginRegistrant")
                }
            }
        }

        // Setup method channel
        let channel = FlutterMethodChannel(
            name: "dev.brewkits/dart_worker_channel",
            binaryMessenger: engine.binaryMessenger
        )

        self.engine = engine
        self.methodChannel = channel

        // Wait for Dart to signal ready
        waitForDartReady(channel: channel, timeout: FlutterEngineManager.initTimeoutSeconds)
    }

    /// Wait for Dart side to signal it's ready.
    private func waitForDartReady(channel: FlutterMethodChannel, timeout: TimeInterval) {
        // `isReady` must only be accessed from `self.queue` (a serial queue) so the timeout
        // check and the handler's write are serialized.  Setting isReady on a different thread
        // from where it's checked creates a data race that can resume continuations twice → crash.
        var isReady = false

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            if call.method == "dartReady" {
                result(nil)
                print("FlutterEngineManager: Dart side ready")

                // All writes to isReady AND continuation-resume happen on self.queue (serial).
                self.queue.async {
                    isReady = true   // guarded: only accessed from queue blocks below
                    self.isInitialized = true
                    self.isInitializing = false

                    // Resume all waiting continuations
                    let continuations = self.initializationContinuations
                    self.initializationContinuations.removeAll()

                    for continuation in continuations {
                        continuation.resume()
                    }
                }
            } else if call.method == "reportProgress" {
                // Progress reports emitted from inside a DartWorker callback.
                // The Dart side calls MethodChannel('dev.brewkits/dart_worker_channel')
                // .invokeMethod('reportProgress', {...}) which arrives here and is
                // forwarded to ProgressReporter → Flutter EventChannel.
                let args     = call.arguments as? [String: Any]
                let taskId   = args?["taskId"]   as? String ?? ""
                let progress = args?["progress"] as? Int    ?? 0
                let message  = args?["message"]  as? String
                ProgressReporter.shared.report(taskId: taskId, progress: progress, message: message)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // Use self.queue (serial) instead of DispatchQueue.global() for the timeout check.
        // This serializes the timeout check with the handler's queue.async block above,
        // so only one of them can see isReady == false and call completeInitialization.
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }

            if !isReady {
                print("FlutterEngineManager: Timeout waiting for Dart ready signal")
                self.completeInitialization(error: FlutterEngineError.dartReadyTimeout)
            }
        }
    }

    /// Complete initialization with error.
    private func completeInitialization(error: Error) {
        queue.async {
            self.isInitializing = false

            let continuations = self.initializationContinuations
            self.initializationContinuations.removeAll()

            for continuation in continuations {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Invoke Dart callback via method channel.
    private func invokeCallback(callbackHandle: Int64, input: String?) async throws -> Bool {
        guard let channel = methodChannel else {
            throw FlutterEngineError.engineNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Pass callbackHandle (not callbackId) — the background isolate resolves the handle
                let args: [String: Any?] = [
                    "callbackHandle": callbackHandle,
                    "input": input
                ]

                channel.invokeMethod("executeCallback", arguments: args) { result in
                    if let error = result as? FlutterError {
                        print("FlutterEngineManager: Callback error: \(error.message ?? "unknown")")
                        continuation.resume(returning: false)
                    } else if let success = result as? Bool {
                        continuation.resume(returning: success)
                    } else {
                        // Default to true if result is nil (backward compatibility)
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }

    /// Schedule automatic engine disposal after idle timeout.
    ///
    /// This method schedules a check to dispose the engine if it has been idle
    /// for longer than `idleTimeoutSeconds`. Each new callback execution resets
    /// the timer.
    private func scheduleDisposalCheck() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Cancel any existing disposal check
            self.disposalWorkItem?.cancel()

            // Create new disposal work item
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                self.queue.sync {
                    // Check if engine is still idle
                    guard let lastUsed = self.lastUsedTimestamp else {
                        return
                    }

                    let idleTime = Date().timeIntervalSince(lastUsed)
                    if idleTime >= FlutterEngineManager.idleTimeoutSeconds {
                        print("FlutterEngineManager: Auto-disposing after \(Int(idleTime))s idle")
                        self.dispose()
                    }
                }
            }

            self.disposalWorkItem = workItem

            // Schedule disposal check
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + FlutterEngineManager.idleTimeoutSeconds,
                execute: workItem
            )
        }
    }
}

// MARK: - Errors

enum FlutterEngineError: LocalizedError {
    case noCallbackHandle
    case invalidCallbackHandle
    case engineStartFailed
    case dartReadyTimeout
    case engineNotInitialized
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .noCallbackHandle:
            return "No callback handle set. Call setCallbackHandle() during initialization."
        case .invalidCallbackHandle:
            return "Invalid callback handle. Make sure dispatcher is a top-level function."
        case .engineStartFailed:
            return "Failed to start Flutter Engine."
        case .dartReadyTimeout:
            return "Timeout waiting for Dart ready signal."
        case .engineNotInitialized:
            return "Engine not initialized."
        case .timeout:
            return "Callback execution timeout."
        case .unknown:
            return "Unknown error."
        }
    }
}
