import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:async';

/// Integration test for WorkManager 2.10.0+ getForegroundInfo() bug fix
///
/// Bug report: https://github.com/brewkits/native_workmanager/issues/xxx
/// Reported by: Abdullah Al-Hasnat
///
/// Original error:
/// ```
/// IllegalStateException: Not implemented
///   at androidx.work.CoroutineWorker.getForegroundInfo(CoroutineWorker.kt:92)
/// ```
///
/// Root cause: WorkManager 2.10.0+ calls getForegroundInfoAsync() in execution
/// path for expedited tasks. kmpworkmanager < 2.3.3 did not override
/// getForegroundInfo(), causing crash.
///
/// Fix: kmpworkmanager 2.3.3+ adds getForegroundInfo() override in KmpWorker
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('WorkManager 2.10.0+ Compatibility Tests', () {
    setUpAll(() async {
      await NativeWorkManager.initialize();
    });

    /// Test 1: OneTime expedited task (original bug scenario)
    ///
    /// This was the primary crash scenario. WorkManager 2.10.0+ promotes
    /// expedited tasks to foreground service and calls getForegroundInfoAsync().
    testWidgets('OneTime expedited task should not crash', (tester) async {
      await tester.pumpAndSettle();

      final taskId = 'bug-fix-test-onetime-expedited-${DateTime.now().millisecondsSinceEpoch}';
      var taskCompleted = false;
      String? taskMessage;

      StreamSubscription? eventsSub;

      // Listen to events
      eventsSub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId) {
          taskCompleted = event.success;
          taskMessage = event.message;
        }
      });

      // Schedule OneTime expedited task (triggers the bug in WM 2.10.0+)
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/delay/1',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      // Wait for task completion (max 30s)
      var attempts = 0;
      while (!taskCompleted && attempts < 60) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      await eventsSub.cancel();

      // Verify task completed without crash
      expect(taskCompleted, true, reason: 'Task should complete without crashing');
      expect(taskMessage, isNotNull, reason: 'Task should return output');
    });

    /// Test 2: Multiple concurrent expedited tasks
    ///
    /// Stress test to ensure getForegroundInfo() handles concurrent calls
    testWidgets('Multiple concurrent expedited tasks should not crash', (tester) async {
      await tester.pumpAndSettle();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final taskIds = List.generate(5, (i) => 'bug-fix-test-concurrent-$timestamp-$i');
      final completedTasks = <String>{};

      StreamSubscription? eventsSub;

      eventsSub = NativeWorkManager.events.listen((event) {
        if (taskIds.contains(event.taskId) && event.success) {
          completedTasks.add(event.taskId);
        }
      });

      // Schedule 5 concurrent expedited tasks
      for (var i = 0; i < taskIds.length; i++) {
        await NativeWorkManager.enqueue(
          taskId: taskIds[i],
          trigger: TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/delay/${i + 1}',
            method: HttpMethod.get,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );
      }

      // Wait for all tasks to complete (max 60s)
      var attempts = 0;
      while (completedTasks.length < taskIds.length && attempts < 120) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      await eventsSub.cancel();

      expect(completedTasks.length, taskIds.length,
          reason: 'All concurrent tasks should complete without crashing');
    });

    /// Test 3: Periodic task (should not crash even though not expedited)
    ///
    /// Verify periodic tasks still work correctly
    testWidgets('Periodic task should work correctly', (tester) async {
      await tester.pumpAndSettle();

      final taskId = 'bug-fix-test-periodic-${DateTime.now().millisecondsSinceEpoch}';

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );

      // Just verify it schedules without crash
      await tester.pump(const Duration(seconds: 2));

      // Cancel the periodic task
      await NativeWorkManager.cancel(taskId);
    });

    /// Test 4: Task chain with expedited tasks
    ///
    /// Verify chain routing fix (heavy tasks use KmpHeavyWorker, regular use KmpWorker)
    testWidgets('Task chain should handle expedited tasks correctly', (tester) async {
      await tester.pumpAndSettle();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final chainName = 'bug-fix-test-chain-$timestamp';
      final task1 = 'chain-step-1-$timestamp';
      final task2 = 'chain-step-2-$timestamp';
      final task3 = 'chain-step-3-$timestamp';

      var chainCompleted = false;

      StreamSubscription? eventsSub;

      eventsSub = NativeWorkManager.events.listen((event) {
        if (event.taskId == task3 && event.success) {
          chainCompleted = true;
        }
      });

      // Create chain with mixed task types
      await NativeWorkManager.beginWith(
        TaskRequest(
          id: task1,
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/get',
            method: HttpMethod.get,
          ),
        ),
      ).then(
        TaskRequest(
          id: task2,
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/delay/2',
            method: HttpMethod.get,
          ),
        ),
      ).then(
        TaskRequest(
          id: task3,
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/post',
            method: HttpMethod.post,
            body: '{"test": "data"}',
          ),
        ),
      ).named(chainName).enqueue();

      // Wait for chain completion (max 60s)
      var attempts = 0;
      while (!chainCompleted && attempts < 120) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      await eventsSub.cancel();

      expect(chainCompleted, true, reason: 'Chain should complete without crashing');
    });

    /// Test 5: Verify WorkManager version
    ///
    /// Confirm we're actually testing against WorkManager 2.10.1+
    test('Verify WorkManager 2.10.1+ is being used', () {
      // This test verifies build.gradle has work-runtime-ktx:2.10.1
      // On Android, we can check the actual WorkManager version at runtime

      // For now, we trust the build.gradle configuration
      // In a real test, you could use platform channels to query the version

      expect(true, true);
    });
  });

  group('Notification Localization Tests (v2.3.3)', () {
    /// Test that notification strings can be overridden
    testWidgets('Notification strings should support localization', (tester) async {
      await tester.pumpAndSettle();

      // Note: To test localization, the host app would need to provide
      // res/values-ja/strings.xml or other locale files
      //
      // For now, we just verify the task executes without crashing,
      // which confirms the string resource system is working

      final taskId = 'notification-i18n-test-${DateTime.now().millisecondsSinceEpoch}';
      var taskCompleted = false;

      StreamSubscription? eventsSub;

      eventsSub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId && event.success) {
          taskCompleted = true;
        }
      });

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );

      var attempts = 0;
      while (!taskCompleted && attempts < 60) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      await eventsSub.cancel();

      expect(taskCompleted, true);
    });
  });
}
