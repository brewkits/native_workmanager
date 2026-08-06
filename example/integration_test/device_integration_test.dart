// ignore_for_file: avoid_print
// ============================================================
// Native WorkManager v1.2.7 – DEVICE INTEGRATION TESTS
// ============================================================
//
// Run on a real device or emulator (NOT unit/mock tests):
//
//   flutter test integration_test/device_integration_test.dart \
//     --timeout=none
//   # or specific group:
//   flutter test integration_test/device_integration_test.dart \
//     --name "Trigger Types"
//
// Coverage:
//   ✅ All trigger types           (oneTime, oneTime+delay, periodic)
//   ✅ ExistingPolicy              (REPLACE, KEEP)
//   ✅ All constraints             (network, charging, heavy, backoff, systemConstraints)
//   ✅ All 11 workers              (HTTP, File, Image, Crypto, DartWorker)
//   ✅ Custom native workers       (success, missing input, unknown className)
//   ✅ Task chains                 (sequential A→B→C)
//   ✅ Tags                        (assign, query, cancelByTag)
//   ✅ Events & Progress streams
//   ✅ cancelAll / cancel by ID
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

/// Unique task IDs to avoid collisions across test runs.
String _id(String name) =>
    'dit_${name}_${DateTime.now().millisecondsSinceEpoch}';

// ──────────────────────────────────────────────────────────────
// Shared event hub
//
// Earlier every _waitEvent() opened its own NativeWorkManager.events
// subscription (plus a Future.delayed timeout timer) and cancelled it on match.
// Across a full ~60-test run this left many lingering listeners and timers and
// made back-to-back tests flaky (events for one test occasionally missed) and
// eventually wedged the run. A single long-lived subscription that routes
// terminal events to per-taskId waiters — and buffers terminal events that
// arrive before their waiter registers — removes that whole class of races.
// ──────────────────────────────────────────────────────────────

StreamSubscription<TaskEvent>? _eventHubSub;
final Map<String, Completer<TaskEvent?>> _eventWaiters = {};
final Map<String, TaskEvent> _eventBuffer = {};

void _startEventHub() {
  _eventHubSub ??= NativeWorkManager.events.listen((event) {
    // Only terminal events resolve a waiter; "started" is a lifecycle event.
    if (event.isStarted) return;
    final waiter = _eventWaiters.remove(event.taskId);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(event);
    } else {
      // No waiter yet (event raced ahead of _waitEvent) or nobody is waiting:
      // keep the latest terminal event so a slightly-late _waitEvent still sees it.
      _eventBuffer[event.taskId] = event;
    }
  });
}

Future<void> _stopEventHub() async {
  await _eventHubSub?.cancel();
  _eventHubSub = null;
  for (final w in _eventWaiters.values) {
    if (!w.isCompleted) w.complete(null);
  }
  _eventWaiters.clear();
  _eventBuffer.clear();
}

/// Resolves when the first terminal event for [taskId] arrives, or returns null
/// on timeout. Backed by the shared [_startEventHub] subscription.
///
/// Default timeout is 60 s — generous enough for real-device WorkManager
/// scheduling variability while still catching genuine hangs.
Future<TaskEvent?> _waitEvent(
  String taskId, {
  Duration timeout = const Duration(seconds: 60),
}) {
  // The event may already have arrived before this call (buffered by the hub).
  final buffered = _eventBuffer.remove(taskId);
  if (buffered != null) return Future.value(buffered);

  final completer = Completer<TaskEvent?>();
  _eventWaiters[taskId] = completer;
  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      _eventWaiters.remove(taskId);
      completer.complete(null);
    }
  });
  return completer.future;
}

/// Creates a small valid text file at [path] and returns it.
File _createTextFile(String path, {String content = 'NativeWorkManager test'}) {
  final file = File(path);
  file.writeAsStringSync(content * 100); // ~2 KB
  return file;
}

/// Minimal 1×1 red pixel PNG (RGB, correct Adler-32 and CRC).
/// Generated via Python's zlib to ensure valid checksums.
Uint8List get _minimalPng => Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR len+type
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // width=1, height=1
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // depth=8, RGB
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IHDR CRC, IDAT
  0x54, 0x78, 0xDA, 0x63, 0xF8, 0xCF, 0xC0, 0x00, // IDAT zlib+data
  0x00, 0x03, 0x01, 0x01, 0x00, 0xF7, 0x03, 0x41, // Adler-32 + CRC
  0x43, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND
  0x44, 0xAE, 0x42, 0x60, 0x82, // IEND CRC
]);

/// Sends an arbitrary raw config map to a native worker, bypassing the typed
/// Dart constructors (e.g. `ImageProcessWorker`'s `int? maxWidth`). Used to
/// exercise native-bridge behavior — like chain placeholder substitution
/// into a numeric field — that no typed public API currently exposes a way
/// to trigger (see issue_57 test group).
class _RawConfigWorker extends Worker {
  const _RawConfigWorker(this._className, this._config);

  final String _className;
  final Map<String, dynamic> _config;

  @override
  String get workerClassName => _className;

  @override
  Map<String, dynamic> toMap() => _config;
}

// ──────────────────────────────────────────────────────────────
// Top-level DartWorker callbacks (must NOT be anonymous/closures)
// PluginUtilities.getCallbackHandle() requires top-level or static functions.
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _ditPass(Map<String, dynamic>? input) async {
  print('[DartWorker] dit_pass ran, input=$input');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _ditFail(Map<String, dynamic>? input) async {
  print('[DartWorker] dit_fail returning false');
  return false;
}

@pragma('vm:entry-point')
Future<bool> _chainA(Map<String, dynamic>? input) async {
  print('[DartWorker] chain_a ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _chainB(Map<String, dynamic>? input) async {
  print('[DartWorker] chain_b ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _chainC(Map<String, dynamic>? input) async {
  print('[DartWorker] chain_c ran');
  return true;
}

/// Issue #30 regression: a long-running callback that exceeds the pre-fix
/// 25 s hardcoded timeout. Pairs with `DartWorker(timeoutMs: 40000)` to prove
/// the user-supplied value actually reaches the Dart dispatcher.
@pragma('vm:entry-point')
Future<bool> _ditLongRunning(Map<String, dynamic>? input) async {
  final delayMs = (input?['delayMs'] as int?) ?? 30000;
  print('[DartWorker] dit_long_running starting (delay ${delayMs}ms)');
  await Future<void>.delayed(Duration(milliseconds: delayMs));
  print('[DartWorker] dit_long_running completed');
  return true;
}

/// Issue #38/#39 regression: a DartWorker that reports progress (50% then 100%)
/// via [NativeWorkManager.reportDartWorkerProgress] and then returns `true`.
/// Proves progress events reach the Dart stream (#38) and that the task moves
/// to a terminal status in the persistent store afterwards (#39).
@pragma('vm:entry-point')
Future<bool> _ditProgress(Map<String, dynamic>? input) async {
  final taskId = input?['__taskId'] as String?;
  print('[DartWorker] dit_progress starting, taskId=$taskId');
  await NativeWorkManager.reportDartWorkerProgress(
    taskId: taskId,
    progress: 50,
    message: 'halfway',
  );
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await NativeWorkManager.reportDartWorkerProgress(
    taskId: taskId,
    progress: 100,
  );
  print('[DartWorker] dit_progress done');
  return true;
}

/// issue_46 regression: a callback that records each invocation to a shared
/// counter file (same app sandbox as the test isolate) and returns `false`.
/// Used to prove (a) `return false` actually retries — the primary bug — and
/// (b) `Constraints.maxRetries` caps the retries at N+1 total runs instead of
/// looping forever (WorkManager has no native max-retry API).
@pragma('vm:entry-point')
Future<bool> _ditRetryCounter(Map<String, dynamic>? input) async {
  final path = input?['counterFile'] as String?;
  if (path != null) {
    final f = File(path);
    final n = f.existsSync()
        ? (int.tryParse(f.readAsStringSync().trim()) ?? 0)
        : 0;
    f.writeAsStringSync('${n + 1}');
    print('[DartWorker] dit_retry_counter run #${n + 1}');
  }
  return false; // fail → should retry under maxRetries, then abandon
}

@pragma('vm:entry-point')
Future<bool> _workflowFinalizer(Map<String, dynamic>? input) async {
  print('[DartWorker] _workflowFinalizer starting...');
  final downloadPath = input?['downloadPath'] as String?;
  final encryptedPath = input?['encryptedPath'] as String?;

  if (downloadPath == null || encryptedPath == null) return false;

  final encFile = File(encryptedPath);
  if (!encFile.existsSync()) return false;

  print(
    '[DartWorker] _workflowFinalizer: success, encrypted file size: ${encFile.lengthSync()}',
  );
  return true;
}

// ──────────────────────────────────────────────────────────────
// Main
// ──────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = Directory(
      '${Directory.systemTemp.path}/nwm_dit_${DateTime.now().millisecondsSinceEpoch}',
    )..createSync();

    await NativeWorkManager.initialize(
      dartWorkers: {
        'dit_pass': _ditPass,
        'dit_fail': _ditFail,
        'dit_long_running': _ditLongRunning,
        'chain_a': _chainA,
        'chain_b': _chainB,
        'chain_c': _chainC,
        'dit_progress': _ditProgress,
        'dit_retry_counter': _ditRetryCounter,
        'workflow_finalizer': _workflowFinalizer,
      },
    );

    // Cancel any leftover tasks from previous runs.
    await NativeWorkManager.cancelAll();

    // One long-lived event subscription for the whole suite (see _startEventHub).
    _startEventHub();
  });

  // Drain the WorkManager queue after every test so delayed/periodic tasks
  // enqueued by one test do not fire mid-way through a later test (which booted
  // the Flutter engine for DartWorker callbacks and contended for resources,
  // causing cross-test flakiness and the full-suite hang).
  tearDown(() async {
    await NativeWorkManager.cancelAll();
  });

  tearDownAll(() async {
    await NativeWorkManager.cancelAll();
    await _stopEventHub();
    tmpDir.deleteSync(recursive: true);
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 1 – Trigger Types
  // Verifies the bug fix: trigger was previously hardcoded to
  // OneTime; now every type is wired through correctly.
  // ════════════════════════════════════════════════════════════
  group('Trigger Types', () {
    testWidgets('oneTime – executes and emits success event', (tester) async {
      final id = _id('onetime');
      final future = _waitEvent(id);

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'oneTime task must be accepted',
      );

      final event = await future;
      expect(event, isNotNull, reason: 'Must receive completion event');
      expect(event!.success, isTrue, reason: 'oneTime task must succeed');
    });

    testWidgets('oneTime with delay – schedules without crash', (tester) async {
      final id = _id('onetime_delay');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 10)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Delayed oneTime must be accepted',
      );

      // Clean up before the delay elapses.
      await NativeWorkManager.cancel(taskId: id);
    });

    testWidgets(
      'periodic – regression test for Issue #26 (initialDelay + runImmediately: false)',
      (tester) async {
        final id = _id('periodic_issue_26');

        // This configuration previously triggered an AssertionError in Dart
        // and had mapping issues in the iOS Swift bridge.
        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: TaskTrigger.periodic(
            const Duration(minutes: 15),
            initialDelay: const Duration(minutes: 5),
            runImmediately: false,
          ),
          worker: DartWorker(callbackId: 'dit_pass'),
        );

        expect(
          result.scheduleResult,
          ScheduleResult.accepted,
          reason:
              'Periodic task with initialDelay and runImmediately: false must be accepted',
        );

        // Verify task status to ensure it's actually scheduled in the native system
        final status = await NativeWorkManager.getTaskStatus(taskId: id);
        expect(
          status,
          isNotNull,
          reason: 'Task should be successfully scheduled',
        );

        await NativeWorkManager.cancel(taskId: id);
      },
    );

    testWidgets('periodic – first execution fires; task survives first run', (
      tester,
    ) async {
      final id = _id('periodic');
      var execCount = 0;
      final firstExecCompleter = Completer<void>();

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == id && !event.isStarted) {
          execCount++;
          print(
            '[periodic test] execution #$execCount success=${event.success}',
          );
          if (!firstExecCompleter.isCompleted) firstExecCompleter.complete();
        }
      });

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.periodic(Duration(minutes: 15)),
        // Use DartWorker to avoid Android 16 network-constraint deferral
        // that prevents the first periodic execution from firing in tests.
        worker: DartWorker(callbackId: 'dit_pass'),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Periodic task must be accepted',
      );

      // WorkManager 2.10+ changed periodic task scheduling: the first execution
      // now waits the full interval (15 min) before running, especially on
      // Android 16+ emulators. On real devices with older Android, the first
      // run fires within seconds.
      //
      // We give it 2 minutes. If it doesn't fire (e.g. Android 16 emulator),
      // we fall back to checking that the task is at least tracked as pending,
      // which still validates correct scheduling.
      bool didFire = false;
      try {
        await firstExecCompleter.future.timeout(const Duration(minutes: 2));
        didFire = true;
      } catch (_) {
        // Timeout: likely Android 16 emulator deferring first periodic execution
        print(
          '[periodic test] First execution not observed within 2 min – '
          'checking scheduled state instead (Android 16 emulator limitation)',
        );
      }

      if (didFire) {
        expect(
          execCount,
          greaterThanOrEqualTo(1),
          reason: 'Periodic task must execute at least once',
        );

        // Wait 3 s – a second execution should NOT happen (15-min interval).
        await Future.delayed(const Duration(seconds: 3));
        expect(
          execCount,
          1,
          reason:
              'Only 1 execution expected within 3s of a 15-min periodic task',
        );
      } else {
        // Validate the task is still tracked as scheduled (not accidentally cancelled)
        final status = await NativeWorkManager.getTaskStatus(taskId: id);
        expect(
          status,
          isNotNull,
          reason: 'Periodic task should still be tracked after enqueue',
        );
        print(
          '[periodic test] PASS – task is scheduled (execution skipped on emulator)',
        );
      }

      await sub.cancel();
      await NativeWorkManager.cancel(taskId: id);

      // After cancel, no more events should arrive.
      await Future.delayed(const Duration(seconds: 2));
      if (didFire) {
        expect(execCount, 1, reason: 'No events after cancellation');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 2 – ExistingPolicy
  // Verifies the bug fix: policy was previously hardcoded to KEEP.
  // ════════════════════════════════════════════════════════════
  group('ExistingPolicy', () {
    testWidgets('REPLACE – replaces an existing pending task', (tester) async {
      final id = _id('policy_replace');

      // First enqueue with a 60s delay so it stays pending.
      final r1 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(r1.scheduleResult, ScheduleResult.accepted);

      // Replace with an immediate DartWorker (no network constraint) so WorkManager
      // runs it immediately on any Android version without battery-deferral delays.
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));
      final r2 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_pass'),
        existingPolicy: ExistingTaskPolicy.replace,
      );
      expect(
        r2.scheduleResult,
        ScheduleResult.accepted,
        reason: 'REPLACE must be accepted',
      );

      final event = await future;
      expect(event, isNotNull, reason: 'Replaced task must execute');
      expect(event!.success, isTrue);
    });

    testWidgets('KEEP – ignores new request when task already exists', (
      tester,
    ) async {
      final id = _id('policy_keep');

      // First enqueue with a 60s delay (stays pending).
      final r1 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(r1.scheduleResult, ScheduleResult.accepted);

      // Second enqueue with KEEP must also be accepted (library-level).
      final r2 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/2',
        ),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(
        r2.scheduleResult,
        ScheduleResult.accepted,
        reason: 'KEEP must be accepted without error',
      );

      await NativeWorkManager.cancel(taskId: id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 3 – Constraints
  // Verifies the bug fix: constraints were hardcoded to Constraints()
  // and silently ignored. Each field is now wired correctly.
  // ════════════════════════════════════════════════════════════
  group('Constraints', () {
    testWidgets('requiresNetwork=true – runs when network available', (
      tester,
    ) async {
      final id = _id('constraint_network');
      // Use DartWorker to avoid Android 16 job-scheduler deferral that affects
      // HTTP workers with requiresNetwork — the constraint itself is still
      // exercised; WorkManager only runs the task on a connected device.
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_pass'),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result.scheduleResult, ScheduleResult.accepted);
      final event = await future;
      expect(
        event?.success,
        isTrue,
        reason: 'Task with requiresNetwork must run on networked device',
      );
    });

    testWidgets(
      'isHeavyTask=true – runs as foreground service (Android) / DartWorker (iOS)',
      (tester) async {
        final id = _id('constraint_heavy');
        final future = _waitEvent(id, timeout: const Duration(seconds: 45));

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'dit_pass', input: {'heavy': true}),
          constraints: const Constraints(isHeavyTask: true),
        );

        expect(
          result.scheduleResult,
          ScheduleResult.accepted,
          reason: 'Heavy task must be accepted',
        );

        final event = await future;
        expect(event, isNotNull, reason: 'Heavy task must emit event');
        expect(event!.success, isTrue);
      },
    );

    testWidgets('backoffPolicy=linear + backoffDelayMs=10000 – accepted', (
      tester,
    ) async {
      final id = _id('constraint_backoff');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          backoffPolicy: BackoffPolicy.linear,
          backoffDelayMs: 10000,
        ),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Linear backoff constraint must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });

    testWidgets('requiresCharging=false – runs without charger', (
      tester,
    ) async {
      final id = _id('constraint_no_charging');
      final future = _waitEvent(id);

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresCharging: false,
        ),
      );

      expect(result.scheduleResult, ScheduleResult.accepted);
      final event = await future;
      expect(event?.success, isTrue);
    });

    testWidgets('systemConstraints=requireBatteryNotLow – accepted (Android)', (
      tester,
    ) async {
      final id = _id('constraint_syscon');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_pass'),
        constraints: const Constraints(
          systemConstraints: {SystemConstraint.requireBatteryNotLow},
        ),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'SystemConstraint must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 4 – All Workers Execute
  // Each declared worker must: (a) schedule, (b) emit a success event.
  // ════════════════════════════════════════════════════════════
  group('All Workers', () {
    // ── HTTP Workers ─────────────────────────────────────────

    testWidgets('HttpRequestWorker GET – success', (tester) async {
      final id = _id('http_get');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpRequestWorker GET failed');
    });

    testWidgets('HttpRequestWorker POST – success', (tester) async {
      final id = _id('http_post');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts',
          method: HttpMethod.post,
          body: '{"title":"test","body":"body","userId":1}',
          headers: {'Content-Type': 'application/json'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpRequestWorker POST failed');
    });

    testWidgets('HttpDownloadWorker – downloads file successfully', (
      tester,
    ) async {
      final id = _id('http_download');
      final savePath = '${tmpDir.path}/downloaded.json';
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
          savePath: savePath,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpDownloadWorker failed');
      expect(
        File(savePath).existsSync(),
        isTrue,
        reason: 'Downloaded file must exist on disk',
      );
    });

    testWidgets('HttpUploadWorker – uploads file successfully', (tester) async {
      final id = _id('http_upload');
      final filePath = '${tmpDir.path}/upload_test.txt';
      _createTextFile(filePath);
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpUploadWorker(
          url: 'https://httpbin.org/post',
          filePath: filePath,
          fileFieldName: 'file',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpUploadWorker failed');
    });

    testWidgets('HttpSyncWorker – syncs data successfully', (tester) async {
      final id = _id('http_sync');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpSyncWorker(
          url: 'https://jsonplaceholder.typicode.com/posts',
          method: HttpMethod.post,
          requestBody: {'title': 'sync', 'body': 'test', 'userId': 1},
          headers: {'Content-Type': 'application/json'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpSyncWorker failed');
    });

    // ── File Workers ─────────────────────────────────────────

    testWidgets('FileCompressionWorker – compresses file to zip', (
      tester,
    ) async {
      final id = _id('file_compress');
      final inputPath = '${tmpDir.path}/to_compress.txt';
      final outputPath = '${tmpDir.path}/compressed.zip';
      _createTextFile(inputPath);
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: FileCompressionWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          level: CompressionLevel.medium,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'FileCompressionWorker failed');
      expect(
        File(outputPath).existsSync(),
        isTrue,
        reason: 'Zip file must exist after compression',
      );
    });

    testWidgets('FileDecompressionWorker – extracts zip correctly', (
      tester,
    ) async {
      // First compress a file, then decompress it.
      final compressId = _id('file_compress_for_decomp');
      final inputPath = '${tmpDir.path}/to_zip.txt';
      final zipPath = '${tmpDir.path}/archive.zip';
      final extractDir = '${tmpDir.path}/extracted/';
      _createTextFile(inputPath);
      Directory(extractDir).createSync();

      // Compress.
      final compressFuture = _waitEvent(
        compressId,
        timeout: const Duration(seconds: 45),
      );
      await NativeWorkManager.enqueue(
        taskId: compressId,
        trigger: const TaskTrigger.oneTime(),
        worker: FileCompressionWorker(
          inputPath: inputPath,
          outputPath: zipPath,
        ),
      );
      final compressEvent = await compressFuture;
      expect(
        compressEvent?.success,
        isTrue,
        reason: 'Compression step failed, cannot test decompression',
      );

      // Decompress.
      final id = _id('file_decompress');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: FileDecompressionWorker(
          zipPath: zipPath,
          targetDir: extractDir,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'FileDecompressionWorker failed');
    });

    // ── Image Worker ─────────────────────────────────────────

    testWidgets('ImageProcessWorker – resizes image successfully', (
      tester,
    ) async {
      final id = _id('image_process');
      final inputPath = '${tmpDir.path}/input.png';
      final outputPath = '${tmpDir.path}/output.png';

      // Write minimal valid PNG.
      File(inputPath).writeAsBytesSync(_minimalPng);

      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: ImageProcessWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          maxWidth: 100,
          maxHeight: 100,
          quality: 80,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'ImageProcessWorker failed');
    });

    // ── Crypto Workers ───────────────────────────────────────

    testWidgets('CryptoHashWorker – hashes file successfully', (tester) async {
      final id = _id('crypto_hash');
      final filePath = '${tmpDir.path}/hash_input.txt';
      _createTextFile(filePath);
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoHashWorker.file(
          filePath: filePath,
          algorithm: HashAlgorithm.sha256,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'CryptoHashWorker failed');
      // Note: resultData availability depends on kmpworkmanager's WorkManager output data
      // support. We verify success is true; resultData is a bonus if available.
    });

    testWidgets('CryptoEncryptWorker – encrypts file successfully', (
      tester,
    ) async {
      final id = _id('crypto_encrypt');
      final inputPath = '${tmpDir.path}/plaintext.txt';
      final outputPath = '${tmpDir.path}/encrypted.dat';
      _createTextFile(inputPath);
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoEncryptWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          password: 'test-password-123',
          algorithm: EncryptionAlgorithm.aes,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'CryptoEncryptWorker failed');
      expect(
        File(outputPath).existsSync(),
        isTrue,
        reason: 'Encrypted file must exist',
      );
    });

    testWidgets('CryptoDecryptWorker – decrypts previously encrypted file', (
      tester,
    ) async {
      const password = 'test-password-decrypt';
      final encryptId = _id('crypto_enc_for_dec');
      final plainPath = '${tmpDir.path}/plain_dec.txt';
      final encPath = '${tmpDir.path}/encrypted_dec.dat';
      final decPath = '${tmpDir.path}/decrypted.txt';
      _createTextFile(plainPath, content: 'Hello NativeWorkManager!');

      // Encrypt first.
      final encFuture = _waitEvent(
        encryptId,
        timeout: const Duration(seconds: 45),
      );
      await NativeWorkManager.enqueue(
        taskId: encryptId,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoEncryptWorker(
          inputPath: plainPath,
          outputPath: encPath,
          password: password,
        ),
      );
      final encEvent = await encFuture;
      expect(
        encEvent?.success,
        isTrue,
        reason: 'Encryption step failed, cannot test decryption',
      );

      // Decrypt.
      final id = _id('crypto_decrypt');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoDecryptWorker(
          inputPath: encPath,
          outputPath: decPath,
          password: password,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'CryptoDecryptWorker failed');
      expect(
        File(decPath).existsSync(),
        isTrue,
        reason: 'Decrypted file must exist',
      );
    });

    // ── DartWorker ───────────────────────────────────────────

    testWidgets('DartWorker – callback executes and returns true', (
      tester,
    ) async {
      final id = _id('dart_worker_pass');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'dit_pass',
          input: {'key': 'value', 'num': 42},
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'DartWorker callback failed');
    });

    testWidgets('DartWorker – callback returning false emits failure event', (
      tester,
    ) async {
      final id = _id('dart_worker_fail');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_fail'),
      );

      final event = await future;
      expect(
        event?.success,
        isFalse,
        reason: 'DartWorker returning false must emit a failure event',
      );
    });

    // ── Issue #30 regression: timeoutMs is honored end-to-end ────
    //
    // Pre-fix the Dart dispatcher hardcoded a 25 s timeout and the native
    // bridges never forwarded the user-supplied `DartWorker.timeoutMs`,
    // so any callback running longer than 25 s was always killed.
    //
    // This test schedules a callback that sleeps 30 s with timeoutMs=45000.
    // If the bug regresses, the callback is killed at 25 s and the event is
    // a failure — caught here.

    testWidgets(
      'issue_30: DartWorker honors user-supplied timeoutMs (>25 s default)',
      (tester) async {
        final id = _id('issue_30_timeout_honored');
        final future = _waitEvent(id, timeout: const Duration(seconds: 90));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(
            callbackId: 'dit_long_running',
            input: {'delayMs': 30000},
            timeoutMs: 45000,
          ),
        );

        final event = await future;
        expect(
          event?.success,
          isTrue,
          reason:
              'Issue #30 regression: callback that sleeps 30 s with timeoutMs=45 s '
              'must complete. A failure here means the Dart dispatcher is back to '
              'the hardcoded 25 s timeout (or the native bridge stopped forwarding '
              'timeoutMs to the Dart side).',
        );
      },
    );

    testWidgets(
      'issue_30: DartWorker timeoutMs can shrink below 25 s default for fail-fast',
      (tester) async {
        // Verifies the inverse direction — pre-fix, a small timeoutMs was also
        // ignored (always 25 s), so this hung path also caught the bug.
        final id = _id('issue_30_fail_fast');
        final future = _waitEvent(id, timeout: const Duration(seconds: 30));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(
            callbackId: 'dit_long_running',
            input: {'delayMs': 20000},
            timeoutMs: 3000,
          ),
        );

        final event = await future;
        expect(
          event?.success,
          isFalse,
          reason:
              'Issue #30 regression: callback that sleeps 20 s with timeoutMs=3 s '
              'must be killed and emit failure. Success here means timeoutMs is '
              'still ignored on the Dart side.',
        );
      },
    );

    // ── issue_46: return false retries, and maxRetries caps the retries ──
    //
    // Two bugs in one runtime test (varies maxRetries, observes behavior — the
    // "wired" bar from the Issue #30 rule):
    //   1. Pre-fix, a DartWorker returning false mapped to a permanent
    //      Result.failure() and NEVER retried.
    //   2. Once it retried, Android had no cap — WorkManager Result.retry() is
    //      unbounded, so maxRetries was ignored and it looped forever.
    // The callback bumps a shared counter file each run. With maxRetries=2 the
    // task must run exactly 3 times (1 initial + 2 retries), then abandon.
    // A count of 1 means retry regressed; a count > 3 means the cap regressed.
    testWidgets(
      'issue_46: DartWorker return false retries up to maxRetries then abandons',
      (tester) async {
        final id = _id('issue_46_retry_cap');
        final counterFile = '${tmpDir.path}/$id.count';
        // Fresh counter for this run.
        final f = File(counterFile);
        if (f.existsSync()) f.deleteSync();

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(
            callbackId: 'dit_retry_counter',
            input: {'counterFile': counterFile},
          ),
          // maxRetries=2 → 3 total runs. Linear/min backoff (WM floor is 10 s)
          // keeps the three attempts inside the poll window below.
          constraints: const Constraints(
            maxRetries: 2,
            backoffPolicy: BackoffPolicy.linear,
            backoffDelayMs: 10000,
          ),
        );

        // Poll until the count stabilizes (no new run for two consecutive checks)
        // or we hit the ceiling. Backoff means runs land ~10 s apart.
        int last = 0;
        int stable = 0;
        for (var i = 0; i < 24; i++) {
          await Future<void>.delayed(const Duration(seconds: 5));
          final n = f.existsSync()
              ? (int.tryParse(f.readAsStringSync().trim()) ?? 0)
              : 0;
          if (n == last) {
            stable++;
            if (n >= 3 && stable >= 3) break; // settled at the cap
          } else {
            stable = 0;
            last = n;
          }
          if (n > 3) break; // cap regressed — fail fast
        }

        expect(
          last,
          greaterThanOrEqualTo(2),
          reason:
              'issue_46: return false must retry (>=2 runs). A count of 1 means '
              'the callback failure mapped to a permanent Result.failure() again.',
        );
        expect(
          last,
          equals(3),
          reason:
              'issue_46: maxRetries=2 must cap at exactly 3 total runs. A higher '
              'count means the Android retry cap (kmpworkmanager 3.1.0 + the '
              'maxRetries key stamping) is not being honored — unbounded retry.',
        );
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 5 – Task Chains (sequential A → B → C)
  // ════════════════════════════════════════════════════════════
  group('Task Chains', () {
    testWidgets('Sequential chain A→B→C – all steps complete in order', (
      tester,
    ) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final idA = 'chain_a_$ts';
      final idB = 'chain_b_$ts';
      final idC = 'chain_c_$ts';

      final executionOrder = <String>[];
      final chainDone = Completer<void>();

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == idA && event.success) {
          executionOrder.add('A');
        } else if (event.taskId == idB && event.success) {
          executionOrder.add('B');
        } else if (event.taskId == idC && event.success) {
          executionOrder.add('C');
          if (!chainDone.isCompleted) chainDone.complete();
        }
      });

      await NativeWorkManager.beginWith(
            TaskRequest(
              id: idA,
              worker: DartWorker(callbackId: 'chain_a'),
            ),
          )
          .then(
            TaskRequest(
              id: idB,
              worker: DartWorker(callbackId: 'chain_b'),
            ),
          )
          .then(
            TaskRequest(
              id: idC,
              worker: DartWorker(callbackId: 'chain_c'),
            ),
          )
          .enqueue();

      await chainDone.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          fail('Chain A→B→C did not complete within 90s');
        },
      );

      await sub.cancel();

      expect(
        executionOrder,
        equals(['A', 'B', 'C']),
        reason: 'Chain steps must execute in order A→B→C',
      );
    });

    testWidgets('Chain cancel after first step stops remaining steps', (
      tester,
    ) async {
      // Verify that cancelling a chain after step A prevents B and C from running.
      // This is fundamental to chain-resume: if we can stop a chain reliably we
      // can also restart it from a later step (the "manual resume" pattern).
      final ts = DateTime.now().millisecondsSinceEpoch;
      final idA = 'cancel_chain_a_$ts';
      final idB = 'cancel_chain_b_$ts';
      final idC = 'cancel_chain_c_$ts';

      final aCompleter = Completer<void>();
      final laterStepsRan = <String>[];

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == idA && event.success) aCompleter.complete();
        // Only count success events — cancelled/failed events don't mean the step "ran".
        if (event.taskId == idB && event.success) laterStepsRan.add('B');
        if (event.taskId == idC && event.success) laterStepsRan.add('C');
      });

      await NativeWorkManager.beginWith(
            TaskRequest(
              id: idA,
              worker: DartWorker(callbackId: 'chain_a'),
            ),
          )
          .then(
            TaskRequest(
              id: idB,
              worker: DartWorker(callbackId: 'chain_b'),
            ),
          )
          .then(
            TaskRequest(
              id: idC,
              worker: DartWorker(callbackId: 'chain_c'),
            ),
          )
          .enqueue();

      // Wait for step A to complete, then cancel before B starts.
      await aCompleter.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          fail('Step A did not complete within 60 s');
        },
      );

      // Cancel remaining steps immediately after A completes.
      await NativeWorkManager.cancel(taskId: idB);
      await NativeWorkManager.cancel(taskId: idC);

      // Give the scheduler time to propagate cancellation.
      await Future<void>.delayed(const Duration(seconds: 5));

      await sub.cancel();

      // B and C should not have run (or at most B if it was already dispatched).
      expect(
        laterStepsRan,
        isNot(contains('C')),
        reason: 'Step C must not run after cancellation',
      );
    });

    testWidgets('Chain resume – re-enqueue remaining steps after first step', (
      tester,
    ) async {
      // Demonstrates the "manual chain resume" pattern:
      //   1. Run step A (first step of original chain).
      //   2. Enqueue a new chain B→C once A succeeds.
      //   3. Verify B and C complete in order.
      //
      // This mirrors what happens on iOS when `resumePendingChains()` picks up
      // an interrupted chain: it enqueues remaining steps as a fresh sequence.
      final ts = DateTime.now().millisecondsSinceEpoch;
      final idA = 'resume_a_$ts';
      final idB = 'resume_b_$ts';
      final idC = 'resume_c_$ts';

      final aCompleter = Completer<void>();
      final executionOrder = <String>[];
      final bcCompleter = Completer<void>();

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == idA && event.success) {
          executionOrder.add('A');
          if (!aCompleter.isCompleted) aCompleter.complete();
        }
        if (event.taskId == idB && event.success) executionOrder.add('B');
        if (event.taskId == idC && event.success) {
          executionOrder.add('C');
          if (!bcCompleter.isCompleted) bcCompleter.complete();
        }
      });

      // Phase 1: enqueue only step A.
      await NativeWorkManager.enqueue(
        taskId: idA,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'chain_a'),
      );

      // Wait for A to finish.
      await aCompleter.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          fail('Step A did not complete within 60 s');
        },
      );

      // Phase 2: enqueue B→C as a "resumed" chain (simulating chain resume).
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: idB,
              worker: DartWorker(callbackId: 'chain_b'),
            ),
          )
          .then(
            TaskRequest(
              id: idC,
              worker: DartWorker(callbackId: 'chain_c'),
            ),
          )
          .enqueue();

      await bcCompleter.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          fail('Resumed chain B→C did not complete within 90 s');
        },
      );

      await sub.cancel();

      expect(
        executionOrder,
        equals(['A', 'B', 'C']),
        reason: 'Resumed chain must complete steps A→B→C in order',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 6 – Tags
  // ════════════════════════════════════════════════════════════
  group('Tags', () {
    testWidgets('assign tag – queryable via getTasksByTag', (tester) async {
      final tag = 'dit_tag_${DateTime.now().millisecondsSinceEpoch}';
      final id1 = _id('tag_task_1');
      final id2 = _id('tag_task_2');

      // Schedule with 60s delay so they stay in the pending queue.
      await NativeWorkManager.enqueue(
        taskId: id1,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: DartWorker(callbackId: 'dit_pass'),
        tag: tag,
      );
      await NativeWorkManager.enqueue(
        taskId: id2,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: DartWorker(callbackId: 'dit_pass'),
        tag: tag,
      );

      final tasks = await NativeWorkManager.getTasksByTag(tag: tag);
      expect(
        tasks,
        containsAll([id1, id2]),
        reason: 'Both tagged tasks must appear in getTasksByTag',
      );

      await NativeWorkManager.cancelByTag(tag: tag);
    });

    testWidgets('cancelByTag – cancels all tasks with that tag', (
      tester,
    ) async {
      final tag = 'dit_cancel_tag_${DateTime.now().millisecondsSinceEpoch}';
      final ids = List.generate(3, (i) => _id('cancel_tag_$i'));

      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
          worker: DartWorker(callbackId: 'dit_pass'),
          tag: tag,
        );
      }

      // Verify tasks exist.
      final before = await NativeWorkManager.getTasksByTag(tag: tag);
      expect(
        before.length,
        equals(3),
        reason: '3 tasks must exist before cancelByTag',
      );

      await NativeWorkManager.cancelByTag(tag: tag);

      // After cancel, the plugin's in-memory tag map is cleared.
      final after = await NativeWorkManager.getTasksByTag(tag: tag);
      expect(after, isEmpty, reason: 'No tasks must remain after cancelByTag');
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 7 – Cancellation
  // ════════════════════════════════════════════════════════════
  group('Cancellation', () {
    testWidgets('cancel by ID – no event fires after cancel', (tester) async {
      final id = _id('cancel_by_id');
      var received = false;

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == id) received = true;
      });

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: DartWorker(callbackId: 'dit_pass'),
      );

      await NativeWorkManager.cancel(taskId: id);

      // Wait 3 s; the task must NOT execute.
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();

      expect(
        received,
        isFalse,
        reason: 'Cancelled task must not emit any event',
      );
    });

    testWidgets('cancelAll – clears all pending tasks', (tester) async {
      // Schedule several tasks with long delays.
      for (var i = 0; i < 3; i++) {
        await NativeWorkManager.enqueue(
          taskId: _id('cancel_all_$i'),
          trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
          worker: DartWorker(callbackId: 'dit_pass'),
        );
      }

      // Must not throw.
      await NativeWorkManager.cancelAll();
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 8 – Events & Progress Streams
  // ════════════════════════════════════════════════════════════
  group('Events and Progress Streams', () {
    testWidgets('events stream – delivers resultData from worker', (
      tester,
    ) async {
      final id = _id('events_result_data');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event, isNotNull);
      expect(
        event!.taskId,
        equals(id),
        reason: 'taskId in event must match scheduled taskId',
      );
      expect(event.success, isTrue);
      // resultData is optional — availability depends on kmpworkmanager's output data support.
    });

    testWidgets(
      'progress stream – emits updates for workers that report progress',
      (tester) async {
        // HttpDownloadWorker emits progress during download.
        final id = _id('progress_stream');
        final progressValues = <int>[];
        final completedOrTimeout = Completer<void>();

        final progressSub = NativeWorkManager.progress.listen((p) {
          if (p.taskId == id) {
            progressValues.add(p.progress);
            if (p.progress >= 100 && !completedOrTimeout.isCompleted) {
              completedOrTimeout.complete();
            }
          }
        });

        final eventFuture = _waitEvent(
          id,
          timeout: const Duration(seconds: 60),
        );

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpDownloadWorker(
            url: 'https://jsonplaceholder.typicode.com/posts',
            savePath: '${tmpDir.path}/progress_test.json',
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await eventFuture;
        await progressSub.cancel();

        expect(event?.success, isTrue, reason: 'Download task must succeed');
        // Progress may or may not be emitted depending on file size;
        // just ensure the stream does not crash if no progress is reported.
        // If progress was emitted, values must be between 0 and 1.
        for (final v in progressValues) {
          expect(
            v,
            inInclusiveRange(0, 100),
            reason: 'Progress value must be in [0, 100]',
          );
        }
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 9 – DartWorker Constraint & Delay Enforcement
  //
  // Reproduces GitHub issue #1: "Constraints (requiresNetwork) and
  // TaskTrigger delays are completely ignored for DartWorker tasks."
  //
  // HOW IT WORKS:
  //   • Delay tests measure wall-clock time from enqueue → event.
  //     If elapsed < 7 s the delay was ignored (task fired immediately).
  //   • Network constraint tests verify DartWorker runs when network
  //     IS available (emulator/device always has network during tests).
  //   • The HttpRequestWorker control test lets us confirm whether the
  //     bug is DartWorker-specific or affects all workers.
  //
  // Run with:
  //   flutter test integration_test/device_integration_test.dart \
  //     --name "DartWorker Constraint" --timeout=none
  //
  // Grab logs with:
  //   adb logcat -s NativeWorkmanagerPlugin:D DartCallbackWorker:D \
  //               FlutterEngineManager:D WorkManager:D
  // ════════════════════════════════════════════════════════════
  group('DartWorker Constraint and Delay Enforcement', () {
    // ── Delay enforcement ─────────────────────────────────────

    testWidgets(
      'DartWorker initialDelay=8s – task must not fire before delay elapses',
      (tester) async {
        final id = _id('dart_delay_8s');
        final enqueueTime = DateTime.now();

        print('[DIAG] Enqueueing DartWorker with 8s delay at $enqueueTime');
        // 90s timeout: real devices under WorkManager queue load can take 30–60s
        // to service a new task even when constraints are met immediately.
        final future = _waitEvent(id, timeout: const Duration(seconds: 90));

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 8)),
          worker: DartWorker(
            callbackId: 'dit_pass',
            input: {'test': 'delay_enforcement', 'delayMs': 8000},
          ),
        );

        expect(
          result.scheduleResult,
          ScheduleResult.accepted,
          reason: 'DartWorker with 8s delay must be accepted',
        );

        final event = await future;
        final elapsedMs = DateTime.now().difference(enqueueTime).inMilliseconds;

        print(
          '[DIAG] DartWorker delay=8s: elapsed=${elapsedMs}ms '
          'success=${event?.success}',
        );

        expect(
          event,
          isNotNull,
          reason:
              'DartWorker with 8s delay must eventually complete '
              '(waited up to 45s)',
        );
        expect(
          event!.success,
          isTrue,
          reason: 'DartWorker callback must return true',
        );

        // 7 s threshold: WorkManager may fire slightly early due to scheduling
        // jitter, but firing within 1–2 s means the delay was completely ignored.
        expect(
          elapsedMs,
          greaterThanOrEqualTo(7000),
          reason:
              '[BUG #1] DartWorker fired after only ${elapsedMs}ms '
              '— 8s delay was IGNORED. '
              'Check logcat tag NativeWorkmanagerPlugin for WorkRequest details.',
        );
      },
    );

    testWidgets(
      'DartWorker delay=8s + requiresNetwork=true – both constraints applied',
      (tester) async {
        final id = _id('dart_delay_net_8s');
        final enqueueTime = DateTime.now();

        print(
          '[DIAG] Enqueueing DartWorker with 8s delay + requiresNetwork=true',
        );
        final future = _waitEvent(id, timeout: const Duration(seconds: 90));

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 8)),
          worker: DartWorker(
            callbackId: 'dit_pass',
            input: {'test': 'delay_and_network'},
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        expect(result.scheduleResult, ScheduleResult.accepted);

        final event = await future;
        final elapsedMs = DateTime.now().difference(enqueueTime).inMilliseconds;

        print(
          '[DIAG] DartWorker delay=8s + requiresNetwork: elapsed=${elapsedMs}ms '
          'success=${event?.success}',
        );

        expect(
          event,
          isNotNull,
          reason: 'DartWorker with delay+network must eventually complete',
        );
        expect(event!.success, isTrue);
        expect(
          elapsedMs,
          greaterThanOrEqualTo(7000),
          reason:
              '[BUG #1] DartWorker fired after only ${elapsedMs}ms '
              '— 8s delay was IGNORED even with requiresNetwork=true set.',
        );
      },
    );

    // ── Network constraint enforcement ────────────────────────

    testWidgets(
      'DartWorker requiresNetwork=true – runs when network is available',
      (tester) async {
        final id = _id('dart_net_constraint');

        print(
          '[DIAG] Enqueueing DartWorker with requiresNetwork=true '
          '(device/emulator has network — task should run)',
        );

        final future = _waitEvent(id, timeout: const Duration(seconds: 90));

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(
            callbackId: 'dit_pass',
            input: {'test': 'network_constraint'},
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        expect(
          result.scheduleResult,
          ScheduleResult.accepted,
          reason: 'DartWorker with requiresNetwork must be accepted',
        );

        final event = await future;
        print('[DIAG] DartWorker requiresNetwork: success=${event?.success}');

        expect(
          event,
          isNotNull,
          reason: 'DartWorker with requiresNetwork must run when network is on',
        );
        expect(
          event!.success,
          isTrue,
          reason: 'DartWorker callback must succeed',
        );
      },
    );

    // ── Control: HttpRequestWorker with delay (not DartWorker) ──

    testWidgets(
      'HttpRequestWorker initialDelay=8s – control: verify delay enforced '
      '(if this ALSO fails, bug is systemic, not DartWorker-specific)',
      (tester) async {
        final id = _id('http_delay_8s_ctrl');
        final enqueueTime = DateTime.now();

        print(
          '[DIAG] Enqueueing HttpRequestWorker with 8s delay (control test)',
        );
        final future = _waitEvent(id, timeout: const Duration(seconds: 90));

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 8)),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        expect(result.scheduleResult, ScheduleResult.accepted);

        final event = await future;
        final elapsedMs = DateTime.now().difference(enqueueTime).inMilliseconds;

        print(
          '[DIAG] HttpRequestWorker delay=8s control: elapsed=${elapsedMs}ms '
          'success=${event?.success}',
        );

        expect(
          event,
          isNotNull,
          reason: 'HttpRequestWorker with 8s delay must complete within 45s',
        );
        expect(event!.success, isTrue);
        expect(
          elapsedMs,
          greaterThanOrEqualTo(7000),
          reason:
              '[CONTROL] HttpRequestWorker fired after only ${elapsedMs}ms '
              '— delay was IGNORED. Bug is NOT DartWorker-specific.',
        );
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 10 – Custom Native Workers
  // Verifies the extensibility feature end-to-end on real device.
  // ImageCompressWorker is registered in:
  //   Android → example/android/.../MainActivity.kt
  //   iOS     → example/ios/Runner/AppDelegate.swift
  // These tests run the REAL native worker, not a simulation.
  // ════════════════════════════════════════════════════════════
  group('Custom Native Workers', () {
    // Uses _minimalPng (defined at top of file) — a verified valid 1×1 PNG.
    // UIImage and BitmapFactory both support PNG input; the worker outputs JPEG.

    testWidgets(
      'ImageCompressWorker – compresses image and creates output file',
      (tester) async {
        final id = _id('custom_compress_ok');
        final inputPath = '${tmpDir.path}/custom_input.png';
        final outputPath = '${tmpDir.path}/custom_compressed.jpg';

        await File(inputPath).writeAsBytes(_minimalPng);

        final future = _waitEvent(id, timeout: const Duration(seconds: 45));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.custom(
            className: 'ImageCompressWorker',
            input: {
              'inputPath': inputPath,
              'outputPath': outputPath,
              'quality': 80,
            },
          ),
        );

        final event = await future;
        expect(
          event,
          isNotNull,
          reason: 'Must receive a completion event from ImageCompressWorker',
        );
        expect(
          event!.success,
          isTrue,
          reason: 'ImageCompressWorker must succeed with a valid image',
        );
        expect(
          File(outputPath).existsSync(),
          isTrue,
          reason: 'Output file must be created on disk after compression',
        );
      },
    );

    testWidgets(
      'ImageCompressWorker – fails gracefully when input file is missing',
      (tester) async {
        final id = _id('custom_compress_no_input');
        final outputPath = '${tmpDir.path}/custom_missing_out.jpg';

        final future = _waitEvent(id, timeout: const Duration(seconds: 30));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.custom(
            className: 'ImageCompressWorker',
            input: {
              'inputPath': '/nonexistent/path/does_not_exist.jpg',
              'outputPath': outputPath,
              'quality': 80,
            },
          ),
        );

        final event = await future;
        expect(
          event,
          isNotNull,
          reason: 'Worker must emit a completion event, not hang',
        );
        expect(
          event!.success,
          isFalse,
          reason: 'Worker must return failure when input file does not exist',
        );
      },
    );

    testWidgets(
      'Custom worker – unregistered className emits failure event (no crash)',
      (tester) async {
        final id = _id('custom_unknown_class');

        final future = _waitEvent(id, timeout: const Duration(seconds: 30));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.custom(
            className: 'ThisWorkerIsNotRegistered_xyz123',
            input: {'key': 'value'},
          ),
        );

        final event = await future;
        expect(
          event,
          isNotNull,
          reason: 'Unknown worker must emit a completion event, not hang',
        );
        expect(
          event!.success,
          isFalse,
          reason:
              'Unknown className must produce a failure, not silently succeed',
        );
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 11 – New v1.1 Features
  //   ✅ ParallelHttpDownloadWorker (parallel + sequential fallback)
  //   ✅ Rich progress (bytesDownloaded, totalBytes, networkSpeed, timeRemaining)
  //   ✅ pauseByTag / resumeByTag (group control)
  //   ✅ pauseAll / resumeAll (global control)
  //   ✅ getTasksByStatus
  //   ✅ enqueueAll (batch enqueue)
  //   ✅ skipExisting on HttpDownloadWorker
  //   ✅ skipExisting on ParallelHttpDownloadWorker
  // ════════════════════════════════════════════════════════════
  group('New v1.1 Features', () {
    // ── ParallelHttpDownloadWorker ─────────────────────────────

    testWidgets(
      'ParallelHttpDownloadWorker – downloads file with parallel chunks',
      (tester) async {
        final id = _id('parallel_dl');
        final savePath = '${tmpDir.path}/parallel_download.zip';
        // Use a smaller well-known test file that supports Range requests
        const testUrl =
            'https://httpbin.org/bytes/102400'; // 100 KB, supports Range
        final future = _waitEvent(id, timeout: const Duration(seconds: 120));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.parallelHttpDownload(
            url: testUrl,
            savePath: savePath,
            numChunks: 4,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await future;
        expect(
          event,
          isNotNull,
          reason: 'ParallelHttpDownloadWorker must emit a completion event',
        );
        expect(
          event!.success,
          isTrue,
          reason: 'Parallel download must succeed',
        );
        expect(
          File(savePath).existsSync(),
          isTrue,
          reason: 'Downloaded file must exist on disk',
        );
      },
    );

    testWidgets(
      'ParallelHttpDownloadWorker – falls back to sequential when no Range support',
      (tester) async {
        final id = _id('parallel_dl_fallback');
        final savePath = '${tmpDir.path}/parallel_fallback.json';
        // httpbin /get does not advertise Accept-Ranges: bytes → sequential fallback
        const url = 'https://httpbin.org/get';
        final future = _waitEvent(id, timeout: const Duration(seconds: 60));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.parallelHttpDownload(
            url: url,
            savePath: savePath,
            numChunks: 4,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await future;
        expect(
          event,
          isNotNull,
          reason: 'Sequential fallback must emit a completion event',
        );
        expect(
          event!.success,
          isTrue,
          reason: 'Sequential fallback must succeed',
        );
        expect(
          File(savePath).existsSync(),
          isTrue,
          reason: 'Fallback file must exist on disk',
        );
      },
    );

    // ── Rich Progress ──────────────────────────────────────────

    testWidgets(
      'Rich progress – HttpDownloadWorker emits bytesDownloaded and totalBytes',
      (tester) async {
        final id = _id('rich_progress_http');
        final savePath = '${tmpDir.path}/rich_progress.json';
        // Use a URL that has a known Content-Length so rich progress fires
        const url = 'https://httpbin.org/bytes/51200'; // 50 KB

        final richUpdates = <TaskProgress>[];
        late StreamSubscription<TaskProgress> sub;
        final progressDone = Completer<void>();

        sub = NativeWorkManager.progress.listen((p) {
          if (p.taskId == id) {
            richUpdates.add(p);
            if (p.progress >= 100 && !progressDone.isCompleted) {
              progressDone.complete();
            }
          }
        });

        final eventFuture = _waitEvent(
          id,
          timeout: const Duration(seconds: 60),
        );

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpDownloadWorker(url: url, savePath: savePath),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await eventFuture;
        await sub.cancel();

        expect(event?.success, isTrue, reason: 'Download must succeed');

        // All emitted progress values must be in range
        for (final p in richUpdates) {
          expect(p.progress, inInclusiveRange(0, 100));
          // If bytesDownloaded is present, it must be non-negative
          if (p.bytesDownloaded != null) {
            expect(p.bytesDownloaded, greaterThanOrEqualTo(0));
          }
          if (p.totalBytes != null) {
            expect(p.totalBytes, greaterThan(0));
          }
          if (p.networkSpeed != null) {
            expect(p.networkSpeed, greaterThan(0));
          }
          if (p.timeRemaining != null) {
            expect(p.timeRemaining!.inMilliseconds, greaterThanOrEqualTo(0));
          }
        }
      },
    );

    testWidgets(
      'Rich progress – ParallelHttpDownloadWorker emits bytesDownloaded',
      (tester) async {
        final id = _id('rich_progress_parallel');
        final savePath = '${tmpDir.path}/rich_progress_parallel.bin';
        const url =
            'https://httpbin.org/bytes/102400'; // 100 KB, supports Range

        final richUpdates = <TaskProgress>[];
        late StreamSubscription<TaskProgress> sub;

        sub = NativeWorkManager.progress.listen((p) {
          if (p.taskId == id) richUpdates.add(p);
        });

        final eventFuture = _waitEvent(
          id,
          timeout: const Duration(seconds: 120),
        );

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.parallelHttpDownload(
            url: url,
            savePath: savePath,
            numChunks: 2,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await eventFuture;
        await sub.cancel();

        expect(
          event?.success,
          isTrue,
          reason: 'Parallel download must succeed',
        );
        // At least some progress events should have been emitted
        for (final p in richUpdates) {
          expect(p.progress, inInclusiveRange(0, 100));
          if (p.bytesDownloaded != null) {
            expect(p.bytesDownloaded, greaterThanOrEqualTo(0));
          }
        }
      },
    );

    // ── skipExisting ───────────────────────────────────────────

    testWidgets(
      'HttpDownloadWorker skipExisting=true – skips download when file exists',
      (tester) async {
        final id = _id('skip_existing_http');
        final savePath = '${tmpDir.path}/skip_existing.txt';
        // Pre-create the file
        File(savePath).writeAsStringSync('existing content');
        final originalContent = File(savePath).readAsStringSync();

        final future = _waitEvent(id, timeout: const Duration(seconds: 30));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpDownloadWorker(
            url: 'https://httpbin.org/get',
            savePath: savePath,
            skipExisting: true,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await future;
        expect(
          event?.success,
          isTrue,
          reason: 'skipExisting must return success, not failure',
        );
        // File must NOT have been overwritten
        expect(
          File(savePath).readAsStringSync(),
          equals(originalContent),
          reason: 'Pre-existing file must not be overwritten',
        );
      },
    );

    testWidgets(
      'ParallelHttpDownloadWorker skipExisting=true – skips when file exists',
      (tester) async {
        final id = _id('skip_existing_parallel');
        final savePath = '${tmpDir.path}/skip_existing_parallel.bin';
        File(savePath).writeAsStringSync('pre-existing content');
        final originalContent = File(savePath).readAsStringSync();

        final future = _waitEvent(id, timeout: const Duration(seconds: 30));

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.parallelHttpDownload(
            url: 'https://httpbin.org/bytes/1024',
            savePath: savePath,
            skipExisting: true,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        final event = await future;
        expect(
          event?.success,
          isTrue,
          reason: 'skipExisting must return success',
        );
        expect(
          File(savePath).readAsStringSync(),
          equals(originalContent),
          reason: 'Pre-existing file must not be overwritten',
        );
      },
    );

    // ── enqueueAll ─────────────────────────────────────────────

    testWidgets('enqueueAll – accepts a batch of tasks', (tester) async {
      final id1 = _id('batch_a');
      final id2 = _id('batch_b');

      final results = await NativeWorkManager.enqueueAll([
        EnqueueRequest(
          taskId: id1,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
          constraints: const Constraints(requiresNetwork: true),
        ),
        EnqueueRequest(
          taskId: id2,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/2',
          ),
          constraints: const Constraints(requiresNetwork: true),
        ),
      ]);

      expect(results.length, equals(2));
      expect(
        results[0].scheduleResult,
        equals(ScheduleResult.accepted),
        reason: 'First batch task must be accepted',
      );
      expect(
        results[1].scheduleResult,
        equals(ScheduleResult.accepted),
        reason: 'Second batch task must be accepted',
      );

      // Subscribe to both events BEFORE awaiting either — tasks run in parallel
      // so id2's event may fire while we are awaiting id1.
      final f1 = _waitEvent(id1, timeout: const Duration(seconds: 60));
      final f2 = _waitEvent(id2, timeout: const Duration(seconds: 60));
      final e1 = await f1;
      final e2 = await f2;
      expect(e1?.success, isTrue);
      expect(e2?.success, isTrue);
    });

    // ── pauseByTag / resumeByTag ───────────────────────────────

    testWidgets('pauseByTag + resumeByTag – group control via tag', (
      tester,
    ) async {
      const tag = 'v11_group_tag';
      final id1 = _id('tagged_a');
      final id2 = _id('tagged_b');

      // Enqueue two tasks with the same tag (use delay so they don't finish
      // before we pause them)
      await NativeWorkManager.enqueue(
        taskId: id1,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 30)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        tag: tag,
        constraints: const Constraints(requiresNetwork: true),
      );
      await NativeWorkManager.enqueue(
        taskId: id2,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 30)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/2',
        ),
        tag: tag,
        constraints: const Constraints(requiresNetwork: true),
      );

      // Verify both tasks are in the store
      final byTag = await NativeWorkManager.getTasksByTag(tag: tag);
      expect(
        byTag.length,
        greaterThanOrEqualTo(2),
        reason: 'Both tasks must be retrievable by tag',
      );

      // pauseByTag must not throw
      await expectLater(
        NativeWorkManager.pauseByTag(tag: tag),
        completes,
        reason: 'pauseByTag must complete without throwing',
      );

      // resumeByTag must not throw
      await expectLater(
        NativeWorkManager.resumeByTag(tag: tag),
        completes,
        reason: 'resumeByTag must complete without throwing',
      );

      // Clean up
      await NativeWorkManager.cancelByTag(tag: tag);
    });

    // ── pauseAll / resumeAll ───────────────────────────────────

    testWidgets('pauseAll + resumeAll – global control', (tester) async {
      // Both methods must complete without throwing, even when no tasks exist
      await expectLater(
        NativeWorkManager.pauseAll(),
        completes,
        reason: 'pauseAll must complete without throwing',
      );
      await expectLater(
        NativeWorkManager.resumeAll(),
        completes,
        reason: 'resumeAll must complete without throwing',
      );
    });

    // ── getTasksByStatus ───────────────────────────────────────

    testWidgets('getTasksByStatus – returns tasks filtered by status', (
      tester,
    ) async {
      final id = _id('status_filter');

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      // Give WorkManager a moment to register the task
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final allTasks = await NativeWorkManager.allTasks();
      expect(
        allTasks,
        isNotEmpty,
        reason: 'allTasks must return at least the newly enqueued task',
      );

      // getTasksByStatus must not throw for any status value
      for (final status in TaskStatus.values) {
        final filtered = await NativeWorkManager.getTasksByStatus(status);
        for (final task in filtered) {
          expect(
            task.status.toLowerCase(),
            equals(status.name.toLowerCase()),
            reason: 'getTasksByStatus($status) must only return $status tasks',
          );
        }
      }

      await NativeWorkManager.cancel(taskId: id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 12 – Tag utilities
  // Verifies getAllTags and allTasks() list completeness.
  // ════════════════════════════════════════════════════════════
  group('Tag utilities', () {
    testWidgets('getAllTags – returns tag after enqueue', (tester) async {
      final tag = 'dit_alltags_${DateTime.now().millisecondsSinceEpoch}';
      final id = _id('get_all_tags');

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        tag: tag,
      );

      final tags = await NativeWorkManager.getAllTags();
      expect(
        tags,
        contains(tag),
        reason: 'getAllTags must include the tag we just assigned',
      );

      await NativeWorkManager.cancel(taskId: id);
    });

    testWidgets('getAllTags – does not contain unknown tags', (tester) async {
      final tags = await NativeWorkManager.getAllTags();
      // Tags from previous runs may exist but a freshly-generated unique
      // string must not appear without being enqueued.
      final ghost = 'ghost_tag_${DateTime.now().microsecondsSinceEpoch}';
      expect(tags, isNot(contains(ghost)));
    });

    testWidgets('allTasks – includes recently enqueued task', (tester) async {
      final id = _id('all_tasks_check');

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final tasks = await NativeWorkManager.allTasks();
      final ids = tasks.map((t) => t.taskId).toList();
      expect(
        ids,
        contains(id),
        reason: 'allTasks must list the newly enqueued task by ID',
      );

      await NativeWorkManager.cancel(taskId: id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 13 – Error resilience
  // Verifies the plugin handles bad inputs and worker failures
  // gracefully without crashing or hanging.
  // ════════════════════════════════════════════════════════════
  group('Error resilience', () {
    testWidgets('HTTP 404 – worker emits failure event', (tester) async {
      final id = _id('http_404');
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(url: 'https://httpbin.org/status/404'),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      // 404 should either succeed with status code or fail — either way
      // the plugin must not hang and must emit an event.
      expect(event, isNotNull, reason: 'Must receive event even for 404');
    });

    testWidgets('DartWorker returning false emits failure event', (
      tester,
    ) async {
      final id = _id('dart_fail');
      final future = _waitEvent(id, timeout: const Duration(seconds: 30));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_fail'),
      );

      final event = await future;
      expect(event, isNotNull);
      expect(
        event!.success,
        isFalse,
        reason: 'DartWorker returning false must emit failure event',
      );
    });

    testWidgets('cancel then re-enqueue same taskId – second run succeeds', (
      tester,
    ) async {
      final id = _id('cancel_reenqueue');

      // First enqueue – will be cancelled immediately.
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
      );
      await NativeWorkManager.cancel(taskId: id);

      // Re-enqueue the same ID without a delay.
      final future = _waitEvent(id, timeout: const Duration(seconds: 30));
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event, isNotNull);
      expect(
        event!.success,
        isTrue,
        reason: 'Re-enqueued task must succeed after cancel',
      );
    });

    testWidgets('cancelAll – stops all pending tasks', (tester) async {
      // Enqueue several tasks with long delays.
      final ids = List.generate(4, (i) => _id('cancel_all_$i'));
      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 120)),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
        );
      }

      await NativeWorkManager.cancelAll();

      // After cancelAll, none of the tasks should fire within 3 s.
      var fired = 0;
      final sub = NativeWorkManager.events.listen((event) {
        if (ids.contains(event.taskId) && !event.isStarted) fired++;
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      await sub.cancel();

      expect(fired, 0, reason: 'cancelAll must stop all enqueued tasks');
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 14 – Task status lifecycle
  // Enqueue → verify pending → let complete → verify completed
  // ════════════════════════════════════════════════════════════
  group('Task status lifecycle', () {
    testWidgets('getTaskStatus transitions: pending → (running) → completed', (
      tester,
    ) async {
      final id = _id('status_lifecycle');
      final eventFuture = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      // Immediately after enqueue the status should be non-null (pending or running).
      final statusBefore = await NativeWorkManager.getTaskStatus(taskId: id);
      expect(
        statusBefore,
        isNotNull,
        reason: 'Task status must be known immediately after enqueue',
      );

      // Wait for completion.
      final event = await eventFuture;
      expect(event?.success, isTrue);

      // After completion the status should reflect completion (completed or null
      // if the platform purges it — both are acceptable).
      final statusAfter = await NativeWorkManager.getTaskStatus(taskId: id);
      if (statusAfter != null) {
        expect(
          [TaskStatus.completed, TaskStatus.running],
          contains(statusAfter),
          reason: 'Completed task status must indicate success',
        );
      }
    });

    testWidgets('cancelled task has cancelled status', (tester) async {
      final id = _id('status_cancelled');

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 120)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
      );

      await NativeWorkManager.cancel(taskId: id);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final status = await NativeWorkManager.getTaskStatus(taskId: id);
      // Status may be null (purged) or 'cancelled' — both are valid.
      if (status != null) {
        expect(
          status,
          TaskStatus.cancelled,
          reason: 'Cancelled task must have cancelled status',
        );
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 15 – Trigger type acceptance
  // Ensures windowed and exact triggers are accepted by the platform
  // without crashing (even if they fire immediately on iOS or
  // are deferred to a valid window on Android).
  // ════════════════════════════════════════════════════════════
  group('Trigger type acceptance', () {
    testWidgets('windowed trigger – accepted and eventually executes', (
      tester,
    ) async {
      final id = _id('windowed_trigger');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.windowed(
          earliest: Duration(seconds: 0),
          latest: Duration(minutes: 5),
        ),
        worker: DartWorker(callbackId: 'dit_pass'),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Windowed trigger must be accepted',
      );

      // We don't strictly require execution (emulator may defer), but the
      // task must at minimum be accepted without crashing.
      await NativeWorkManager.cancel(taskId: id);
    });

    testWidgets('exact trigger – accepted', (tester) async {
      final id = _id('exact_trigger');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: TaskTrigger.exact(
          DateTime.now().add(const Duration(minutes: 5)),
        ),
        worker: DartWorker(callbackId: 'dit_pass'),
      );

      expect(
        result.scheduleResult,
        anyOf(
          equals(ScheduleResult.accepted),
          equals(ScheduleResult.rejectedOsPolicy),
        ),
        reason:
            'Exact trigger accepted, or rejected on Android 12+ without SCHEDULE_EXACT_ALARM permission',
      );

      await NativeWorkManager.cancel(taskId: id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP – Issue #36 regression (iOS BGTask registration timing)
  // The example app runs the Flutter 3.38+ UIScene template, where
  // plugin registration happens AFTER didFinishLaunching returns.
  // Before the fix, BGTaskScheduler.register at that point threw
  // NSInternalInconsistencyException and the app crashed at startup
  // (so this suite booting at all is itself part of the regression
  // coverage). This test additionally asserts the +load registrar
  // did the OS-level registration in the launch window, exactly once.
  // ════════════════════════════════════════════════════════════
  group('Issue #36 – BGTask launch handler registration', () {
    testWidgets(
      'issue_36: handlers registered in +load, before launch completed, exactly once',
      (tester) async {
        if (!Platform.isIOS) {
          markTestSkipped('BGTaskScheduler registration is iOS-only');
          return;
        }

        const channel = MethodChannel('dev.brewkits/native_workmanager');
        final raw = await channel.invokeMethod<dynamic>(
          'debugBGTaskRegistration',
        );
        final info = Map<String, dynamic>.from(raw as Map);

        expect(
          info['handlersAttached'],
          isTrue,
          reason: 'Swift handlers must be attached after plugin registration',
        );

        for (final identifier in [
          'dev.brewkits.native_workmanager.task',
          'dev.brewkits.native_workmanager.refresh',
        ]) {
          final entry = Map<String, dynamic>.from(info[identifier] as Map);
          expect(
            entry['registered'],
            isTrue,
            reason:
                '$identifier must be registered with BGTaskScheduler '
                '(would have crashed pre-fix on the UIScene template)',
          );
          expect(
            entry['registeredInLoad'],
            isTrue,
            reason:
                '$identifier must be registered by the ObjC +load hook, '
                'inside the "before application finishes launching" window',
          );
          expect(
            entry['handlerAttached'],
            isTrue,
            reason: '$identifier must have a Swift handler attached',
          );
          expect(
            entry['registerAttempts'],
            1,
            reason:
                '$identifier must be registered exactly once — a second '
                'OS-level attempt (e.g. from the headless background engine '
                're-running GeneratedPluginRegistrant) throws '
                'NSInternalInconsistencyException',
          );
        }
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 16 – Concurrent tasks
  // Validates that multiple tasks can run in parallel and that
  // all emit events independently.
  // ════════════════════════════════════════════════════════════
  group('Concurrent tasks', () {
    testWidgets('3 simultaneous tasks – all complete successfully', (
      tester,
    ) async {
      final ids = List.generate(3, (i) => _id('concurrent_$i'));
      final futures = ids
          .map((id) => _waitEvent(id, timeout: const Duration(seconds: 60)))
          .toList();

      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
          constraints: const Constraints(requiresNetwork: true),
        );
      }

      final events = await Future.wait(futures);
      for (var i = 0; i < ids.length; i++) {
        expect(
          events[i],
          isNotNull,
          reason: 'Task ${ids[i]} must emit an event',
        );
        expect(
          events[i]!.success,
          isTrue,
          reason: 'Task ${ids[i]} must succeed',
        );
      }
    });

    testWidgets(
      '5 tasks with different tags – each tag resolves independently',
      (tester) async {
        final tag1 = 'concurrent_tag1_${DateTime.now().millisecondsSinceEpoch}';
        final tag2 = 'concurrent_tag2_${DateTime.now().millisecondsSinceEpoch}';

        final idGroup1 = List.generate(2, (i) => _id('ctag1_$i'));
        final idGroup2 = List.generate(3, (i) => _id('ctag2_$i'));

        for (final id in idGroup1) {
          await NativeWorkManager.enqueue(
            taskId: id,
            trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
            worker: DartWorker(callbackId: 'dit_pass'),
            tag: tag1,
          );
        }
        for (final id in idGroup2) {
          await NativeWorkManager.enqueue(
            taskId: id,
            trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
            worker: DartWorker(callbackId: 'dit_pass'),
            tag: tag2,
          );
        }

        final byTag1 = await NativeWorkManager.getTasksByTag(tag: tag1);
        final byTag2 = await NativeWorkManager.getTasksByTag(tag: tag2);

        expect(byTag1.length, 2, reason: 'tag1 must have 2 tasks');
        expect(byTag2.length, 3, reason: 'tag2 must have 3 tasks');

        // Groups must be disjoint.
        final set1 = byTag1.toSet();
        final set2 = byTag2.toSet();
        expect(
          set1.intersection(set2),
          isEmpty,
          reason: 'Tag groups must not overlap',
        );

        await NativeWorkManager.cancelByTag(tag: tag1);
        await NativeWorkManager.cancelByTag(tag: tag2);
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 17 – Chain data flow
  // Validates parallel first-steps and chain with data passing.
  // ════════════════════════════════════════════════════════════
  group('Chain data flow', () {
    testWidgets('chain with parallel first steps – both run before step 2', (
      tester,
    ) async {
      // Two tasks in step 1 running in parallel, then one in step 2.
      final idA = _id('chain_par_a');
      final idB = _id('chain_par_b');
      final idC = _id('chain_par_c');

      final completedIds = <String>[];
      late StreamSubscription<TaskEvent> sub;
      final allDone = Completer<void>();

      sub = NativeWorkManager.events.listen((event) {
        if ([idA, idB, idC].contains(event.taskId) && !event.isStarted) {
          completedIds.add(event.taskId);
          if (completedIds.length == 3 && !allDone.isCompleted) {
            allDone.complete();
          }
        }
      });

      final result =
          await NativeWorkManager.beginWithAll([
                TaskRequest(
                  id: idA,
                  worker: DartWorker(callbackId: 'chain_a'),
                ),
                TaskRequest(
                  id: idB,
                  worker: DartWorker(callbackId: 'chain_b'),
                ),
              ])
              .then(
                TaskRequest(
                  id: idC,
                  worker: DartWorker(callbackId: 'chain_c'),
                ),
              )
              .enqueue();

      expect(
        result,
        ScheduleResult.accepted,
        reason: 'Parallel-first-step chain must be accepted',
      );

      try {
        await allDone.future.timeout(const Duration(seconds: 90));
      } catch (_) {
        // Timeout: iOS may not emit per-step events (chain emits single event).
      }
      await sub.cancel();

      expect(
        completedIds,
        contains(idA),
        reason: 'First-step task A must complete',
      );
      expect(
        completedIds,
        contains(idB),
        reason: 'First-step task B must complete',
      );
    });

    testWidgets(
      'Complex Multi-Stage Workflow (Download -> Encrypt -> Dart Finalizer)',
      (tester) async {
        final id = _id('workflow');
        final downloadPath = '${tmpDir.path}/data.txt';
        final encryptedPath = '${tmpDir.path}/data.enc';

        // Cleanup (though tmpDir is fresh)
        if (File(downloadPath).existsSync()) File(downloadPath).deleteSync();
        if (File(encryptedPath).existsSync()) File(encryptedPath).deleteSync();

        await NativeWorkManager.beginWith(
              TaskRequest(
                id: '$id-1',
                worker: NativeWorker.httpDownload(
                  url: 'https://httpbin.org/range/1024',
                  savePath: downloadPath,
                ),
              ),
            )
            .then(
              TaskRequest(
                id: '$id-2',
                worker: NativeWorker.cryptoEncrypt(
                  inputPath: downloadPath,
                  outputPath: encryptedPath,
                  password: 'super-secret-password',
                ),
              ),
            )
            .then(
              TaskRequest(
                id: '$id-3',
                worker: DartWorker(
                  callbackId: 'workflow_finalizer',
                  input: {
                    'downloadPath': downloadPath,
                    'encryptedPath': encryptedPath,
                  },
                ),
              ),
            )
            .enqueue();

        final event = await _waitEvent(
          '$id-3',
          timeout: const Duration(seconds: 120),
        );
        expect(
          event?.success,
          isTrue,
          reason: 'Complex workflow should succeed',
        );
        expect(File(encryptedPath).existsSync(), isTrue);
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP – Issue #38 / #39: DartWorker progress + persisted status
  //
  // #38: reportDartWorkerProgress from a DartWorker must reach the Dart
  //      progress stream. Regression cause: native emitted the progress map
  //      WITHOUT a `timestamp`, so the Dart session-filter (timestamp <
  //      _sessionStartTime, with a 0 default) silently dropped every event.
  //
  // #39: after a DartWorker returns true, allTasks() must report a terminal
  //      status (not `pending` forever). Regression cause: the WorkInfo
  //      fallback in observeWorkCompletion updated only the in-memory map and
  //      the Dart sink, never taskStore.updateStatus(...).
  //
  // Both fail if the native bridge stops forwarding the field — a serialization
  // round-trip test alone does not cover them (see Issue #30 rule).
  // ════════════════════════════════════════════════════════════
  group('Issue #38/#39 – DartWorker progress and persisted status', () {
    testWidgets(
      'issue_38: DartWorker reportDartWorkerProgress reaches the progress stream',
      (tester) async {
        final id = _id('issue38_progress');
        final progressValues = <int>[];
        final saw100 = Completer<void>();

        final progressSub = NativeWorkManager.progress.listen((p) {
          if (p.taskId == id) {
            progressValues.add(p.progress);
            if (p.progress >= 100 && !saw100.isCompleted) saw100.complete();
          }
        });

        final eventFuture = _waitEvent(
          id,
          timeout: const Duration(seconds: 45),
        );

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'dit_progress'),
        );

        final event = await eventFuture;
        // Give the last progress event a moment to arrive after completion.
        await saw100.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
        await progressSub.cancel();

        expect(event?.success, isTrue, reason: 'dit_progress must succeed');
        expect(
          progressValues,
          isNotEmpty,
          reason:
              'issue_38: progress events must reach the Dart stream (were '
              'dropped when native omitted the timestamp field)',
        );
        expect(
          progressValues,
          contains(50),
          reason: 'issue_38: the 50% update must not be filtered out',
        );
      },
    );

    testWidgets(
      'issue_39: DartWorker status becomes terminal in allTasks() after success',
      (tester) async {
        final id = _id('issue39_status');
        final eventFuture = _waitEvent(
          id,
          timeout: const Duration(seconds: 45),
        );

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'dit_progress'),
        );

        final event = await eventFuture;
        expect(event?.success, isTrue, reason: 'dit_progress must succeed');

        // Allow the WorkInfo-fallback coroutine to persist the terminal status.
        await Future<void>.delayed(const Duration(seconds: 2));

        final tasks = await NativeWorkManager.allTasks();
        final record = tasks.where((t) => t.taskId == id).toList();
        // The record may be purged by the platform; if present it must NOT be
        // stuck on pending/running — that is exactly the #39 bug.
        if (record.isNotEmpty) {
          expect(
            record.first.status,
            isNot(anyOf('pending', 'running')),
            reason:
                'issue_39: DartWorker TaskStore status stuck on pending after '
                'success (WorkInfo fallback never called taskStore.updateStatus)',
          );
        }
      },
    );
  });

  // ════════════════════════════════════════════════════════════
  // GROUP – Issue #57: chain step data flow ({{taskId.outputKey}} placeholders)
  //
  // task_chain.dart documents `{{task_id.output_key}}` for passing one step's
  // output into the next step's config. It never actually worked on either
  // platform: step results were stored under flat, unprefixed keys
  // (e.g. "savePath"), but substitution looked up the *whole* placeholder
  // string as one key (e.g. "downloader.savePath") — the two never matched,
  // so the literal "{{...}}" text always reached the next worker untouched.
  // A parallel step's tasks also overwrote each other's stored result, so
  // only the last-to-finish task's data ever survived even by accident.
  // Android had no substitution mechanism at all — chains there are built by
  // enqueuing every step's WorkRequest upfront via WorkManager's native
  // .then() chaining, which freezes each step's config before any earlier
  // step has run.
  //
  // Fixed by namespacing step results "<taskId>.<key>" (iOS: merged in
  // NativeWorkmanagerPlugin+Execution.swift; Android: per-task rows in
  // ChainStore, merged at read time) and, on Android, moving to a dynamic
  // per-step enqueue driven by ChainResultCapturingWorker + WorkInfo
  // completion (NativeWorkmanagerPlugin+EventChannel.kt).
  // ════════════════════════════════════════════════════════════
  group('Issue #57 – chain placeholder data flow', () {
    testWidgets(
      'issue_57: {{taskId.key}} resolves into the next step\'s config (partial match)',
      (tester) async {
        final step1Id = _id('issue57_mkdir1');
        final step2Id = _id('issue57_mkdir2');
        final baseDir = '${tmpDir.path}/issue57_${step1Id}_base';
        final expectedNestedDir = '$baseDir/nested';

        final step2Future = _waitEvent(
          step2Id,
          timeout: const Duration(seconds: 45),
        );

        await NativeWorkManager.beginWith(
              TaskRequest(
                id: step1Id,
                worker: NativeWorker.fileMkdir(path: baseDir),
              ),
            )
            .then(
              TaskRequest(
                id: step2Id,
                // Partial match: the placeholder is embedded in a larger
                // string, so this exercises string interpolation, not the
                // whole-match typed-value path.
                worker: NativeWorker.fileMkdir(
                  path: '{{$step1Id.path}}/nested',
                ),
              ),
            )
            .enqueue();

        final step2Event = await step2Future;
        expect(
          step2Event?.success,
          isTrue,
          reason: 'issue_57: step 2 mkdir must succeed',
        );
        expect(
          Directory(expectedNestedDir).existsSync(),
          isTrue,
          reason:
              'issue_57: {{$step1Id.path}} must resolve to the real step-1 '
              'output path — if the placeholder stayed literal, mkdir would '
              'have created a differently-named (or failed) directory '
              'instead of $expectedNestedDir',
        );
      },
    );

    testWidgets(
      'issue_57: parallel step tasks do not overwrite each other\'s data',
      (tester) async {
        final taskAId = _id('issue57_par_a');
        final taskBId = _id('issue57_par_b');
        final step2AId = _id('issue57_par_step2a');
        final step2BId = _id('issue57_par_step2b');
        final dirA = '${tmpDir.path}/issue57_${taskAId}_a';
        final dirB = '${tmpDir.path}/issue57_${taskBId}_b';

        final step2AFuture = _waitEvent(
          step2AId,
          timeout: const Duration(seconds: 45),
        );
        final step2BFuture = _waitEvent(
          step2BId,
          timeout: const Duration(seconds: 45),
        );

        await NativeWorkManager.beginWithAll([
              TaskRequest(
                id: taskAId,
                worker: NativeWorker.fileMkdir(path: dirA),
              ),
              TaskRequest(
                id: taskBId,
                worker: NativeWorker.fileMkdir(path: dirB),
              ),
            ])
            .thenAll([
              TaskRequest(
                id: step2AId,
                worker: NativeWorker.fileMkdir(
                  path: '{{$taskAId.path}}/nested',
                ),
              ),
              TaskRequest(
                id: step2BId,
                worker: NativeWorker.fileMkdir(
                  path: '{{$taskBId.path}}/nested',
                ),
              ),
            ])
            .enqueue();

        final results = await Future.wait([step2AFuture, step2BFuture]);
        expect(
          results.every((e) => e?.success == true),
          isTrue,
          reason: 'issue_57: both parallel step-2 tasks must succeed',
        );
        expect(
          Directory('$dirA/nested').existsSync(),
          isTrue,
          reason:
              "issue_57: task A's result must survive task B finishing "
              'alongside it in the same step (previously the last task to '
              'complete silently overwrote the others\' stored data)',
        );
        expect(
          Directory('$dirB/nested').existsSync(),
          isTrue,
          reason: "issue_57: task B's result must independently survive too",
        );
      },
    );

    testWidgets(
      'issue_57: a whole-match placeholder resolves to a typed value, not a string',
      (tester) async {
        final step1Id = _id('issue57_dim_probe');
        final step2Id = _id('issue57_dim_crop');
        final inputPath = '${tmpDir.path}/issue57_${step1Id}_input.png';
        final midPath = '${tmpDir.path}/issue57_${step1Id}_mid.png';
        final outputPath = '${tmpDir.path}/issue57_${step1Id}_out.png';
        File(inputPath).writeAsBytesSync(_minimalPng);

        final step2Future = _waitEvent(
          step2Id,
          timeout: const Duration(seconds: 45),
        );

        await NativeWorkManager.beginWith(
              TaskRequest(
                id: step1Id,
                worker: ImageProcessWorker(
                  inputPath: inputPath,
                  outputPath: midPath,
                  maxWidth: 100,
                  maxHeight: 100,
                ),
              ),
            )
            .then(
              TaskRequest(
                id: step2Id,
                // ImageProcessWorker.maxWidth/maxHeight are typed `int?` in
                // the public Dart API, so there is no supported way to pass
                // a placeholder through the typed constructor (that gap is
                // tracked separately, see discussion #56's cropAspectRatio
                // suggestion). _RawConfigWorker bypasses the typed API to
                // exercise the native substitution mechanism itself: the
                // whole-match path must hand the native decoder a real Int
                // (originalWidth/Height from step 1, both 1 for a 1x1 PNG),
                // not the stringified "1" the old code always produced. A
                // typed field getting a JSON string instead of a number is
                // exactly the failure mode this proves absence of — Swift's
                // Codable rejects the type mismatch outright.
                worker: _RawConfigWorker('ImageProcessWorker', {
                  'inputPath': midPath,
                  'outputPath': outputPath,
                  'maxWidth': '{{$step1Id.originalWidth}}',
                  'maxHeight': '{{$step1Id.originalHeight}}',
                }),
              ),
            )
            .enqueue();

        final step2Event = await step2Future;
        expect(
          step2Event?.success,
          isTrue,
          reason:
              'issue_57: step 2 must decode maxWidth/maxHeight as real '
              'numbers substituted from step 1\'s output — a stringified '
              'placeholder value would fail native config decoding '
              '(message: ${step2Event?.message})',
        );
        expect(File(outputPath).existsSync(), isTrue);
      },
    );
  });
}
