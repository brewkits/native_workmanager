import 'dart:async';
import 'package:flutter/foundation.dart';
import 'native_work_manager.dart';
import 'events.dart';

/// A controller for a specific background task.
///
/// Returned by [NativeWorkManager.enqueue] to allow tracking progress and
/// completion of a specific task without manually filtering global streams.
///
/// ## Usage
///
/// ```dart
/// final handler = await NativeWorkManager.enqueue(
///   taskId: 'download-video',
///   worker: NativeWorker.httpDownload(url: '...'),
/// );
///
/// // 1. Check if OS accepted the task
/// if (handler.scheduleResult != ScheduleResult.accepted) {
///   print('Failed to schedule: ${handler.scheduleResult}');
///   return;
/// }
///
/// // 2. Listen to progress for THIS task only
/// handler.progress.listen((p) {
///   print('Progress: ${p.progress}% (${p.networkSpeedHuman})');
/// });
///
/// // 3. Wait for final result
/// final event = await handler.result;
/// if (event.success) {
///   print('Finished! Result: ${event.resultData}');
/// }
/// ```
@immutable
class TaskHandler {
  /// The unique ID of the task.
  final String taskId;

  /// The result of the scheduling request.
  ///
  /// If [ScheduleResult.accepted], the task was successfully added to the
  /// OS queue. Otherwise, the task will not run.
  final ScheduleResult scheduleResult;

  const TaskHandler({
    required this.taskId,
    required this.scheduleResult,
  });

  /// A stream of progress updates for this specific task.
  ///
  /// Only emits updates if the worker supports progress reporting (e.g.
  /// httpDownload, httpUpload).
  Stream<TaskProgress> get progress =>
      NativeWorkManager.progress.where((p) => p.taskId == taskId);

  /// A stream of lifecycle events for this specific task.
  ///
  /// Emits when the task starts, succeeds, or fails.
  Stream<TaskEvent> get events =>
      NativeWorkManager.events.where((e) => e.taskId == taskId);

  /// A future that completes when the task finishes (either success or failure).
  ///
  /// This is a convenience for `events.firstWhere((e) => !e.isStarted)`.
  ///
  /// **Note:** If the app is terminated and restarted, this future will never
  /// complete because the stream is transient. For long-running tasks, always
  /// use [NativeWorkManager.getTaskStatus] or [NativeWorkManager.events]
  /// subscription for robust state management.
  Future<TaskEvent> get result =>
      events.firstWhere((e) => !e.isStarted).timeout(
            const Duration(days: 7), // Long timeout for background tasks
            onTimeout: () => throw TimeoutException(
              'Task $taskId did not complete within 7 days or was lost.',
            ),
          );

  /// Cancel this task.
  Future<void> cancel() => NativeWorkManager.cancel(taskId: taskId);

  /// Get the current status of this task.
  Future<TaskStatus?> getStatus() =>
      NativeWorkManager.getTaskStatus(taskId: taskId);
}

/// Helper extensions for displaying [TaskProgress] information.
extension TaskProgressExtensions on TaskProgress {
  /// Returns the network speed in a human-readable format (e.g., "1.2 MB/s").
  String get networkSpeedHuman {
    if (networkSpeed == null) return 'n/a';
    if (networkSpeed! < 1024) return '${networkSpeed!.toStringAsFixed(1)} B/s';
    if (networkSpeed! < 1024 * 1024) {
      return '${(networkSpeed! / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(networkSpeed! / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Returns the estimated time remaining in a human-readable format (e.g., "2m 15s").
  String get timeRemainingHuman {
    if (timeRemaining == null) return 'unknown';
    if (timeRemaining!.inSeconds < 60) return '${timeRemaining!.inSeconds}s';
    if (timeRemaining!.inMinutes < 60) {
      final s = timeRemaining!.inSeconds % 60;
      return '${timeRemaining!.inMinutes}m ${s}s';
    }
    final m = timeRemaining!.inMinutes % 60;
    return '${timeRemaining!.inHours}h ${m}m';
  }
}
