import 'package:flutter/foundation.dart';

/// Result of scheduling a task.
///
/// Returned by [NativeWorkManager.enqueue] to indicate whether the OS
/// accepted the task for scheduling.
///
/// ## Success Case
///
/// ```dart
/// final result = await NativeWorkManager.enqueue(
///   taskId: 'sync-data',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
/// );
///
/// if (result == ScheduleResult.accepted) {
///   print('Task scheduled successfully');
/// }
/// ```
///
/// ## Handling Rejection
///
/// ```dart
/// final result = await NativeWorkManager.enqueue(
///   taskId: 'upload-large-file',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpUpload(
///     url: 'https://api.example.com/upload',
///     filePath: '/data/large-file.zip',
///   ),
/// );
///
/// switch (result) {
///   case ScheduleResult.accepted:
///     showNotification('Upload scheduled');
///     break;
///   case ScheduleResult.rejectedOsPolicy:
///     showError('Device cannot schedule tasks (low battery?)');
///     break;
///   case ScheduleResult.throttled:
///     showWarning('Too many tasks - try again later');
///     break;
/// }
/// ```
///
/// ## Why Tasks Get Rejected
///
/// **rejectedOsPolicy:**
/// - Device in power save mode
/// - Too many tasks already scheduled
/// - App in background restrictions (Android)
/// - Constraints too restrictive
///
/// **throttled:**
/// - Too many enqueue() calls in short period
/// - OS rate limiting to prevent abuse
/// - Typical limit: ~500 tasks per hour
///
/// ## Best Practices
///
/// ✅ **Do** check the result and handle rejections gracefully
/// ✅ **Do** implement retry logic with exponential backoff
/// ✅ **Do** inform users if critical tasks can't be scheduled
///
/// ❌ **Don't** assume tasks are always accepted
/// ❌ **Don't** schedule hundreds of tasks rapidly
/// ❌ **Don't** ignore throttling errors
///
/// See also: [NativeWorkManager.enqueue]
enum ScheduleResult {
  /// Task was successfully scheduled.
  ///
  /// The OS accepted the task and will execute it according to the trigger
  /// and constraints. This is the normal success case.
  accepted,

  /// Task was rejected due to OS policy.
  ///
  /// Common causes:
  /// - Device in power save mode
  /// - Too many tasks already scheduled
  /// - Background execution restrictions
  /// - Constraints cannot be satisfied
  rejectedOsPolicy,

  /// Task was throttled (too many requests).
  ///
  /// The app is scheduling tasks too rapidly. The OS rejected this task
  /// to prevent resource abuse. Wait and retry with exponential backoff.
  throttled,
}

/// Policy for handling existing tasks with the same ID.
///
/// When scheduling a task with an ID that already exists, this policy
/// determines whether to keep the existing task or replace it with the new one.
///
/// ## Keep Existing Task
///
/// ```dart
/// // Schedule initial sync
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-sync',
///   trigger: TaskTrigger.periodic(Duration(hours: 24)),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   policy: ExistingTaskPolicy.keep,  // Default
/// );
///
/// // Later, user changes settings - but keep the original task running
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-sync',  // Same ID
///   trigger: TaskTrigger.periodic(Duration(hours: 12)),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   policy: ExistingTaskPolicy.keep,  // Original 24h task continues
/// );
/// ```
///
/// ## Replace Existing Task
///
/// ```dart
/// // Schedule initial sync
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-sync',
///   trigger: TaskTrigger.periodic(Duration(hours: 24)),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
/// );
///
/// // User changes settings - update the task immediately
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-sync',  // Same ID
///   trigger: TaskTrigger.periodic(Duration(hours: 12)),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   policy: ExistingTaskPolicy.replace,  // Cancels 24h, starts 12h
/// );
/// ```
///
/// ## When to Use Keep
///
/// Use `ExistingTaskPolicy.keep` when:
/// - Task is idempotent (safe to run multiple times)
/// - You want to ensure at least one execution happens
/// - Avoiding duplicate work is critical (e.g., expensive API calls)
/// - Initial scheduling during app install
///
/// **Example:** One-time data migration
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'v2-migration',
///   trigger: TaskTrigger.oneTime(),
///   worker: DartWorker(callbackId: 'migrateData'),
///   policy: ExistingTaskPolicy.keep,  // Don't duplicate if already scheduled
/// );
/// ```
///
/// ## When to Use Replace
///
/// Use `ExistingTaskPolicy.replace` when:
/// - User changed settings/preferences
/// - Task configuration needs updating
/// - Old parameters are no longer valid
/// - Cancelling and rescheduling is intentional
///
/// **Example:** User changes sync frequency
/// ```dart
/// // User updates setting: hourly → every 6 hours
/// await NativeWorkManager.enqueue(
///   taskId: 'background-sync',
///   trigger: TaskTrigger.periodic(newInterval),
///   worker: NativeWorker.httpSync(url: syncUrl),
///   policy: ExistingTaskPolicy.replace,  // Apply new frequency immediately
/// );
/// ```
///
/// ## Comparison
///
/// | Scenario | Keep | Replace |
/// |----------|------|---------|
/// | Task already exists | New request ignored | Old task cancelled, new scheduled |
/// | Task not found | New task scheduled | New task scheduled |
/// | Typical use case | Prevent duplicates | Update configuration |
///
/// ## Default Behavior
///
/// If policy is not specified, `ExistingTaskPolicy.keep` is used by default.
/// This prevents accidental duplicate tasks.
///
/// See also: [NativeWorkManager.enqueue]
enum ExistingTaskPolicy {
  /// Keep the existing task, ignore the new one.
  ///
  /// If a task with the same ID already exists, the new enqueue request
  /// is silently ignored. The existing task continues unchanged.
  ///
  /// This is the **default policy** and prevents accidental duplicate tasks.
  keep,

  /// Replace the existing task with the new one.
  ///
  /// If a task with the same ID already exists, it is cancelled and replaced
  /// with the new task. Use this when updating task configuration.
  replace,
}

/// Current status of a task.
///
/// Represents the lifecycle state of a scheduled task. Query task status
/// using [NativeWorkManager.getTaskStatus].
///
/// ## Task Lifecycle
///
/// ```
/// PENDING → RUNNING → COMPLETED
///                   → FAILED
///         → CANCELLED
/// ```
///
/// ## Checking Task Status
///
/// ```dart
/// final status = await NativeWorkManager.getTaskStatus('upload-photos');
///
/// switch (status) {
///   case TaskStatus.pending:
///     print('Waiting for WiFi...');
///     break;
///   case TaskStatus.running:
///     print('Upload in progress...');
///     break;
///   case TaskStatus.completed:
///     print('Upload finished!');
///     break;
///   case TaskStatus.failed:
///     print('Upload failed - will retry');
///     break;
///   case TaskStatus.cancelled:
///     print('Upload cancelled by user');
///     break;
///   case null:
///     print('Task not found');
///     break;
/// }
/// ```
///
/// ## Monitoring Multiple Tasks
///
/// ```dart
/// Future<void> checkUploads() async {
///   final tasks = await NativeWorkManager.getTasksByTag('upload');
///
///   final pending = tasks.where((t) => t.status == TaskStatus.pending).length;
///   final running = tasks.where((t) => t.status == TaskStatus.running).length;
///   final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
///
///   print('Uploads: $pending pending, $running active, $completed done');
/// }
/// ```
///
/// ## Status Transitions
///
/// **PENDING → RUNNING:**
/// - Constraints are met (network, battery, etc.)
/// - OS scheduler starts execution
/// - Task begins doing work
///
/// **RUNNING → COMPLETED:**
/// - Worker returns success result
/// - All work finished successfully
/// - Task removed from queue
///
/// **RUNNING → FAILED:**
/// - Worker throws exception
/// - Network error, timeout, etc.
/// - OS may retry automatically (periodic tasks)
///
/// **ANY → CANCELLED:**
/// - [NativeWorkManager.cancel] called
/// - [NativeWorkManager.cancelByTag] called
/// - [NativeWorkManager.cancelAll] called
/// - Task removed from queue immediately
///
/// ## Important Notes
///
/// - **Completed tasks** are automatically removed after a short period (OS-dependent)
/// - **Failed periodic tasks** may be retried automatically by the OS
/// - **Cancelled tasks** cannot be resumed - must enqueue again
/// - **Running tasks** may take time to fully stop when cancelled
///
/// See also:
/// - [NativeWorkManager.getTaskStatus] - Query status
/// - [NativeWorkManager.events] - Listen for completion events
/// - [TaskEvent] - Task completion notification
enum TaskStatus {
  /// Task is waiting to be executed.
  ///
  /// The task is scheduled but constraints are not yet met
  /// (e.g., waiting for WiFi, charging, etc.).
  pending,

  /// Task is currently running.
  ///
  /// The worker is actively executing. Listen to [NativeWorkManager.progress]
  /// for real-time progress updates.
  running,

  /// Task completed successfully.
  ///
  /// The worker finished and returned success. Completed tasks are
  /// automatically removed from the queue after a short period.
  completed,

  /// Task failed.
  ///
  /// The worker threw an exception or returned failure. For periodic tasks,
  /// the OS may automatically retry. For one-time tasks, the task is marked
  /// as failed and removed from the queue.
  failed,

  /// Task was cancelled.
  ///
  /// The task was explicitly cancelled via [NativeWorkManager.cancel],
  /// [NativeWorkManager.cancelByTag], or [NativeWorkManager.cancelAll].
  /// Cancelled tasks are removed from the queue and cannot be resumed.
  cancelled,
}

/// Event emitted when a task completes (success or failure).
///
/// Listen to [NativeWorkManager.events] to receive notifications when
/// background tasks finish executing. Useful for updating UI, logging,
/// or triggering follow-up actions.
///
/// ## Basic Event Listening
///
/// ```dart
/// void initState() {
///   super.initState();
///
///   // Listen to all task completions
///   NativeWorkManager.events.listen((event) {
///     if (event.success) {
///       print('✅ Task ${event.taskId} completed');
///       if (event.resultData != null) {
///         print('Result: ${event.resultData}');
///       }
///     } else {
///       print('❌ Task ${event.taskId} failed: ${event.message}');
///     }
///   });
/// }
/// ```
///
/// ## Filtering Specific Tasks
///
/// ```dart
/// NativeWorkManager.events
///     .where((event) => event.taskId.startsWith('sync-'))
///     .listen((event) {
///       if (event.success) {
///         showNotification('Sync completed');
///         refreshUI();
///       } else {
///         showError('Sync failed: ${event.message}');
///       }
///     });
/// ```
///
/// ## Handling Different Task Types
///
/// ```dart
/// NativeWorkManager.events.listen((event) {
///   switch (event.taskId) {
///     case 'download-images':
///       if (event.success) {
///         final count = event.resultData?['downloaded_count'];
///         print('Downloaded $count images');
///       }
///       break;
///
///     case 'upload-logs':
///       if (event.success) {
///         clearLocalLogs();
///       } else {
///         scheduleRetry();
///       }
///       break;
///
///     case 'sync-contacts':
///       if (event.success) {
///         updateLastSyncTime(event.timestamp);
///       }
///       break;
///   }
/// });
/// ```
///
/// ## Extracting Result Data
///
/// ```dart
/// // Worker returns data
/// @pragma('vm:entry-point')
/// Future<WorkerResult> processData(WorkerInput input) async {
///   final result = await heavyComputation();
///   return WorkerResult.success(data: {
///     'processed_items': result.count,
///     'total_size': result.sizeInBytes,
///     'duration_ms': result.durationMs,
///   });
/// }
///
/// // Listen for results
/// NativeWorkManager.events
///     .where((e) => e.taskId == 'process-data')
///     .listen((event) {
///       if (event.success && event.resultData != null) {
///         final items = event.resultData!['processed_items'];
///         final size = event.resultData!['total_size'];
///         print('Processed $items items ($size bytes)');
///       }
///     });
/// ```
///
/// ## Error Handling
///
/// ```dart
/// NativeWorkManager.events.listen((event) {
///   if (!event.success) {
///     // Log error for analytics
///     analytics.logError(
///       taskId: event.taskId,
///       error: event.message ?? 'Unknown error',
///       timestamp: event.timestamp,
///     );
///
///     // Notify user for critical tasks
///     if (event.taskId == 'backup-critical-data') {
///       showCriticalErrorDialog(event.message);
///     }
///
///     // Implement retry logic
///     if (shouldRetry(event.taskId)) {
///       scheduleRetry(event.taskId, exponentialBackoff: true);
///     }
///   }
/// });
/// ```
///
/// ## Event Fields
///
/// - [taskId]: Unique identifier of the completed task
/// - [success]: `true` if task completed successfully, `false` if failed
/// - [message]: Error message if failed, or optional success message
/// - [resultData]: Custom data returned by the worker (if any)
/// - [timestamp]: When the task completed execution
///
/// ## Platform Behavior
///
/// **Android:**
/// - Events delivered via WorkManager's Result mechanism
/// - May be delayed if app is in background
/// - Guaranteed delivery when app comes to foreground
///
/// **iOS:**
/// - Events delivered when app is active
/// - Background completion may not trigger immediate event
/// - Events batched if app was terminated
///
/// ## Important Notes
///
/// - Events are only delivered **while the app is running**
/// - If app is terminated, events are **not persisted**
/// - For critical outcomes, persist state in the **worker itself**
/// - Events are **fire-and-forget** (no replay mechanism)
/// - Use [getTaskStatus] to check status if you miss events
///
/// ## Best Practices
///
/// ✅ **Do** listen to events for UI updates and logging
/// ✅ **Do** filter events by taskId or patterns for specific handling
/// ✅ **Do** persist important results in the worker, not just events
/// ✅ **Do** handle both success and failure cases
///
/// ❌ **Don't** rely on events for critical state management
/// ❌ **Don't** assume events arrive in order (parallel tasks)
/// ❌ **Don't** expect events if app is terminated
///
/// See also:
/// - [NativeWorkManager.events] - Stream of task events
/// - [TaskProgress] - Progress updates during execution
/// - [TaskStatus] - Current task status
@immutable
class TaskEvent {
  const TaskEvent({
    required this.taskId,
    required this.success,
    this.message,
    this.resultData,
    required this.timestamp,
  });

  /// ID of the completed task.
  final String taskId;

  /// Whether the task succeeded.
  final bool success;

  /// Optional message (error message if failed).
  final String? message;

  /// Optional result data from the worker.
  final Map<String, dynamic>? resultData;

  /// When the task completed.
  final DateTime timestamp;

  /// Create from platform channel map.
  factory TaskEvent.fromMap(Map<String, dynamic> map) => TaskEvent(
        taskId: map['taskId'] as String,
        success: map['success'] as bool,
        message: map['message'] as String?,
        resultData: map['resultData'] != null
            ? Map<String, dynamic>.from(map['resultData'] as Map)
            : null,
        timestamp: map['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
            : DateTime.now(),
      );

  /// Convert to map.
  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'success': success,
        'message': message,
        'resultData': resultData,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskEvent &&
          taskId == other.taskId &&
          success == other.success &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(taskId, success, timestamp);

  @override
  String toString() => 'TaskEvent('
      'taskId: $taskId, '
      'success: $success, '
      'message: $message, '
      'timestamp: $timestamp)';
}

/// Progress update during task execution.
///
/// Workers can report progress during long-running operations. Listen to
/// [NativeWorkManager.progress] to receive real-time updates and show
/// progress bars or status messages in your UI.
///
/// ## Reporting Progress from Worker
///
/// ```dart
/// @pragma('vm:entry-point')
/// Future<WorkerResult> downloadFiles(WorkerInput input) async {
///   final urls = input.data['urls'] as List<String>;
///   final total = urls.length;
///
///   for (var i = 0; i < urls.length; i++) {
///     // Report progress
///     await input.reportProgress(
///       progress: ((i + 1) / total * 100).round(),
///       message: 'Downloading file ${i + 1} of $total',
///       currentStep: i + 1,
///       totalSteps: total,
///     );
///
///     await downloadFile(urls[i]);
///   }
///
///   return WorkerResult.success();
/// }
/// ```
///
/// ## Listening to Progress Updates
///
/// ```dart
/// void initState() {
///   super.initState();
///
///   // Listen to progress for all tasks
///   NativeWorkManager.progress.listen((progress) {
///     setState(() {
///       _currentProgress = progress.progress;
///       _statusMessage = progress.message ?? 'Processing...';
///     });
///   });
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       LinearProgressIndicator(value: _currentProgress / 100),
///       Text(_statusMessage),
///       if (_currentStep != null && _totalSteps != null)
///         Text('Step $_currentStep of $_totalSteps'),
///     ],
///   );
/// }
/// ```
///
/// ## Filtering Progress by Task
///
/// ```dart
/// // Only listen to specific task's progress
/// NativeWorkManager.progress
///     .where((p) => p.taskId == 'bulk-upload')
///     .listen((progress) {
///       print('Upload: ${progress.progress}% - ${progress.message}');
///
///       if (progress.currentStep != null && progress.totalSteps != null) {
///         print('File ${progress.currentStep}/${progress.totalSteps}');
///       }
///     });
/// ```
///
/// ## Multi-Step Task with Progress
///
/// ```dart
/// @pragma('vm:entry-point')
/// Future<WorkerResult> processImages(WorkerInput input) async {
///   final images = input.data['images'] as List<String>;
///   final steps = ['Download', 'Resize', 'Compress', 'Upload'];
///   final totalSteps = images.length * steps.length;
///   var currentStep = 0;
///
///   for (var image in images) {
///     // Download
///     currentStep++;
///     await input.reportProgress(
///       progress: (currentStep / totalSteps * 100).round(),
///       message: 'Downloading $image',
///       currentStep: currentStep,
///       totalSteps: totalSteps,
///     );
///     await downloadImage(image);
///
///     // Resize
///     currentStep++;
///     await input.reportProgress(
///       progress: (currentStep / totalSteps * 100).round(),
///       message: 'Resizing $image',
///       currentStep: currentStep,
///       totalSteps: totalSteps,
///     );
///     await resizeImage(image);
///
///     // Compress
///     currentStep++;
///     await input.reportProgress(
///       progress: (currentStep / totalSteps * 100).round(),
///       message: 'Compressing $image',
///       currentStep: currentStep,
///       totalSteps: totalSteps,
///     );
///     await compressImage(image);
///
///     // Upload
///     currentStep++;
///     await input.reportProgress(
///       progress: (currentStep / totalSteps * 100).round(),
///       message: 'Uploading $image',
///       currentStep: currentStep,
///       totalSteps: totalSteps,
///     );
///     await uploadImage(image);
///   }
///
///   return WorkerResult.success();
/// }
/// ```
///
/// ## Progress with Network Upload
///
/// ```dart
/// @pragma('vm:entry-point')
/// Future<WorkerResult> uploadLargeFile(WorkerInput input) async {
///   final file = File(input.data['filePath']);
///   final fileSize = await file.length();
///   var uploaded = 0;
///
///   await uploadWithProgress(
///     file,
///     onProgress: (bytes) {
///       uploaded += bytes;
///       final progress = (uploaded / fileSize * 100).round();
///
///       input.reportProgress(
///         progress: progress,
///         message: 'Uploaded ${uploaded ~/ 1024}KB / ${fileSize ~/ 1024}KB',
///       );
///     },
///   );
///
///   return WorkerResult.success();
/// }
/// ```
///
/// ## Progress Fields
///
/// - [taskId]: Identifier of the task reporting progress
/// - [progress]: Percentage (0-100) of completion
/// - [message]: Optional human-readable status message
/// - [currentStep]: Current step number (for multi-step tasks)
/// - [totalSteps]: Total number of steps (for multi-step tasks)
///
/// ## Platform Behavior
///
/// **Android:**
/// - Progress delivered via WorkManager's setProgress API
/// - Updates throttled to ~1 per second to conserve resources
/// - Reliable delivery while app is active
///
/// **iOS:**
/// - Progress delivered when app is active or backgrounded
/// - Updates batched if app is suspended
/// - May be delayed for terminated apps
///
/// ## Important Notes
///
/// - Progress updates are **best-effort** delivery
/// - Not guaranteed if app is terminated
/// - Updates may be **throttled** by the OS
/// - Don't rely on receiving every single update
/// - Progress is **optional** - tasks work without it
///
/// ## Performance Tips
///
/// ✅ **Do** report progress at meaningful intervals (e.g., every file, every 5%)
/// ✅ **Do** include useful messages for users
/// ✅ **Do** use currentStep/totalSteps for multi-step tasks
///
/// ❌ **Don't** report progress on every byte (too frequent)
/// ❌ **Don't** report progress more than once per second
/// ❌ **Don't** report progress for tasks under 5 seconds
/// ❌ **Don't** block worker execution waiting for progress delivery
///
/// ## When to Use Progress
///
/// **Good for:**
/// - File uploads/downloads (show bytes transferred)
/// - Batch processing (show items processed)
/// - Multi-step workflows (show current step)
/// - Long operations (>10 seconds)
///
/// **Not needed for:**
/// - Quick tasks (<5 seconds)
/// - Tasks with no intermediate steps
/// - Tasks running while app is terminated
///
/// See also:
/// - [NativeWorkManager.progress] - Stream of progress updates
/// - [WorkerInput.reportProgress] - Report from worker
/// - [TaskEvent] - Task completion notification
@immutable
class TaskProgress {
  const TaskProgress({
    required this.taskId,
    required this.progress,
    this.message,
    this.currentStep,
    this.totalSteps,
  });

  /// ID of the task.
  final String taskId;

  /// Progress percentage (0-100).
  final int progress;

  /// Optional status message.
  final String? message;

  /// Current step number (for multi-step tasks).
  final int? currentStep;

  /// Total number of steps.
  final int? totalSteps;

  /// Create from platform channel map.
  factory TaskProgress.fromMap(Map<String, dynamic> map) => TaskProgress(
        taskId: map['taskId'] as String,
        progress: map['progress'] as int,
        message: map['message'] as String?,
        currentStep: map['currentStep'] as int?,
        totalSteps: map['totalSteps'] as int?,
      );

  /// Convert to map.
  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'progress': progress,
        'message': message,
        'currentStep': currentStep,
        'totalSteps': totalSteps,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskProgress &&
          taskId == other.taskId &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(taskId, progress);

  @override
  String toString() => 'TaskProgress('
      'taskId: $taskId, '
      'progress: $progress%, '
      'message: $message, '
      'step: $currentStep/$totalSteps)';
}
