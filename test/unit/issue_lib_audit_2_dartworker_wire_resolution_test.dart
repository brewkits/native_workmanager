import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Guards a real gap found by the 2026-09-23 lib/ audit.
///
/// [NativeWorkManager.enqueue] and task chains convert a [DartWorker] to a
/// [DartWorkerInternal] (resolving its native callback handle) before
/// sending it to native. [TaskGraph] nodes and [RemoteTriggerRule]
/// `workerMappings` never did — they called the worker's own `toMap()`
/// directly, which for a plain `DartWorker` never includes `callbackHandle`
/// at all (only `DartWorkerInternal.toMap()` does). Native's
/// `DartCallbackWorker` requires `callbackHandle`, so the task was enqueued
/// but the callback could never resolve — a silent no-op, discoverable only
/// by the task never running.
class _MockPlatform extends NativeWorkManagerPlatform
    with MockPlatformInterfaceMixin {
  Map<String, dynamic>? capturedGraphMap;
  RemoteTriggerRule? capturedRule;
  Map<String, dynamic>? capturedChainMap;

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
  }) async {}

  @override
  void setCallbackExecutor(
      Future<bool> Function(String callbackId, Map<String, dynamic>? input)
          executor) {}

  @override
  Future<String> enqueueGraph(Map<String, dynamic> graphMap) async {
    capturedGraphMap = graphMap;
    return 'accepted';
  }

  // enqueueTaskGraph() subscribes to this right after enqueueGraph() — an
  // empty stream is enough since these tests only assert on the outgoing
  // payload, not on graph completion.
  @override
  Stream<TaskEvent> get events => const Stream.empty();

  @override
  Future<void> registerRemoteTrigger({
    required RemoteTriggerSource source,
    required RemoteTriggerRule rule,
  }) async {
    capturedRule = rule;
  }

  @override
  Future<ScheduleResult> enqueueChain(Map<String, dynamic> chainMap) async {
    capturedChainMap = chainMap;
    return ScheduleResult.accepted;
  }
}

// Top-level function: PluginUtilities.getCallbackHandle requires this.
Future<bool> _testCallback(Map<String, dynamic>? input) async => true;

void main() {
  late _MockPlatform mockPlatform;

  setUp(() {
    mockPlatform = _MockPlatform();
    NativeWorkManagerPlatform.instance = mockPlatform;
    NativeWorkManager.initialize(
      dartWorkers: {'test-worker': _testCallback},
    );
  });

  group('TaskGraph node DartWorker resolution', () {
    test('a DartWorker node carries a resolved callbackHandle', () async {
      final graph = TaskGraph(id: 'g1')
        ..add(TaskNode(
          id: 'a',
          worker: DartWorker(callbackId: 'test-worker'),
        ));

      await NativeWorkManager.enqueueGraph(graph);

      final nodes = mockPlatform.capturedGraphMap!['nodes'] as List;
      final nodeConfig = (nodes.first as Map)['workerConfig'] as Map;
      expect(nodeConfig['callbackHandle'], isNotNull,
          reason: 'Without resolution, a plain DartWorker.toMap() never '
              'includes callbackHandle — native could never resolve it.');
    });

    test('a non-DartWorker node is unaffected', () async {
      final graph = TaskGraph(id: 'g2')
        ..add(TaskNode(
          id: 'a',
          worker: NativeWorker.httpSync(url: 'https://example.com'),
        ));

      await NativeWorkManager.enqueueGraph(graph);

      final nodes = mockPlatform.capturedGraphMap!['nodes'] as List;
      expect((nodes.first as Map)['workerClassName'], 'HttpSyncWorker');
    });

    test('a DartWorker node is promoted to isHeavyTask on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final graph = TaskGraph(id: 'g3')
        ..add(TaskNode(
          id: 'a',
          worker: DartWorker(callbackId: 'test-worker'),
          constraints: const Constraints(isHeavyTask: false),
        ));

      await NativeWorkManager.enqueueGraph(graph);

      final nodes = mockPlatform.capturedGraphMap!['nodes'] as List;
      final constraints = (nodes.first as Map)['constraints'] as Map;
      expect(constraints['isHeavyTask'], isTrue);
    });
  });

  group('RemoteTriggerRule workerMappings DartWorker resolution', () {
    test('a mapped DartWorker carries a resolved callbackHandle', () async {
      await NativeWorkManager.registerRemoteTrigger(
        source: RemoteTriggerSource.fcm,
        rule: RemoteTriggerRule(
          payloadKey: 'action',
          workerMappings: {
            'sync': DartWorker(callbackId: 'test-worker'),
          },
        ),
      );

      final mapped = mockPlatform.capturedRule!.workerMappings['sync']!;
      expect(mapped, isA<DartWorkerInternal>());
      expect((mapped as DartWorkerInternal).callbackHandle, isNonZero);
    });

    test('a mapped NativeWorker is unaffected', () async {
      await NativeWorkManager.registerRemoteTrigger(
        source: RemoteTriggerSource.fcm,
        rule: RemoteTriggerRule(
          payloadKey: 'action',
          workerMappings: {
            'sync': NativeWorker.httpSync(url: 'https://example.com'),
          },
        ),
      );

      final mapped = mockPlatform.capturedRule!.workerMappings['sync']!;
      expect(mapped, isNot(isA<DartWorkerInternal>()));
    });
  });

  group('Task chain DartWorker resolution (regression guard)', () {
    test('a chain-step DartWorker is promoted to isHeavyTask on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await NativeWorkManager.beginWith(
        TaskRequest(id: 'step1', worker: DartWorker(callbackId: 'test-worker')),
      ).enqueue();

      final steps = mockPlatform.capturedChainMap!['steps'] as List;
      final firstStep = (steps.first as List).first as Map;
      final constraints = firstStep['constraints'] as Map;
      expect(constraints['isHeavyTask'], isTrue,
          reason: 'This was skipped before resolveWorkerForWire unified the '
              'chain and enqueue() code paths.');
    });
  });

  group('Chain-step unregistered DartWorker error message', () {
    test('is the same helpful message enqueue() gives, not a misleading '
        '"INTERNAL ERROR" — pre-fix, chains skipped the registration check '
        'and fell straight into the internal-error branch meant for a truly '
        'impossible state', () async {
      expect(
        () => NativeWorkManager.beginWith(
          TaskRequest(
            id: 'step1',
            worker: DartWorker(callbackId: 'never-registered'),
          ),
        ).enqueue(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not registered'),
          ),
        ),
      );
    });
  });

  group('Unregistered DartWorker fails loudly instead of silently', () {
    test('enqueueGraph() rejects with a StateError, not a crash or a silent '
        'no-op native call', () async {
      final graph = TaskGraph(id: 'g4')
        ..add(TaskNode(
          id: 'a',
          worker: DartWorker(callbackId: 'never-registered'),
        ));

      await expectLater(
        NativeWorkManager.enqueueGraph(graph),
        throwsA(isA<StateError>()),
      );
      // The whole point of failing before the native call: it must never
      // have been reached with an unresolvable worker.
      expect(mockPlatform.capturedGraphMap, isNull);
    });

    test('registerRemoteTrigger() rejects with a StateError, not a crash or '
        'a silent no-op native call', () async {
      await expectLater(
        NativeWorkManager.registerRemoteTrigger(
          source: RemoteTriggerSource.fcm,
          rule: RemoteTriggerRule(
            payloadKey: 'action',
            workerMappings: {
              'sync': DartWorker(callbackId: 'never-registered'),
            },
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(mockPlatform.capturedRule, isNull);
    });
  });
}
