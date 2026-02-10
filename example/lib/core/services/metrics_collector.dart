/// Real-time performance metrics collection service
/// Uses platform channels to get accurate memory, CPU, and battery metrics
library;

import 'dart:async';
import 'package:flutter/services.dart';
import '../models/task_metrics.dart';

/// Service for collecting real performance metrics from platform
class MetricsCollector {
  static const MethodChannel _channel = MethodChannel(
    'dev.brewkits.native_workmanager.example/metrics',
  );

  /// Singleton instance
  static final MetricsCollector _instance = MetricsCollector._internal();
  factory MetricsCollector() => _instance;
  MetricsCollector._internal();

  /// Stream controller for real-time memory updates
  final _memoryController = StreamController<MemoryMetrics>.broadcast();

  /// Stream controller for real-time CPU updates
  final _cpuController = StreamController<CPUMetrics>.broadcast();

  /// Stream controller for real-time battery updates
  final _batteryController = StreamController<BatteryMetrics>.broadcast();

  /// Monitoring timer
  Timer? _monitoringTimer;

  /// Battery monitoring state
  double? _lastBatteryLevel;
  DateTime? _lastBatteryCheck;

  /// Get current memory usage from platform
  Future<MemoryMetrics> getMemoryUsage() async {
    try {
      final result = await _channel.invokeMethod<Map>('getMemoryMetrics');
      if (result == null) {
        throw Exception('Failed to get memory metrics');
      }

      final metrics = MemoryMetrics.fromMap(Map<String, dynamic>.from(result));
      _memoryController.add(metrics);
      return metrics;
    } catch (e) {
      throw Exception('Failed to collect memory metrics: $e');
    }
  }

  /// Get current CPU usage from platform
  Future<CPUMetrics> getCpuUsage() async {
    try {
      final result = await _channel.invokeMethod<Map>('getCpuMetrics');
      if (result == null) {
        throw Exception('Failed to get CPU metrics');
      }

      final metrics = CPUMetrics.fromMap(Map<String, dynamic>.from(result));
      _cpuController.add(metrics);
      return metrics;
    } catch (e) {
      throw Exception('Failed to collect CPU metrics: $e');
    }
  }

  /// Get current battery metrics from platform
  Future<BatteryMetrics> getBatteryMetrics() async {
    try {
      final result = await _channel.invokeMethod<Map>('getBatteryMetrics');
      if (result == null) {
        throw Exception('Failed to get battery metrics');
      }

      final now = DateTime.now();
      final level = (result['level'] as num).toDouble();
      final isCharging = result['isCharging'] as bool;

      // Calculate drain rate if we have previous data
      double drainRate = 0.0;
      Duration monitorDuration = Duration.zero;

      if (_lastBatteryLevel != null &&
          _lastBatteryCheck != null &&
          !isCharging) {
        final timeDiff = now.difference(_lastBatteryCheck!);
        if (timeDiff.inSeconds > 0) {
          final levelDiff = _lastBatteryLevel! - level;
          // Convert to % per hour
          drainRate = (levelDiff / timeDiff.inSeconds) * 3600;
          monitorDuration = timeDiff;
        }
      }

      _lastBatteryLevel = level;
      _lastBatteryCheck = now;

      final metrics = BatteryMetrics(
        level: level,
        drainRate: drainRate,
        monitorDuration: monitorDuration,
        isCharging: isCharging,
        timestamp: now,
      );

      _batteryController.add(metrics);
      return metrics;
    } catch (e) {
      throw Exception('Failed to collect battery metrics: $e');
    }
  }

  /// Start real-time monitoring with specified interval
  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_monitoringTimer != null) {
      return; // Already monitoring
    }

    _monitoringTimer = Timer.periodic(interval, (_) async {
      try {
        await getMemoryUsage();
        await getCpuUsage();
        await getBatteryMetrics();
      } catch (e) {
        // Silently handle errors during monitoring
      }
    });
  }

  /// Stop real-time monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Stream of memory metrics updates
  Stream<MemoryMetrics> get memoryStream => _memoryController.stream;

  /// Stream of CPU metrics updates
  Stream<CPUMetrics> get cpuStream => _cpuController.stream;

  /// Stream of battery metrics updates
  Stream<BatteryMetrics> get batteryStream => _batteryController.stream;

  /// Reset battery monitoring baseline
  void resetBatteryBaseline() {
    _lastBatteryLevel = null;
    _lastBatteryCheck = null;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _memoryController.close();
    _cpuController.close();
    _batteryController.close();
  }
}

/// Utility for measuring task execution with metrics
class TaskMetricsRecorder {
  final MetricsCollector _collector = MetricsCollector();

  /// Record metrics for a task execution
  Future<TaskMetrics> recordTask({
    required String taskId,
    required Future<void> Function() task,
  }) async {
    final startTime = DateTime.now();
    MemoryMetrics? memoryStart;
    MemoryMetrics? memoryEnd;
    CPUMetrics? cpuMetrics;
    BatteryMetrics? batteryMetrics;
    bool success = false;
    String? errorMessage;

    try {
      // Collect start metrics
      memoryStart = await _collector.getMemoryUsage();

      // Execute task
      final stopwatch = Stopwatch()..start();
      await task();
      stopwatch.stop();
      success = true;

      // Collect end metrics
      memoryEnd = await _collector.getMemoryUsage();
      cpuMetrics = await _collector.getCpuUsage();
      batteryMetrics = await _collector.getBatteryMetrics();

      return TaskMetrics(
        taskId: taskId,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        success: success,
        errorMessage: errorMessage,
        memoryStart: memoryStart,
        memoryEnd: memoryEnd,
        cpuMetrics: cpuMetrics,
        batteryMetrics: batteryMetrics,
        timestamp: startTime,
      );
    } catch (e) {
      success = false;
      errorMessage = e.toString();

      // Try to collect end metrics even on error
      try {
        memoryEnd = await _collector.getMemoryUsage();
        cpuMetrics = await _collector.getCpuUsage();
        batteryMetrics = await _collector.getBatteryMetrics();
      } catch (_) {
        // Ignore errors during cleanup
      }

      return TaskMetrics(
        taskId: taskId,
        executionTimeMs: DateTime.now().difference(startTime).inMilliseconds,
        success: success,
        errorMessage: errorMessage,
        memoryStart: memoryStart,
        memoryEnd: memoryEnd,
        cpuMetrics: cpuMetrics,
        batteryMetrics: batteryMetrics,
        timestamp: startTime,
      );
    }
  }

  /// Record metrics for multiple task executions
  Future<List<TaskMetrics>> recordTasks({
    required List<String> taskIds,
    required Future<void> Function(String taskId) taskFactory,
  }) async {
    final results = <TaskMetrics>[];

    for (final taskId in taskIds) {
      final metrics = await recordTask(
        taskId: taskId,
        task: () => taskFactory(taskId),
      );
      results.add(metrics);

      // Small delay between tasks to stabilize metrics
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return results;
  }
}
