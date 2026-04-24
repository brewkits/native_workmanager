// ignore_for_file: avoid_print
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

String _id(String name) =>
    'sst_${name}_${DateTime.now().millisecondsSinceEpoch}';

class TaskEventTracker {
  final Map<String, Completer<TaskEvent>> _completers = {};
  late StreamSubscription<TaskEvent> _sub;

  void start() {
    _sub = NativeWorkManager.events.listen((event) {
      final completer = _completers[event.taskId];
      if (completer != null && !completer.isCompleted && !event.isStarted) {
        print(
          '[Tracker] Received terminal event for ${event.taskId} (success: ${event.success})',
        );
        completer.complete(event);
      }
    });
  }

  Future<TaskEvent> waitFor(
    String taskId, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    final completer = _completers.putIfAbsent(
      taskId,
      () => Completer<TaskEvent>(),
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        print('[Tracker] Timeout waiting for $taskId');
        throw TimeoutException('Task $taskId did not complete in time');
      },
    );
  }

  void stop() {
    _sub.cancel();
  }
}

// ──────────────────────────────────────────────────────────────
// Top-level DartWorker callbacks
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _stressWorker(Map<String, dynamic>? input) async {
  final int index = input?['index'] ?? 0;
  print('[StressWorker] index=$index starting...');
  await Future.delayed(const Duration(milliseconds: 100));
  return true;
}

@pragma('vm:entry-point')
Future<bool> _mediaProcessor(Map<String, dynamic>? input) async {
  print('[MediaProcessor] input=$input');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _largePayloadWorker(Map<String, dynamic>? input) async {
  final data = input?['data'] as String?;
  final len = data?.length ?? 0;
  print('[LargePayloadWorker] received data length: $len');
  return len > 0;
}

// ──────────────────────────────────────────────────────────────
// main
// ──────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final tracker = TaskEventTracker();

  setUpAll(() async {
    await NativeWorkManager.initialize(
      dartWorkers: {
        'stress_worker': _stressWorker,
        'media_processor': _mediaProcessor,
        'large_payload': _largePayloadWorker,
      },
    );
    tracker.start();
  });

  tearDownAll(() {
    tracker.stop();
  });

  group('Stress Tests', () {
    testWidgets(
      'Massive Enqueue: 30 tasks mixed (Native + Dart)',
      (tester) async {
        const taskCount = 30;
        final ids = List.generate(taskCount, (i) => _id('massive_$i'));

        print('Enqueuing $taskCount tasks with delays...');
        for (int i = 0; i < taskCount; i++) {
          // Mix Native and Dart workers to test resource sharing
          final isDart = i % 2 == 0;
          final worker = isDart
              ? DartWorker(callbackId: 'stress_worker', input: {'index': i})
              : NativeWorker.httpRequest(url: 'https://httpbin.org/get');

          await NativeWorkManager.enqueue(
            taskId: ids[i],
            trigger: TaskTrigger.oneTime(),
            worker: worker,
          );

          // Staggering more to avoid bridge congestion
          await Future.delayed(const Duration(milliseconds: 200));
        }

        print('Waiting for all $taskCount tasks to complete...');
        int completedCount = 0;
        for (final id in ids) {
          try {
            final event = await tracker.waitFor(
              id,
              timeout: const Duration(seconds: 120),
            );
            if (event.success) completedCount++;
          } catch (_) {}
        }

        print('Completed: $completedCount / $taskCount');
        expect(
          completedCount,
          greaterThanOrEqualTo(24), // 80%
          reason:
              'At least 80% of tasks should complete with staggered scheduling',
        );
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );

    testWidgets('Rapid fire enqueue 50 tasks (Zero Delay)', (tester) async {
      const count = 50;
      final futures = <Future<TaskHandler>>[];

      print('[Stress] Starting rapid fire enqueue of $count tasks...');
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < count; i++) {
        futures.add(
          NativeWorkManager.enqueue(
            taskId: _id('rapid_$i'),
            trigger: TaskTrigger.oneTime(),
            worker: DartWorker(callbackId: 'stress_worker'),
          ),
        );
      }

      final results = await Future.wait(futures);
      stopwatch.stop();

      final acceptedCount = results
          .where((r) => r.scheduleResult == ScheduleResult.accepted)
          .length;

      print(
        '[Stress] Enqueued $count tasks in ${stopwatch.elapsedMilliseconds}ms '
        '($acceptedCount accepted)',
      );

      expect(acceptedCount, count, reason: 'All tasks should be accepted');
    });

    testWidgets('Rapid-fire Enqueue/Cancel loop', (tester) async {
      const iterations = 10;
      int successCount = 0;

      for (int i = 0; i < iterations; i++) {
        final taskId = _id('rapid_$i');
        await NativeWorkManager.enqueue(
          taskId: taskId,
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'stress_worker'),
        );
        await NativeWorkManager.cancel(taskId: taskId);
        final result = await NativeWorkManager.enqueue(
          taskId: taskId,
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'stress_worker'),
        );
        if (result.scheduleResult == ScheduleResult.accepted) successCount++;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(successCount, equals(iterations));
    });

    testWidgets('Large Data Payload: 8KB input map', (tester) async {
      final taskId = _id('large_payload');
      final largeString = 'A' * 8192;

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'large_payload',
          input: {'data': largeString},
        ),
      );

      final event = await tracker.waitFor(taskId);
      expect(event.success, isTrue, reason: 'Worker should handle 8KB payload');
    });
  });

  group('System Tests (End-to-End)', () {
    testWidgets('Data Flow Pipeline: Pass output between tasks', (
      tester,
    ) async {
      final chainName = 'flow_${DateTime.now().millisecondsSinceEpoch}';
      final idA = 'gen_$chainName';
      final idB = 'cons_$chainName';

      await NativeWorkManager.beginWith(
            TaskRequest(
              id: idA,
              worker: DartWorker(
                callbackId: 'stress_worker',
                input: {'val': 'hello'},
              ),
            ),
          )
          .then(
            TaskRequest(
              id: idB,
              worker: DartWorker(
                callbackId: 'media_processor',
                input: {'received': '{{$idA.val}}'},
              ),
            ),
          )
          .named(chainName)
          .enqueue();

      final finalEvent = await tracker.waitFor(
        idB,
        timeout: const Duration(seconds: 120),
      );
      expect(
        finalEvent.success,
        isTrue,
        reason: 'Data flow between tasks should work',
      );
    });

    testWidgets(
      'Media Pipeline: Download -> Compress -> Encrypt -> Upload',
      (tester) async {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final chainName = 'media_$ts';
        final idDl = 'dl_$ts';
        final idCp = 'cp_$ts';
        final idEn = 'en_$ts';
        final idUp = 'up_$ts';

        await NativeWorkManager.beginWith(
              TaskRequest(
                id: idDl,
                worker: NativeWorker.httpDownload(
                  url: 'https://httpbin.org/image/png',
                  savePath: '/tmp/test_image.png',
                ),
              ),
            )
            .then(
              TaskRequest(
                id: idCp,
                worker: NativeWorker.fileCompress(
                  inputPath: '{{$idDl.savePath}}',
                  outputPath: '/tmp/test_image_compressed.zip',
                ),
              ),
            )
            .then(
              TaskRequest(
                id: idEn,
                worker: NativeWorker.cryptoEncrypt(
                  inputPath: '{{$idCp.outputPath}}',
                  password: 'securePassword123',
                  outputPath: '/tmp/test_image.enc',
                ),
              ),
            )
            .then(
              TaskRequest(
                id: idUp,
                worker: NativeWorker.httpUpload(
                  url: 'https://httpbin.org/post',
                  filePath: '{{$idEn.outputPath}}',
                ),
              ),
            )
            .named(chainName)
            .enqueue();

        final finalEvent = await tracker.waitFor(
          idUp,
          timeout: const Duration(seconds: 180),
        );
        expect(
          finalEvent.success,
          isTrue,
          reason: 'Chain should execute to completion',
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    testWidgets(
      'Complex DAG: Parallel Processing with Fan-in',
      (tester) async {
        final graphId = 'dag_${DateTime.now().millisecondsSinceEpoch}';

        final graph = TaskGraph(id: graphId)
          ..add(
            TaskNode(
              id: 'fetch_config',
              worker: NativeWorker.httpRequest(
                url: 'https://httpbin.org/get',
                method: HttpMethod.get,
              ),
            ),
          )
          ..add(
            TaskNode(
              id: 'process_a',
              worker: DartWorker(
                callbackId: 'media_processor',
                input: {'part': 'A'},
              ),
              dependsOn: ['fetch_config'],
            ),
          )
          ..add(
            TaskNode(
              id: 'process_b',
              worker: DartWorker(
                callbackId: 'media_processor',
                input: {'part': 'B'},
              ),
              dependsOn: ['fetch_config'],
            ),
          )
          ..add(
            TaskNode(
              id: 'final_merge',
              worker: DartWorker(
                callbackId: 'media_processor',
                input: {'action': 'merge'},
              ),
              dependsOn: ['process_a', 'process_b'],
            ),
          );

        final execution = await NativeWorkManager.enqueueGraph(graph);
        final graphResult = await execution.result.timeout(
          const Duration(minutes: 3),
        );

        print(
          'Graph completed: success=${graphResult.success}, completed=${graphResult.completedCount}, failed=${graphResult.failedNodes}',
        );
        expect(
          graphResult.success,
          isTrue,
          reason: 'DAG should complete all nodes',
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}
