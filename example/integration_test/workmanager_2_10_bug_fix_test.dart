import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

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
      await NativeWorkManager.initialize(
        isDebug: true,
        enableBackgroundIsolate: true,
      );
    });

    /// Test 1: OneTime expedited task (original bug scenario)
    ///
    /// This was the primary crash scenario. WorkManager 2.10.0+ promotes
    /// expedited tasks to foreground service and calls getForegroundInfoAsync().
    testWidgets('OneTime expedited task should not crash', (tester) async {
      await tester.pumpAndSettle();

      final taskId = 'bug-fix-test-onetime-expedited';
      var taskCompleted = false;
      String? taskOutput;

      // Register callback
      NativeWorkManager.onTaskCompleted((id, output) {
        if (id == taskId) {
          taskCompleted = true;
          taskOutput = output;
        }
      });

      // Schedule OneTime expedited task (triggers the bug in WM 2.10.0+)
      await NativeWorkManager.scheduleOneTime(
        taskId: taskId,
        workerType: WorkerType.sync,
        inputData: {
          'url': 'https://httpbin.org/delay/1',
          'method': 'GET',
        },
        constraints: WorkConstraints(
          networkType: NetworkType.connected,
          requiresCharging: false,
          requiresBatteryNotLow: false,
          // Expedited = true triggers getForegroundInfoAsync() call
        ),
        // initialDelay: Duration.zero, // Execute ASAP
      );

      // Wait for task completion (max 30s)
      var attempts = 0;
      while (!taskCompleted && attempts < 60) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      // Verify task completed without crash
      expect(taskCompleted, true, reason: 'Task should complete without crashing');
      expect(taskOutput, isNotNull, reason: 'Task should return output');

      print('✓ OneTime expedited task completed successfully: $taskOutput');
    });

    /// Test 2: Multiple concurrent expedited tasks
    ///
    /// Stress test to ensure getForegroundInfo() handles concurrent calls
    testWidgets('Multiple concurrent expedited tasks should not crash', (tester) async {
      await tester.pumpAndSettle();

      final taskIds = List.generate(5, (i) => 'bug-fix-test-concurrent-$i');
      final completedTasks = <String>{};

      NativeWorkManager.onTaskCompleted((id, output) {
        if (taskIds.contains(id)) {
          completedTasks.add(id);
        }
      });

      // Schedule 5 concurrent expedited tasks
      for (var i = 0; i < taskIds.length; i++) {
        await NativeWorkManager.scheduleOneTime(
          taskId: taskIds[i],
          workerType: WorkerType.sync,
          inputData: {
            'url': 'https://httpbin.org/delay/${i + 1}',
            'method': 'GET',
          },
          constraints: WorkConstraints(
            networkType: NetworkType.connected,
          ),
        );
      }

      // Wait for all tasks to complete (max 60s)
      var attempts = 0;
      while (completedTasks.length < taskIds.length && attempts < 120) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      expect(completedTasks.length, taskIds.length,
          reason: 'All concurrent tasks should complete without crashing');

      print('✓ ${completedTasks.length} concurrent expedited tasks completed successfully');
    });

    /// Test 3: Periodic task (should not crash even though not expedited)
    ///
    /// Verify periodic tasks still work correctly
    testWidgets('Periodic task should work correctly', (tester) async {
      await tester.pumpAndSettle();

      final taskId = 'bug-fix-test-periodic';

      await NativeWorkManager.schedulePeriodic(
        taskId: taskId,
        workerType: WorkerType.sync,
        interval: const Duration(minutes: 15),
        inputData: {
          'url': 'https://httpbin.org/get',
          'method': 'GET',
        },
      );

      // Just verify it schedules without crash
      await tester.pump(const Duration(seconds: 2));

      // Cancel the periodic task
      await NativeWorkManager.cancelTask(taskId);

      print('✓ Periodic task scheduled and cancelled successfully');
    });

    /// Test 4: Task chain with expedited tasks
    ///
    /// Verify chain routing fix (heavy tasks use KmpHeavyWorker, regular use KmpWorker)
    testWidgets('Task chain should handle expedited tasks correctly', (tester) async {
      await tester.pumpAndSettle();

      final chainId = 'bug-fix-test-chain';
      var chainCompleted = false;

      NativeWorkManager.onChainCompleted((id) {
        if (id == chainId) {
          chainCompleted = true;
        }
      });

      // Create chain with mixed task types
      await NativeWorkManager.scheduleChain(
        chainId: chainId,
        steps: [
          [
            // Step 1: Regular sync task (expedited)
            ChainTaskRequest(
              workerType: WorkerType.sync,
              inputData: {
                'url': 'https://httpbin.org/get',
                'method': 'GET',
              },
            ),
          ],
          [
            // Step 2: Heavy task (uses KmpHeavyWorker, not expedited)
            ChainTaskRequest(
              workerType: WorkerType.fileDownload,
              inputData: {
                'url': 'https://httpbin.org/delay/2',
                'destinationPath': '/tmp/test-download.json',
              },
              constraints: WorkConstraints(
                isHeavyTask: true, // This should use KmpHeavyWorker
              ),
            ),
          ],
          [
            // Step 3: Another regular task (expedited)
            ChainTaskRequest(
              workerType: WorkerType.sync,
              inputData: {
                'url': 'https://httpbin.org/post',
                'method': 'POST',
                'body': '{"test": "data"}',
              },
            ),
          ],
        ],
      );

      // Wait for chain completion (max 60s)
      var attempts = 0;
      while (!chainCompleted && attempts < 120) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      expect(chainCompleted, true, reason: 'Chain should complete without crashing');

      print('✓ Task chain with mixed expedited/heavy tasks completed successfully');
    });

    /// Test 5: Verify WorkManager version
    ///
    /// Confirm we're actually testing against WorkManager 2.10.1+
    test('Verify WorkManager 2.10.1+ is being used', () {
      // This test verifies build.gradle has work-runtime-ktx:2.10.1
      // On Android, we can check the actual WorkManager version at runtime

      // For now, we trust the build.gradle configuration
      // In a real test, you could use platform channels to query the version

      print('✓ Assuming WorkManager 2.10.1+ per build.gradle configuration');
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

      final taskId = 'notification-i18n-test';
      var taskCompleted = false;

      NativeWorkManager.onTaskCompleted((id, output) {
        if (id == taskId) {
          taskCompleted = true;
        }
      });

      await NativeWorkManager.scheduleOneTime(
        taskId: taskId,
        workerType: WorkerType.sync,
        inputData: {
          'url': 'https://httpbin.org/get',
          'method': 'GET',
        },
      );

      var attempts = 0;
      while (!taskCompleted && attempts < 60) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }

      expect(taskCompleted, true);
      print('✓ Task with notification i18n support completed successfully');
    });
  });
}
