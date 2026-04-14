import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Persistence & SQLite Integration Tests', () {
    setUpAll(() async {
      await NativeWorkManager.initialize(debugMode: true);
    });

    testWidgets('Verify task status persistence after enqueue', (
      WidgetTester tester,
    ) async {
      final taskId = 'persist-test-${DateTime.now().millisecondsSinceEpoch}';

      // Enqueue a delayed task. API: TaskTrigger.oneTime([Duration? initialDelay])
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(const Duration(seconds: 5)),
        worker: NativeWorker.httpRequest(
          url: 'https://httpbin.org/delay/2',
          method: HttpMethod.get,
        ),
      );

      // Check status using named parameter: getTaskStatus({required String taskId})
      var status = await NativeWorkManager.getTaskStatus(taskId: taskId);
      expect(
        status,
        isNotNull,
        reason: 'Status should be persisted in SQLite immediately',
      );

      await Future.delayed(const Duration(seconds: 1));
      status = await NativeWorkManager.getTaskStatus(taskId: taskId);
      expect(
        status,
        anyOf([TaskStatus.pending, TaskStatus.running]),
        reason: 'Task should be in a valid persisted state',
      );
    });

    testWidgets('Verify allTasks() retrieves records from SQLite', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tasks = ['t1-$now', 't2-$now', 't3-$now'];

      for (final id in tasks) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: TaskTrigger.oneTime(),
          worker: NativeWorker.httpRequest(url: 'https://httpbin.org/get'),
        );
      }

      // Retrieve all tasks
      final allRecords = await NativeWorkManager.allTasks();

      final retrievedIds = allRecords.map((e) => e.taskId).toSet();
      for (final id in tasks) {
        expect(
          retrievedIds.contains(id),
          isTrue,
          reason: 'Task $id should be found in allTasks()',
        );
      }
    });

    testWidgets('Verify task chain persistence', (WidgetTester tester) async {
      final chainName =
          'chain-persist-${DateTime.now().millisecondsSinceEpoch}';

      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'step1-$chainName',
              worker: NativeWorker.httpRequest(url: 'https://httpbin.org/get'),
            ),
          )
          .then(
            TaskRequest(
              id: 'step2-$chainName',
              worker: NativeWorker.httpRequest(url: 'https://httpbin.org/get'),
            ),
          )
          .named(chainName)
          .enqueue();

      // Check if chain steps are visible in allTasks
      final allRecords = await NativeWorkManager.allTasks();
      final chainTasks = allRecords.where((e) => e.taskId.contains(chainName));

      expect(
        chainTasks.isNotEmpty,
        isTrue,
        reason: 'Chain steps should be persisted as individual tasks',
      );
    });
  });
}
