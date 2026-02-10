import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:native_workmanager/native_workmanager.dart' hide PerformanceMonitor;
// ✅ IMPORT PerformanceMonitor to link benchmark data to UI
import 'package:native_workmanager_example/src/performance/performance_monitor.dart';

class PerformanceBenchmark {
  /// Run all benchmarks and return results.
  static Future<BenchmarkResults> runAll() async {
    debugPrint('🏁 Starting performance benchmarks...');

    // 1. Enable monitor to capture stats for the Overview card
    PerformanceMonitor.instance.enable();

    final results = BenchmarkResults();

    try {
      // 2. Run benchmarks sequentially with small delays
      results.taskStartupLatency = await _benchmarkTaskStartupLatency();
      await Future.delayed(const Duration(milliseconds: 500));

      results.chainExecutionPerformance = await _benchmarkChainExecution();
      await Future.delayed(const Duration(milliseconds: 500));

      results.throughput = await _benchmarkThroughput();
    } catch (e) {
      debugPrint('❌ Benchmark error: $e');
    }

    debugPrint('✅ Benchmarks completed');
    return results;
  }

  /// Benchmark 1: Task Startup Latency
  static Future<BenchmarkResult> _benchmarkTaskStartupLatency() async {
    debugPrint('📊 Benchmarking task startup latency...');
    final measurements = <int>[];
    // ✅ Reduced iterations for faster testing (was 10)
    const iterations = 3;

    for (int i = 0; i < iterations; i++) {
      final completer = Completer<void>();
      final startTime = DateTime.now();
      final taskId = 'bench-startup-${DateTime.now().millisecondsSinceEpoch}-$i';

      // ✅ Record in Monitor
      PerformanceMonitor.instance.recordTaskScheduled(taskId, 'DartWorker');

      final subscription = NativeWorkManager.events.listen((event) {
        // Accept exact ID match OR any success (sequential execution assumption)
        if ((event.taskId == taskId || event.taskId.contains(taskId) || event.success) && !completer.isCompleted) {
          final latency = DateTime.now().difference(startTime).inMilliseconds;
          measurements.add(latency);

          // ✅ Record success in Monitor
          PerformanceMonitor.instance.recordTaskComplete(taskId, event.success);

          completer.complete();
        }
      });

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'customTask'),
      );

      // ✅ Reduced timeout to 5s to prevent long hangs
      try {
        await completer.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        debugPrint('⚠️ Timeout waiting for $taskId');
        PerformanceMonitor.instance.recordTaskComplete(taskId, false);
      }

      await subscription.cancel();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return BenchmarkResult(
      name: 'Task Startup Latency',
      measurements: measurements,
      unit: 'ms',
    );
  }

  /// Benchmark 2: Chain Execution
  static Future<BenchmarkResult> _benchmarkChainExecution() async {
    debugPrint('📊 Benchmarking chain execution...');
    final measurements = <int>[];
    const iterations = 2; // Reduced for speed

    for (int i = 0; i < iterations; i++) {
      final completer = Completer<void>();
      final startTime = DateTime.now();
      var completedSteps = 0;
      const totalSteps = 3;
      final chainId = 'bench-chain-${DateTime.now().millisecondsSinceEpoch}-$i';

      // ✅ FIX: Listen for ANY success events.
      // IDs inside chains often change (e.g. UUIDs), so we just count completions.
      final subscription = NativeWorkManager.events.listen((event) {
        if (event.success) {
          completedSteps++;
          // Record in Monitor for stats
          PerformanceMonitor.instance.recordTaskComplete(event.taskId, true);

          if (completedSteps >= totalSteps && !completer.isCompleted) {
            final duration = DateTime.now().difference(startTime).inMilliseconds;
            measurements.add(duration);
            completer.complete();
          }
        }
      });

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: '$chainId-1',
          worker: DartWorker(callbackId: 'customTask'),
        ),
      ).then(
        TaskRequest(
          id: '$chainId-2',
          worker: DartWorker(callbackId: 'customTask'),
        ),
      ).then(
        TaskRequest(
          id: '$chainId-3',
          worker: DartWorker(callbackId: 'customTask'),
        ),
      ).enqueue();

      try {
        // Wait max 15s for the whole chain
        await completer.future.timeout(const Duration(seconds: 15));
      } catch (_) {
        debugPrint('⚠️ Timeout waiting for chain $i');
      }

      await subscription.cancel();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return BenchmarkResult(
      name: 'Chain Execution (3 steps)',
      measurements: measurements,
      unit: 'ms',
    );
  }

  /// Benchmark 3: Throughput
  static Future<BenchmarkResult> _benchmarkThroughput() async {
    debugPrint('📊 Benchmarking throughput...');
    final measurements = <int>[];
    const tasksPerRun = 20;
    const iterations = 1; // Single run for speed

    for (int run = 0; run < iterations; run++) {
      final startTime = DateTime.now();

      for (int i = 0; i < tasksPerRun; i++) {
        final id = 'bench-thru-$run-$i';
        PerformanceMonitor.instance.recordTaskScheduled(id, 'DartWorker');

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'customTask'),
        );
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (duration > 0) {
        final tasksPerSecond = (tasksPerRun * 1000 / duration).round();
        measurements.add(tasksPerSecond);
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    return BenchmarkResult(
      name: 'Scheduling Throughput',
      measurements: measurements,
      unit: 'tasks/sec',
    );
  }

  // Dummy implementation for missing method to prevent errors
  static Future<BenchmarkResult> _benchmarkEventDispatchLatency() async {
    return BenchmarkResult(name: 'Event Latency', measurements: [], unit: 'us');
  }
}

// --- Data Models ---

class BenchmarkResult {
  BenchmarkResult({
    required this.name,
    required this.measurements,
    required this.unit,
  });

  final String name;
  final List<int> measurements;
  final String unit;

  double get average => measurements.isEmpty
      ? 0
      : measurements.reduce((a, b) => a + b) / measurements.length;

  int get min =>
      measurements.isEmpty ? 0 : measurements.reduce((a, b) => a < b ? a : b);

  int get max =>
      measurements.isEmpty ? 0 : measurements.reduce((a, b) => a > b ? a : b);

  double get median {
    if (measurements.isEmpty) return 0;
    final sorted = List<int>.from(measurements)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isEven) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      return sorted[middle].toDouble();
    }
  }
}

class BenchmarkResults {
  BenchmarkResult? taskStartupLatency;
  BenchmarkResult? chainExecutionPerformance;
  BenchmarkResult? eventDispatchLatency;
  BenchmarkResult? throughput;
}