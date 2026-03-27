// ignore_for_file: avoid_print
// ============================================================
// Native WorkManager – Advanced Features Integration Tests
// ============================================================
//
// Run on a real device or emulator:
//
//   flutter test integration_test/advanced_features_test.dart \
//     --timeout=none
//
// Coverage:
//   ✅ TaskGraph (DAG) – parallel fan-out + fan-in
//   ✅ TaskGraph – failure cancels downstream nodes
//   ✅ TaskGraph – cycle detection (ArgumentError)
//   ✅ ObservabilityConfig – onTaskComplete / onTaskFail callbacks
//   ✅ Typed results – DownloadResult.from(), HttpRequestResult.from()
//   ✅ OfflineQueue – FIFO processing, dead-letter after maxRetries
//   ✅ Builder methods – HttpDownloadWorker.withBandwidthLimit/withSigning
//   ✅ Builder methods – HttpUploadWorker.copyWith/withAuth/withSigning
//   ✅ Builder methods – HttpRequestWorker.copyWith/withBody/withAuth
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

String _id(String name) =>
    'aft_${name}_${DateTime.now().millisecondsSinceEpoch}';

Future<TaskEvent?> _waitEvent(
  String taskId, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final completer = Completer<TaskEvent?>();
  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    if (event.taskId == taskId && !completer.isCompleted) {
      completer.complete(event);
      sub.cancel();
    }
  });
  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      sub.cancel();
      completer.complete(null);
    }
  });
  return completer.future;
}

// ─────────────────────────────────────────────────────────────
// Dart worker callbacks
// ─────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _nodeA(Map<String, dynamic>? input) async {
  print('[DartWorker] node_a ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _nodeB(Map<String, dynamic>? input) async {
  print('[DartWorker] node_b ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _nodeC(Map<String, dynamic>? input) async {
  print('[DartWorker] node_c ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _nodeAlwaysFail(Map<String, dynamic>? input) async {
  print('[DartWorker] node_fail – returning false');
  return false;
}

// ─────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize(
      dartWorkers: {
        'node_a': _nodeA,
        'node_b': _nodeB,
        'node_c': _nodeC,
        'node_fail': _nodeAlwaysFail,
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 1 – TaskGraph (DAG)
  // ════════════════════════════════════════════════════════════

  group('TaskGraph', () {
    testWidgets('linear graph A→B→C completes in order', (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final graphId = 'linear_$ts';

      final graph = TaskGraph(id: graphId)
        ..add(TaskNode(id: 'a', worker: DartWorker(callbackId: 'node_a')))
        ..add(TaskNode(
            id: 'b',
            worker: DartWorker(callbackId: 'node_b'),
            dependsOn: ['a']))
        ..add(TaskNode(
            id: 'c',
            worker: DartWorker(callbackId: 'node_c'),
            dependsOn: ['b']));

      final exec = await NativeWorkManager.enqueueGraph(graph);
      final result =
          await exec.result.timeout(const Duration(seconds: 120), onTimeout: () {
        fail('Linear graph did not finish within 120 s');
      });

      expect(result.success, isTrue, reason: 'All nodes must succeed');
      expect(result.completedCount, equals(3));
      expect(result.failedNodes, isEmpty);
      expect(result.cancelledNodes, isEmpty);
    });

    testWidgets('parallel fan-out A,B → merge C completes', (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;

      final graph = TaskGraph(id: 'fanout_$ts')
        ..add(TaskNode(id: 'a', worker: DartWorker(callbackId: 'node_a')))
        ..add(TaskNode(id: 'b', worker: DartWorker(callbackId: 'node_b')))
        ..add(TaskNode(
            id: 'c',
            worker: DartWorker(callbackId: 'node_c'),
            dependsOn: ['a', 'b']));

      final exec = await NativeWorkManager.enqueueGraph(graph);
      final result =
          await exec.result.timeout(const Duration(seconds: 120), onTimeout: () {
        fail('Fan-out graph did not finish within 120 s');
      });

      expect(result.success, isTrue);
      expect(result.completedCount, equals(3));
    });

    testWidgets('failed root cancels downstream nodes', (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // fail_root → (b, c) — both should be cancelled
      final graph = TaskGraph(id: 'failcancel_$ts')
        ..add(
            TaskNode(id: 'fail_root', worker: DartWorker(callbackId: 'node_fail')))
        ..add(TaskNode(
            id: 'b',
            worker: DartWorker(callbackId: 'node_b'),
            dependsOn: ['fail_root']))
        ..add(TaskNode(
            id: 'c',
            worker: DartWorker(callbackId: 'node_c'),
            dependsOn: ['b']));

      final exec = await NativeWorkManager.enqueueGraph(graph);
      final result =
          await exec.result.timeout(const Duration(seconds: 60), onTimeout: () {
        fail('Failure graph did not resolve within 60 s');
      });

      expect(result.success, isFalse);
      expect(result.failedNodes, contains('fail_root'));
      expect(result.cancelledNodes, containsAll(['b', 'c']));
    });

    testWidgets('cycle detection throws ArgumentError before scheduling',
        (tester) async {
      final graph = TaskGraph(id: 'cycle_test')
        ..add(TaskNode(
            id: 'a',
            worker: DartWorker(callbackId: 'node_a'),
            dependsOn: ['b']))
        ..add(TaskNode(
            id: 'b',
            worker: DartWorker(callbackId: 'node_b'),
            dependsOn: ['a']));

      expect(
        () => NativeWorkManager.enqueueGraph(graph),
        throwsArgumentError,
        reason: 'Cycle must be detected before any task is scheduled',
      );
    });

    testWidgets('duplicate node ID throws ArgumentError', (tester) async {
      final graph = TaskGraph(id: 'dup_test')
        ..add(TaskNode(id: 'a', worker: DartWorker(callbackId: 'node_a')))
        ..add(TaskNode(id: 'a', worker: DartWorker(callbackId: 'node_b')));

      expect(
        () => NativeWorkManager.enqueueGraph(graph),
        throwsArgumentError,
      );
    });

    testWidgets('empty graph returns success immediately', (tester) async {
      final exec =
          await NativeWorkManager.enqueueGraph(TaskGraph(id: 'empty_test'));
      final result = await exec.result;
      expect(result.success, isTrue);
      expect(result.completedCount, equals(0));
    });

    testWidgets('native worker chain via TaskGraph completes', (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Use a fast native HTTP request so the test doesn't need DartWorker engine
      final graph = TaskGraph(id: 'native_graph_$ts')
        ..add(TaskNode(
            id: 'req1',
            worker: HttpRequestWorker(
              url: 'https://jsonplaceholder.typicode.com/posts/1',
            )))
        ..add(TaskNode(
            id: 'req2',
            worker: HttpRequestWorker(
              url: 'https://jsonplaceholder.typicode.com/posts/2',
            ),
            dependsOn: ['req1']));

      final exec = await NativeWorkManager.enqueueGraph(graph);
      final result =
          await exec.result.timeout(const Duration(seconds: 90), onTimeout: () {
        fail('Native graph did not finish within 90 s');
      });

      expect(result.success, isTrue);
      expect(result.completedCount, equals(2));
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 2 – ObservabilityConfig
  // ════════════════════════════════════════════════════════════

  group('ObservabilityConfig', () {
    tearDown(() {
      // Remove observability after each test
      NativeWorkManager.configure();
    });

    testWidgets('onTaskComplete fires for successful task', (tester) async {
      final completer = Completer<TaskEvent>();

      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskComplete: (event) {
            if (!completer.isCompleted) completer.complete(event);
          },
        ),
      );

      final id = _id('obs_complete');
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => fail('onTaskComplete not fired within 60 s'),
      );

      expect(event.taskId, equals(id));
      expect(event.success, isTrue);
    });

    testWidgets('onTaskFail fires for failed task', (tester) async {
      final completer = Completer<TaskEvent>();

      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskFail: (event) {
            if (!completer.isCompleted) completer.complete(event);
          },
        ),
      );

      final id = _id('obs_fail');
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        // Deliberately invalid URL → worker returns failure
        worker: const HttpRequestWorker(url: 'file:///not-allowed'),
      );

      final event = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => fail('onTaskFail not fired within 60 s'),
      );

      expect(event.taskId, equals(id));
      expect(event.success, isFalse);
    });

    testWidgets('exception in callback does not break event stream',
        (tester) async {
      var callbackHitCount = 0;

      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskComplete: (event) {
            callbackHitCount++;
            throw StateError('intentional test exception');
          },
        ),
      );

      final id1 = _id('obs_throw_1');
      final id2 = _id('obs_throw_2');

      await NativeWorkManager.enqueue(
        taskId: id1,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1'),
        constraints: const Constraints(requiresNetwork: true),
      );
      await NativeWorkManager.enqueue(
        taskId: id2,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/2'),
        constraints: const Constraints(requiresNetwork: true),
      );

      // Wait for both tasks
      await Future.wait([
        _waitEvent(id1, timeout: const Duration(seconds: 60))
            .then((e) => expect(e?.success, isTrue)),
        _waitEvent(id2, timeout: const Duration(seconds: 60))
            .then((e) => expect(e?.success, isTrue)),
      ]);

      // Both events must reach the stream despite the callback throwing
      expect(callbackHitCount, greaterThanOrEqualTo(2),
          reason: 'Both success events must reach callback even if it throws');
    });

    testWidgets('configure(null) removes existing config', (tester) async {
      var fired = false;

      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskComplete: (_) => fired = true,
        ),
      );

      // Remove config
      NativeWorkManager.configure();

      final id = _id('obs_remove');
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1'),
        constraints: const Constraints(requiresNetwork: true),
      );

      await _waitEvent(id, timeout: const Duration(seconds: 60));

      // Allow a tick for any stray callbacks
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(fired, isFalse,
          reason: 'Callback must not fire after configure() removes config');
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 3 – Typed Worker Results
  // ════════════════════════════════════════════════════════════

  group('Typed Worker Results', () {
    testWidgets('DownloadResult.from parses resultData correctly',
        (tester) async {
      final savePath =
          '${Directory.systemTemp.path}/aft_typed_dl_${DateTime.now().millisecondsSinceEpoch}.json';

      final id = _id('typed_dl');
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
          savePath: savePath,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await _waitEvent(id, timeout: const Duration(seconds: 60));
      expect(event, isNotNull, reason: 'Task must complete');
      expect(event!.success, isTrue);

      final result = DownloadResult.from(event.resultData);
      expect(result, isNotNull);
      expect(result!.filePath, equals(savePath));
      expect(result.fileName, isNotEmpty);
      expect(result.fileSize, greaterThan(0));
      expect(result.skipped, isFalse);

      // Cleanup
      try {
        File(savePath).deleteSync();
      } catch (_) {}
    });

    testWidgets('HttpRequestResult.from parses resultData correctly',
        (tester) async {
      final id = _id('typed_req');
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await _waitEvent(id, timeout: const Duration(seconds: 60));
      expect(event, isNotNull);
      expect(event!.success, isTrue);

      final result = HttpRequestResult.from(event.resultData);
      expect(result, isNotNull);
      expect(result!.statusCode, equals(200));
      expect(result.body, isNotEmpty);
      expect(result.contentLength, greaterThan(0));
    });

    testWidgets('DownloadResult.from returns null for null input',
        (tester) async {
      expect(DownloadResult.from(null), isNull);
    });

    testWidgets('DownloadResult.from returns null for incomplete map',
        (tester) async {
      expect(DownloadResult.from({'filePath': '/tmp/x'}), isNull,
          reason: 'Missing fileName and fileSize must return null');
    });

    testWidgets('DownloadResult skipped=true is parsed', (tester) async {
      final data = <String, dynamic>{
        'filePath': '/tmp/test.zip',
        'fileName': 'test.zip',
        'fileSize': 0,
        'skipped': true,
      };
      final result = DownloadResult.from(data);
      expect(result?.skipped, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 4 – OfflineQueue
  // ════════════════════════════════════════════════════════════

  group('OfflineQueue', () {
    testWidgets('processes tasks in FIFO order', (tester) async {
      final completedIds = <String>[];
      final allDone = Completer<void>();

      final id1 = _id('oq_fifo_1');
      final id2 = _id('oq_fifo_2');
      final id3 = _id('oq_fifo_3');

      final sub = NativeWorkManager.events.listen((event) {
        if ([id1, id2, id3].contains(event.taskId) && event.success) {
          completedIds.add(event.taskId);
          if (completedIds.length == 3 && !allDone.isCompleted) {
            allDone.complete();
          }
        }
      });

      final queue = OfflineQueue(
        id: 'fifo_queue_${DateTime.now().millisecondsSinceEpoch}',
        defaultRetryPolicy: const OfflineRetryPolicy(
          maxRetries: 0,
          requiresNetwork: true,
        ),
      );

      await queue.enqueue(QueueEntry(
        taskId: id1,
        worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1'),
      ));
      await queue.enqueue(QueueEntry(
        taskId: id2,
        worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/2'),
      ));
      await queue.enqueue(QueueEntry(
        taskId: id3,
        worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/3'),
      ));

      expect(queue.pendingCount, equals(3));
      queue.start();

      await allDone.future.timeout(const Duration(seconds: 120), onTimeout: () {
        fail(
            'OfflineQueue FIFO did not finish within 120 s — completed: $completedIds');
      });

      await sub.cancel();

      // FIFO: id1 must come before id2, id2 before id3
      expect(completedIds.indexOf(id1), lessThan(completedIds.indexOf(id2)));
      expect(completedIds.indexOf(id2), lessThan(completedIds.indexOf(id3)));
    });

    testWidgets('maxSize exceeded throws StateError', (tester) async {
      final queue = OfflineQueue(
        id: 'maxsize_${DateTime.now().millisecondsSinceEpoch}',
        maxSize: 2,
      );

      await queue.enqueue(QueueEntry(
        taskId: _id('ms1'),
        worker: HttpRequestWorker(url: 'https://jsonplaceholder.typicode.com'),
      ));
      await queue.enqueue(QueueEntry(
        taskId: _id('ms2'),
        worker: HttpRequestWorker(url: 'https://jsonplaceholder.typicode.com'),
      ));

      expect(
        () => queue.enqueue(QueueEntry(
          taskId: _id('ms3'),
          worker:
              HttpRequestWorker(url: 'https://jsonplaceholder.typicode.com'),
        )),
        throwsA(isA<StateError>()),
        reason: 'Adding beyond maxSize must throw StateError',
      );
    });

    testWidgets('cancel removes matching entries', (tester) async {
      final queue = OfflineQueue(
        id: 'cancel_${DateTime.now().millisecondsSinceEpoch}',
        maxSize: 10,
      );

      final id1 = _id('cq1');
      final id2 = _id('cq2');
      final id3 = _id('cq3');

      await queue.enqueue(
          QueueEntry(taskId: id1, worker: HttpRequestWorker(url: 'https://example.com'), tag: 'group-a'));
      await queue.enqueue(
          QueueEntry(taskId: id2, worker: HttpRequestWorker(url: 'https://example.com'), tag: 'group-b'));
      await queue.enqueue(
          QueueEntry(taskId: id3, worker: HttpRequestWorker(url: 'https://example.com'), tag: 'group-a'));

      queue.cancel(tag: 'group-a');

      expect(queue.pendingCount, equals(1),
          reason: 'Only group-b task must remain after cancelling group-a');
    });

    testWidgets('failed task moves to dead-letter after maxRetries',
        (tester) async {
      final queue = OfflineQueue(
        id: 'deadletter_${DateTime.now().millisecondsSinceEpoch}',
        defaultRetryPolicy: const OfflineRetryPolicy(
          maxRetries: 1,
          requiresNetwork: false,
          initialDelay: Duration(milliseconds: 100),
        ),
      );

      // Deliberately invalid URL causes task failure
      await queue.enqueue(QueueEntry(
        taskId: _id('dl_fail'),
        worker: const HttpRequestWorker(url: 'file:///not-allowed'),
        retryPolicy: const OfflineRetryPolicy(
          maxRetries: 1,
          requiresNetwork: false,
          initialDelay: Duration(milliseconds: 100),
        ),
      ));

      queue.start();

      // Wait for both attempts (initial + 1 retry) + dead-letter move
      await Future<void>.delayed(const Duration(seconds: 30));

      expect(queue.deadLetterCount, greaterThan(0),
          reason: 'Task must be in dead-letter after exhausting retries');
      expect(queue.pendingCount, equals(0),
          reason: 'No pending tasks must remain after dead-letter move');
    });

    testWidgets('stop halts queue processing', (tester) async {
      final queue = OfflineQueue(
        id: 'stop_${DateTime.now().millisecondsSinceEpoch}',
        maxSize: 5,
      );

      for (var i = 0; i < 3; i++) {
        await queue.enqueue(QueueEntry(
          taskId: _id('stop_$i'),
          worker:
              HttpRequestWorker(url: 'https://jsonplaceholder.typicode.com'),
        ));
      }

      queue.start();
      queue.stop();

      // After stop, pendingCount stays > 0 (no tasks dequeued) because
      // stop prevents further dequeue; any in-flight task may still finish.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(queue.isRunning, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 5 – Builder / Convenience Methods
  // ════════════════════════════════════════════════════════════

  group('Builder methods', () {
    test('HttpDownloadWorker.withBandwidthLimit preserves all other fields',
        () {
      const base = HttpDownloadWorker(
        url: 'https://example.com/file.zip',
        savePath: '/tmp/file.zip',
        enableResume: true,
      );

      final limited = base.withBandwidthLimit(500 * 1024);
      expect(limited.bandwidthLimitBytesPerSecond, equals(500 * 1024));
      expect(limited.url, equals(base.url));
      expect(limited.savePath, equals(base.savePath));
      expect(limited.enableResume, equals(base.enableResume));
    });

    test('HttpDownloadWorker.withSigning sets requestSigning', () {
      const base =
          HttpDownloadWorker(url: 'https://example.com/', savePath: '/tmp/f');
      const signing = RequestSigning(secretKey: 'supersecretkey1234567');
      final signed = base.withSigning(signing);
      expect(signed.requestSigning, equals(signing));
      expect(signed.url, equals(base.url));
    });

    test('HttpUploadWorker.copyWith produces correct copy', () {
      const base = HttpUploadWorker(
        url: 'https://example.com/upload',
        filePath: '/tmp/file.jpg',
      );

      final copy = base.copyWith(fileFieldName: 'photo', timeout: const Duration(minutes: 10));
      expect(copy.fileFieldName, equals('photo'));
      expect(copy.timeout, equals(const Duration(minutes: 10)));
      expect(copy.url, equals(base.url));
      expect(copy.filePath, equals(base.filePath));
    });

    test('HttpUploadWorker.withAuth sets Authorization header', () {
      const base = HttpUploadWorker(
        url: 'https://example.com/upload',
        filePath: '/tmp/file.jpg',
      );
      final authed = base.withAuth(token: 'mytoken123');
      expect(authed.headers['Authorization'], equals('Bearer mytoken123'));
    });

    test('HttpUploadWorker.withHeaders merges with existing', () {
      const base = HttpUploadWorker(
        url: 'https://example.com/upload',
        filePath: '/tmp/file.jpg',
        headers: {'X-App': '1'},
      );
      final merged = base.withHeaders({'X-Version': '2'});
      expect(merged.headers['X-App'], equals('1'));
      expect(merged.headers['X-Version'], equals('2'));
    });

    test('HttpRequestWorker.withBody sets body and Content-Type', () {
      const base = HttpRequestWorker(
        url: 'https://example.com/api',
        method: HttpMethod.post,
      );
      final withBody =
          base.withBody('{"key":"value"}');
      expect(withBody.body, equals('{"key":"value"}'));
      expect(withBody.headers['Content-Type'], equals('application/json'));
    });

    test('HttpRequestWorker.withAuth injects Authorization header', () {
      const base =
          HttpRequestWorker(url: 'https://example.com/api');
      final authed = base.withAuth(token: 'tok_abc');
      expect(authed.headers['Authorization'], equals('Bearer tok_abc'));
    });

    test('HttpRequestWorker.withAuth custom template', () {
      const base =
          HttpRequestWorker(url: 'https://example.com/api');
      final authed =
          base.withAuth(token: 'apiKey123', template: 'ApiKey {accessToken}');
      expect(authed.headers['Authorization'], equals('ApiKey apiKey123'));
    });

    test('HttpRequestWorker.withSigning sets requestSigning', () {
      const base =
          HttpRequestWorker(url: 'https://example.com/api');
      const signing = RequestSigning(secretKey: 'mysecretkey123456789');
      final signed = base.withSigning(signing);
      expect(signed.requestSigning, equals(signing));
    });

    test('OfflineRetryPolicy.networkAvailable preset has correct values', () {
      const policy = OfflineRetryPolicy.networkAvailable;
      expect(policy.maxRetries, equals(10));
      expect(policy.requiresNetwork, isTrue);
    });

    test('OfflineRetryPolicy.delayFor uses exponential backoff', () {
      const policy = OfflineRetryPolicy(
        maxRetries: 5,
        initialDelay: Duration(seconds: 10),
        backoffMultiplier: 2.0,
      );
      expect(policy.delayFor(0).inSeconds, equals(10));
      expect(policy.delayFor(1).inSeconds, equals(20));
      expect(policy.delayFor(2).inSeconds, equals(40));
    });

    test('OfflineRetryPolicy.delayFor respects maxDelay cap', () {
      const policy = OfflineRetryPolicy(
        initialDelay: Duration(seconds: 30),
        backoffMultiplier: 10.0,
        maxDelay: Duration(minutes: 1),
      );
      expect(policy.delayFor(5).inSeconds,
          lessThanOrEqualTo(const Duration(minutes: 1).inSeconds));
    });
  });
}
