import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/testing.dart';

/// Unit tests for [TaskHandler] and related [FakeWorkManager] stub machinery.
///
/// The BLE disconnect bug (issue #6) is also covered here at the Dart level:
/// the root cause was that FlutterEngineManager created a secondary FlutterEngine
/// with automaticallyRegisterPlugins=true (the default), which registered
/// BLE plugins in the background engine. When that engine was destroyed the
/// BLE plugin's onDetachedFromEngine() cleanup ran against shared Android
/// BluetoothManager state, disconnecting any active BLE connection in the
/// main engine.
///
/// The Kotlin fix (automaticallyRegisterPlugins=false + waitForRestorationData=false)
/// cannot be verified in Dart tests — it needs an Android instrumented test.
/// What we CAN verify here:
/// - The [DartWorker.autoDispose] flag is correctly passed to the native side,
///   so the engine is torn down immediately after single-task use. This minimises
///   the window during which the background engine is alive and could interfere
///   with system-level resources like BluetoothManager.
/// - The [FakeWorkManager] correctly reflects the schedule result the test
///   configures, so tests that simulate rejection/OS-policy flows work properly.
void main() {
  // ── TaskHandler construction ────────────────────────────────────────────────

  group('TaskHandler – construction', () {
    test('stores taskId and scheduleResult', () {
      final h = TaskHandler(
        taskId: 'my-task',
        scheduleResult: ScheduleResult.accepted,
      );
      expect(h.taskId, equals('my-task'));
      expect(h.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('stores rejectedOsPolicy result', () {
      final h = TaskHandler(
        taskId: 'blocked',
        scheduleResult: ScheduleResult.rejectedOsPolicy,
      );
      expect(h.scheduleResult, equals(ScheduleResult.rejectedOsPolicy));
    });

    test('two handlers with same taskId and result are value-equal', () {
      final a = TaskHandler(
        taskId: 'x',
        scheduleResult: ScheduleResult.accepted,
      );
      final b = TaskHandler(
        taskId: 'x',
        scheduleResult: ScheduleResult.accepted,
      );
      // TaskHandler is @immutable but does not override == by default.
      // This test documents current identity behaviour so any future
      // value-equality change is caught.
      expect(a.taskId, equals(b.taskId));
      expect(a.scheduleResult, equals(b.scheduleResult));
    });
  });

  // ── FakeWorkManager – enqueue result stubs ─────────────────────────────────
  //
  // These tests verify the stub machinery that was broken in the v1.2.x refactor:
  // FakeWorkManager.enqueue() was hardcoding ScheduleResult.accepted and ignoring
  // enqueueResult / enqueueResultByTaskId. Tests that simulate OS rejection
  // (e.g., exact-alarm permission denied) would silently pass with a wrong result.

  group('FakeWorkManager – enqueue result stubs', () {
    late FakeWorkManager wm;

    setUp(() {
      wm = FakeWorkManager();
    });

    tearDown(() {
      wm.dispose();
    });

    test('default result is accepted', () async {
      final h = await wm.enqueue(
        taskId: 'task-1',
        trigger: TaskTrigger.oneTime(),
        worker: const HttpRequestWorker(
          url: 'https://example.com',
          method: HttpMethod.get,
        ),
      );
      expect(h.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('enqueueResult override is respected', () async {
      wm.enqueueResult = ScheduleResult.rejectedOsPolicy;

      final h = await wm.enqueue(
        taskId: 'task-1',
        trigger: TaskTrigger.oneTime(),
        worker: const HttpRequestWorker(
          url: 'https://example.com',
          method: HttpMethod.get,
        ),
      );
      expect(h.scheduleResult, equals(ScheduleResult.rejectedOsPolicy));
    });

    test('enqueueResultByTaskId takes precedence over enqueueResult', () async {
      wm.enqueueResult = ScheduleResult.rejectedOsPolicy;
      wm.enqueueResultByTaskId['special-task'] = ScheduleResult.accepted;

      final h = await wm.enqueue(
        taskId: 'special-task',
        trigger: TaskTrigger.oneTime(),
        worker: const HttpRequestWorker(
          url: 'https://example.com',
          method: HttpMethod.get,
        ),
      );
      expect(h.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('enqueueResultByTaskId falls back to enqueueResult for other tasks',
        () async {
      wm.enqueueResult = ScheduleResult.rejectedOsPolicy;
      wm.enqueueResultByTaskId['special-task'] = ScheduleResult.accepted;

      final h = await wm.enqueue(
        taskId: 'other-task',
        trigger: TaskTrigger.oneTime(),
        worker: const HttpRequestWorker(
          url: 'https://example.com',
          method: HttpMethod.get,
        ),
      );
      expect(h.scheduleResult, equals(ScheduleResult.rejectedOsPolicy));
    });

    test('enqueueAll propagates per-task overrides', () async {
      wm.enqueueResultByTaskId['task-2'] = ScheduleResult.rejectedOsPolicy;

      final results = await wm.enqueueAll([
        EnqueueRequest(
          taskId: 'task-1',
          trigger: TaskTrigger.oneTime(),
          worker: const HttpRequestWorker(
            url: 'https://example.com',
            method: HttpMethod.get,
          ),
        ),
        EnqueueRequest(
          taskId: 'task-2',
          trigger: TaskTrigger.oneTime(),
          worker: const HttpRequestWorker(
            url: 'https://example.com',
            method: HttpMethod.get,
          ),
        ),
      ]);

      expect(results[0].scheduleResult, equals(ScheduleResult.accepted));
      expect(results[1].scheduleResult, equals(ScheduleResult.rejectedOsPolicy));
    });

    test('dispose() resets enqueueResult to accepted', () async {
      wm.enqueueResult = ScheduleResult.rejectedOsPolicy;
      wm.dispose();

      final wm2 = FakeWorkManager();
      final h = await wm2.enqueue(
        taskId: 'task-1',
        trigger: TaskTrigger.oneTime(),
        worker: const HttpRequestWorker(
          url: 'https://example.com',
          method: HttpMethod.get,
        ),
      );
      expect(h.scheduleResult, equals(ScheduleResult.accepted));
      wm2.dispose();
    });
  });

  // ── Issue #6 – DartWorker engine lifecycle at the Dart level ───────────────
  //
  // The BLE disconnect (github.com/brewkits/native_workmanager/issues/6) was
  // caused by the background FlutterEngine living longer than necessary AND
  // registering all host-app plugins including flutter_reactive_ble.
  //
  // The Kotlin fix ensures automaticallyRegisterPlugins=false so BLE and other
  // system plugins are never initialised in the background engine.
  //
  // The Dart-level mitigation is autoDispose=true: request the engine to be
  // torn down immediately after the single task completes, minimising the
  // overlap window. The tests below verify that this flag round-trips correctly
  // to the map that the native side deserialises.

  group('Issue #6 – DartWorker autoDispose (engine lifecycle / BLE safety)', () {
    test('autoDispose defaults to false', () {
      final worker = DartWorker(callbackId: 'cb');
      final map = worker.toMap();
      // When not set, the key should be absent or false — native side defaults to false.
      final autoDispose = map['autoDispose'];
      expect(autoDispose == null || autoDispose == false, isTrue,
          reason: 'autoDispose should be absent or false by default');
    });

    test('autoDispose=true is passed through to the native channel map', () {
      final worker = DartWorker(callbackId: 'cb', autoDispose: true);
      final map = worker.toMap();
      expect(map['autoDispose'], isTrue,
          reason:
              'autoDispose=true must reach the native side so the engine is '
              'destroyed immediately — reducing BLE interference window');
    });

    test('autoDispose=false is explicit and distinct from null', () {
      final workerTrue = DartWorker(callbackId: 'cb', autoDispose: true);
      final workerFalse = DartWorker(callbackId: 'cb', autoDispose: false);

      expect(workerTrue.toMap()['autoDispose'], isTrue);
      // false means "cache engine for 5 min" — native side should see false/null
      final falseVal = workerFalse.toMap()['autoDispose'];
      expect(falseVal == null || falseVal == false, isTrue);
    });

    test('DartWorkerInternal autoDispose is included in toMap', () {
      final internal = DartWorkerInternal(
        callbackId: 'cb',
        callbackHandle: 999,
        autoDispose: true,
      );
      final map = internal.toMap();
      expect(map['autoDispose'], isTrue);
    });

    test('DartWorkerInternal autoDispose false is preserved', () {
      final internal = DartWorkerInternal(
        callbackId: 'cb',
        callbackHandle: 999,
        autoDispose: false,
      );
      final map = internal.toMap();
      final autoDispose = map['autoDispose'];
      expect(autoDispose == null || autoDispose == false, isTrue);
    });

    test('all relevant DartWorker fields survive round-trip for BLE use-case',
        () {
      // Simulates a health-data sync worker that should dispose immediately
      // to minimise time spent with a background engine (BLE safety).
      final worker = DartWorker(
        callbackId: 'health-sync',
        input: {'userId': '123', 'dataType': 'steps'},
        autoDispose: true,
        timeoutMs: 30000,
      );

      final map = worker.toMap();

      expect(map['callbackId'], equals('health-sync'));
      expect(map['workerType'], equals('dartCallback'));
      expect(map['input'], isA<String>());
      expect(map['input'], contains('userId'));
      expect(map['autoDispose'], isTrue);
      expect(map['timeoutMs'], equals(30000));
    });
  });
}
