import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Callback type for Dart workers.
///
/// [input] - JSON-decoded input data passed when scheduling.
/// Returns `true` for success, `false` for failure.
typedef DartWorkerCallback = Future<bool> Function(Map<String, dynamic>? input);

/// Dart callback worker for custom logic (requires Flutter Engine).
///
/// Executes Dart code in a background isolate. This starts the Flutter Engine,
/// which uses more resources (~50MB RAM) but gives you full access to Dart/Flutter
/// APIs, packages, and local databases.
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
@immutable
final class DartWorker extends Worker {
  const DartWorker({
    required this.callbackId,
    this.input,
    this.autoDispose = false,
  }) : assert(
          callbackId.length > 0,
          'callbackId cannot be empty. '
          'Use the ID you registered in NativeWorkManager.initialize().',
        );

  /// ID of the registered callback (from initialize()).
  final String callbackId;

  /// Optional input data (will be JSON encoded).
  final Map<String, dynamic>? input;

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

  @override
  String get workerClassName => 'DartCallbackWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'dartCallback',
        'callbackId': callbackId,
        'input': input != null ? jsonEncode(input) : null,
        'autoDispose': autoDispose,
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
  });

  /// ID of the registered callback.
  final String callbackId;

  /// Serializable callback handle for cross-isolate communication.
  final int callbackHandle;

  /// Optional input data (will be JSON encoded).
  final Map<String, dynamic>? input;

  /// Whether to dispose Flutter Engine immediately after task completes.
  final bool autoDispose;

  @override
  String get workerClassName => 'DartCallbackWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'dartCallback',
        'callbackId': callbackId,
        'callbackHandle': callbackHandle,
        'input': input != null ? jsonEncode(input) : null,
        'autoDispose': autoDispose,
      };
}
