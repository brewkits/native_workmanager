import 'dart:collection';

/// Performance monitoring for native_workmanager.
///
/// Tracks metrics like:
/// - Task execution times
/// - Success/failure rates
/// - Event dispatch latency
/// - Throughput (tasks per minute)
/// - Per-worker-type statistics
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Enable performance monitoring
///   PerformanceMonitor.instance.enable();
///
///   await NativeWorkManager.initialize();
///   runApp(MyApp());
/// }
///
/// // Get statistics
/// final stats = PerformanceMonitor.instance.getStatistics();
/// print('Success rate: ${stats.successRate}');
/// ```
class PerformanceMonitor {
  PerformanceMonitor._();

  /// Singleton instance.
  static final instance = PerformanceMonitor._();

  bool _enabled = false;
  final _metrics = <String, TaskMetrics>{};
  final _recentEvents = Queue<PerformanceEvent>();
  DateTime? _monitoringStartTime;

  static const _maxRecentEvents = 1000;

  /// Enable performance monitoring.
  void enable() {
    _enabled = true;
    _monitoringStartTime ??= DateTime.now();
  }

  /// Disable performance monitoring.
  void disable() {
    _enabled = false;
  }

  /// Check if monitoring is enabled.
  bool get isEnabled => _enabled;

  /// Clear all collected metrics.
  void clear() {
    _metrics.clear();
    _recentEvents.clear();
    _monitoringStartTime = DateTime.now();
  }

  /// Record task scheduling.
  void recordTaskScheduled(String taskId, String workerType) {
    if (!_enabled) return;

    _metrics[taskId] = TaskMetrics(
      taskId: taskId,
      workerType: workerType,
      scheduledAt: DateTime.now(),
    );

    _addEvent(
      PerformanceEvent(
        type: PerformanceEventType.taskScheduled,
        taskId: taskId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Record task start.
  void recordTaskStart(String taskId, String workerType) {
    if (!_enabled) return;

    final existing = _metrics[taskId];
    if (existing != null) {
      _metrics[taskId] = existing.copyWith(startedAt: DateTime.now());
    } else {
      _metrics[taskId] = TaskMetrics(
        taskId: taskId,
        workerType: workerType,
        startedAt: DateTime.now(),
      );
    }

    _addEvent(
      PerformanceEvent(
        type: PerformanceEventType.taskStarted,
        taskId: taskId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Record task completion.
  void recordTaskComplete(
    String taskId,
    bool success, {
    Map<String, dynamic>? resultData,
  }) {
    if (!_enabled) return;

    final existing = _metrics[taskId];
    if (existing != null) {
      _metrics[taskId] = existing.copyWith(
        completedAt: DateTime.now(),
        success: success,
        resultData: resultData,
      );
    }

    _addEvent(
      PerformanceEvent(
        type: success
            ? PerformanceEventType.taskSucceeded
            : PerformanceEventType.taskFailed,
        taskId: taskId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Record event dispatch.
  void recordEventDispatched(String taskId) {
    if (!_enabled) return;

    _addEvent(
      PerformanceEvent(
        type: PerformanceEventType.eventDispatched,
        taskId: taskId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Get metrics for a specific task.
  TaskMetrics? getTaskMetrics(String taskId) {
    return _metrics[taskId];
  }

  /// Get performance statistics.
  PerformanceStatistics getStatistics() {
    if (!_enabled || _monitoringStartTime == null) {
      return PerformanceStatistics.empty();
    }

    final completedTasks = _metrics.values
        .where((m) => m.completedAt != null)
        .toList();
    final successfulTasks = completedTasks
        .where((m) => m.success == true)
        .toList();

    final durations = completedTasks
        .where((m) => m.duration != null)
        .map((m) => m.duration!.inMilliseconds.toDouble())
        .toList();

    final eventLatencies = _recentEvents
        .where((e) => e.type == PerformanceEventType.eventDispatched)
        .map((e) => e.latency?.inMicroseconds.toDouble() ?? 0.0)
        .where((l) => l > 0)
        .toList();

    final monitoringDuration = DateTime.now().difference(_monitoringStartTime!);
    final tasksPerMinute = monitoringDuration.inSeconds > 0
        ? (completedTasks.length / monitoringDuration.inSeconds) * 60
        : 0.0;

    // Per-worker-type statistics
    final workerTypeStats = <String, WorkerTypeStatistics>{};
    for (final task in completedTasks) {
      final workerType = task.workerType;
      final existing = workerTypeStats[workerType];

      if (existing == null) {
        workerTypeStats[workerType] = WorkerTypeStatistics(
          workerType: workerType,
          totalTasks: 1,
          successfulTasks: task.success == true ? 1 : 0,
          totalDuration: task.duration?.inMilliseconds.toDouble() ?? 0.0,
        );
      } else {
        workerTypeStats[workerType] = WorkerTypeStatistics(
          workerType: workerType,
          totalTasks: existing.totalTasks + 1,
          successfulTasks:
              existing.successfulTasks + (task.success == true ? 1 : 0),
          totalDuration:
              existing.totalDuration +
              (task.duration?.inMilliseconds.toDouble() ?? 0.0),
        );
      }
    }

    return PerformanceStatistics(
      totalTasksScheduled: _metrics.length,
      totalTasksCompleted: completedTasks.length,
      totalTasksSuccessful: successfulTasks.length,
      totalTasksFailed: completedTasks.length - successfulTasks.length,
      averageTaskDuration: durations.isEmpty
          ? 0.0
          : durations.reduce((a, b) => a + b) / durations.length,
      minTaskDuration: durations.isEmpty
          ? 0
          : durations.reduce((a, b) => a < b ? a : b).toInt(),
      maxTaskDuration: durations.isEmpty
          ? 0
          : durations.reduce((a, b) => a > b ? a : b).toInt(),
      averageEventDispatchLatency: eventLatencies.isEmpty
          ? 0.0
          : eventLatencies.reduce((a, b) => a + b) /
                eventLatencies.length /
                1000,
      tasksPerMinute: tasksPerMinute,
      successRate: completedTasks.isEmpty
          ? 0.0
          : successfulTasks.length / completedTasks.length,
      monitoringDuration: monitoringDuration,
      workerTypeStatistics: workerTypeStats,
      recentEvents: List.unmodifiable(_recentEvents),
    );
  }

  void _addEvent(PerformanceEvent event) {
    _recentEvents.add(event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeFirst();
    }
  }
}

/// Metrics for a single task.
class TaskMetrics {
  const TaskMetrics({
    required this.taskId,
    required this.workerType,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.success,
    this.resultData,
  });

  final String taskId;
  final String workerType;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool? success;
  final Map<String, dynamic>? resultData;

  /// Duration from start to completion.
  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  /// Latency from scheduling to start.
  Duration? get startLatency {
    if (scheduledAt == null || startedAt == null) return null;
    return startedAt!.difference(scheduledAt!);
  }

  TaskMetrics copyWith({
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? success,
    Map<String, dynamic>? resultData,
  }) {
    return TaskMetrics(
      taskId: taskId,
      workerType: workerType,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      success: success ?? this.success,
      resultData: resultData ?? this.resultData,
    );
  }
}

/// Performance event types.
enum PerformanceEventType {
  taskScheduled,
  taskStarted,
  taskSucceeded,
  taskFailed,
  eventDispatched,
}

/// A performance event.
class PerformanceEvent {
  const PerformanceEvent({
    required this.type,
    required this.taskId,
    required this.timestamp,
    this.latency,
  });

  final PerformanceEventType type;
  final String taskId;
  final DateTime timestamp;
  final Duration? latency;
}

/// Overall performance statistics.
class PerformanceStatistics {
  const PerformanceStatistics({
    required this.totalTasksScheduled,
    required this.totalTasksCompleted,
    required this.totalTasksSuccessful,
    required this.totalTasksFailed,
    required this.averageTaskDuration,
    required this.minTaskDuration,
    required this.maxTaskDuration,
    required this.averageEventDispatchLatency,
    required this.tasksPerMinute,
    required this.successRate,
    required this.monitoringDuration,
    required this.workerTypeStatistics,
    required this.recentEvents,
  });

  final int totalTasksScheduled;
  final int totalTasksCompleted;
  final int totalTasksSuccessful;
  final int totalTasksFailed;
  final double averageTaskDuration;
  final int minTaskDuration;
  final int maxTaskDuration;
  final double averageEventDispatchLatency;
  final double tasksPerMinute;
  final double successRate;
  final Duration monitoringDuration;
  final Map<String, WorkerTypeStatistics> workerTypeStatistics;
  final List<PerformanceEvent> recentEvents;

  factory PerformanceStatistics.empty() {
    return PerformanceStatistics(
      totalTasksScheduled: 0,
      totalTasksCompleted: 0,
      totalTasksSuccessful: 0,
      totalTasksFailed: 0,
      averageTaskDuration: 0.0,
      minTaskDuration: 0,
      maxTaskDuration: 0,
      averageEventDispatchLatency: 0.0,
      tasksPerMinute: 0.0,
      successRate: 0.0,
      monitoringDuration: Duration.zero,
      workerTypeStatistics: const {},
      recentEvents: const [],
    );
  }
}

/// Statistics for a specific worker type.
class WorkerTypeStatistics {
  const WorkerTypeStatistics({
    required this.workerType,
    required this.totalTasks,
    required this.successfulTasks,
    required this.totalDuration,
  });

  final String workerType;
  final int totalTasks;
  final int successfulTasks;
  final double totalDuration;

  double get averageDuration =>
      totalTasks == 0 ? 0.0 : totalDuration / totalTasks;
  double get successRate =>
      totalTasks == 0 ? 0.0 : successfulTasks / totalTasks;
}
