import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'events.dart';
import 'platform_interface.dart';

/// Register the DevTools service extensions for native_workmanager.
/// This allows the DevTools Extension to request real-time task metrics,
/// queue sizes, and DAG states without needing continuous polling.
@pragma('vm:entry-point')
void registerDevToolsExtensions() {
  if (!kDebugMode && !kProfileMode) return;

  developer.registerExtension('ext.native_workmanager.getMetrics',
      (method, parameters) async {
    try {
      final metrics = await NativeWorkManagerPlatform.instance.getMetrics();
      return developer.ServiceExtensionResponse.result(jsonEncode(metrics));
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  });

  developer.registerExtension('ext.native_workmanager.syncQueue',
      (method, parameters) async {
    try {
      final success =
          await NativeWorkManagerPlatform.instance.syncOfflineQueue();
      return developer.ServiceExtensionResponse.result(
          jsonEncode({'success': success}));
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  });
}

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
/// - `onTaskStart` fires when the native worker **actually begins execution**, driven by
///   a dedicated lifecycle event from the native side. It fires for **all** tasks —
///   including fast workers that never emit a progress update.
/// - `onTaskComplete` / `onTaskFail` are mutually exclusive for a given task.
@immutable
class ObservabilityConfig {
  const ObservabilityConfig({
    this.onTaskStart,
    this.onTaskComplete,
    this.onTaskFail,
    this.onProgress,
  });

  /// Called when the native worker begins execution.
  ///
  /// The `workerType` parameter is the worker class name (e.g. `'HttpDownloadWorker'`,
  /// `'HttpUploadWorker'`, `'DartCallbackWorker'`), or an empty string if
  /// the native side does not report a type.
  ///
  /// This callback fires reliably for **all** tasks — including fast workers
  /// that never emit progress. It is driven by a native "started" lifecycle
  /// event emitted when the worker actually begins execution, not by the first
  /// progress update.
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

  /// Called by [NativeWorkManager] internals when a progress update arrives.
  void dispatchProgress(TaskProgress progress) {
    if (_config.onProgress != null) {
      _safeCall(() => _config.onProgress!(progress), 'onProgress');
    }
  }

  /// Called by [NativeWorkManager] internals when a task event arrives.
  ///
  /// Handles both lifecycle events ([TaskEvent.isStarted]) and completion
  /// events (success / failure).
  void dispatchEvent(TaskEvent event) {
    if (event.isStarted) {
      if (_config.onTaskStart != null) {
        _safeCall(
          () => _config.onTaskStart!(event.taskId, event.workerType ?? ''),
          'onTaskStart',
        );
      }
      return;
    }

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
