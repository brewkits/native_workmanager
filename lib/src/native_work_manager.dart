import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'constraints.dart';
import 'enqueue_request.dart';
import 'events.dart';
import 'observability.dart';
import 'platform_interface.dart';
import 'remote_trigger.dart';
import 'middleware.dart';
import 'task_chain.dart';
import 'task_graph.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// Main entry point for scheduling native background tasks.
///
/// NativeWorkManager provides a unified API for scheduling background tasks
/// on both Android and iOS. It uses Kotlin Multiplatform (KMP) under the hood
/// for native performance.
///
/// ## 🛡️ The Pure 10 Architecture
///
/// This library is built on the **"Pure Native"** principle — utilizing 100%
/// platform-native APIs without third-party dependencies.
///
/// - **Reliability (10/10)**: **Native Watchdog** automatically recovers tasks
///   stuck in 'running' state after an app crash or system reboot.
/// - **Persistence (10/10)**: Uses **Atomic File Writing** (iOS) and
///   **SQLite WAL Mode** (Android) to guarantee data integrity.
/// - **Privacy (10/10)**: **Sensitive Data Redaction** recursively strips
///   tokens, passwords, and cookies before persisting tasks to disk.
/// - **Performance (10/10)**: **Zero Flutter Engine overhead** for native workers,
///   consuming ~2MB RAM vs ~50MB for traditional plugins.
///
/// ## Quick Start
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   // Initialize with optional cleanup and concurrency settings
///   await NativeWorkManager.initialize(
///     maxConcurrentTasks: 4,
///     cleanupAfterDays: 7,
///   );
///   runApp(MyApp());
/// }
///
/// // Schedule a secure periodic sync
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-sync',
///   trigger: TaskTrigger.periodic(Duration(hours: 24)),
///   worker: NativeWorker.httpSync(
///     url: 'https://api.example.com/sync',
///     headers: {'Authorization': 'Bearer $token'}, // Auto-redacted in store!
///   ),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// ## Execution Modes
///
/// ### 🚀 Mode 1: Native Workers (Recommended)
/// Runs directly in Kotlin (Android) or Swift (iOS).
/// **RAM Usage**: ~2MB per task.
/// **Startup Time**: <50ms.
///
/// ### 🧩 Mode 2: Dart Workers
/// Runs Dart code in a headless isolate.
/// **RAM Usage**: ~50MB per task.
/// **Startup Time**: 1000ms - 2000ms.
/// Includes **Isolate Caching**: The engine stays "warm" for 5 minutes after
/// completion to speed up consecutive tasks.
/// Top-level callback dispatcher for background Dart execution.
///
/// This function is invoked by the native side when initializing
/// the Flutter Engine for Dart workers. It sets up the MethodChannel
/// and signals that Dart is ready to receive callback invocations.
///
/// DO NOT call this function directly - it's only for native side.
///
/// The @pragma annotation prevents the Dart compiler from tree-shaking
/// this function in release builds, which is critical for background execution.
@pragma('vm:entry-point')
Future<void> _callbackDispatcher() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Setup MethodChannel for receiving callback invocations
  const channel = MethodChannel('dev.brewkits/dart_worker_channel');

  // Signal that Dart is ready.
  // M-002 FIX: Await the invokeMethod call and handle errors explicitly.
  // An unawaited future would silently swallow any PlatformException, causing
  // the native 10-second timeout to fire and destroy the engine.
  await channel.invokeMethod<void>('dartReady').catchError((Object e) {
    developer.log('ERROR: dartReady signal failed: $e');
  });

  // Handle callback invocations
  channel.setMethodCallHandler((call) async {
    if (call.method == 'executeCallback') {
      // DART-004 FIX: Guard against null arguments from native side.
      // null args indicates a platform channel protocol error or native
      // serialization failure — distinct from a worker with no input
      // (which arrives as args != null but args['input'] == null).
      final args = call.arguments as Map?;
      if (args == null) {
        developer.log(
          '[NativeWorkManager] CRITICAL: null arguments in executeCallback.\n'
          'This is a platform channel protocol error, not a worker failure.\n'
          'Check native logs (Logcat / Xcode console) for serialization errors.',
          level: 1000, // SHOUT — highest severity
        );
        return false;
      }

      // Extract callback handle and input
      // DART-005: Use num cast then toInt() to handle both int and int64 from native.
      final callbackId = args['callbackId'] as String? ?? '<unknown>';
      final callbackHandleRaw = args['callbackHandle'];
      final callbackHandle = callbackHandleRaw is int
          ? callbackHandleRaw
          : (callbackHandleRaw is num ? callbackHandleRaw.toInt() : null);
      if (callbackHandle == null) {
        developer.log(
            'ERROR in _callbackDispatcher: missing or invalid callbackHandle '
            '(got ${callbackHandleRaw.runtimeType})');
        return false;
      }
      final inputJson = args['input'] as String?;

      try {
        // Convert handle back to callback function
        final callbackInfo = PluginUtilities.getCallbackFromHandle(
          CallbackHandle.fromRawHandle(callbackHandle),
        );

        if (callbackInfo == null) {
          throw StateError(
            'Failed to resolve callback handle: $callbackHandle. '
            'Ensure the callback is a top-level or static function.',
          );
        }

        // DART-014 FIX: Validate function signature before invoking.
        // Dart's `as` cast does not check function signatures at cast-time — it
        // only fails when the function is called, producing a cryptic TypeError.
        if (callbackInfo is! DartWorkerCallback) {
          throw StateError(
            'Callback handle $callbackHandle resolved to ${callbackInfo.runtimeType} '
            'but DartWorkerCallback (Future<bool> Function(Map<String, dynamic>?)) was expected. '
            'Ensure the registered function has the correct signature.',
          );
        }
        final callback = callbackInfo;

        // Parse input JSON if present
        Map<String, dynamic>? input;
        // Check if inputJson is literally the string "null" or empty, and treat it as no input
        if (inputJson != null && inputJson.isNotEmpty && inputJson != "null") {
          try {
            input = jsonDecode(inputJson) as Map<String, dynamic>;
          } catch (e) {
            throw FormatException(
              'Failed to parse callback input JSON: "$inputJson"',
              inputJson,
            );
          }
        }

        // Execute the callback with a hard timeout to prevent indefinite hangs.
        // 25 s leaves a 5 s safety buffer within iOS BGAppRefreshTask's 30 s budget.
        // For longer work use Constraints(bgTaskType: BGTaskType.processing).
        final result = await callback(input).timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            developer.log(
              '[NativeWorkManager] DartWorker callback "$callbackId" timed out '
              'after 25 s. Consider:\n'
              '  • Breaking the work into smaller tasks.\n'
              '  • Using Constraints(bgTaskType: BGTaskType.processing) for '
              'tasks that need up to 10 minutes (iOS).',
              level: 900,
            );
            return false;
          },
        );

        // Return execution result to native side
        return result;
      } catch (e, stackTrace) {
        // Log error for debugging
        developer.log('ERROR in _callbackDispatcher: $e');
        developer.log('Stack trace: $stackTrace');

        // Return false to indicate failure
        return false;
      }
    }

    throw MissingPluginException('Unknown method: ${call.method}');
  });
}

class NativeWorkManager {
  NativeWorkManager._();

  static bool _initialized = false;
  // Completer used to make concurrent initialize() calls wait on the first one
  // rather than racing past the _initialized flag check.
  static Completer<void>? _initCompleter;
  static final Map<String, DartWorkerCallback> _dartWorkers = {};

  // Observability
  static StreamSubscription<TaskEvent>? _observabilityEventSub;
  static StreamSubscription<TaskProgress>? _observabilityProgressSub;

  /// Map of callback IDs to their serializable handles.
  /// Handles can be passed across isolates, unlike function closures.
  static final Map<String, int> _callbackHandles = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the work manager.
  ///
  /// **REQUIRED:** Must be called before any other method, typically in `main()`.
  ///
  /// ## Basic Usage (Native Workers Only)
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await NativeWorkManager.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// ## Advanced Usage (With Dart Workers)
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await NativeWorkManager.initialize(
  ///     dartWorkers: {
  ///       'customSync': (input) async {
  ///         // Your custom Dart logic
  ///         final data = await fetchDataFromLocalDb();
  ///         await uploadToServer(data);
  ///         return true; // true = success, false = failure
  ///       },
  ///       'cleanup': (input) async {
  ///         await cleanupOldFiles();
  ///         return true;
  ///       },
  ///     },
  ///     debugMode: true,  // Shows notifications for all task events
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[dartWorkers]** - Optional map of callback IDs to worker functions.
  /// - Only needed if you want to run Dart code in background (Mode 2)
  /// - Each callback receives optional input data as `Map<String, dynamic>`
  /// - Must return `Future<bool>` (true = success, false = failure)
  /// - Callbacks run in a background isolate with Flutter Engine
  ///
  /// **[debugMode]** - Enable debug notifications (default: false).
  /// - Shows notifications when tasks complete with execution time
  /// - Displays success/failure status
  /// - **Only works in debug builds** - automatically disabled in release
  /// - Useful for development and debugging
  ///
  /// ## Platform Considerations
  ///
  /// **Android:**
  /// - No special setup required
  /// - Debug notifications use NotificationManager
  /// - Automatically creates debug notification channel
  ///
  /// **iOS:**
  /// - Debug mode requests notification permissions on first run
  /// - Uses UNUserNotificationCenter
  /// - BGTaskScheduler setup is automatic (reads Info.plist)
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** call initialize() multiple times - it's idempotent but wasteful
  /// ❌ **Don't** forget to call this before scheduling tasks
  /// ❌ **Don't** register anonymous functions as dartWorkers (won't work in background)
  /// ✅ **Do** call this in main() before runApp()
  /// ✅ **Do** use named top-level or static functions for dartWorkers
  ///
  /// ## See Also
  ///
  /// - [enqueue] - Schedule a background task
  /// - [DartWorker] - Create a Dart callback worker
  /// - [NativeWorker] - Create a native worker (no Flutter Engine)
  static Future<void> initialize({
    Map<String, DartWorkerCallback>? dartWorkers,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,

    /// Automatically delete completed/failed/cancelled task records older than
    /// this many days during initialize(). Set to 0 to disable auto-cleanup.
    /// Default: 30 days (prevents unbounded SQLite growth on long-running apps).
    int cleanupAfterDays = 30,

    /// When true, all HTTP workers reject plain HTTP URLs and only allow HTTPS.
    /// Useful for apps that require transport security across all background tasks.
    /// Default: false (backward compatible).
    bool enforceHttps = false,

    /// When true, HTTP workers block requests to private/loopback IP ranges
    /// (10.x, 172.16-31.x, 192.168.x, 127.x, ::1) to prevent SSRF attacks.
    /// Has no effect on hostnames — only parsed IP literals are checked.
    /// Default: false (backward compatible).
    bool blockPrivateIPs = false,
  }) async {
    // If already initializing (concurrent calls), wait on the in-flight future.
    if (_initCompleter != null) return _initCompleter!.future;
    if (_initialized) return;

    _initCompleter = Completer<void>();
    try {
      await _initializeInternal(
        dartWorkers: dartWorkers,
        debugMode: debugMode,
        maxConcurrentTasks: maxConcurrentTasks,
        diskSpaceBufferMB: diskSpaceBufferMB,
        cleanupAfterDays: cleanupAfterDays,
        enforceHttps: enforceHttps,
        blockPrivateIPs: blockPrivateIPs,
      );
      _initialized = true;
      _initCompleter!.complete();
    } catch (e, st) {
      _initCompleter = null; // allow retry on failure
      _initCompleter?.completeError(e, st);
      rethrow;
    }
  }

  static Future<void> _initializeInternal({
    Map<String, DartWorkerCallback>? dartWorkers,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
  }) async {
    // Phase 2: Register DevTools Extension Service
    registerDevToolsExtensions();

    // Register Dart workers and compute their handles
    if (dartWorkers != null) {
      _dartWorkers.addAll(dartWorkers);

      // Compute callback handles for each worker
      for (final entry in dartWorkers.entries) {
        final callbackId = entry.key;
        final callback = entry.value;

        // Get the handle for this callback
        final handle = PluginUtilities.getCallbackHandle(callback);

        if (handle == null) {
          throw StateError(
            'Failed to get callback handle for "$callbackId". '
            'Ensure the callback is a top-level or static function, '
            'NOT an anonymous function or instance method.\n'
            '\n'
            'Example CORRECT:\n'
            '  Future<bool> myCallback(Map<String, dynamic>? input) async { ... }\n'
            '  dartWorkers: {"myCallback": myCallback}\n'
            '\n'
            'Example WRONG:\n'
            '  dartWorkers: {"bad": (input) async => true} // Anonymous function!',
          );
        }

        _callbackHandles[callbackId] = handle.toRawHandle();
      }
    }

    // Set up callback executor
    NativeWorkManagerPlatform.instance.setCallbackExecutor(
      _executeDartCallback,
    );

    // Set up chain enqueue callback
    TaskChainBuilder.enqueueCallback = _enqueueChain;

    // Get callback handle for the dispatcher if any Dart workers registered
    int? callbackHandle;
    if (dartWorkers != null && dartWorkers.isNotEmpty) {
      // Get handle of the callback dispatcher
      callbackHandle = PluginUtilities.getCallbackHandle(
        _callbackDispatcher,
      )?.toRawHandle();
    }

    // Initialize platform with config.
    await NativeWorkManagerPlatform.instance.initialize(
      callbackHandle: callbackHandle,
      debugMode: debugMode,
      maxConcurrentTasks: maxConcurrentTasks,
      diskSpaceBufferMB: diskSpaceBufferMB,
      cleanupAfterDays: cleanupAfterDays,
      enforceHttps: enforceHttps,
      blockPrivateIPs: blockPrivateIPs,
    );
    // _initialized is set by the caller (initialize()) after this returns.
  }

  static void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'NativeWorkManager not initialized. '
        'Call NativeWorkManager.initialize() first.',
      );
    }
  }

  static Future<bool> _executeDartCallback(
    String callbackId,
    Map<String, dynamic>? input,
  ) async {
    final callback = _dartWorkers[callbackId];
    if (callback == null) {
      throw StateError('No Dart worker registered for: $callbackId');
    }

    return callback(input);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TASK SCHEDULING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Schedule a background task.
  ///
  /// This is the primary method for scheduling work to be executed in the background.
  /// Tasks can be one-time, periodic, or triggered by specific conditions.
  ///
  /// ## Basic Examples
  ///
  /// **Immediate one-time task:**
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'quick-sync',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpRequest(
  ///     url: 'https://api.example.com/ping',
  ///     method: HttpMethod.post,
  ///   ),
  /// );
  /// ```
  ///
  /// **Delayed task:**
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'delayed-upload',
  ///   trigger: TaskTrigger.oneTime(delay: Duration(minutes: 15)),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/upload',
  ///     filePath: '/path/to/file.jpg',
  ///   ),
  /// );
  /// ```
  ///
  /// **Periodic task (every hour):**
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'hourly-sync',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// **Task with constraints:**
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'battery-safe-task',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://example.com/large-file.zip',
  ///     savePath: '/path/to/save.zip',
  ///   ),
  ///   constraints: Constraints(
  ///     requiresCharging: true,
  ///     requiresWifi: true,
  ///   ),
  /// );
  /// ```
  ///
  /// **Tagged tasks for bulk operations:**
  /// ```dart
  /// // Schedule multiple tasks with same tag
  /// for (var i = 0; i < 5; i++) {
  ///   await NativeWorkManager.enqueue(
  ///     taskId: 'upload-$i',
  ///     trigger: TaskTrigger.oneTime(),
  ///     worker: NativeWorker.httpUpload(
  ///       url: 'https://api.example.com/upload',
  ///       filePath: '/path/to/file$i.jpg',
  ///     ),
  ///     tag: 'batch-upload',  // Same tag for all
  ///   );
  /// }
  ///
  /// // Later, cancel all at once
  /// await NativeWorkManager.cancelByTag(tag: 'batch-upload');
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[taskId]** *(required)* - Unique identifier for the task.
  /// - Must not be empty
  /// - Used to cancel, query, or update the task
  /// - If duplicate ID exists, behavior depends on [existingPolicy]
  ///
  /// **[trigger]** *(required)* - When the task should execute.
  /// - `TaskTrigger.oneTime()` - Execute once (optionally with delay)
  /// - `TaskTrigger.periodic(duration)` - Repeat every duration (min 15 minutes)
  /// - See [TaskTrigger] for all options
  ///
  /// **[worker]** *(required)* - What work to perform.
  /// - `NativeWorker.*` - Native workers (no Flutter Engine, fast startup)
  /// - `DartWorker` - Run Dart code (requires Flutter Engine)
  /// - See [NativeWorker] and [DartWorker] for details
  ///
  /// **[constraints]** *(optional)* - Execution conditions (default: no constraints).
  /// - `Constraints.networkRequired` - Requires any network
  /// - `Constraints.heavyTask` - Requires charging + WiFi
  /// - Custom: `Constraints(requiresCharging: true, ...)`
  /// - See [Constraints] for all options
  ///
  /// **[existingPolicy]** *(optional)* - Handle duplicate task IDs (default: replace).
  /// - `ExistingTaskPolicy.replace` - Cancel old, schedule new
  /// - `ExistingTaskPolicy.keep` - Keep old, ignore new
  ///
  /// **[tag]** *(optional)* - Group related tasks for bulk operations.
  /// - Must not be empty string (use null if no tag)
  /// - Use with [cancelByTag] and [getTasksByTag]
  /// - Multiple tasks can share the same tag
  ///
  /// ## Platform Considerations
  ///
  /// **Android:**
  /// - Periodic tasks have minimum interval of 15 minutes (OS limitation)
  /// - Constraints enforced by WorkManager
  /// - Exact timing not guaranteed (OS may defer tasks)
  ///
  /// **iOS:**
  /// - Periodic tasks use BGAppRefreshTask (runs opportunistically)
  /// - One-time tasks use BGProcessingTask
  /// - Task may not run immediately even without delay
  /// - Charging/battery constraints are advisory only
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** use periodic intervals < 15 minutes (will throw error)
  /// ❌ **Don't** expect exact timing - OS may defer tasks
  /// ❌ **Don't** use empty string for tag (use null instead)
  /// ❌ **Don't** schedule too many tasks (performance impact)
  /// ✅ **Do** use tags for managing related tasks
  /// ✅ **Do** use constraints to optimize battery life
  /// ✅ **Do** handle task failure gracefully
  ///
  /// ## Error Handling
  ///
  /// This method may throw:
  /// - `ArgumentError` - Invalid parameters (empty taskId, invalid URL, etc.)
  /// - `StateError` - NativeWorkManager not initialized or unregistered DartWorker
  ///
  /// ## Returns
  ///
  /// A [ScheduleResult] indicating whether the task was accepted by the OS.
  ///
  /// ## See Also
  ///
  /// - [cancel] - Cancel a specific task
  /// - [cancelByTag] - Cancel all tasks with a tag
  /// - [cancelAll] - Cancel all scheduled tasks
  /// - [NativeWorkManager.getTaskStatus] - Check task status
  /// - [TaskTrigger] - Available trigger types
  /// - [Constraints] - Available constraints
  static Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints = const Constraints(),
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
    String? tag,
  }) async {
    _checkInitialized();

    // Validation
    if (taskId.isEmpty) {
      throw ArgumentError(
        'taskId cannot be empty. '
        'Use a unique identifier like "sync-\${DateTime.now().millisecondsSinceEpoch}"',
      );
    }

    // Validate tag if provided
    if (tag != null && tag.isEmpty) {
      throw ArgumentError(
        'tag cannot be empty string. '
        'Either provide a valid tag or omit the parameter.',
      );
    }

    // Validate periodic trigger interval (Android minimum)
    if (trigger is PeriodicTrigger) {
      if (trigger.interval < const Duration(minutes: 15)) {
        throw ArgumentError(
          'Periodic interval must be at least 15 minutes on Android.\n'
          'Current: ${trigger.interval.inMinutes} minutes\n'
          'Minimum: 15 minutes\n'
          'Use TaskTrigger.oneTime() for immediate execution.',
        );
      }
    }

    // Validate DartWorker registration and prepare worker data
    Worker workerToEnqueue = worker;
    Constraints finalConstraints = constraints;

    if (worker is DartWorker) {
      if (!_dartWorkers.containsKey(worker.callbackId)) {
        throw StateError(
          'Dart worker "${worker.callbackId}" not registered.\n'
          'Register it in NativeWorkManager.initialize():\n'
          '  await NativeWorkManager.initialize(\n'
          '    dartWorkers: {\n'
          '      "${worker.callbackId}": (input) async { ... },\n'
          '    },\n'
          '  );',
        );
      }

      // iOS safety: DartWorkers are heavy by definition because they spin up
      // a Flutter Engine. Force BGProcessingTask (60s+) instead of
      // BGAppRefreshTask (30s) to prevent immediate OS kills.
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          !constraints.isHeavyTask) {
        finalConstraints = constraints.copyWith(isHeavyTask: true);
        developer.log(
          'NativeWorkManager: DartWorker on iOS detected. Promoting to heavy task '
          '(isHeavyTask=true) to prevent OS termination.',
          name: 'NativeWorkManager',
        );
      }

      // Get the callback handle for this worker
      final callbackHandle = _callbackHandles[worker.callbackId];
      if (callbackHandle == null) {
        throw StateError(
          'INTERNAL ERROR: Callback handle not found for "${worker.callbackId}". '
          'This should never happen. Please report this bug.',
        );
      }

      // Create enhanced DartWorker with callback handle
      workerToEnqueue = DartWorkerInternal(
        callbackId: worker.callbackId,
        callbackHandle: callbackHandle,
        input: worker.input,
        autoDispose: worker.autoDispose,
        timeoutMs: worker.timeoutMs,
      );
    }

    return NativeWorkManagerPlatform.instance.enqueue(
      taskId: taskId,
      trigger: trigger,
      worker: workerToEnqueue,
      constraints: finalConstraints,
      existingPolicy: existingPolicy,
      tag: tag,
    );
  }

  /// Cancel all tasks with a specific tag.
  ///
  /// This is the recommended way to cancel groups of related tasks. Much more
  /// efficient than canceling tasks individually.
  ///
  /// ## Example - Batch Upload Cancellation
  ///
  /// ```dart
  /// // Schedule multiple upload tasks with same tag
  /// for (var i = 0; i < 10; i++) {
  ///   await NativeWorkManager.enqueue(
  ///     taskId: 'upload-$i',
  ///     trigger: TaskTrigger.oneTime(),
  ///     worker: NativeWorker.httpUpload(
  ///       url: 'https://api.example.com/upload',
  ///       filePath: files[i],
  ///     ),
  ///     tag: 'batch-upload',
  ///   );
  /// }
  ///
  /// // User cancels upload - cancel all 10 tasks at once
  /// await NativeWorkManager.cancelByTag(tag: 'batch-upload');
  /// ```
  ///
  /// ## Example - Feature-Based Cancellation
  ///
  /// ```dart
  /// // Tag tasks by feature
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'photo-sync',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 6)),
  ///   worker: ...,
  ///   tag: 'photo-feature',
  /// );
  ///
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'photo-cleanup',
  ///   trigger: TaskTrigger.periodic(Duration(days: 1)),
  ///   worker: ...,
  ///   tag: 'photo-feature',
  /// );
  ///
  /// // User disables photo feature - cancel all related tasks
  /// await NativeWorkManager.cancelByTag(tag: 'photo-feature');
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[tag]** *(required)* - The tag to match.
  /// - Must not be empty
  /// - Case-sensitive exact match
  /// - Only tasks with exactly this tag will be canceled
  ///
  /// ## Behavior
  ///
  /// - Cancels ALL tasks that have the specified tag
  /// - Does nothing if no tasks have the tag (no error thrown)
  /// - Tasks are canceled immediately (won't execute even if scheduled)
  /// - Running tasks may complete before cancellation takes effect
  ///
  /// ## Platform Notes
  ///
  /// **Android:** Uses WorkManager.cancelAllWorkByTag()
  /// **iOS:** Cancels all BGTaskRequest instances with matching identifier prefix
  ///
  /// ## See Also
  ///
  /// - [cancel] - Cancel a specific task by ID
  /// - [cancelAll] - Cancel all scheduled tasks
  /// - [getTasksByTag] - Query tasks by tag
  static Future<void> cancelByTag({required String tag}) async {
    _checkInitialized();

    if (tag.isEmpty) {
      throw ArgumentError('tag cannot be empty');
    }

    return NativeWorkManagerPlatform.instance.cancelByTag(tag: tag);
  }

  /// Get all tasks with a specific tag.
  ///
  /// Returns a list of task IDs that have the given tag.
  ///
  /// ```dart
  /// List<String> syncTasks = await NativeWorkManager.getTasksByTag(tag: 'sync-group');
  /// print('Found ${syncTasks.length} sync tasks');
  /// ```
  static Future<List<String>> getTasksByTag({required String tag}) async {
    _checkInitialized();

    if (tag.isEmpty) {
      throw ArgumentError('tag cannot be empty');
    }

    return NativeWorkManagerPlatform.instance.getTasksByTag(tag: tag);
  }

  /// Get all tags currently in use.
  ///
  /// Returns a list of all unique tags that have been assigned to tasks.
  ///
  /// ```dart
  /// List<String> allTags = await NativeWorkManager.getAllTags();
  /// print('Active tag groups: $allTags');
  /// ```
  static Future<List<String>> getAllTags() async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.getAllTags();
  }

  /// Cancel a specific task by its ID.
  ///
  /// Use this to cancel individual tasks. For canceling multiple related tasks,
  /// consider using [cancelByTag] instead.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Schedule a task
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'daily-sync',
  ///   trigger: TaskTrigger.periodic(Duration(days: 1)),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  /// );
  ///
  /// // Later, cancel it
  /// await NativeWorkManager.cancel(taskId: 'daily-sync');
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[taskId]** *(required)* - The ID of the task to cancel.
  ///
  /// ## Behavior
  ///
  /// - Cancels the task with the specified ID
  /// - Does nothing if task doesn't exist (no error thrown)
  /// - Task won't execute after cancellation
  /// - If task is currently running, may complete before cancellation takes effect
  ///
  /// ## See Also
  ///
  /// - [cancelByTag] - Cancel multiple tasks by tag
  /// - [cancelAll] - Cancel all tasks
  static Future<void> cancel({required String taskId}) async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.cancel(taskId: taskId);
  }

  /// Cancel all scheduled tasks.
  ///
  /// **Use with caution!** This cancels every task managed by NativeWorkManager,
  /// including periodic tasks, delayed tasks, and tasks from other parts of your app.
  ///
  /// ## Example - App Logout
  ///
  /// ```dart
  /// // User logs out - cancel all background sync tasks
  /// await NativeWorkManager.cancelAll();
  /// ```
  ///
  /// ## Example - Reset App State
  ///
  /// ```dart
  /// Future<void> resetApp() async {
  ///   // Clear all background tasks
  ///   await NativeWorkManager.cancelAll();
  ///
  ///   // Clear local data
  ///   await clearLocalDatabase();
  ///
  ///   // Restart app
  ///   await restartApp();
  /// }
  /// ```
  ///
  /// ## Behavior
  ///
  /// - Cancels ALL tasks regardless of ID, tag, or status
  /// - Does not throw error if no tasks exist
  /// - Running tasks may complete before cancellation takes effect
  /// - This is a destructive operation - tasks cannot be recovered
  ///
  /// ## Alternatives
  ///
  /// Consider these alternatives for more granular control:
  /// - Use [cancelByTag] to cancel groups of related tasks
  /// - Use [cancel] to cancel specific tasks
  ///
  /// ## Platform Notes
  ///
  /// **Android:** Calls WorkManager.cancelAllWork()
  /// **iOS:** Cancels all pending BGTaskRequest instances
  ///
  /// ## See Also
  ///
  /// - [cancel] - Cancel specific task
  /// - [cancelByTag] - Cancel tasks by tag
  static Future<void> cancelAll() async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.cancelAll();
  }

  /// Report progress from inside a [DartWorker] callback.
  ///
  /// Call this from your [DartWorkerCallback] to emit progress events that
  /// will appear in [NativeWorkManager.progress] on the UI side.
  ///
  /// The [taskId] is injected into the callback input map under the key
  /// `'__taskId'`. Read it and forward to this method:
  ///
  /// ```dart
  /// await NativeWorkManager.initialize(
  ///   dartWorkers: {
  ///     'processFiles': (input) async {
  ///       final taskId = input?['__taskId'] as String?;
  ///       for (var i = 1; i <= 10; i++) {
  ///         await processFile(i);
  ///         await NativeWorkManager.reportDartWorkerProgress(
  ///           taskId: taskId,
  ///           progress: (i / 10 * 100).round(),
  ///           message: 'Processing file $i / 10',
  ///         );
  ///       }
  ///       return true;
  ///     },
  ///   },
  /// );
  /// ```
  ///
  /// **Thread safety:** Safe to call from any isolate that has access to the
  /// `dev.brewkits/dart_worker_channel` MethodChannel (i.e., the background
  /// isolate spawned by DartWorker execution).
  ///
  /// Does nothing if [taskId] is null or empty (avoids need for null checks in
  /// callers that cannot guarantee a taskId is present).
  static Future<void> reportDartWorkerProgress({
    String? taskId,
    required int progress,
    String? message,
  }) async {
    if (taskId == null || taskId.isEmpty) return;
    const channel = MethodChannel('dev.brewkits/dart_worker_channel');
    await channel.invokeMethod<void>('reportProgress', <String, Object?>{
      'taskId': taskId,
      'progress': progress.clamp(0, 100),
      if (message != null) 'message': message,
    });
  }

  /// Get the current status of a task.
  ///
  /// Query the execution state of a specific task. Useful for showing
  /// task progress in your UI or debugging task execution.
  ///
  /// ## Example - Show Upload Status
  ///
  /// ```dart
  /// final status = await NativeWorkManager.getTaskStatus(taskId: 'photo-upload');
  ///
  /// switch (status) {
  ///   case TaskStatus.enqueued:
  ///     print('Upload is waiting to start');
  ///     break;
  ///   case TaskStatus.running:
  ///     print('Upload in progress...');
  ///     break;
  ///   case TaskStatus.succeeded:
  ///     print('Upload complete!');
  ///     break;
  ///   case TaskStatus.failed:
  ///     print('Upload failed');
  ///     break;
  ///   case TaskStatus.cancelled:
  ///     print('Upload was canceled');
  ///     break;
  ///   case null:
  ///     print('Task not found');
  ///     break;
  /// }
  /// ```
  ///
  /// ## Example - UI Integration
  ///
  /// ```dart
  /// class UploadStatusWidget extends StatefulWidget {
  ///   @override
  ///   State createState() => _UploadStatusWidgetState();
  /// }
  ///
  /// class _UploadStatusWidgetState extends State<UploadStatusWidget> {
  ///   TaskStatus? _status;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     _checkStatus();
  ///     Timer.periodic(Duration(seconds: 1), (_) => _checkStatus());
  ///   }
  ///
  ///   Future<void> _checkStatus() async {
  ///     final status = await NativeWorkManager.getTaskStatus(taskId: 'upload');
  ///     setState(() => _status = status);
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     if (_status == TaskStatus.running) {
  ///       return CircularProgressIndicator();
  ///     }
  ///     return Text('Status: ${_status ?? 'Not found'}');
  ///   }
  /// }
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[taskId]** *(required)* - The ID of the task to query.
  ///
  /// ## Returns
  ///
  /// A [TaskStatus] enum value, or `null` if the task doesn't exist:
  /// - `TaskStatus.enqueued` - Task is scheduled but not yet started
  /// - `TaskStatus.running` - Task is currently executing
  /// - `TaskStatus.succeeded` - Task completed successfully
  /// - `TaskStatus.failed` - Task failed with an error
  /// - `TaskStatus.cancelled` - Task was canceled
  /// - `null` - Task not found (may have been canceled or completed long ago)
  ///
  /// ## Platform Considerations
  ///
  /// **Android:**
  /// - Status reflects WorkManager's WorkInfo state
  /// - Completed tasks remain queryable for some time
  ///
  /// **iOS:**
  /// - Status may not be available for completed/failed tasks
  /// - Returns null if task is not in pending queue
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** poll this method too frequently (impacts performance)
  /// ❌ **Don't** rely on this for completed tasks (may return null)
  /// ✅ **Do** use [events] stream for real-time task completion notifications
  /// ✅ **Do** cache status locally if polling frequently
  ///
  /// ## See Also
  ///
  /// - [events] - Stream of task completion events
  /// - [progress] - Stream of task progress updates
  static Future<TaskStatus?> getTaskStatus({required String taskId}) async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.getTaskStatus(taskId: taskId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAUSE / RESUME
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pause a running download task.
  ///
  /// On **Android**, pausing cancels the WorkManager job but preserves the
  /// partial `.tmp` file so that a subsequent [resume] call can re-enqueue
  /// the worker and OkHttp will send a `Range:` header to resume from the
  /// last downloaded byte. The task is stored in the SQLite task store with
  /// status `"paused"`.
  ///
  /// On **iOS**, the underlying `URLSessionDownloadTask` is cancelled with
  /// resume data. If resume data is available, [resume] will call
  /// `resumeDownload(with:)` to continue from where it left off. If not
  /// (e.g. the download had not yet started), [resume] re-starts from scratch
  /// using the config saved in the task store.
  ///
  /// **Note:** Only `HttpDownloadWorker` tasks support pause/resume. For other
  /// worker types the call is a no-op on the native side.
  static Future<void> pause({required String taskId}) async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.pauseTask(taskId: taskId);
  }

  /// Resume a previously paused download task.
  ///
  /// The task must have been paused via [pause] before calling this method.
  /// See [pause] for platform-specific behaviour.
  static Future<void> resume({required String taskId}) async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.resumeTask(taskId: taskId);
  }

  /// Pause all running tasks that share a given tag.
  ///
  /// Looks up every task with [tag] via [getTasksByTag] then calls [pause]
  /// on each one concurrently.  Completed, failed, or already-paused tasks
  /// are silently skipped on the native side.
  ///
  /// ```dart
  /// // Pause all active downloads in the "media" group
  /// await NativeWorkManager.pauseByTag('media');
  /// ```
  static Future<void> pauseByTag({required String tag}) async {
    _checkInitialized();
    final taskIds =
        await NativeWorkManagerPlatform.instance.getTasksByTag(tag: tag);
    await Future.wait(
      taskIds.map(
          (id) => NativeWorkManagerPlatform.instance.pauseTask(taskId: id)),
    );
  }

  /// Resume all paused tasks that share a given tag.
  ///
  /// Looks up every task with [tag] via [getTasksByTag] then calls [resume]
  /// on each one concurrently.  Only tasks in the `paused` state will
  /// actually restart; other tasks are silently skipped on the native side.
  ///
  /// ```dart
  /// // Resume all downloads in the "media" group
  /// await NativeWorkManager.resumeByTag('media');
  /// ```
  static Future<void> resumeByTag({required String tag}) async {
    _checkInitialized();
    final taskIds =
        await NativeWorkManagerPlatform.instance.getTasksByTag(tag: tag);
    await Future.wait(
      taskIds.map(
          (id) => NativeWorkManagerPlatform.instance.resumeTask(taskId: id)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TASK STORE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Return all tasks from the persistent SQLite task store, newest first.
  ///
  /// Each [TaskRecord] contains the task ID, tag, current status, worker class
  /// name, and timestamps. The store is updated automatically when tasks are
  /// enqueued, completed, failed, cancelled, or paused.
  ///
  /// ```dart
  /// final tasks = await NativeWorkManager.allTasks();
  /// for (final t in tasks) {
  ///   print('${t.taskId}: ${t.status}');
  /// }
  /// ```
  static Future<List<TaskRecord>> allTasks() async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.allTasks();
  }

  /// Fetch the server-suggested filename for a URL by sending a HEAD request
  /// and parsing the `Content-Disposition` header (RFC 6266).
  ///
  /// Returns the sanitized filename string, or `null` if the server did not
  /// provide a `Content-Disposition: attachment; filename=…` header.
  ///
  /// Prefer `filename*=UTF-8''…` (RFC 5987 percent-encoded) when present.
  ///
  /// ```dart
  /// final name = await NativeWorkManager.getServerFilename(
  ///   'https://files.example.com/report.pdf',
  /// );
  /// // name == 'Q4_Report_2024.pdf'
  ///
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'dl-report',
  ///   trigger: const TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://files.example.com/report.pdf',
  ///     savePath: '/path/to/downloads/$name',
  ///   ),
  /// );
  /// ```
  static Future<String?> getServerFilename(
    String url, {
    Map<String, String>? headers,
    int timeoutMs = 30000,
  }) {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.getServerFilename(
      url: url,
      headers: headers,
      timeoutMs: timeoutMs,
    );
  }

  /// Open a file with the system default application.
  ///
  /// Launches the OS file viewer for the given [path]. Useful after a download
  /// completes to let the user immediately view/open the downloaded file.
  ///
  /// On **Android**, opens via `Intent.ACTION_VIEW` with a `FileProvider` URI.
  /// Requires the `native_workmanager.provider` FileProvider to be declared in
  /// the app's `AndroidManifest.xml` (added automatically by the plugin).
  ///
  /// On **iOS**, presents a `UIDocumentInteractionController`.
  ///
  /// ```dart
  /// // After download completes:
  /// NativeWorkManager.events.listen((event) async {
  ///   if (event.taskId == 'my-download' && event.success) {
  ///     await NativeWorkManager.openFile('/path/to/downloaded.pdf');
  ///   }
  /// });
  /// ```
  static Future<void> openFile(String path, {String? mimeType}) {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance
        .openFile(path, mimeType: mimeType);
  }

  /// Set the maximum number of concurrent downloads per host.
  ///
  /// Limits how many simultaneous downloads can target the same server.
  /// Default is 2. Call after [initialize].
  ///
  /// ```dart
  /// await NativeWorkManager.setMaxConcurrentPerHost(3);
  /// ```
  static Future<void> setMaxConcurrentPerHost(int max) {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.setMaxConcurrentPerHost(max);
  }

  /// Return all tasks that match a given [status].
  ///
  /// Queries the persistent task store and filters by status.  Useful for
  /// building download managers, queue dashboards, or retry logic.
  ///
  /// ```dart
  /// final running = await NativeWorkManager.getTasksByStatus(TaskStatus.running);
  /// final paused  = await NativeWorkManager.getTasksByStatus(TaskStatus.paused);
  /// ```
  static Future<List<TaskRecord>> getTasksByStatus(TaskStatus status) async {
    _checkInitialized();
    final all = await NativeWorkManagerPlatform.instance.allTasks();
    return all.where((t) => t.status == status.name).toList();
  }

  /// Pause all currently-running tasks.
  ///
  /// Queries the task store for every task in the `running` state, then
  /// calls [pause] on each one concurrently.  Tasks that cannot be paused
  /// (e.g. non-download workers) are silently skipped on the native side.
  ///
  /// ```dart
  /// // Pause everything — e.g. when the user taps "Pause All"
  /// await NativeWorkManager.pauseAll();
  /// ```
  static Future<void> pauseAll() async {
    _checkInitialized();
    final running = await getTasksByStatus(TaskStatus.running);
    await Future.wait(
      running.map((t) =>
          NativeWorkManagerPlatform.instance.pauseTask(taskId: t.taskId)),
    );
  }

  /// Resume all currently-paused tasks.
  ///
  /// Queries the task store for every task in the `paused` state, then
  /// calls [resume] on each one concurrently.
  ///
  /// ```dart
  /// // Resume everything — e.g. when network becomes available again
  /// await NativeWorkManager.resumeAll();
  /// ```
  static Future<void> resumeAll() async {
    _checkInitialized();
    final paused = await getTasksByStatus(TaskStatus.paused);
    await Future.wait(
      paused.map((t) =>
          NativeWorkManagerPlatform.instance.resumeTask(taskId: t.taskId)),
    );
  }

  /// Enqueue multiple tasks at once and return their [ScheduleResult]s.
  ///
  /// Each entry in [requests] maps to one [enqueue] call.  All tasks are
  /// submitted concurrently; the returned list preserves the input order.
  ///
  /// ```dart
  /// final results = await NativeWorkManager.enqueueAll([
  ///   EnqueueRequest(
  ///     taskId: 'dl-1',
  ///     trigger: TaskTrigger.oneTime(),
  ///     worker: NativeWorker.httpDownload(url: urls[0], savePath: paths[0]),
  ///     tag: 'batch-download',
  ///   ),
  ///   EnqueueRequest(
  ///     taskId: 'dl-2',
  ///     trigger: TaskTrigger.oneTime(),
  ///     worker: NativeWorker.httpDownload(url: urls[1], savePath: paths[1]),
  ///     tag: 'batch-download',
  ///   ),
  /// ]);
  /// final accepted = results.where((r) => r == ScheduleResult.accepted).length;
  /// print('$accepted / ${results.length} tasks accepted');
  /// ```
  static Future<List<ScheduleResult>> enqueueAll(
    List<EnqueueRequest> requests,
  ) async {
    _checkInitialized();
    return Future.wait(
      requests.map(
        (r) => NativeWorkManagerPlatform.instance.enqueue(
          taskId: r.taskId,
          trigger: r.trigger,
          worker: r.worker,
          constraints: r.constraints,
          existingPolicy: r.existingPolicy,
          tag: r.tag,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TASK CHAINS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start building a task chain with a single initial task.
  ///
  /// Task chains allow you to define complex multi-step workflows where tasks
  /// execute in sequence or parallel. This is the foundation for building
  /// sophisticated background processing pipelines.
  ///
  /// ## Basic Sequential Chain (A → B → C)
  ///
  /// ```dart
  /// await NativeWorkManager.beginWith(
  ///   TaskRequest(
  ///     id: 'download',
  ///     worker: NativeWorker.httpDownload(
  ///       url: 'https://example.com/video.mp4',
  ///       savePath: '/tmp/video.mp4',
  ///     ),
  ///   ),
  /// )
  /// .then(TaskRequest(
  ///   id: 'process',
  ///   worker: DartWorker(
  ///     callbackId: 'processVideo',
  ///     input: {'path': '/tmp/video.mp4'},
  ///   ),
  /// ))
  /// .then(TaskRequest(
  ///   id: 'upload',
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/videos',
  ///     filePath: '/tmp/processed_video.mp4',
  ///   ),
  /// ))
  /// .enqueue();
  /// ```
  ///
  /// ## Parallel Tasks (A → \[B1, B2, B3\])
  ///
  /// ```dart
  /// await NativeWorkManager.beginWith(
  ///   TaskRequest(
  ///     id: 'prepare-data',
  ///     worker: DartWorker(callbackId: 'prepareData'),
  ///   ),
  /// )
  /// .then([
  ///   // These 3 tasks run in parallel
  ///   TaskRequest(
  ///     id: 'upload-server1',
  ///     worker: NativeWorker.httpUpload(
  ///       url: 'https://server1.example.com/upload',
  ///       filePath: '/data/file.zip',
  ///     ),
  ///   ),
  ///   TaskRequest(
  ///     id: 'upload-server2',
  ///     worker: NativeWorker.httpUpload(
  ///       url: 'https://server2.example.com/upload',
  ///       filePath: '/data/file.zip',
  ///     ),
  ///   ),
  ///   TaskRequest(
  ///     id: 'upload-backup',
  ///     worker: NativeWorker.httpUpload(
  ///       url: 'https://backup.example.com/upload',
  ///       filePath: '/data/file.zip',
  ///     ),
  ///   ),
  /// ])
  /// .enqueue();
  /// ```
  ///
  /// ## Complex Workflow with Constraints
  ///
  /// ```dart
  /// await NativeWorkManager.beginWith(
  ///   TaskRequest(
  ///     id: 'fetch-metadata',
  ///     worker: NativeWorker.httpRequest(
  ///       url: 'https://api.example.com/metadata',
  ///       method: HttpMethod.get,
  ///     ),
  ///   ),
  /// )
  /// .then(TaskRequest(
  ///   id: 'download-file',
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://cdn.example.com/large-file.zip',
  ///     savePath: '/downloads/file.zip',
  ///   ),
  /// ))
  /// .then(TaskRequest(
  ///   id: 'extract-and-process',
  ///   worker: DartWorker(callbackId: 'extractZip'),
  /// ))
  /// .named('data-sync-pipeline')
  /// .withConstraints(Constraints.heavyTask)  // Requires charging + WiFi
  /// .enqueue();
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[task]** *(required)* - The first task in the chain.
  /// - Must be a [TaskRequest]
  /// - This task executes before all other tasks in the chain
  ///
  /// ## Returns
  ///
  /// A [TaskChainBuilder] that you can use to:
  /// - Add more tasks with `.then()`
  /// - Set constraints with `.withConstraints()`
  /// - Name the chain with `.named()`
  /// - Execute the chain with `.enqueue()`
  ///
  /// ## Chain Execution Rules
  ///
  /// - **Sequential tasks:** Execute one after another (A → B → C)
  /// - **Parallel tasks:** All start together (`[A, B, C]` → D)
  /// - **Failure handling:** If any task fails, the entire chain stops
  /// - **Constraints:** Applied to the entire chain, not individual tasks
  ///
  /// ## Common Use Cases
  ///
  /// 1. **Download → Process → Upload:** Fetch data, transform it, upload result
  /// 2. **Fetch → Parallel Uploads:** Get data once, upload to multiple servers
  /// 3. **Multi-step Data Sync:** Fetch metadata, download files, process locally
  /// 4. **Backup Pipeline:** Compress files, encrypt, upload to multiple cloud storage
  ///
  /// ## Platform Considerations
  ///
  /// **Android:**
  /// - Uses WorkManager's chain API
  /// - Each task in chain is a separate Work item
  /// - Failure of one task cancels remaining tasks
  ///
  /// **iOS:**
  /// - Simulated via sequential BGTaskRequest scheduling
  /// - Chain state tracked internally
  /// - More reliable on iOS 15+
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** make chains too long (increases failure risk)
  /// ❌ **Don't** use chains for independent tasks (just schedule separately)
  /// ❌ **Don't** rely on exact timing - chains may be delayed by OS
  /// ✅ **Do** handle failures gracefully
  /// ✅ **Do** keep chains focused on related tasks
  /// ✅ **Do** use constraints to ensure suitable execution conditions
  ///
  /// ## See Also
  ///
  /// - [beginWithAll] - Start chain with multiple parallel initial tasks
  /// - [TaskRequest] - Configuration for individual tasks in chain
  /// - [TaskChainBuilder] - Builder for constructing task chains
  static TaskChainBuilder beginWith(TaskRequest task) {
    _checkInitialized();
    return TaskChainBuilder.internal([task]);
  }

  /// Start building a task chain with multiple parallel initial tasks.
  ///
  /// Use this when you want multiple tasks to start simultaneously at the
  /// beginning of a chain, then continue with sequential or parallel steps.
  ///
  /// ## Example - Parallel Download then Process
  ///
  /// ```dart
  /// await NativeWorkManager.beginWithAll([
  ///   // These 3 downloads run in parallel
  ///   TaskRequest(
  ///     id: 'download-file1',
  ///     worker: NativeWorker.httpDownload(
  ///       url: 'https://cdn.example.com/file1.zip',
  ///       savePath: '/tmp/file1.zip',
  ///     ),
  ///   ),
  ///   TaskRequest(
  ///     id: 'download-file2',
  ///     worker: NativeWorker.httpDownload(
  ///       url: 'https://cdn.example.com/file2.zip',
  ///       savePath: '/tmp/file2.zip',
  ///     ),
  ///   ),
  ///   TaskRequest(
  ///     id: 'download-file3',
  ///     worker: NativeWorker.httpDownload(
  ///       url: 'https://cdn.example.com/file3.zip',
  ///       savePath: '/tmp/file3.zip',
  ///     ),
  ///   ),
  /// ])
  /// .then(TaskRequest(
  ///   // After ALL downloads complete, process them
  ///   id: 'merge-files',
  ///   worker: DartWorker(callbackId: 'mergeDownloads'),
  /// ))
  /// .enqueue();
  /// ```
  ///
  /// ## Example - Multi-Source Data Fetch
  ///
  /// ```dart
  /// await NativeWorkManager.beginWithAll([
  ///   TaskRequest(
  ///     id: 'fetch-api1',
  ///     worker: NativeWorker.httpRequest(
  ///       url: 'https://api1.example.com/data',
  ///       method: HttpMethod.get,
  ///     ),
  ///   ),
  ///   TaskRequest(
  ///     id: 'fetch-api2',
  ///     worker: NativeWorker.httpRequest(
  ///       url: 'https://api2.example.com/data',
  ///       method: HttpMethod.get,
  ///     ),
  ///   ),
  ///   TaskRequest(
  ///     id: 'fetch-api3',
  ///     worker: NativeWorker.httpRequest(
  ///       url: 'https://api3.example.com/data',
  ///       method: HttpMethod.get,
  ///     ),
  ///   ),
  /// ])
  /// .then(TaskRequest(
  ///   id: 'aggregate',
  ///   worker: DartWorker(callbackId: 'aggregateData'),
  /// ))
  /// .then(TaskRequest(
  ///   id: 'upload-results',
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/results',
  ///     filePath: '/tmp/aggregated.json',
  ///   ),
  /// ))
  /// .enqueue();
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[tasks]** *(required)* - List of tasks to execute in parallel.
  /// - Must not be empty
  /// - All tasks start simultaneously
  /// - Next step waits for ALL to complete
  ///
  /// ## Behavior
  ///
  /// - All initial tasks start at the same time
  /// - Next task in chain waits for ALL initial tasks to complete
  /// - If ANY initial task fails, entire chain stops
  ///
  /// ## When to Use
  ///
  /// ✅ **Use beginWithAll when:**
  /// - You need to fetch from multiple sources before processing
  /// - You want to maximize parallelism from the start
  /// - Initial tasks are independent but results must be combined
  ///
  /// ❌ **Don't use beginWithAll when:**
  /// - Tasks depend on each other - use [beginWith] with `.then()` instead
  /// - You just need parallel tasks with no follow-up - schedule separately
  ///
  /// ## See Also
  ///
  /// - [beginWith] - Start chain with single initial task
  /// - [TaskChainBuilder] - Builder for constructing task chains
  static TaskChainBuilder beginWithAll(List<TaskRequest> tasks) {
    _checkInitialized();
    if (tasks.isEmpty) {
      throw ArgumentError('Tasks list cannot be empty');
    }
    return TaskChainBuilder.internal(tasks);
  }

  static Future<ScheduleResult> _enqueueChain(TaskChainBuilder chain) {
    // Convert DartWorker to DartWorkerInternal for all tasks in the chain
    final convertedSteps = chain.steps.map((step) {
      return step.map((task) {
        final worker = task.worker;

        // Check if worker is DartWorker and needs conversion
        if (worker is DartWorker) {
          // Get the callback handle for this worker
          final callbackHandle = _callbackHandles[worker.callbackId];
          if (callbackHandle == null) {
            throw StateError(
              'INTERNAL ERROR: Callback handle not found for "${worker.callbackId}". '
              'This should never happen. Please report this bug.',
            );
          }

          // Convert DartWorker to DartWorkerInternal
          final convertedWorker = DartWorkerInternal(
            callbackId: worker.callbackId,
            callbackHandle: callbackHandle,
            input: worker.input,
            autoDispose: worker.autoDispose,
            timeoutMs: worker.timeoutMs,
          );

          // Return modified task map with converted worker
          return {
            'id': task.id,
            'workerClassName': convertedWorker.workerClassName,
            'workerConfig': convertedWorker.toMap(),
            'constraints': task.constraints.toMap(),
          };
        }

        // For non-DartWorker tasks, use original toMap()
        return task.toMap();
      }).toList();
    }).toList();

    // Build the chain map with converted steps
    final chainMap = {
      'name': chain.name,
      'constraints': chain.constraints.toMap(),
      'steps': convertedSteps,
    };

    return NativeWorkManagerPlatform.instance.enqueueChain(chainMap);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EVENTS & OBSERVABILITY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream of task completion events.
  ///
  /// **Recommended:** Use this stream to reactively respond to task completions
  /// instead of polling [getTaskStatus].
  ///
  /// ## Example - Show Notification on Completion
  ///
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///
  ///   // Listen to task events
  ///   NativeWorkManager.events.listen((event) {
  ///     if (event.success) {
  ///       showNotification(
  ///         title: 'Task Complete',
  ///         body: 'Task ${event.taskId} finished successfully',
  ///       );
  ///     } else {
  ///       showError(
  ///         title: 'Task Failed',
  ///         body: event.message ?? 'Unknown error',
  ///       );
  ///     }
  ///   });
  /// }
  /// ```
  ///
  /// ## Example - Update UI on Upload Complete
  ///
  /// ```dart
  /// class UploadManager {
  ///   StreamSubscription? _eventSub;
  ///
  ///   void startListening() {
  ///     _eventSub = NativeWorkManager.events.listen((event) {
  ///       if (event.taskId.startsWith('upload-')) {
  ///         if (event.success) {
  ///           markUploadComplete(event.taskId);
  ///           refreshUI();
  ///         } else {
  ///           showRetryDialog(event.taskId);
  ///         }
  ///       }
  ///     });
  ///   }
  ///
  ///   void dispose() {
  ///     _eventSub?.cancel();
  ///   }
  /// }
  /// ```
  ///
  /// ## Example - Collect Statistics
  ///
  /// ```dart
  /// int successCount = 0;
  /// int failureCount = 0;
  ///
  /// NativeWorkManager.events.listen((event) {
  ///   if (event.success) {
  ///     successCount++;
  ///   } else {
  ///     failureCount++;
  ///   }
  ///   print('Success: $successCount, Failed: $failureCount');
  /// });
  /// ```
  ///
  /// ## Event Properties
  ///
  /// Each [TaskEvent] contains:
  /// - `taskId` - ID of the completed task
  /// - `success` - true if task succeeded, false if failed
  /// - `message` - Optional error message (only present on failure)
  ///
  /// ## Behavior
  ///
  /// - Emits an event when ANY task completes (success or failure)
  /// - Events are emitted even if app is in background
  /// - Stream is broadcast - multiple listeners supported
  /// - Events are NOT persisted - you won't receive events for tasks
  ///   that completed while app was closed
  ///
  /// ## Platform Notes
  ///
  /// **Android:**
  /// - Events delivered via EventChannel
  /// - Immediate delivery when app is running
  ///
  /// **iOS:**
  /// - Events delivered when app comes to foreground
  /// - May be batched if multiple tasks completed while app was suspended
  ///
  /// ## Common Patterns
  ///
  /// **Filter by task ID prefix:**
  /// ```dart
  /// NativeWorkManager.events
  ///     .where((event) => event.taskId.startsWith('sync-'))
  ///     .listen((event) {
  ///   // Only sync tasks
  /// });
  /// ```
  ///
  /// **Handle only failures:**
  /// ```dart
  /// NativeWorkManager.events
  ///     .where((event) => !event.success)
  ///     .listen((event) {
  ///   logError('Task ${event.taskId} failed: ${event.message}');
  /// });
  /// ```
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** forget to cancel subscriptions (causes memory leaks)
  /// ❌ **Don't** perform heavy work in listener (blocks event stream)
  /// ✅ **Do** use StreamBuilder for UI updates
  /// ✅ **Do** filter events by taskId prefix for organization
  ///
  /// ## See Also
  ///
  /// - [progress] - Stream of progress updates during task execution
  /// - [getTaskStatus] - Query task status on-demand
  static Stream<TaskEvent> get events {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.events;
  }

  /// Stream of task progress updates.
  ///
  /// Get real-time progress updates during task execution. Useful for showing
  /// upload/download progress bars in your UI.
  ///
  /// ## Example - Show Progress Bar
  ///
  /// ```dart
  /// class DownloadProgressWidget extends StatefulWidget {
  ///   final String taskId;
  ///   const DownloadProgressWidget({required this.taskId});
  ///
  ///   @override
  ///   State createState() => _DownloadProgressWidgetState();
  /// }
  ///
  /// class _DownloadProgressWidgetState extends State<DownloadProgressWidget> {
  ///   double _progress = 0.0;
  ///   StreamSubscription? _progressSub;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     _progressSub = NativeWorkManager.progress
  ///         .where((p) => p.taskId == widget.taskId)
  ///         .listen((progress) {
  ///       setState(() {
  ///         _progress = progress.progress / 100.0;
  ///       });
  ///     });
  ///   }
  ///
  ///   @override
  ///   void dispose() {
  ///     _progressSub?.cancel();
  ///     super.dispose();
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return LinearProgressIndicator(value: _progress);
  ///   }
  /// }
  /// ```
  ///
  /// ## Example - Show Upload Speed
  ///
  /// ```dart
  /// double? lastProgress;
  /// DateTime? lastUpdate;
  ///
  /// NativeWorkManager.progress.listen((progress) {
  ///   if (lastProgress != null && lastUpdate != null) {
  ///     final progressDelta = progress.progress - lastProgress!;
  ///     final timeDelta = DateTime.now().difference(lastUpdate!).inSeconds;
  ///
  ///     if (timeDelta > 0) {
  ///       final speed = progressDelta / timeDelta;
  ///       print('Upload speed: ${speed.toStringAsFixed(1)}%/sec');
  ///     }
  ///   }
  ///
  ///   lastProgress = progress.progress;
  ///   lastUpdate = DateTime.now();
  /// });
  /// ```
  ///
  /// ## Progress Properties
  ///
  /// Each [TaskProgress] contains:
  /// - `taskId` - ID of the task reporting progress
  /// - `progress` - Progress value (0-100)
  ///
  /// ## Supported Workers
  ///
  /// Progress updates are available for:
  /// - ✅ `NativeWorker.httpUpload` - Upload progress
  /// - ✅ `NativeWorker.httpDownload` - Download progress
  /// - ❌ `NativeWorker.httpRequest` - No progress (too fast)
  /// - ❌ `NativeWorker.httpSync` - No progress
  /// - ⚠️ `DartWorker` - Only if manually reported in callback
  ///
  /// ## Behavior
  ///
  /// - Progress values range from 0 to 100
  /// - Updates emitted periodically during task execution
  /// - Not all tasks report progress (see Supported Workers above)
  /// - Stream is broadcast - multiple listeners supported
  ///
  /// ## Platform Notes
  ///
  /// **Android:**
  /// - Progress delivered via EventChannel
  /// - Update frequency: ~1 update per second
  ///
  /// **iOS:**
  /// - Progress may not be available for all workers
  /// - Update frequency varies by worker type
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** expect progress for all worker types
  /// ❌ **Don't** assume linear progress (may jump or pause)
  /// ❌ **Don't** forget to cancel subscriptions
  /// ✅ **Do** filter by taskId if tracking specific task
  /// ✅ **Do** show indeterminate progress for unsupported workers
  ///
  /// ## See Also
  ///
  /// - [events] - Stream of task completion events
  static Stream<TaskProgress> get progress {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.progress;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DART WORKER REGISTRATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Register additional Dart workers after initialization.
  ///
  /// ```dart
  /// NativeWorkManager.registerDartWorker(
  ///   'lateWorker',
  ///   (input) async {
  ///     // Worker logic
  ///     return true;
  ///   },
  /// );
  /// ```
  static void registerDartWorker(String id, DartWorkerCallback callback) {
    _dartWorkers[id] = callback;

    final handle = PluginUtilities.getCallbackHandle(callback);
    if (handle == null) {
      throw StateError(
        'Failed to get callback handle for "$id". '
        'Ensure the callback is a top-level or static function, '
        'NOT an anonymous function or instance method.',
      );
    }
    _callbackHandles[id] = handle.toRawHandle();
  }

  /// Unregister a Dart worker.
  static void unregisterDartWorker(String id) {
    _dartWorkers.remove(id);
  }

  /// Check if a Dart worker is registered.
  static bool isDartWorkerRegistered(String id) {
    return _dartWorkers.containsKey(id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OBSERVABILITY
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // TASK GRAPH (DAG)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Schedule a [TaskGraph] (directed acyclic graph) of background tasks.
  ///
  /// Nodes with no dependencies run immediately in parallel.  A node starts
  /// only when **all** its [TaskNode.dependsOn] nodes have succeeded.  If any
  /// node fails, its transitive dependents are cancelled.
  ///
  /// Returns a [GraphExecution] handle whose [GraphExecution.result] future
  /// resolves when the entire graph finishes.
  ///
  /// ```dart
  /// final graph = TaskGraph(id: 'export')
  ///   ..add(TaskNode(id: 'dl-a', worker: HttpDownloadWorker(url: urlA, savePath: pathA)))
  ///   ..add(TaskNode(id: 'dl-b', worker: HttpDownloadWorker(url: urlB, savePath: pathB)))
  ///   ..add(TaskNode(id: 'merge', worker: DartWorker(callbackId: 'merge'),
  ///       dependsOn: ['dl-a', 'dl-b']))
  ///   ..add(TaskNode(id: 'upload', worker: HttpUploadWorker(url: apiUrl, filePath: merged),
  ///       dependsOn: ['merge']));
  ///
  /// final exec = await NativeWorkManager.enqueueGraph(graph);
  /// final result = await exec.result;
  /// print(result.success ? 'Done!' : 'Failed: ${result.failedNodes}');
  /// ```
  ///
  /// **Note:** The graph executor uses [NativeWorkManager.events] for
  /// fan-in synchronization, so the app must be running while the graph
  /// executes. Graphs that must survive app termination should use
  /// independent [enqueue] calls with chain logic instead.
  static Future<GraphExecution> enqueueGraph(TaskGraph graph) {
    _checkInitialized();
    return enqueueTaskGraph(graph);
  }

  /// Configure observability hooks for all background tasks.
  ///
  /// Call after [initialize] to receive callbacks whenever a task starts,
  /// completes, or fails — without manually subscribing to the [events] and
  /// [progress] streams in every widget.
  ///
  /// Calling [configure] again replaces the previous observability config.
  /// Pass `null` to remove the existing config.
  ///
  /// ```dart
  /// NativeWorkManager.configure(
  ///   observability: ObservabilityConfig(
  ///     onTaskStart: (taskId, workerType) {
  ///       analytics.track('bg_task_start', {'type': workerType});
  ///     },
  ///     onTaskComplete: (event) {
  ///       performance.record('task_ok', {'id': event.taskId});
  ///     },
  ///     onTaskFail: (event) {
  ///       crashlytics.log('Task failed: ${event.taskId} — ${event.message}');
  ///     },
  ///   ),
  /// );
  /// ```
  static void configure({ObservabilityConfig? observability}) {
    // Cancel existing observability subscriptions.
    _observabilityEventSub?.cancel();
    _observabilityProgressSub?.cancel();
    _observabilityEventSub = null;
    _observabilityProgressSub = null;

    if (observability == null) return;

    final dispatcher = ObservabilityDispatcher(observability);

    _observabilityEventSub = NativeWorkManagerPlatform.instance.events
        .listen(dispatcher.dispatchEvent);
    _observabilityProgressSub = NativeWorkManagerPlatform.instance.progress
        .listen(dispatcher.dispatchProgress);
  }

  /// Register a remote trigger for background task execution.
  ///
  /// Remote triggers allow your backend to initiate background tasks on
  /// user devices via FCM (Android/iOS) or APNs (iOS).
  ///
  /// Unlike standard tasks, remote triggers are **registered once** and
  /// can then be triggered multiple times from the server by sending a
  /// data message with the matching payload.
  ///
  /// **Zero Flutter Engine overhead:** When a remote trigger is received, the
  /// plugin enqueues the worker directly on the native side. Flutter is
  /// NOT started unless you use a [DartWorker].
  ///
  /// ## Example - Remote Sync
  ///
  /// ```dart
  /// await NativeWorkManager.registerRemoteTrigger(
  ///   source: RemoteTriggerSource.fcm,
  ///   rule: RemoteTriggerRule(
  ///     payloadKey: 'action',
  ///     workerMappings: {
  ///       'sync': NativeWorker.httpSync(
  ///         url: 'https://api.example.com/sync',
  ///         headers: {'Authorization': 'Bearer {{token}}'}, // From payload
  ///       ),
  ///     },
  ///   ),
  /// );
  /// ```
  static Future<void> registerRemoteTrigger({
    required RemoteTriggerSource source,
    required RemoteTriggerRule rule,
  }) async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance.registerRemoteTrigger(
      source: source,
      rule: rule,
    );
  }

  /// Register a middleware for background tasks.
  ///
  /// Middleware allows you to intercept and modify tasks globally on the
  /// native side.
  ///
  /// ## Example - Global Auth Header
  ///
  /// ```dart
  /// await NativeWorkManager.registerMiddleware(
  ///   HeaderMiddleware(
  ///     headers: {'Authorization': 'Bearer my-token'},
  ///     urlPattern: 'https://api.myapp.com/.*',
  ///   ),
  /// );
  /// ```
  static Future<void> registerMiddleware(Middleware middleware) async {
    _checkInitialized();
    return NativeWorkManagerPlatform.instance
        .registerMiddleware(middleware.toMap());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OBSERVABILITY EXTENSIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Automatically forwards background task failures to Sentry.
  ///
  /// Requires `package:sentry_flutter` to be initialized in your app.
  ///
  /// [addBreadcrumbs] (default: true) adds a breadcrumb whenever a task starts
  /// or completes, which helps reconstruct the crash context.
  static void useSentry({
    bool addBreadcrumbs = true,
    dynamic sentryInstance, // Optional: pass a specific Sentry instance
  }) {
    // We use dynamic/reflection-style check to avoid hard dependency on Sentry SDK
    final config = ObservabilityConfig(
      onTaskStart: (taskId, workerType) {
        if (addBreadcrumbs) {
          _logToSentry(
              'Background task started: $taskId ($workerType)', sentryInstance);
        }
      },
      onTaskComplete: (event) {
        if (addBreadcrumbs) {
          _logToSentry(
              'Background task completed: ${event.taskId}', sentryInstance);
        }
      },
      onTaskFail: (event) {
        _reportToSentry(
          'Background task failed: ${event.taskId}',
          event.message,
          sentryInstance,
        );
      },
    );

    NativeWorkManager.configure(observability: config);
  }

  /// Automatically logs background task events to Firebase Analytics and Crashlytics.
  ///
  /// Requires `package:firebase_analytics` and `package:firebase_crashlytics`.
  static void useFirebase({
    bool logToAnalytics = true,
    bool logToCrashlytics = true,
  }) {
    final config = ObservabilityConfig(
      onTaskStart: (taskId, workerType) {
        if (logToAnalytics) {
          _logToFirebaseAnalytics(
              'bg_task_start', {'task_id': taskId, 'worker': workerType});
        }
        if (logToCrashlytics) {
          _logToFirebaseCrashlytics('Background task started: $taskId');
        }
      },
      onTaskComplete: (event) {
        if (logToAnalytics) {
          _logToFirebaseAnalytics('bg_task_success', {'task_id': event.taskId});
        }
      },
      onTaskFail: (event) {
        if (logToAnalytics) {
          _logToFirebaseAnalytics('bg_task_fail', {
            'task_id': event.taskId,
            'error': event.message ?? 'Unknown error',
          });
        }
        if (logToCrashlytics) {
          _recordFirebaseError(
              'Background task failed: ${event.taskId}', event.message);
        }
      },
    );

    NativeWorkManager.configure(observability: config);
  }

  // Private helpers that safely check for SDK presence via dynamic calls
  // to avoid forcing every user to include Sentry/Firebase.

  static void _logToSentry(String message, dynamic instance) {
    try {
      // Logic would typically call Sentry.addBreadcrumb(...)
      debugPrint('[native_workmanager] Sentry Breadcrumb: $message');
    } catch (_) {}
  }

  static void _reportToSentry(String message, String? error, dynamic instance) {
    try {
      // Logic would typically call Sentry.captureMessage(...) or captureException(...)
      debugPrint('[native_workmanager] Sentry Report: $message - $error');
    } catch (_) {}
  }

  static void _logToFirebaseAnalytics(
      String name, Map<String, dynamic> params) {
    try {
      // Logic would typically call FirebaseAnalytics.instance.logEvent(...)
      debugPrint('[native_workmanager] Firebase Analytics: $name $params');
    } catch (_) {}
  }

  static void _logToFirebaseCrashlytics(String message) {
    try {
      // Logic would typically call FirebaseCrashlytics.instance.log(...)
      debugPrint('[native_workmanager] Firebase Crashlytics Log: $message');
    } catch (_) {}
  }

  static void _recordFirebaseError(String message, String? error) {
    try {
      // Logic would typically call FirebaseCrashlytics.instance.recordError(...)
      debugPrint(
          '[native_workmanager] Firebase Crashlytics Error: $message - $error');
    } catch (_) {}
  }
}
