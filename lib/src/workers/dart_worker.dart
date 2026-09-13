import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Marks a top-level function as a [DartWorker] callback.
///
/// Use with `native_workmanager_gen` to auto-generate:
/// - A type-safe `WorkerIds` constants class (eliminates magic strings).
/// - A `generatedWorkerRegistry` map ready for [NativeWorkManager.initialize].
///
/// ## Setup
///
/// 1. Add `native_workmanager_gen` to `dev_dependencies` in pubspec.yaml.
/// 2. Annotate top-level functions and add a `part` directive:
///
/// ```dart
/// // lib/workers.dart
/// import 'package:native_workmanager/native_workmanager.dart';
///
/// part 'workers.g.dart';
///
/// @WorkerCallback('sync_contacts')
/// Future<bool> syncContacts(Map<String, dynamic>? input) async {
///   // ...
///   return true;
/// }
///
/// @WorkerCallback('backup_photos')
/// Future<bool> backupPhotos(Map<String, dynamic>? input) async {
///   // ...
///   return true;
/// }
/// ```
///
/// 3. Run code generation:
/// ```sh
/// dart run build_runner build
/// ```
///
/// 4. Use generated code:
/// ```dart
/// // In main.dart
/// await NativeWorkManager.initialize(
///   dartWorkers: generatedWorkerRegistry,
/// );
///
/// // Schedule with compile-time-safe ID:
/// DartWorker(callbackId: WorkerIds.syncContacts)
/// ```
///
/// ## Constraints
///
/// - Must be applied to a **top-level function** (not a method or closure).
/// - Function must have the signature `Future<bool> Function(Map<String, dynamic>?)`.
/// - The `id` must be **unique** across all annotated functions in the same library.

/// Callback type for Dart workers.
///
/// [input] - JSON-decoded input data passed when scheduling.
/// Returns `true` for success, `false` for failure.
typedef DartWorkerCallback = Future<bool> Function(Map<String, dynamic>? input);

/// Callback type for [DartWorker.onStoppedId] handlers (issue #75).
///
/// Invoked when the platform stops a running DartWorker — an explicit
/// [NativeWorkManager.cancel], or the OS reclaiming background time (WorkManager
/// stopping the worker on Android, BGTask expiration on iOS).
///
/// [input] is the task's own input plus `__taskId` and `__executionId`, so one
/// handler can serve several tasks and tell them apart. Additional keys may be
/// added here over time (a stop *reason* is the next one planned), which is why
/// this takes a map rather than positional arguments.
///
/// This is a **notification, not preemption**: returning from this handler does
/// not abort whatever the worker callback is currently `await`-ing — Dart has no
/// API to do that. Use it to persist progress and release resources, and return
/// promptly; the budget is [DartWorker.cancelGrace].
typedef DartWorkerStoppedCallback = Future<void> Function(
    Map<String, dynamic>? input);

/// Dart callback worker for custom logic (requires Flutter Engine).
///
/// Executes Dart code in a background isolate. This starts the Flutter Engine,
/// which uses more resources (~50MB RAM) but gives you full access to Dart/Flutter
/// APIs, packages, and local databases.
///
/// ---
/// ## ⚠️ WARNING — Resource Cost
///
/// Every `DartWorker` task **boots a Flutter Engine** in the background:
///
/// | Resource | DartWorker | NativeWorker |
/// |----------|------------|--------------|
/// | RAM      | ~50 MB     | ~2 MB        |
/// | CPU startup | ~500–1000 ms cold / ~100 ms warm | < 100 ms |
/// | Battery  | High (JIT/AOT warm-up) | Low |
///
/// **Practical limits:**
/// - Running 3+ DartWorker tasks concurrently can push total background RAM
///   above 150 MB, risking OS termination on low-memory devices.
/// - On iOS, background execution time is strictly budgeted (~30 s for
///   `BGAppRefreshTask`, ~minutes for `BGProcessingTask`). Engine startup
///   alone can consume a significant portion of that budget.
///
/// **Use [NativeWorker] instead whenever possible.** Only reach for
/// `DartWorker` when you genuinely need Dart/Flutter APIs (e.g. sqflite,
/// Hive, custom Dart packages) in the background.
///
/// **Set `autoDispose: true`** on infrequent tasks to free the ~50 MB RAM
/// immediately after the callback returns, at the cost of a cold-start
/// penalty on the next execution.
/// ---
///
/// **Resource Cost:** Starts Flutter Engine (~50MB RAM vs ~2MB for NativeWorker)
/// **Flexibility:** Full Dart/Flutter API access
/// **Use Case:** Complex logic, database access, response processing
///
/// ## Complete Example - Process API Response
///
/// ```dart
/// // 1. Register callback during initialization
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await NativeWorkManager.initialize(
///     dartWorkers: {
///       'processSync': (input) async {
///         // Make HTTP call
///         final response = await http.get(
///           Uri.parse('https://api.example.com/sync'),
///         );
///
///         // Parse JSON response
///         final data = jsonDecode(response.body);
///
///         // Save to local database
///         final db = await openDatabase('app.db');
///         for (var item in data['items']) {
///           await db.insert('items', item);
///         }
///
///         return true; // Success
///       },
///     },
///   );
///
///   runApp(MyApp());
/// }
///
/// // 2. Schedule the worker
/// await NativeWorkManager.enqueue(
///   taskId: 'sync-with-processing',
///   trigger: TaskTrigger.periodic(Duration(hours: 6)),
///   worker: DartWorker(callbackId: 'processSync'),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// ## Example - Database Cleanup
///
/// ```dart
/// await NativeWorkManager.initialize(
///   dartWorkers: {
///     'cleanupDatabase': (input) async {
///       final db = await openDatabase('app.db');
///
///       // Delete old records
///       await db.delete(
///         'cache',
///         where: 'timestamp < ?',
///         whereArgs: [DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch],
///       );
///
///       // Vacuum database
///       await db.execute('VACUUM');
///
///       return true;
///     },
///   },
/// );
///
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-cleanup',
///   trigger: TaskTrigger.periodic(Duration(days: 1)),
///   worker: DartWorker(callbackId: 'cleanupDatabase'),
/// );
/// ```
///
/// ## Example - Image Processing
///
/// ```dart
/// await NativeWorkManager.initialize(
///   dartWorkers: {
///     'processImages': (input) async {
///       final imagePaths = input?['paths'] as List<String>;
///
///       for (var path in imagePaths) {
///         // Read image
///         final image = await decodeImageFromList(
///           await File(path).readAsBytes(),
///         );
///
///         // Resize and compress
///         final resized = await FlutterImageCompress.compressWithFile(
///           path,
///           minWidth: 1024,
///           minHeight: 1024,
///           quality: 85,
///         );
///
///         // Save compressed version
///         await File('$path.compressed').writeAsBytes(resized);
///       }
///
///       return true;
///     },
///   },
/// );
///
/// await NativeWorkManager.enqueue(
///   taskId: 'compress-images',
///   trigger: TaskTrigger.oneTime(),
///   worker: DartWorker(
///     callbackId: 'processImages',
///     input: {
///       'paths': ['/path/img1.jpg', '/path/img2.jpg'],
///     },
///   ),
/// );
/// ```
///
/// ## Constructor Parameters
///
/// **[callbackId]** *(required)* - ID of registered callback.
/// - Must match a key in dartWorkers map from initialize()
/// - Throws `StateError` if not registered
/// - Throws `ArgumentError` if empty
///
/// **[input]** *(optional)* - Data to pass to callback.
/// - Will be JSON encoded/decoded automatically
/// - Available as parameter in callback function
/// - Can be null if callback needs no input
///
/// ## Callback Requirements
///
/// Your callback function must:
/// - Be a top-level or static function (not a closure)
/// - Return `Future<bool>` (true = success, false = failure)
/// - Accept optional `Map<String, dynamic>?` parameter
/// - Be registered in NativeWorkManager.initialize()
///
/// ```dart
/// // ✅ GOOD - Top-level function
/// Future<bool> myWorker(Map<String, dynamic>? input) async {
///   // Your logic here
///   return true;
/// }
///
/// // ❌ BAD - Anonymous function (won't work in background isolate)
/// dartWorkers: {
///   'worker': (input) async => true, // Won't work!
/// }
/// ```
///
/// ## When to Use DartWorker
///
/// ✅ **Use DartWorker when:**
/// - You need to process API responses
/// - You need database access (sqflite, hive, etc.)
/// - You need complex Dart logic or algorithms
/// - You need to use Dart/Flutter packages
/// - You need to transform/process data
///
/// ❌ **Don't use DartWorker when:**
/// - Simple HTTP request is enough → Use `NativeWorker.httpRequest`
/// - Just uploading/downloading files → Use `NativeWorker.httpUpload/Download`
/// - Fire-and-forget JSON API call → Use `NativeWorker.httpSync`
///
/// ## Performance Comparison
///
/// | Aspect | DartWorker | NativeWorker |
/// |--------|------------|--------------|
/// | RAM Usage | ~50MB | ~2MB |
/// | Startup Time | ~2-3 seconds | <100ms |
/// | Capabilities | Full Dart/Flutter | HTTP only |
/// | Use Case | Complex logic | Simple HTTP |
///
/// ## Common Pitfalls
///
/// ❌ **Don't** use anonymous functions (must be top-level/static)
/// ❌ **Don't** forget to register callback in initialize()
/// ❌ **Don't** use DartWorker for simple HTTP (wasteful)
/// ❌ **Don't** access UI/BuildContext (background isolate)
/// ✅ **Do** use for complex processing
/// ✅ **Do** return true/false from callback
/// ✅ **Do** handle errors gracefully in callback
/// ✅ **Do** keep callbacks focused and efficient
///
/// ## Error Handling
///
/// ```dart
/// dartWorkers: {
///   'safeWorker': (input) async {
///     try {
///       // Your logic
///       await riskyOperation();
///       return true;
///     } catch (e) {
///       print('Worker error: $e');
///       return false; // Mark as failed
///     }
///   },
/// }
/// ```
///
/// ## Platform Notes
///
/// **Android:**
/// - Starts Flutter Engine in WorkManager worker
/// - Background isolate with full Dart VM
/// - Can access SQLite, SharedPreferences, etc.
///
/// **iOS:**
/// - Starts Flutter Engine in BGProcessingTask
/// - Background isolate with full Dart VM
/// - Limited execution time (iOS may terminate)
///
/// ## See Also
///
/// - [NativeWorker] - Lightweight HTTP workers (no Flutter Engine)
/// - [NativeWorkManager.initialize] - Register dart workers
/// - [DartWorkerCallback] - Callback function type
final class DartWorker extends Worker {
  DartWorker({
    required this.callbackId,
    this.input,
    this.autoDispose = false,
    this.timeoutMs,
    this.onStoppedId,
    this.cancelGrace,
  }) {
    if (onStoppedId != null && onStoppedId!.isEmpty) {
      throw ArgumentError(
        'onStoppedId cannot be empty. '
        'Use the ID you registered in NativeWorkManager.initialize('
        'onStoppedHandlers: ...), or omit it entirely.',
      );
    }
    if (cancelGrace != null && cancelGrace!.isNegative) {
      throw ArgumentError(
        'cancelGrace cannot be negative (got $cancelGrace). '
        'Use null for notify-only, or Duration.zero to tear down as soon as '
        'the onStopped handler returns.',
      );
    }
    if (callbackId.isEmpty) {
      throw ArgumentError(
        'callbackId cannot be empty. '
        'Use the ID you registered in NativeWorkManager.initialize().',
      );
    }
    // Validate input is JSON-serializable at construction time so developers
    // see a clear error here rather than a cryptic failure during enqueue().
    if (input != null) {
      try {
        jsonEncode(input);
      } on JsonUnsupportedObjectError catch (e) {
        throw ArgumentError(
          'DartWorker.input must be JSON-serializable '
          '(String, int, double, bool, List, Map, null only).\n'
          'Unsupported value: ${e.unsupportedObject} '
          '(${e.unsupportedObject.runtimeType})',
        );
      }
    }
  }

  /// ID of the registered callback (from initialize()).
  final String callbackId;

  /// Optional input data (will be JSON encoded).
  final Map<String, dynamic>? input;

  /// Maximum time in milliseconds the callback is allowed to run.
  ///
  /// If the callback does not complete within this duration, the worker will
  /// be killed and the task will be marked as failed.
  ///
  /// Defaults to `null`, which uses the platform default (300 000 ms / 5 min).
  /// Increase this for long-running tasks; decrease it to fail fast on hangs.
  ///
  /// ```dart
  /// // Heavy sync that may take up to 10 minutes
  /// DartWorker(callbackId: 'heavySync', timeoutMs: 10 * 60 * 1000)
  ///
  /// // Quick health-check — fail within 30 s if hung
  /// DartWorker(callbackId: 'healthCheck', timeoutMs: 30 * 1000)
  /// ```
  final int? timeoutMs;

  /// Whether to dispose Flutter Engine immediately after task completes.
  ///
  /// **Memory-First Mode (autoDispose: true)**:
  /// - Engine is killed immediately after callback returns
  /// - Frees ~50MB RAM instantly
  /// - Next task will have cold start penalty (~500ms)
  /// - Best for: Infrequent tasks, low-memory devices
  ///
  /// **Performance-First Mode (autoDispose: false, default)**:
  /// - Engine stays alive for 5 minutes
  /// - Next task within 5min has warm start (~100ms)
  /// - Uses ~50MB RAM during idle period
  /// - Best for: Frequent tasks, task chains
  ///
  /// Example:
  /// ```dart
  /// // One-off sync task (dispose immediately to save RAM)
  /// DartWorker(
  ///   callbackId: 'syncData',
  ///   autoDispose: true, // Kill engine after done
  /// )
  ///
  /// // Frequent monitoring task (keep engine warm)
  /// DartWorker(
  ///   callbackId: 'checkUpdates',
  ///   autoDispose: false, // Keep engine for 5min
  /// )
  /// ```
  final bool autoDispose;

  /// ID of a registered [DartWorkerStoppedCallback] to notify when this task is
  /// stopped mid-flight (issue #75).
  ///
  /// Must match a key in the `onStoppedHandlers` map passed to
  /// [NativeWorkManager.initialize]. Fires on explicit cancellation and on the
  /// OS reclaiming background time (WorkManager stopping the worker on Android,
  /// BGTask expiration on iOS).
  ///
  /// Leave `null` if you'd rather poll [NativeWorkManager.isTaskCancelled] from
  /// inside the callback — both mechanisms work, and they compose.
  ///
  /// ```dart
  /// Future<void> onSyncStopped(Map<String, dynamic>? input) async {
  ///   await db.markInterrupted(input?['__taskId'] as String?);
  /// }
  ///
  /// await NativeWorkManager.initialize(
  ///   dartWorkers: {'sync': syncCallback},
  ///   onStoppedHandlers: {'syncStopped': onSyncStopped},
  /// );
  ///
  /// DartWorker(callbackId: 'sync', onStoppedId: 'syncStopped')
  /// ```
  final String? onStoppedId;

  /// How long the worker may keep running after it has been told to stop
  /// (issue #75).
  ///
  /// This is the budget for the [onStoppedId] handler, and it also decides
  /// whether the Flutter Engine is torn down afterwards:
  ///
  /// - `null` *(default)* — **notify only.** The handler still runs under a
  ///   bounded internal budget, but the engine is never force-disposed, so an
  ///   uncooperative callback keeps running until it finishes on its own. This
  ///   is exactly the v1.8.x behaviour plus a notification, so upgrading cannot
  ///   change how an existing task behaves.
  /// - `Duration.zero` — tear down as soon as the handler returns.
  /// - a positive duration — tear down once the handler returns **or** this
  ///   elapses, whichever comes first.
  ///
  /// ## ⚠️ Teardown is Android-only today
  ///
  /// The **notification** fires on both platforms. The **teardown** currently
  /// happens on Android only. On iOS this setting still bounds the handler's
  /// budget, but nothing is disposed:
  ///
  /// - Foreground / simulator runs the callback on the host app's own Flutter
  ///   engine, which must never be disposed — doing so would kill the app.
  /// - The killed-app headless engine could be torn down, but iOS has no
  ///   in-flight task counter yet to make that safe (see below), so it is left
  ///   as follow-up rather than shipped ungated.
  ///
  /// So on iOS an uncooperative callback keeps running until it returns on its
  /// own. Poll [NativeWorkManager.isTaskCancelled] inside the callback if you
  /// need it to stop early there.
  ///
  /// ## ⚠️ Teardown is not per-task
  ///
  /// The background Flutter Engine is **shared** by all concurrently running
  /// DartWorkers, so it can only be disposed when nothing else is in flight —
  /// disposing while another task still holds the method channel crashes the
  /// process. When a sibling task is running, the cancelled task is left to
  /// finish on its own and the teardown is skipped with a warning. Treat this
  /// as a best-effort stop, not a guarantee.
  ///
  /// A teardown is a **hard kill**: no `finally`, no `await` resumes after it.
  /// Anything that must survive belongs in the [onStoppedId] handler.
  final Duration? cancelGrace;

  @override
  String get workerClassName => 'DartCallbackWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'dartCallback',
        'callbackId': callbackId,
        'input': input != null ? jsonEncode(input) : null,
        'autoDispose': autoDispose,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        if (onStoppedId != null) 'onStoppedId': onStoppedId,
        if (cancelGrace != null) 'cancelGraceMs': cancelGrace!.inMilliseconds,
      };
}

/// Internal DartWorker with callback handle.
///
/// This class is used internally by NativeWorkManager to pass the callback
/// handle to the native side. Users should use [DartWorker] instead.
///
/// DO NOT use this class directly - it's for internal use only.
@immutable
final class DartWorkerInternal extends Worker {
  const DartWorkerInternal({
    required this.callbackId,
    required this.callbackHandle,
    this.input,
    this.autoDispose = false,
    this.timeoutMs,
    this.onStoppedId,
    this.onStoppedHandle,
    this.cancelGraceMs,
  });

  /// ID of the registered callback.
  final String callbackId;

  /// Serializable callback handle for cross-isolate communication.
  final int callbackHandle;

  /// Optional input data (will be JSON encoded).
  final Map<String, dynamic>? input;

  /// Whether to dispose Flutter Engine immediately after task completes.
  final bool autoDispose;

  /// Maximum time in milliseconds the callback is allowed to run.
  /// `null` means use the platform default (5 min).
  final int? timeoutMs;

  /// ID of the registered stop handler, for the main-isolate path (issue #75).
  final String? onStoppedId;

  /// Serializable handle of the stop handler, for the headless-isolate path
  /// (issue #75). The background isolate never runs `initialize()`, so it has
  /// no registry to look [onStoppedId] up in and must resolve by handle.
  final int? onStoppedHandle;

  /// Grace budget in milliseconds. `null` means notify-only — never tear the
  /// engine down. See [DartWorker.cancelGrace].
  final int? cancelGraceMs;

  @override
  String get workerClassName => 'DartCallbackWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'dartCallback',
        'callbackId': callbackId,
        'callbackHandle': callbackHandle,
        'input': input != null ? jsonEncode(input) : null,
        'autoDispose': autoDispose,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        if (onStoppedId != null) 'onStoppedId': onStoppedId,
        if (onStoppedHandle != null) 'onStoppedHandle': onStoppedHandle,
        if (cancelGraceMs != null) 'cancelGraceMs': cancelGraceMs,
      };
}
