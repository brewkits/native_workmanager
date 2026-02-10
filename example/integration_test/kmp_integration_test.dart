import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('KMP WorkManager v2.1.2 Integration Tests', () {
    setUpAll(() async {
      // Initialize WorkManager once for all tests
      await NativeWorkManager.initialize(
        dartWorkers: {
          'testTask': (Map<String, dynamic>? input) async {
            developer.log('✅ Test task executed with input: $input');
            return true;
          },
          'task1': (input) async {
            developer.log('✅ Chain task 1 executed');
            return true;
          },
          'task2': (input) async {
            developer.log('✅ Chain task 2 executed');
            return true;
          },
        },
      );
    });

    testWidgets('Can enqueue a simple one-time task', (
      WidgetTester tester,
    ) async {
      // Enqueue a task using DartWorker with kmpworkmanager v2.1.2
      final result = await NativeWorkManager.enqueue(
        taskId: 'test_kmp_integration',
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'testTask',
          input: {'test': 'kmp_v2.1.2'},
        ),
      );

      expect(result, ScheduleResult.accepted);
      developer.log(
        '✅ KMP Integration Test: Task enqueued successfully via kmpworkmanager',
      );
    });

    testWidgets('Can cancel a task', (WidgetTester tester) async {
      // Enqueue a task first
      await NativeWorkManager.enqueue(
        taskId: 'test_task_to_cancel',
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'testTask'),
      );

      // Cancel the task
      await NativeWorkManager.cancel('test_task_to_cancel');

      developer.log('✅ KMP Integration Test: Task cancelled successfully');
    });

    testWidgets('Can use native HTTP worker', (WidgetTester tester) async {
      // Test native worker (runs without Flutter Engine overhead)
      final result = await NativeWorkManager.enqueue(
        taskId: 'test_http_worker',
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
          method: HttpMethod.get,
        ),
      );

      expect(result, ScheduleResult.accepted);
      developer.log(
        '✅ KMP Integration Test: Native HTTP worker enqueued (zero Flutter overhead)',
      );
    });
  });
}
