import 'dart:collection';

/// Performance monitoring utilities for native_workmanager.
///
/// Provides tools to track and analyze:
/// - Task execution time
/// - Memory usage
/// - Event dispatch latency
/// - Task throughput
/// - Chain execution performance
///
/// Example usage:
/// ```dart
/// final monitor = PerformanceMonitor.instance;
/// monitor.enable();
///
/// // Tasks are automatically tracked when they run
/// await NativeWorkManager.enqueue(...);
///
/// // Get performance statistics
/// final stats = monitor.getStatistics();
/// print('Average task duration: ${stats.averageTaskDuration}ms');
/// ```
class PerformanceMonitor {
  PerformanceMonitor._();

  /// Singleton instance.
  static final PerformanceMonitor instance = PerformanceMonitor._();

  bool _enabled = false;
  final _taskMetrics = <String, TaskMetrics>{};
  final _recentEvents = Queue<PerformanceEvent>();
  final _maxRecentEvents = 100;

  DateTime? _monitoringStartTime;

  /// Enable performance monitoring.
  void enable() {
    _enabled = true;
    _monitoringStartTime = DateTime.now();
  }

  /// Disable performance monitoring.
  void disable() {
    _enabled = false;
  }

  /// Check if monitoring is enabled.
  bool get isEnabled => _enabled;

  /// Record task start.
  void recordTaskStart(String taskId, String workerType) {
    if (!_enabled) return;

    _taskMetrics[taskId] = TaskMetrics(
      taskId: taskId,
      workerType: workerType,
      startTime: DateTime.now(),
    );

    _addEvent(PerformanceEvent(
      type: PerformanceEventType.taskStarted,
      taskId: taskId,
      timestamp: DateTime.now(),
      metadata: {'workerType': workerType},
    ));
  }

  /// Record task completion.
  void recordTaskComplete(String taskId, bool success, {Map<String, dynamic>? resultData}) {
    if (!_enabled) return;

    final metrics = _taskMetrics[taskId];
    if (metrics == null) return;

    metrics.endTime = DateTime.now();
    metrics.success = success;
    metrics.resultData = resultData;

    _addEvent(PerformanceEvent(
      type: success ? PerformanceEventType.taskCompleted : PerformanceEventType.taskFailed,
      taskId: taskId,
      timestamp: DateTime.now(),
      metadata: {
        'duration': metrics.duration.inMilliseconds,
        'success': success,
      },
    ));
  }

  /// Record event dispatch latency.
  void recordEventDispatch(String taskId, Duration latency) {
    if (!_enabled) return;

    _addEvent(PerformanceEvent(
      type: PerformanceEventType.eventDispatched,
      taskId: taskId,
      timestamp: DateTime.now(),
      metadata: {'latency': latency.inMilliseconds},
    ));
  }

  /// Record chain start.
  void recordChainStart(String chainId, int stepCount) {
    if (!_enabled) return;

    _addEvent(PerformanceEvent(
      type: PerformanceEventType.chainStarted,
      taskId: chainId,
      timestamp: DateTime.now(),
      metadata: {'stepCount': stepCount},
    ));
  }

  /// Record chain completion.
  void recordChainComplete(String chainId, bool success, Duration duration) {
    if (!_enabled) return;

    _addEvent(PerformanceEvent(
      type: success ? PerformanceEventType.chainCompleted : PerformanceEventType.chainFailed,
      taskId: chainId,
      timestamp: DateTime.now(),
      metadata: {
        'duration': duration.inMilliseconds,
        'success': success,
      },
    ));
  }

  /// Get performance statistics.
  PerformanceStatistics getStatistics() {
    if (!_enabled) {
      return PerformanceStatistics.empty();
    }

    final completedTasks = _taskMetrics.values.where((m) => m.endTime != null).toList();
    final successfulTasks = completedTasks.where((m) => m.success == true).toList();
    final failedTasks = completedTasks.where((m) => m.success == false).toList();

    final durations = completedTasks.map((m) => m.duration.inMilliseconds).toList();
    final avgDuration = durations.isEmpty ? 0.0 : durations.reduce((a, b) => a + b) / durations.length;
    final minDuration = durations.isEmpty ? 0 : durations.reduce((a, b) => a < b ? a : b);
    final maxDuration = durations.isEmpty ? 0 : durations.reduce((a, b) => a > b ? a : b);

    // Calculate event dispatch latencies
    final eventLatencies = _recentEvents
        .where((e) => e.type == PerformanceEventType.eventDispatched)
        .map((e) => e.metadata['latency'] as int? ?? 0)
        .toList();
    final avgEventLatency = eventLatencies.isEmpty ? 0.0 : eventLatencies.reduce((a, b) => a + b) / eventLatencies.length;

    // Calculate throughput
    final monitoringDuration = _monitoringStartTime == null ? Duration.zero : DateTime.now().difference(_monitoringStartTime!);
    final tasksPerMinute = monitoringDuration.inMinutes == 0 ? 0.0 : completedTasks.length / monitoringDuration.inMinutes;

    // Group by worker type
    final byWorkerType = <String, List<TaskMetrics>>{};
    for (final metrics in completedTasks) {
      byWorkerType.putIfAbsent(metrics.workerType, () => []).add(metrics);
    }

    final workerTypeStats = byWorkerType.map((type, tasks) {
      final taskDurations = tasks.map((t) => t.duration.inMilliseconds).toList();
      final avgTaskDuration = taskDurations.isEmpty ? 0.0 : taskDurations.reduce((a, b) => a + b) / taskDurations.length;
      return MapEntry(type, WorkerTypeStatistics(
        workerType: type,
        totalTasks: tasks.length,
        averageDuration: avgTaskDuration,
        successRate: tasks.where((t) => t.success == true).length / tasks.length,
      ));
    });

    return PerformanceStatistics(
      totalTasksScheduled: _taskMetrics.length,
      totalTasksCompleted: completedTasks.length,
      totalTasksSuccessful: successfulTasks.length,
      totalTasksFailed: failedTasks.length,
      averageTaskDuration: avgDuration,
      minTaskDuration: minDuration,
      maxTaskDuration: maxDuration,
      averageEventDispatchLatency: avgEventLatency,
      tasksPerMinute: tasksPerMinute,
      monitoringDuration: monitoringDuration,
      workerTypeStatistics: workerTypeStats,
      recentEvents: List.from(_recentEvents),
    );
  }

  /// Get metrics for a specific task.
  TaskMetrics? getTaskMetrics(String taskId) {
    return _taskMetrics[taskId];
  }

  /// Get all task metrics.
  List<TaskMetrics> getAllTaskMetrics() {
    return List.from(_taskMetrics.values);
  }

  /// Clear all recorded data.
  void clear() {
    _taskMetrics.clear();
    _recentEvents.clear();
    _monitoringStartTime = DateTime.now();
  }

  void _addEvent(PerformanceEvent event) {
    _recentEvents.add(event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeFirst();
    }
  }
}

/// Metrics for a single task execution.
class TaskMetrics {
  TaskMetrics({
    required this.taskId,
    required this.workerType,
    required this.startTime,
    this.endTime,
    this.success,
    this.resultData,
  });

  final String taskId;
  final String workerType;
  final DateTime startTime;
  DateTime? endTime;
  bool? success;
  Map<String, dynamic>? resultData;

  /// Duration of task execution.
  Duration get duration => endTime == null ? Duration.zero : endTime!.difference(startTime);

  /// Whether the task is still running.
  bool get isRunning => endTime == null;

  @override
  String toString() {
    return 'TaskMetrics(taskId: $taskId, workerType: $workerType, '
        'duration: ${duration.inMilliseconds}ms, success: $success)';
  }
}

/// Performance event types.
enum PerformanceEventType {
  taskStarted,
  taskCompleted,
  taskFailed,
  chainStarted,
  chainCompleted,
  chainFailed,
  eventDispatched,
}

/// A performance event record.
class PerformanceEvent {
  PerformanceEvent({
    required this.type,
    required this.taskId,
    required this.timestamp,
    this.metadata = const {},
  });

  final PerformanceEventType type;
  final String taskId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  @override
  String toString() {
    return 'PerformanceEvent(type: $type, taskId: $taskId, '
        'timestamp: $timestamp, metadata: $metadata)';
  }
}

/// Performance statistics summary.
class PerformanceStatistics {
  PerformanceStatistics({
    required this.totalTasksScheduled,
    required this.totalTasksCompleted,
    required this.totalTasksSuccessful,
    required this.totalTasksFailed,
    required this.averageTaskDuration,
    required this.minTaskDuration,
    required this.maxTaskDuration,
    required this.averageEventDispatchLatency,
    required this.tasksPerMinute,
    required this.monitoringDuration,
    required this.workerTypeStatistics,
    required this.recentEvents,
  });

  factory PerformanceStatistics.empty() {
    return PerformanceStatistics(
      totalTasksScheduled: 0,
      totalTasksCompleted: 0,
      totalTasksSuccessful: 0,
      totalTasksFailed: 0,
      averageTaskDuration: 0,
      minTaskDuration: 0,
      maxTaskDuration: 0,
      averageEventDispatchLatency: 0,
      tasksPerMinute: 0,
      monitoringDuration: Duration.zero,
      workerTypeStatistics: {},
      recentEvents: [],
    );
  }

  final int totalTasksScheduled;
  final int totalTasksCompleted;
  final int totalTasksSuccessful;
  final int totalTasksFailed;
  final double averageTaskDuration;
  final int minTaskDuration;
  final int maxTaskDuration;
  final double averageEventDispatchLatency;
  final double tasksPerMinute;
  final Duration monitoringDuration;
  final Map<String, WorkerTypeStatistics> workerTypeStatistics;
  final List<PerformanceEvent> recentEvents;

  /// Success rate (0.0 - 1.0).
  double get successRate =>
      totalTasksCompleted == 0 ? 0 : totalTasksSuccessful / totalTasksCompleted;

  @override
  String toString() {
    return 'PerformanceStatistics(\n'
        '  Total tasks: $totalTasksScheduled\n'
        '  Completed: $totalTasksCompleted\n'
        '  Successful: $totalTasksSuccessful\n'
        '  Failed: $totalTasksFailed\n'
        '  Success rate: ${(successRate * 100).toStringAsFixed(1)}%\n'
        '  Avg duration: ${averageTaskDuration.toStringAsFixed(1)}ms\n'
        '  Min duration: ${minTaskDuration}ms\n'
        '  Max duration: ${maxTaskDuration}ms\n'
        '  Avg event latency: ${averageEventDispatchLatency.toStringAsFixed(1)}ms\n'
        '  Throughput: ${tasksPerMinute.toStringAsFixed(2)} tasks/min\n'
        '  Monitoring duration: ${monitoringDuration.inSeconds}s\n'
        ')';
  }
}

/// Statistics for a specific worker type.
class WorkerTypeStatistics {
  WorkerTypeStatistics({
    required this.workerType,
    required this.totalTasks,
    required this.averageDuration,
    required this.successRate,
  });

  final String workerType;
  final int totalTasks;
  final double averageDuration;
  final double successRate;

  @override
  String toString() {
    return 'WorkerTypeStatistics(\n'
        '  Type: $workerType\n'
        '  Tasks: $totalTasks\n'
        '  Avg duration: ${averageDuration.toStringAsFixed(1)}ms\n'
        '  Success rate: ${(successRate * 100).toStringAsFixed(1)}%\n'
        ')';
  }
}
