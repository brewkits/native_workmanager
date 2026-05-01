import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/src/performance/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;

    setUp(() {
      monitor = PerformanceMonitor.instance;
      monitor.clear();
      monitor.disable();
    });

    test('is initially disabled', () {
      expect(monitor.isEnabled, isFalse);
    });

    test('enable() sets isEnabled to true', () {
      monitor.enable();
      expect(monitor.isEnabled, isTrue);
    });

    test('disable() sets isEnabled to false', () {
      monitor.enable();
      monitor.disable();
      expect(monitor.isEnabled, isFalse);
    });

    test('recordTaskStart does nothing if disabled', () {
      monitor.recordTaskStart('task-1', 'HttpWorker');

      final metrics = monitor.getTaskMetrics('task-1');
      expect(metrics, isNull);
    });

    test('recordTaskStart stores metrics and adds event', () {
      monitor.enable();
      monitor.recordTaskStart('task-1', 'HttpWorker');

      final metrics = monitor.getTaskMetrics('task-1');
      expect(metrics, isNotNull);
      expect(metrics!.taskId, 'task-1');
      expect(metrics.workerType, 'HttpWorker');
      expect(metrics.isRunning, isTrue);

      final stats = monitor.getStatistics();
      expect(stats.recentEvents.length, 1);
      expect(stats.recentEvents.first.type, PerformanceEventType.taskStarted);
      expect(stats.recentEvents.first.taskId, 'task-1');
    });

    test('recordTaskComplete updates metrics and adds event', () async {
      monitor.enable();
      monitor.recordTaskStart('task-2', 'CryptoWorker');

      await Future.delayed(const Duration(milliseconds: 10));

      monitor.recordTaskComplete('task-2', true, resultData: {'hash': 'abc'});

      final metrics = monitor.getTaskMetrics('task-2');
      expect(metrics, isNotNull);
      expect(metrics!.isRunning, isFalse);
      expect(metrics.success, isTrue);
      expect(metrics.resultData, {'hash': 'abc'});
      expect(metrics.duration.inMilliseconds, greaterThanOrEqualTo(10));

      final stats = monitor.getStatistics();
      expect(stats.recentEvents.length, 2); // Started, then Completed
      expect(stats.recentEvents.last.type, PerformanceEventType.taskCompleted);
      expect(stats.recentEvents.last.taskId, 'task-2');
      expect(stats.totalTasksSuccessful, 1);
      expect(stats.totalTasksFailed, 0);
    });

    test('recordTaskComplete for failed task', () {
      monitor.enable();
      monitor.recordTaskStart('task-3', 'HttpWorker');
      monitor.recordTaskComplete('task-3', false);

      final metrics = monitor.getTaskMetrics('task-3');
      expect(metrics!.success, isFalse);

      final stats = monitor.getStatistics();
      expect(stats.recentEvents.last.type, PerformanceEventType.taskFailed);
      expect(stats.totalTasksFailed, 1);
      expect(stats.totalTasksSuccessful, 0);
    });

    test('recordEventDispatch adds event', () {
      monitor.enable();
      monitor.recordEventDispatch('task-4', const Duration(milliseconds: 5));

      final stats = monitor.getStatistics();
      expect(stats.recentEvents.length, 1);
      expect(
          stats.recentEvents.first.type, PerformanceEventType.eventDispatched);
      expect(stats.averageEventDispatchLatency, 5.0);
    });

    test('recordChainStart and recordChainComplete add events', () {
      monitor.enable();
      monitor.recordChainStart('chain-1', 3);
      monitor.recordChainComplete('chain-1', true, const Duration(seconds: 1));

      final stats = monitor.getStatistics();
      expect(stats.recentEvents.length, 2);
      expect(stats.recentEvents.first.type, PerformanceEventType.chainStarted);
      expect(stats.recentEvents.last.type, PerformanceEventType.chainCompleted);
    });

    test('getStatistics handles empty state', () {
      monitor.enable();
      final stats = monitor.getStatistics();
      expect(stats.totalTasksScheduled, 0);
      expect(stats.averageTaskDuration, 0.0);
      expect(stats.tasksPerMinute, 0.0);
      expect(stats.workerTypeStatistics, isEmpty);
    });

    test('getStatistics calculates correctly for multiple tasks', () async {
      monitor.enable();

      // Task 1: success
      monitor.recordTaskStart('t1', 'WorkerA');
      await Future.delayed(const Duration(milliseconds: 10));
      monitor.recordTaskComplete('t1', true);

      // Task 2: fail
      monitor.recordTaskStart('t2', 'WorkerA');
      await Future.delayed(const Duration(milliseconds: 15));
      monitor.recordTaskComplete('t2', false);

      // Task 3: success
      monitor.recordTaskStart('t3', 'WorkerB');
      await Future.delayed(const Duration(milliseconds: 25));
      monitor.recordTaskComplete('t3', true);

      final stats = monitor.getStatistics();
      expect(stats.totalTasksScheduled, 3);
      expect(stats.totalTasksCompleted, 3);
      expect(stats.totalTasksSuccessful, 2);
      expect(stats.totalTasksFailed, 1);
      expect(stats.successRate, 2 / 3);

      expect(stats.averageTaskDuration, greaterThan(0.0));
      expect(stats.minTaskDuration, greaterThanOrEqualTo(10));
      expect(stats.maxTaskDuration, greaterThanOrEqualTo(25));

      final workerAStats = stats.workerTypeStatistics['WorkerA']!;
      expect(workerAStats.totalTasks, 2);
      expect(workerAStats.successRate, 0.5);

      final workerBStats = stats.workerTypeStatistics['WorkerB']!;
      expect(workerBStats.totalTasks, 1);
      expect(workerBStats.successRate, 1.0);
    });

    test('getAllTaskMetrics returns list', () {
      monitor.enable();
      monitor.recordTaskStart('t1', 'W1');
      monitor.recordTaskStart('t2', 'W2');

      final metrics = monitor.getAllTaskMetrics();
      expect(metrics.length, 2);
    });

    test('clear removes all data', () {
      monitor.enable();
      monitor.recordTaskStart('t1', 'W1');
      expect(monitor.getAllTaskMetrics(), isNotEmpty);

      monitor.clear();
      expect(monitor.getAllTaskMetrics(), isEmpty);
      expect(monitor.getStatistics().recentEvents, isEmpty);
    });

    test('TaskMetrics toString', () {
      final metrics =
          TaskMetrics(taskId: 't', workerType: 'w', startTime: DateTime.now());
      metrics.endTime = metrics.startTime.add(const Duration(milliseconds: 50));
      metrics.success = true;

      expect(metrics.toString(), contains('taskId: t'));
      expect(metrics.toString(), contains('workerType: w'));
      expect(metrics.toString(), contains('duration: 50ms'));
      expect(metrics.toString(), contains('success: true'));
    });

    test('PerformanceEvent toString', () {
      final event = PerformanceEvent(
        type: PerformanceEventType.taskStarted,
        taskId: 't1',
        timestamp: DateTime.now(),
        metadata: {'k': 'v'},
      );

      expect(
          event.toString(), contains('type: PerformanceEventType.taskStarted'));
      expect(event.toString(), contains('taskId: t1'));
      expect(event.toString(), contains('metadata: {k: v}'));
    });

    test('PerformanceStatistics toString', () {
      final stats = PerformanceStatistics.empty();
      final str = stats.toString();
      expect(str, contains('Total tasks: 0'));
      expect(str, contains('Success rate: 0.0%'));
    });

    test('WorkerTypeStatistics toString', () {
      final stats = WorkerTypeStatistics(
        workerType: 'W1',
        totalTasks: 10,
        averageDuration: 15.5,
        successRate: 0.9,
      );
      final str = stats.toString();
      expect(str, contains('Type: W1'));
      expect(str, contains('Tasks: 10'));
      expect(str, contains('Avg duration: 15.5ms'));
      expect(str, contains('Success rate: 90.0%'));
    });
  });
}
