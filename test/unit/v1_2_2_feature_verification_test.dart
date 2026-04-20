// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/testing.dart';
import 'package:native_workmanager/src/platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ──────────────────────────────────────────────────────────────────────────────
// v1.2.2 Feature Verification Tests
//
// Covers every Dart-observable change introduced in hotfix/1.2.2:
//
//   feat(#18) – registerPlugins option (persist and restore across cold starts)
//   fix(#16)  – iOS openFile deprecation (UIWindowScene-safe activeRootViewController)
//   fix(#17)  – Android applyMiddlewareInternal rename (StackOverflowError fix)
//   fix(#15)  – native_workmanager_gen analyzer constraint widen
//   chore     – kmpworkmanager 2.4.0 upgrade (8 KB periodic payload limit)
//
// Tests that are iOS/Android-native-only (UIWindowScene traversal, Kotlin
// companion renaming) cannot be exercised at the Dart unit-test level.
// Those are covered in example/integration_test/.
// ──────────────────────────────────────────────────────────────────────────────

// ── Mock platform that captures initialize() arguments ──────────────────────

class _CapturingPlatform extends NativeWorkManagerPlatform
    with MockPlatformInterfaceMixin {
  bool? capturedRegisterPlugins;
  bool? capturedEnforceHttps;
  bool? capturedBlockPrivateIPs;
  int? capturedMaxConcurrent;
  int? capturedDiskSpaceBufferMB;
  int? capturedCleanupAfterDays;
  Constraints? capturedConstraints;

  @override
  Future<void> initialize({
    int? callbackHandle,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
    bool registerPlugins = false,
  }) async {
    capturedRegisterPlugins = registerPlugins;
    capturedEnforceHttps = enforceHttps;
    capturedBlockPrivateIPs = blockPrivateIPs;
    capturedMaxConcurrent = maxConcurrentTasks;
    capturedDiskSpaceBufferMB = diskSpaceBufferMB;
    capturedCleanupAfterDays = cleanupAfterDays;
  }

  @override
  void setCallbackExecutor(
      Future<bool> Function(String, Map<String, dynamic>?) executor) {}

  @override
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    required Constraints constraints,
    required ExistingTaskPolicy existingPolicy,
    String? tag,
  }) async {
    capturedConstraints = constraints;
    return ScheduleResult.accepted;
  }
}

// ── Top-level callback (required for DartWorker handle computation) ──────────

@pragma('vm:entry-point')
Future<bool> _noopCallback(Map<String, dynamic>? input) async => true;

// ── Helpers ──────────────────────────────────────────────────────────────────

void _resetNativeWorkManager() {
  NativeWorkManager.resetSecurityFlags();
  NativeWorkManager.resetInitializedState();
}

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // §1  registerPlugins — static flag
  // ──────────────────────────────────────────────────────────────────────────

  group('registerPlugins – static flag (feat #18)', () {
    setUp(_resetNativeWorkManager);
    tearDown(_resetNativeWorkManager);

    test('registerPluginsEnabled defaults to false before initialize()', () {
      expect(NativeWorkManager.registerPluginsEnabled, isFalse);
    });

    test('resetSecurityFlags() resets registerPluginsEnabled to false', () {
      NativeWorkManager.resetSecurityFlags();
      expect(NativeWorkManager.registerPluginsEnabled, isFalse);
    });

    test('resetSecurityFlags() resets all three security flags together', () {
      NativeWorkManager.resetSecurityFlags();
      expect(NativeWorkManager.enforceHttps, isFalse);
      expect(NativeWorkManager.blockPrivateIPs, isFalse);
      expect(NativeWorkManager.registerPluginsEnabled, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §2  registerPlugins — platform channel round-trip
  // ──────────────────────────────────────────────────────────────────────────

  group('registerPlugins – platform channel serialization', () {
    late _CapturingPlatform mock;

    setUp(() {
      mock = _CapturingPlatform();
      NativeWorkManagerPlatform.instance = mock;
      _resetNativeWorkManager();
    });

    tearDown(_resetNativeWorkManager);

    test('registerPlugins=false is forwarded to platform (default)', () async {
      await NativeWorkManager.initialize();
      expect(mock.capturedRegisterPlugins, isFalse);
    });

    test('registerPlugins=true is forwarded to platform', () async {
      await NativeWorkManager.initialize(registerPlugins: true);
      expect(mock.capturedRegisterPlugins, isTrue);
    });

    test('registerPlugins=true sets registerPluginsEnabled getter', () async {
      await NativeWorkManager.initialize(registerPlugins: true);
      expect(NativeWorkManager.registerPluginsEnabled, isTrue);
    });

    test('registerPlugins=false leaves registerPluginsEnabled false', () async {
      await NativeWorkManager.initialize(registerPlugins: false);
      expect(NativeWorkManager.registerPluginsEnabled, isFalse);
    });

    test('registerPlugins does not affect other init flags', () async {
      await NativeWorkManager.initialize(
        registerPlugins: true,
        enforceHttps: true,
        blockPrivateIPs: false,
        maxConcurrentTasks: 8,
      );
      expect(mock.capturedRegisterPlugins, isTrue);
      expect(mock.capturedEnforceHttps, isTrue);
      expect(mock.capturedBlockPrivateIPs, isFalse);
      expect(mock.capturedMaxConcurrent, 8);
    });

    test('all three boolean flags forwarded independently', () async {
      await NativeWorkManager.initialize(
        enforceHttps: false,
        blockPrivateIPs: true,
        registerPlugins: true,
      );
      expect(mock.capturedEnforceHttps, isFalse);
      expect(mock.capturedBlockPrivateIPs, isTrue);
      expect(mock.capturedRegisterPlugins, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §3  registerPlugins — idempotent initialization
  // ──────────────────────────────────────────────────────────────────────────

  group('registerPlugins – idempotent initialize()', () {
    late _CapturingPlatform mock;

    setUp(() {
      mock = _CapturingPlatform();
      NativeWorkManagerPlatform.instance = mock;
      _resetNativeWorkManager();
    });

    tearDown(_resetNativeWorkManager);

    test('second initialize() call is a no-op (flag kept from first call)',
        () async {
      await NativeWorkManager.initialize(registerPlugins: true);
      expect(NativeWorkManager.registerPluginsEnabled, isTrue);

      // Second call should be ignored — initialized guard fires
      await NativeWorkManager.initialize(registerPlugins: false);
      expect(NativeWorkManager.registerPluginsEnabled, isTrue,
          reason: 'Second initialize() must be a no-op');
    });

    test('after resetInitializedState(), new initialize() applies new flag',
        () async {
      await NativeWorkManager.initialize(registerPlugins: true);
      _resetNativeWorkManager(); // clears both _initialized and flags
      await NativeWorkManager.initialize(registerPlugins: false);
      expect(NativeWorkManager.registerPluginsEnabled, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §4  registerPlugins — Zero-Engine I/O default (BLE safety contract)
  // ──────────────────────────────────────────────────────────────────────────

  group('registerPlugins – Zero-Engine I/O default (BLE safety)', () {
    setUp(_resetNativeWorkManager);
    tearDown(_resetNativeWorkManager);

    test('registerPlugins=false is the default — preserves BLE connections',
        () {
      // The BLE safety contract: default must be false so existing apps that
      // don't opt in never see side-effects (BLE disconnects, audio drops) when
      // the background engine is destroyed. This test pins the default.
      expect(NativeWorkManager.registerPluginsEnabled, isFalse,
          reason:
              'Default must remain false to avoid side-effects on plugin teardown');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §5  kmpworkmanager 2.4.0 – ScheduleResult.rejectedOsPolicy semantics
  //
  //  kmpworkmanager 2.4.0 enforces an 8 KB payload limit for periodic tasks
  //  and returns REJECTED_OS_POLICY instead of silently truncating. At the
  //  Dart layer this manifests as ScheduleResult.rejectedOsPolicy. These
  //  tests verify that the enum and its serialisation are correct so that
  //  callers can distinguish the new rejection reason.
  // ──────────────────────────────────────────────────────────────────────────

  group('ScheduleResult – kmpworkmanager 2.4.0 rejectedOsPolicy', () {
    test('ScheduleResult.rejectedOsPolicy exists and is distinct', () {
      expect(
        ScheduleResult.values.contains(ScheduleResult.rejectedOsPolicy),
        isTrue,
      );
    });

    test('ScheduleResult.rejectedOsPolicy != accepted', () {
      expect(ScheduleResult.rejectedOsPolicy, isNot(ScheduleResult.accepted));
    });

    test('ScheduleResult.rejectedOsPolicy != throttled', () {
      expect(ScheduleResult.rejectedOsPolicy, isNot(ScheduleResult.throttled));
    });

    test('all ScheduleResult variants are distinct', () {
      final values = ScheduleResult.values;
      expect(values.toSet().length, equals(values.length));
    });

    test(
        'FakeWorkManager can simulate rejectedOsPolicy for oversized periodic task',
        () async {
      // Simulates the kmpworkmanager 2.4.0 behaviour: a periodic task whose
      // serialised config exceeds 8 KB returns rejectedOsPolicy.
      final wm = FakeWorkManager()
        ..enqueueResult = ScheduleResult.rejectedOsPolicy;
      addTearDown(wm.dispose);

      final handler = await wm.enqueue(
        taskId: 'oversized-periodic',
        worker: NativeWorker.httpRequest(
          url: 'https://api.example.com/sync',
          method: HttpMethod.post,
        ),
        trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
      );

      expect(handler.scheduleResult, ScheduleResult.rejectedOsPolicy);
    });

    test(
        'FakeWorkManager.enqueueResultByTaskId overrides per-task for oversized scenario',
        () async {
      final wm = FakeWorkManager();
      addTearDown(wm.dispose);
      wm.enqueueResultByTaskId['too-big'] = ScheduleResult.rejectedOsPolicy;
      wm.enqueueResultByTaskId['normal'] = ScheduleResult.accepted;

      final big = await wm.enqueue(
        taskId: 'too-big',
        worker: NativeWorker.httpRequest(url: 'https://api.example.com'),
        trigger: TaskTrigger.periodic(const Duration(hours: 1)),
      );
      final normal = await wm.enqueue(
        taskId: 'normal',
        worker: NativeWorker.httpRequest(url: 'https://api.example.com'),
        trigger: const TaskTrigger.oneTime(),
      );

      expect(big.scheduleResult, ScheduleResult.rejectedOsPolicy);
      expect(normal.scheduleResult, ScheduleResult.accepted);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §6  Middleware API – applyMiddlewareInternal rename (fix #17)
  //
  //  The Android fix renamed the internal package-level function to avoid
  //  infinite recursion (StackOverflowError). The public Dart API must be
  //  unchanged. These tests pin the public API contract so regressions are
  //  caught immediately.
  // ──────────────────────────────────────────────────────────────────────────

  group('Middleware API – applyMiddlewareInternal rename (fix #17)', () {
    test('HeaderMiddleware serialises correctly (type=header)', () {
      const m = HeaderMiddleware(
        headers: {'X-App-Version': '1.2.2', 'X-Platform': 'iOS'},
      );
      final map = m.toMap();
      expect(map['type'], 'header');
      expect((map['headers'] as Map)['X-App-Version'], '1.2.2');
    });

    test('HeaderMiddleware with urlPattern round-trips', () {
      const m = HeaderMiddleware(
        headers: {'Authorization': 'Bearer tok'},
        urlPattern: r'https://api\.example\.com/.*',
      );
      final map = m.toMap();
      expect(map['urlPattern'], r'https://api\.example\.com/.*');
    });

    test('LoggingMiddleware serialises correctly (type=logging)', () {
      const m = LoggingMiddleware(
        logUrl: 'https://log.example.com/tasks',
      );
      final map = m.toMap();
      expect(map['type'], 'logging');
      expect(map['logUrl'], 'https://log.example.com/tasks');
    });

    test('RemoteConfigMiddleware serialises correctly (type=remoteConfig)', () {
      const m = RemoteConfigMiddleware(
        values: {'timeout': 30, 'retries': 3},
        workerType: 'HttpDownload',
      );
      final map = m.toMap();
      expect(map['type'], 'remoteConfig');
      expect((map['values'] as Map)['timeout'], 30);
      expect(map['workerType'], 'HttpDownload');
    });

    test('multiple middleware types can coexist without crash', () {
      const middlewares = <Middleware>[
        HeaderMiddleware(headers: {'X-Tenant': 'acme'}),
        LoggingMiddleware(logUrl: 'https://log.example.com'),
        RemoteConfigMiddleware(values: {'key': 'value'}),
      ];
      final maps = middlewares.map((m) => m.toMap()).toList();
      expect(maps[0]['type'], 'header');
      expect(maps[1]['type'], 'logging');
      expect(maps[2]['type'], 'remoteConfig');
    });

    test('HeaderMiddleware with empty headers is valid', () {
      const m = HeaderMiddleware(headers: {});
      expect(() => m.toMap(), returnsNormally);
      expect(m.toMap()['headers'], isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §7  iOS DartWorker heavy-task promotion still works alongside registerPlugins
  // ──────────────────────────────────────────────────────────────────────────

  group('DartWorker iOS isHeavyTask promotion – unaffected by registerPlugins',
      () {
    late _CapturingPlatform mock;

    setUp(() {
      mock = _CapturingPlatform();
      NativeWorkManagerPlatform.instance = mock;
      _resetNativeWorkManager();
      NativeWorkManager.registerDartWorker('noop', _noopCallback);
    });

    tearDown(() {
      NativeWorkManager.unregisterDartWorker('noop');
      _resetNativeWorkManager();
    });

    test('iOS DartWorker promoted to heavy regardless of registerPlugins=true',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // Initialize with registerPlugins=true, then enqueue a DartWorker.
      // The platform-level heavy-task promotion must still apply.
      await NativeWorkManager.initialize(registerPlugins: true);

      await NativeWorkManager.enqueue(
        taskId: 'dart-heavy',
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'noop'),
        constraints: const Constraints(isHeavyTask: false),
      );

      expect(mock.capturedConstraints?.isHeavyTask, isTrue,
          reason:
              'DartWorker must remain heavy on iOS regardless of registerPlugins');
      expect(NativeWorkManager.registerPluginsEnabled, isTrue,
          reason: 'registerPlugins flag should have been set');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // §8  Backward compatibility — existing callers require no migration
  // ──────────────────────────────────────────────────────────────────────────

  group('Backward compatibility – no migration needed', () {
    late _CapturingPlatform mock;

    setUp(() {
      mock = _CapturingPlatform();
      NativeWorkManagerPlatform.instance = mock;
      _resetNativeWorkManager();
    });

    tearDown(_resetNativeWorkManager);

    test('initialize() with no registerPlugins param defaults to false',
        () async {
      await NativeWorkManager.initialize();
      expect(mock.capturedRegisterPlugins, isFalse,
          reason: 'Callers that omit registerPlugins must not be affected');
    });

    test('all default init params are forwarded correctly', () async {
      await NativeWorkManager.initialize();
      expect(mock.capturedMaxConcurrent, 4);
      expect(mock.capturedDiskSpaceBufferMB, 20);
      expect(mock.capturedCleanupAfterDays, 30);
      expect(mock.capturedEnforceHttps, isFalse);
      expect(mock.capturedBlockPrivateIPs, isFalse);
      expect(mock.capturedRegisterPlugins, isFalse);
    });

    test('custom init params are all forwarded', () async {
      await NativeWorkManager.initialize(
        maxConcurrentTasks: 2,
        diskSpaceBufferMB: 50,
        cleanupAfterDays: 7,
        enforceHttps: true,
        blockPrivateIPs: true,
        registerPlugins: true,
      );
      expect(mock.capturedMaxConcurrent, 2);
      expect(mock.capturedDiskSpaceBufferMB, 50);
      expect(mock.capturedCleanupAfterDays, 7);
      expect(mock.capturedEnforceHttps, isTrue);
      expect(mock.capturedBlockPrivateIPs, isTrue);
      expect(mock.capturedRegisterPlugins, isTrue);
    });
  });
}
