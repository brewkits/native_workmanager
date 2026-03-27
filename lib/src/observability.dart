import 'package:flutter/foundation.dart';
import 'events.dart';

/// Configuration for built-in observability hooks.
///
/// Pass to [NativeWorkManager.configure] to receive callbacks whenever
/// a background task starts, completes, or fails. Useful for analytics,
/// performance monitoring, and crash reporting — without having to manually
/// subscribe to the events/progress streams everywhere in your app.
///
/// ## Setup
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await NativeWorkManager.initialize();
///
///   NativeWorkManager.configure(
///     observability: ObservabilityConfig(
///       onTaskStart: (taskId, workerType) {
///         analytics.track('bg_task_start', {'worker': workerType});
///       },
///       onTaskComplete: (event) {
///         performance.record('task_duration', {
///           'taskId': event.taskId,
///           'elapsed': event.timestamp.difference(startTimes[event.taskId]!),
///         });
///       },
///       onTaskFail: (event) {
///         crashlytics.log('Background task failed: ${event.taskId}');
///         if (event.message != null) {
///           crashlytics.recordError(event.message!, null);
///         }
///       },
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
///
/// ## Callback Guarantees
///
/// - All callbacks are invoked on the **main thread** (same as the events/progress streams).
/// - Callbacks are **fire-and-forget** — exceptions inside them are caught and logged
///   to avoid disrupting the events stream.
/// - `onTaskStart` fires on the **first progress update** for a task.  Workers that
///   do not emit progress (e.g. quick HTTP requests) will not trigger `onTaskStart`,
///   but will always trigger `onTaskComplete` or `onTaskFail`.
/// - `onTaskComplete` / `onTaskFail` are mutually exclusive for a given task.
@immutable
class ObservabilityConfig {
  const ObservabilityConfig({
    this.onTaskStart,
    this.onTaskComplete,
    this.onTaskFail,
    this.onProgress,
  });

  /// Called when the first progress update is received for [taskId].
  ///
  /// [workerType] is the `workerType` field from the task config (e.g.
  /// `'httpDownload'`, `'httpUpload'`, `'parallelHttpUpload'`), or an empty
  /// string if the worker does not report a type.
  ///
  /// **Note:** Workers that emit no progress events (e.g. quick HTTP requests)
  /// will not trigger this callback. Subscribe to [NativeWorkManager.events]
  /// for guaranteed start/end signals on all tasks.
  final void Function(String taskId, String workerType)? onTaskStart;

  /// Called when a task completes successfully.
  final void Function(TaskEvent event)? onTaskComplete;

  /// Called when a task fails.
  final void Function(TaskEvent event)? onTaskFail;

  /// Called on every [TaskProgress] update for any task.
  ///
  /// Use for a global progress dashboard or logging. For task-specific
  /// progress, filter by `progress.taskId`.
  final void Function(TaskProgress progress)? onProgress;
}

/// Internal dispatcher that routes events/progress to [ObservabilityConfig].
///
/// Not part of the public API — use [NativeWorkManager.configure] instead.
class ObservabilityDispatcher {
  ObservabilityDispatcher(this._config);

  final ObservabilityConfig _config;

  /// Track which taskIds have already fired `onTaskStart`.
  final _startedTasks = <String>{};

  /// Called by [NativeWorkManager] internals when a progress update arrives.
  void dispatchProgress(TaskProgress progress) {
    // Fire onTaskStart on first progress for this task.
    if (_config.onTaskStart != null &&
        _startedTasks.add(progress.taskId)) {
      _safeCall(
        () => _config.onTaskStart!(progress.taskId, ''),
        'onTaskStart',
      );
    }
    if (_config.onProgress != null) {
      _safeCall(() => _config.onProgress!(progress), 'onProgress');
    }
  }

  /// Called by [NativeWorkManager] internals when a task event arrives.
  void dispatchEvent(TaskEvent event) {
    // Clean up start-tracking for finished tasks.
    _startedTasks.remove(event.taskId);

    if (event.success) {
      if (_config.onTaskComplete != null) {
        _safeCall(() => _config.onTaskComplete!(event), 'onTaskComplete');
      }
    } else {
      if (_config.onTaskFail != null) {
        _safeCall(() => _config.onTaskFail!(event), 'onTaskFail');
      }
    }
  }

  static void _safeCall(void Function() fn, String callbackName) {
    try {
      fn();
    } catch (e, stack) {
      // Swallow exceptions so a buggy callback can't break the events stream.
      debugPrint(
        '[native_workmanager] ObservabilityConfig.$callbackName threw: $e\n$stack',
      );
    }
  }
}
