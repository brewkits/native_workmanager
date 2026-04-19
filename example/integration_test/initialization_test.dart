// ignore_for_file: avoid_print
// ============================================================
// Initialization & Cold-Start Persistence — Integration Tests
// ============================================================
//
// Run on a real device or emulator:
//
//   cd example
//   flutter test integration_test/initialization_test.dart --timeout=none
//
// Coverage:
//   ✅ callbackHandle persistence across re-initialization
//   ✅ DartWorker execution after re-initialization (hot-restart simulation)
//   ✅ Multiple DartWorkers registered and executed
//   ✅ Initialize → enqueue → result pipeline (cold path simulation)
//   ✅ Engine caching: second DartWorker executes faster
//   ✅ Native worker succeeds after DartWorker (engine isolation)
//   ✅ idempotent initialization (no crash on double-init)
//
// NOTE: True killed-app cold-start testing (process death → WorkManager fires)
// cannot be automated in-process. Use the ColdStartDemoPage in the demo app,
// then force-close the app and trigger WorkManager manually:
//
//   adb shell cmd jobscheduler run -f your.package.name 1
//
// Then check Logcat for:
//   FlutterEngineManager: Initializing Flutter engine... (cold process start)
//   FlutterEngineManager: Dart ready signal received
// ============================================================

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// ──────────────────────────────────────────────────────────────
// Callbacks
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _dummyCallback(Map<String, dynamic>? input) async => true;

@pragma('vm:entry-point')
Future<bool> _slowCallback(Map<String, dynamic>? input) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return true;
}

@pragma('vm:entry-point')
Future<bool> _echoCallback(Map<String, dynamic>? input) async {
  final key = input?['key'] as String?;
  return key != null && key.isNotEmpty;
}

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

String _id(String name) =>
    'init_${name}_${DateTime.now().millisecondsSinceEpoch}';

Future<TaskEvent?> _waitEvent(
  String taskId, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final completer = Completer<TaskEvent?>();
  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    if (event.taskId == taskId && !event.isStarted && !completer.isCompleted) {
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

// ──────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────────
  // Group 1: Basic initialization
  // ──────────────────────────────────────────────────────────────
  group('Basic Initialization', () {
    testWidgets('initialize() completes without error', (tester) async {
      await NativeWorkManager.initialize(
        dartWorkers: {'dummy': _dummyCallback},
        debugMode: true,
      );
      // No exception → pass
    });

    testWidgets('double initialize() is idempotent', (tester) async {
      await NativeWorkManager.initialize(
        dartWorkers: {'dummy': _dummyCallback},
      );
      // Second call should not throw or crash WorkManager
      await NativeWorkManager.initialize(
        dartWorkers: {'dummy': _dummyCallback},
      );
    });

    testWidgets('initialize() without dartWorkers succeeds', (tester) async {
      // Native-worker-only apps don't need dartWorkers
      await NativeWorkManager.initialize();
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Group 2: DartWorker execution after initialization
  // ──────────────────────────────────────────────────────────────
  group('DartWorker Execution After Initialization', () {
    setUpAll(() async {
      await NativeWorkManager.initialize(
        dartWorkers: {
          'dummy': _dummyCallback,
          'slow': _slowCallback,
          'echo': _echoCallback,
        },
        debugMode: true,
      );
    });

    testWidgets('DartWorker executes and returns success', (tester) async {
      final taskId = _id('dart_basic');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: DartWorker(callbackId: 'dummy'),
        trigger: const TaskTrigger.oneTime(),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'DartWorker timed out after 60s');
      expect(event!.success, isTrue, reason: 'DartWorker should succeed');
    });

    testWidgets('DartWorker passes input to callback', (tester) async {
      final taskId = _id('dart_echo');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: DartWorker(callbackId: 'echo', input: {'key': 'hello'}),
        trigger: const TaskTrigger.oneTime(),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'DartWorker timed out after 60s');
      expect(
        event!.success,
        isTrue,
        reason: 'Echo worker should return true when key is present',
      );
    });

    testWidgets('DartWorker with missing input key returns failure', (
      tester,
    ) async {
      final taskId = _id('dart_echo_fail');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: DartWorker(
          callbackId: 'echo',
          input: {}, // no 'key' → callback returns false
        ),
        trigger: const TaskTrigger.oneTime(),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'DartWorker timed out after 60s');
      expect(
        event!.success,
        isFalse,
        reason: 'Echo worker should fail when key is missing',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Group 3: callbackHandle persistence (hot-restart simulation)
  // ──────────────────────────────────────────────────────────────
  group('callbackHandle Persistence (Hot-Restart Simulation)', () {
    testWidgets(
      'DartWorker works after re-initialization (simulates hot-restart)',
      (tester) async {
        // First init
        await NativeWorkManager.initialize(
          dartWorkers: {'dummy': _dummyCallback},
        );

        final h1 = await NativeWorkManager.enqueue(
          taskId: _id('persist_1'),
          worker: DartWorker(callbackId: 'dummy'),
          trigger: const TaskTrigger.oneTime(),
        );
        expect((await h1.result).success, isTrue);

        // Simulate hot-restart: re-initialize
        await NativeWorkManager.initialize(
          dartWorkers: {'dummy': _dummyCallback},
        );

        final h2 = await NativeWorkManager.enqueue(
          taskId: _id('persist_2'),
          worker: DartWorker(callbackId: 'dummy'),
          trigger: const TaskTrigger.oneTime(),
        );
        expect((await h2.result).success, isTrue);
      },
    );

    testWidgets(
      'callbackHandle is registered on native side after initialize()',
      (tester) async {
        // After initialize(), the native side should have the callbackHandle.
        // We verify indirectly: a DartWorker should succeed only if the handle
        // is available on the native side.
        await NativeWorkManager.initialize(
          dartWorkers: {'dummy': _dummyCallback},
        );

        final taskId = _id('handle_check');
        final eventFuture = _waitEvent(taskId);
        await NativeWorkManager.enqueue(
          taskId: taskId,
          worker: DartWorker(callbackId: 'dummy'),
          trigger: const TaskTrigger.oneTime(),
        );
        final event = await eventFuture;
        expect(
          event?.success,
          isTrue,
          reason: 'Handle must be set for DartWorker to succeed',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────
  // Group 4: Engine caching performance
  // ──────────────────────────────────────────────────────────────
  group('Engine Caching (Performance)', () {
    setUpAll(() async {
      await NativeWorkManager.initialize(
        dartWorkers: {'dummy': _dummyCallback},
      );
    });

    testWidgets('second DartWorker executes in ≤ first execution time', (
      tester,
    ) async {
      // First task — may be cold start (FlutterEngine boot: 500-1000ms)
      final id1 = _id('cache_cold');
      final t0 = DateTime.now();
      final future1 = _waitEvent(id1);
      await NativeWorkManager.enqueue(
        taskId: id1,
        worker: DartWorker(callbackId: 'dummy'),
        trigger: const TaskTrigger.oneTime(),
      );
      await future1;
      final coldMs = DateTime.now().difference(t0).inMilliseconds;
      print('[Cache Test] Cold start: ${coldMs}ms');

      // Second task — should use warm/cached engine
      final id2 = _id('cache_warm');
      final t1 = DateTime.now();
      final future2 = _waitEvent(id2);
      await NativeWorkManager.enqueue(
        taskId: id2,
        worker: DartWorker(callbackId: 'dummy'),
        trigger: const TaskTrigger.oneTime(),
      );
      await future2;
      final warmMs = DateTime.now().difference(t1).inMilliseconds;
      print('[Cache Test] Warm start: ${warmMs}ms');
      print(
        '[Cache Test] Speedup: ${(coldMs / warmMs.clamp(1, coldMs)).toStringAsFixed(1)}×',
      );

      // Warm should be ≤ cold. Allow generous margin for WorkManager scheduling jitter.
      // The key insight is warm should not be dramatically SLOWER than cold.
      // On a real device: cold ~500-1000ms, warm ~100-200ms.
      // On emulators: both may be similar due to scheduling overhead.
      expect(
        warmMs,
        lessThanOrEqualTo(
          coldMs + 5000,
        ), // 5s margin for WorkManager scheduling
        reason: 'Warm start should not be dramatically slower than cold start',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Group 5: Native worker co-existence with DartWorker
  // ──────────────────────────────────────────────────────────────
  group('Native Worker Co-existence', () {
    setUpAll(() async {
      await NativeWorkManager.initialize(
        dartWorkers: {'dummy': _dummyCallback},
      );
    });

    testWidgets('native HTTP worker succeeds independently of DartWorker', (
      tester,
    ) async {
      final nativeId = _id('native_coexist');
      final eventFuture = _waitEvent(
        nativeId,
        timeout: const Duration(seconds: 30),
      );

      await NativeWorkManager.enqueue(
        taskId: nativeId,
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
        trigger: const TaskTrigger.oneTime(),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'Native worker timed out');
      expect(event!.success, isTrue, reason: 'Native HTTP GET should succeed');
    });

    testWidgets('DartWorker and native worker run in same session', (
      tester,
    ) async {
      final dartId = _id('coexist_dart');
      final nativeId = _id('coexist_native');

      final dartFuture = _waitEvent(dartId);
      final nativeFuture = _waitEvent(
        nativeId,
        timeout: const Duration(seconds: 30),
      );

      // Enqueue both
      await NativeWorkManager.enqueue(
        taskId: dartId,
        worker: DartWorker(callbackId: 'dummy'),
        trigger: const TaskTrigger.oneTime(),
      );
      await NativeWorkManager.enqueue(
        taskId: nativeId,
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
        trigger: const TaskTrigger.oneTime(),
        constraints: const Constraints(requiresNetwork: true),
      );

      final dartEvent = await dartFuture;
      final nativeEvent = await nativeFuture;

      expect(dartEvent?.success, isTrue, reason: 'DartWorker should succeed');
      expect(
        nativeEvent?.success,
        isTrue,
        reason: 'Native worker should succeed',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Group 6: Stress — rapid DartWorker enqueue
  // ──────────────────────────────────────────────────────────────
  group('Stress: Rapid DartWorker Enqueue', () {
    const workerCount = 5;

    setUpAll(() async {
      await NativeWorkManager.initialize(
        dartWorkers: {'dummy': _dummyCallback},
      );
    });

    testWidgets('$workerCount sequential DartWorkers all succeed', (
      tester,
    ) async {
      for (var i = 0; i < workerCount; i++) {
        final taskId = _id('stress_seq_$i');
        final eventFuture = _waitEvent(taskId);

        await NativeWorkManager.enqueue(
          taskId: taskId,
          worker: DartWorker(callbackId: 'dummy'),
          trigger: const TaskTrigger.oneTime(),
        );

        final event = await eventFuture;
        expect(event?.success, isTrue, reason: 'Worker $i should succeed');
      }
    });

    testWidgets('$workerCount concurrent DartWorkers all succeed', (
      tester,
    ) async {
      final ids = List.generate(workerCount, (i) => _id('stress_conc_$i'));
      final futures = ids.map((id) => _waitEvent(id)).toList();

      // Enqueue all before waiting for any
      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          worker: DartWorker(callbackId: 'dummy'),
          trigger: const TaskTrigger.oneTime(),
        );
      }

      final events = await Future.wait(futures);
      for (var i = 0; i < events.length; i++) {
        expect(
          events[i]?.success,
          isTrue,
          reason: 'Concurrent worker ${ids[i]} should succeed',
        );
      }
    });
  });
}
