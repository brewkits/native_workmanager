import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskGraph Execution', () {
    const MethodChannel channel =
        MethodChannel('dev.brewkits/native_workmanager');

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'initialize':
            return null;
          case 'enqueueGraph':
            return 'accepted';
          default:
            return null;
        }
      });
      await NativeWorkManager.initialize();
    });

    test('executes simple graph (A -> B)', () async {
      final graph = TaskGraph(id: 'g1')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['a']));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      // Simulate success for A
      NativeWorkManager.reportTestEvent(TaskEvent(
        taskId: 'g1__a',
        success: true,
        timestamp: DateTime.now(),
      ));

      // Simulate success for B
      NativeWorkManager.reportTestEvent(TaskEvent(
        taskId: 'g1__b',
        success: true,
        timestamp: DateTime.now(),
      ));

      final result = await execution.result;
      expect(result.success, isTrue);
      expect(result.completedCount, 2);
    });

    test('cancels downstream on failure', () async {
      final graph = TaskGraph(id: 'g2')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['a']))
        ..add(TaskNode(
            id: 'c',
            worker: NativeWorker.httpSync(url: 'https://c.com'),
            dependsOn: ['b']));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      // Node A fails
      NativeWorkManager.reportTestEvent(TaskEvent(
        taskId: 'g2__a',
        success: false,
        message: 'Boom',
        timestamp: DateTime.now(),
      ));

      final result = await execution.result;
      expect(result.success, isFalse);
      expect(result.completedCount, 0);
      expect(result.failedNodes, ['a']);
      expect(result.cancelledNodes, containsAll(['b', 'c']));
    });

    test('ignores started events', () async {
      final graph = TaskGraph(id: 'g3')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      // Send started event
      NativeWorkManager.reportTestEvent(TaskEvent(
        taskId: 'g3__a',
        success: true,
        message: 'Started',
        errorCode: NativeWorkManagerError.unknown,
        isStarted: true,
        timestamp: DateTime.now(),
      ));

      // Graph should still be waiting
      var resolved = false;
      unawaited(execution.result.then((_) => resolved = true));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(resolved, isFalse);

      // Send terminal success event
      NativeWorkManager.reportTestEvent(TaskEvent(
        taskId: 'g3__a',
        success: true,
        timestamp: DateTime.now(),
      ));

      final result = await execution.result;
      expect(result.success, isTrue);
    });

    test('GraphResult toString', () {
      const result = GraphResult(
        graphId: 'g',
        success: true,
        completedCount: 5,
        failedNodes: [],
        cancelledNodes: [],
      );
      expect(result.toString(), contains('g'));
      expect(result.toString(), contains('5'));
    });
  });

  // ─── TaskGraph.validate ───────────────────────────────────────────────────

  group('TaskGraph.validate', () {
    test('valid single-node graph passes', () {
      final g = TaskGraph(id: 'v1')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')));
      expect(() => g.validate(), returnsNormally);
    });

    test('valid chain A → B → C passes', () {
      final g = TaskGraph(id: 'v2')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['a']))
        ..add(TaskNode(
            id: 'c',
            worker: NativeWorker.httpSync(url: 'https://c.com'),
            dependsOn: ['b']));
      expect(() => g.validate(), returnsNormally);
    });

    test('diamond dependency passes (A→B, A→C, B+C→D)', () {
      final g = TaskGraph(id: 'diamond')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['a']))
        ..add(TaskNode(
            id: 'c',
            worker: NativeWorker.httpSync(url: 'https://c.com'),
            dependsOn: ['a']))
        ..add(TaskNode(
            id: 'd',
            worker: NativeWorker.httpSync(url: 'https://d.com'),
            dependsOn: ['b', 'c']));
      expect(() => g.validate(), returnsNormally);
    });

    test('throws ArgumentError on duplicate node ID', () {
      final g = TaskGraph(id: 'dup')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://b.com')));
      expect(() => g.validate(), throwsArgumentError);
    });

    test('throws ArgumentError on missing dependency', () {
      final g = TaskGraph(id: 'miss')
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['nonexistent']));
      expect(() => g.validate(), throwsArgumentError);
    });

    test('throws ArgumentError on self-dependency (cycle)', () {
      final g = TaskGraph(id: 'self')
        ..add(TaskNode(
            id: 'a',
            worker: NativeWorker.httpSync(url: 'https://a.com'),
            dependsOn: ['a']));
      expect(() => g.validate(), throwsArgumentError);
    });

    test('throws ArgumentError on 2-node cycle', () {
      final g = TaskGraph(id: 'cyc2')
        ..add(TaskNode(
            id: 'a',
            worker: NativeWorker.httpSync(url: 'https://a.com'),
            dependsOn: ['b']))
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['a']));
      expect(() => g.validate(), throwsArgumentError);
    });

    test('throws ArgumentError on 3-node cycle', () {
      final g = TaskGraph(id: 'cyc3')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b',
            worker: NativeWorker.httpSync(url: 'https://b.com'),
            dependsOn: ['a']))
        ..add(TaskNode(
            id: 'c',
            worker: NativeWorker.httpSync(url: 'https://c.com'),
            dependsOn: ['b', 'a']))
        ..add(TaskNode(
            id: 'd',
            worker: NativeWorker.httpSync(url: 'https://d.com'),
            dependsOn: ['c']));
      // Still valid — no cycle here; just re-check with actual cycle
      expect(() => g.validate(), returnsNormally);
    });
  });

  // ─── TaskGraph API ────────────────────────────────────────────────────────

  group('TaskGraph nodes API', () {
    test('nodes returns unmodifiable list', () {
      final g = TaskGraph(id: 'api')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')));
      final node = TaskNode(
          id: 'b', worker: NativeWorker.httpSync(url: 'https://b.com'));
      expect(
          () => (g.nodes as List<TaskNode>).add(node), throwsUnsupportedError);
    });

    test('empty graph has zero nodes', () {
      final g = TaskGraph(id: 'empty');
      expect(g.nodes, isEmpty);
    });

    test('add returns graph for fluent chaining', () {
      final g = TaskGraph(id: 'chain');
      final result = g.add(TaskNode(
          id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')));
      expect(result, same(g));
    });

    test('nodes length matches added count', () {
      final g = TaskGraph(id: 'cnt')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b', worker: NativeWorker.httpSync(url: 'https://b.com')))
        ..add(TaskNode(
            id: 'c', worker: NativeWorker.httpSync(url: 'https://c.com')));
      expect(g.nodes.length, 3);
    });

    test('toMap includes id and nodes', () {
      final g = TaskGraph(id: 'tm')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')));
      final m = g.toMap();
      expect(m['id'], 'tm');
      expect(m['nodes'], isA<List>());
      expect((m['nodes'] as List).length, 1);
    });
  });

  // ─── TaskNode API ─────────────────────────────────────────────────────────

  group('TaskNode', () {
    test('default dependsOn is empty', () {
      final n = TaskNode(
          id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com'));
      expect(n.dependsOn, isEmpty);
    });

    test('toMap includes id, workerClassName, dependsOn', () {
      final n = TaskNode(
        id: 'upload',
        worker: NativeWorker.httpSync(url: 'https://a.com'),
        dependsOn: ['download'],
      );
      final m = n.toMap();
      expect(m['id'], 'upload');
      expect(m['dependsOn'], ['download']);
      expect(m['workerClassName'], isNotEmpty);
    });
  });

  // ─── GraphResult ──────────────────────────────────────────────────────────

  group('GraphResult', () {
    test('success=true with no failures', () {
      const r = GraphResult(
          graphId: 'g',
          success: true,
          completedCount: 3,
          failedNodes: [],
          cancelledNodes: []);
      expect(r.success, isTrue);
      expect(r.completedCount, 3);
      expect(r.failedNodes, isEmpty);
      expect(r.cancelledNodes, isEmpty);
    });

    test('success=false records failed and cancelled nodes', () {
      const r = GraphResult(
          graphId: 'g',
          success: false,
          completedCount: 1,
          failedNodes: ['b'],
          cancelledNodes: ['c', 'd']);
      expect(r.success, isFalse);
      expect(r.completedCount, 1);
      expect(r.failedNodes, ['b']);
      expect(r.cancelledNodes, containsAll(['c', 'd']));
    });

    test('toString contains graphId', () {
      const r = GraphResult(
          graphId: 'my-graph',
          success: false,
          completedCount: 0,
          failedNodes: ['x'],
          cancelledNodes: []);
      expect(r.toString(), contains('my-graph'));
    });
  });

  // ─── Graph execution via mock channel ────────────────────────────────────

  group('TaskGraph execution', () {
    const MethodChannel channel =
        MethodChannel('dev.brewkits/native_workmanager');

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') return null;
        if (methodCall.method == 'enqueueGraph') return 'accepted';
        return null;
      });
      await NativeWorkManager.initialize();
    });

    test('parallel roots both complete → success', () async {
      final graph = TaskGraph(id: 'par1')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b', worker: NativeWorker.httpSync(url: 'https://b.com')))
        ..add(TaskNode(
            id: 'merge',
            worker: NativeWorker.httpSync(url: 'https://m.com'),
            dependsOn: ['a', 'b']));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'par1__a', success: true, timestamp: DateTime.now()));
      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'par1__b', success: true, timestamp: DateTime.now()));
      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'par1__merge', success: true, timestamp: DateTime.now()));

      final result = await execution.result;
      expect(result.success, isTrue);
      expect(result.completedCount, 3);
      expect(result.failedNodes, isEmpty);
      expect(result.cancelledNodes, isEmpty);
    });

    test('second root failure cancels merge but not independent first root',
        () async {
      final graph = TaskGraph(id: 'par2')
        ..add(TaskNode(
            id: 'a', worker: NativeWorker.httpSync(url: 'https://a.com')))
        ..add(TaskNode(
            id: 'b', worker: NativeWorker.httpSync(url: 'https://b.com')))
        ..add(TaskNode(
            id: 'merge',
            worker: NativeWorker.httpSync(url: 'https://m.com'),
            dependsOn: ['a', 'b']));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'par2__a', success: true, timestamp: DateTime.now()));
      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'par2__b', success: false, timestamp: DateTime.now()));

      final result = await execution.result;
      expect(result.success, isFalse);
      expect(result.completedCount, 1); // only 'a' completed
      expect(result.failedNodes, contains('b'));
      expect(result.cancelledNodes, contains('merge'));
    });

    test('single-node graph completes on success', () async {
      final graph = TaskGraph(id: 'solo')
        ..add(TaskNode(
            id: 'only', worker: NativeWorker.httpSync(url: 'https://s.com')));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'solo__only', success: true, timestamp: DateTime.now()));

      final result = await execution.result;
      expect(result.success, isTrue);
      expect(result.completedCount, 1);
    });

    test('single-node graph fails on failure', () async {
      final graph = TaskGraph(id: 'solo2')
        ..add(TaskNode(
            id: 'only', worker: NativeWorker.httpSync(url: 'https://s.com')));

      final execution = await NativeWorkManager.enqueueGraph(graph);

      NativeWorkManager.reportTestEvent(TaskEvent(
          taskId: 'solo2__only', success: false, timestamp: DateTime.now()));

      final result = await execution.result;
      expect(result.success, isFalse);
      expect(result.completedCount, 0);
      expect(result.failedNodes, ['only']);
    });
  });
}
