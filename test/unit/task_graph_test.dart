import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// Workers reused across tests.
final _workerA = HttpRequestWorker(url: 'https://api.example.com/a');
final _workerB = HttpRequestWorker(url: 'https://api.example.com/b');
final _workerC = HttpRequestWorker(url: 'https://api.example.com/c');
final _workerD = HttpRequestWorker(url: 'https://api.example.com/d');

void main() {
  // ──────────────────────────────────────────────────────────────
  // TaskNode
  // ──────────────────────────────────────────────────────────────
  group('TaskNode', () {
    test('default dependsOn is empty', () {
      const node = TaskNode(id: 'a', worker: HttpRequestWorker(url: 'u'));
      expect(node.dependsOn, isEmpty);
    });

    test('default constraints is Constraints()', () {
      const node = TaskNode(id: 'a', worker: HttpRequestWorker(url: 'u'));
      expect(node.constraints, const Constraints());
    });

    test('stores id, worker, dependsOn, constraints', () {
      final worker = HttpRequestWorker(url: 'https://x.com');
      const constraints = Constraints(requiresNetwork: true);
      final node = TaskNode(
        id: 'myNode',
        worker: worker,
        dependsOn: ['dep1', 'dep2'],
        constraints: constraints,
      );
      expect(node.id, 'myNode');
      expect(node.worker, same(worker));
      expect(node.dependsOn, ['dep1', 'dep2']);
      expect(node.constraints, constraints);
    });

    test('toMap contains id and workerClassName', () {
      final node = TaskNode(id: 'n1', worker: _workerA);
      final map = node.toMap();
      expect(map['id'], 'n1');
      expect(map['workerClassName'], 'HttpRequestWorker');
    });

    test('toMap contains workerConfig', () {
      final node = TaskNode(id: 'n1', worker: _workerA);
      final map = node.toMap();
      expect(map['workerConfig'], isA<Map>());
      expect((map['workerConfig'] as Map)['url'], 'https://api.example.com/a');
    });

    test('toMap contains dependsOn list', () {
      final node = TaskNode(
        id: 'n2',
        worker: _workerB,
        dependsOn: ['n1', 'n0'],
      );
      final map = node.toMap();
      expect(map['dependsOn'], ['n1', 'n0']);
    });

    test('toMap contains constraints map', () {
      const c = Constraints(requiresNetwork: true);
      final node = TaskNode(id: 'n3', worker: _workerC, constraints: c);
      final map = node.toMap();
      expect(map['constraints'], isA<Map>());
      expect((map['constraints'] as Map)['requiresNetwork'], true);
    });

    test('toMap dependsOn is empty list when no dependencies', () {
      final node = TaskNode(id: 'n1', worker: _workerA);
      final map = node.toMap();
      expect(map['dependsOn'], isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // TaskGraph – add / nodes
  // ──────────────────────────────────────────────────────────────
  group('TaskGraph – add / nodes', () {
    test('starts empty', () {
      final g = TaskGraph(id: 'g');
      expect(g.nodes, isEmpty);
    });

    test('add returns the graph (fluent)', () {
      final g = TaskGraph(id: 'g');
      final ret = g.add(TaskNode(id: 'a', worker: _workerA));
      expect(identical(ret, g), isTrue);
    });

    test('nodes accumulates added nodes', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA))
        ..add(TaskNode(id: 'b', worker: _workerB));
      expect(g.nodes.length, 2);
      expect(g.nodes.map((n) => n.id), containsAll(['a', 'b']));
    });

    test('nodes is unmodifiable', () {
      final g = TaskGraph(id: 'g')..add(TaskNode(id: 'a', worker: _workerA));
      expect(
        () => g.nodes.add(TaskNode(id: 'x', worker: _workerB)),
        throwsUnsupportedError,
      );
    });

    test('graph id is stored correctly', () {
      final g = TaskGraph(id: 'my-workflow');
      expect(g.id, 'my-workflow');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // TaskGraph – validate – valid graphs
  // ──────────────────────────────────────────────────────────────
  group('TaskGraph – validate – valid', () {
    test('empty graph is valid', () {
      final g = TaskGraph(id: 'g');
      expect(() => g.validate(), returnsNormally);
    });

    test('single node no deps is valid', () {
      final g = TaskGraph(id: 'g')..add(TaskNode(id: 'a', worker: _workerA));
      expect(() => g.validate(), returnsNormally);
    });

    test('linear chain A→B→C is valid', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a']))
        ..add(TaskNode(id: 'c', worker: _workerC, dependsOn: ['b']));
      expect(() => g.validate(), returnsNormally);
    });

    test('diamond DAG (A→B, A→C, B→D, C→D) is valid', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a']))
        ..add(TaskNode(id: 'c', worker: _workerC, dependsOn: ['a']))
        ..add(TaskNode(id: 'd', worker: _workerD, dependsOn: ['b', 'c']));
      expect(() => g.validate(), returnsNormally);
    });

    test('parallel roots with shared fan-in is valid', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'r1', worker: _workerA))
        ..add(TaskNode(id: 'r2', worker: _workerB))
        ..add(TaskNode(id: 'merge', worker: _workerC, dependsOn: ['r1', 'r2']));
      expect(() => g.validate(), returnsNormally);
    });

    test('node depending on multiple siblings is valid', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'x', worker: _workerA))
        ..add(TaskNode(id: 'y', worker: _workerB))
        ..add(TaskNode(id: 'z', worker: _workerC, dependsOn: ['x', 'y']));
      expect(() => g.validate(), returnsNormally);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // TaskGraph – validate – duplicate IDs
  // ──────────────────────────────────────────────────────────────
  group('TaskGraph – validate – duplicate IDs', () {
    test('throws ArgumentError for two identical IDs', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'dup', worker: _workerA))
        ..add(TaskNode(id: 'dup', worker: _workerB));
      expect(
        () => g.validate(),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Duplicate node ID'),
        )),
      );
    });

    test('error message includes the duplicate ID', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'alpha', worker: _workerA))
        ..add(TaskNode(id: 'alpha', worker: _workerB));
      expect(
        () => g.validate(),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('alpha'),
        )),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // TaskGraph – validate – missing dependencies
  // ──────────────────────────────────────────────────────────────
  group('TaskGraph – validate – missing dependencies', () {
    test('throws when dependsOn references unknown node', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA, dependsOn: ['ghost']));
      expect(() => g.validate(), throwsA(isA<ArgumentError>()));
    });

    test('error message includes the missing dependency ID', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA, dependsOn: ['missing-dep']));
      expect(
        () => g.validate(),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('missing-dep'),
        )),
      );
    });

    test('error names the node with the missing dep', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'node-x', worker: _workerA, dependsOn: ['ghost']));
      expect(
        () => g.validate(),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('node-x'),
        )),
      );
    });

    test('throws even if some dependencies exist', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a', 'ghost']));
      expect(() => g.validate(), throwsA(isA<ArgumentError>()));
    });
  });

  // ──────────────────────────────────────────────────────────────
  // TaskGraph – validate – cycle detection
  // ──────────────────────────────────────────────────────────────
  group('TaskGraph – validate – cycle detection', () {
    test('self-loop A → A throws', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA, dependsOn: ['a']));
      expect(() => g.validate(), throwsA(isA<ArgumentError>()));
    });

    test('two-node cycle A→B, B→A throws', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA, dependsOn: ['b']))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a']));
      expect(() => g.validate(), throwsA(isA<ArgumentError>()));
    });

    test('three-node cycle A→B→C→A throws', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA, dependsOn: ['c']))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a']))
        ..add(TaskNode(id: 'c', worker: _workerC, dependsOn: ['b']));
      expect(() => g.validate(), throwsA(isA<ArgumentError>()));
    });

    test('cycle in subgraph with unrelated root node throws', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'root', worker: _workerD))
        ..add(TaskNode(id: 'a', worker: _workerA, dependsOn: ['b']))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a']));
      expect(() => g.validate(), throwsA(isA<ArgumentError>()));
    });

    test('cycle error message mentions "Cycle"', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'x', worker: _workerA, dependsOn: ['x']));
      expect(
        () => g.validate(),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Cycle'),
        )),
      );
    });

    test('diamond (no cycle) does NOT throw', () {
      final g = TaskGraph(id: 'g')
        ..add(TaskNode(id: 'a', worker: _workerA))
        ..add(TaskNode(id: 'b', worker: _workerB, dependsOn: ['a']))
        ..add(TaskNode(id: 'c', worker: _workerC, dependsOn: ['a']))
        ..add(TaskNode(id: 'd', worker: _workerD, dependsOn: ['b', 'c']));
      expect(() => g.validate(), returnsNormally);
    });
  });
}
