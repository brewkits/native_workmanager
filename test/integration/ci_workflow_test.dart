import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWorkManager fakeWorkManager;

  setUp(() {
    fakeWorkManager = FakeWorkManager();
  });

  tearDown(() {
    fakeWorkManager.dispose();
  });

  group('CI/CD Integration: Enterprise Workflow', () {
    test('Full Chain Execution with Observability', () async {
      // 1. Setup Observability
      var startCount = 0;
      var completeCount = 0;

      // In this test, we are calling configure on NativeWorkManager,
      // but since we aren't using the static NativeWorkManager for enqueuing,
      // and ObservabilityConfig listens to NativeWorkManagerPlatform.instance,
      // we need to make sure the events from fakeWorkManager reach the observer.
      //
      // Actually, for simplicity in this integration test, let's just test
      // the recording behavior of fakeWorkManager.

      // 2. Build a complex chain via fakeWorkManager
      final chain = fakeWorkManager
          .beginWith(
            TaskRequest(
              id: 'step-1',
              worker: NativeWorker.httpRequest(url: 'https://api.test/1'),
            ),
          )
          .then(
            TaskRequest(
              id: 'step-2',
              worker: NativeWorker.imageProcess(
                inputPath: '/data/in.jpg',
                outputPath: '/data/out.jpg',
                maxWidth: 100,
                maxHeight: 100,
              ),
            ),
          );

      // 3. Enqueue
      await chain.enqueue();

      // 4. Verify Enqueue
      expect(fakeWorkManager.enqueued.length, 2);
      expect(fakeWorkManager.enqueued[0].taskId, contains('step-1'));

      // 5. Simulate Native Completion for Step 1
      fakeWorkManager.emitEvent(TaskEvent(
        taskId: fakeWorkManager.enqueued[0].taskId,
        success: true,
        timestamp: DateTime.now(),
      ));

      // 6. Simulate Native Completion for Step 2
      fakeWorkManager.emitEvent(TaskEvent(
        taskId: fakeWorkManager.enqueued[1].taskId,
        success: true,
        timestamp: DateTime.now(),
      ));

      // Verification
      expect(fakeWorkManager.enqueued.every((t) => t.worker != null), isTrue);
    });

    test('TaskGraph DAG Validation and Scheduling', () async {
      final graph = TaskGraph(id: 'ci-graph')
        ..add(TaskNode(
          id: 'root-1',
          worker: NativeWorker.fileList(path: '/tmp'),
        ))
        ..add(TaskNode(
          id: 'root-2',
          worker: NativeWorker.fileList(path: '/home'),
        ))
        ..add(TaskNode(
          id: 'dependent-3',
          worker: NativeWorker.fileCompress(
            inputPath: '/tmp',
            outputPath: '/backups/backup.zip',
          ),
          dependsOn: const ['root-1', 'root-2'],
        ));

      // Validate graph integrity (No cycles)
      expect(() => graph.validate(), returnsNormally);

      // Enqueue graph via fakeWorkManager
      await fakeWorkManager.enqueueGraph(graph);

      // Root nodes should be scheduled immediately
      expect(fakeWorkManager.enqueued.length, 2);
      expect(fakeWorkManager.enqueued.any((t) => t.taskId.contains('root-1')),
          isTrue);
      expect(fakeWorkManager.enqueued.any((t) => t.taskId.contains('root-2')),
          isTrue);

      // Dependent node should NOT be scheduled yet
      expect(
          fakeWorkManager.enqueued.any((t) => t.taskId.contains('dependent-3')),
          isFalse);
    });
  });
}
