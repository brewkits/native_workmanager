import 'dart:async';

import 'package:flutter/foundation.dart';

import 'constraints.dart';
import 'events.dart';
import 'native_work_manager.dart';
import 'platform_interface.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// A node in a [TaskGraph].
///
/// Each node represents one background task. Nodes can have zero or more
/// dependencies — a node does not execute until all its dependencies complete
/// successfully.
@immutable
class TaskNode {
  const TaskNode({
    required this.id,
    required this.worker,
    this.dependsOn = const [],
    this.constraints = const Constraints(),
  });

  /// Unique ID for this task within the graph.
  final String id;

  /// The worker to execute.
  final Worker worker;

  /// IDs of nodes that must complete before this node runs.
  ///
  /// Empty means the node has no dependencies and runs immediately.
  final List<String> dependsOn;

  /// Optional scheduling constraints for this node.
  final Constraints constraints;

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerClassName': worker.workerClassName,
      'workerConfig': worker.toMap(),
      'dependsOn': dependsOn,
      'constraints': constraints.toMap(),
    };
  }
}

/// A directed acyclic graph (DAG) of background tasks.
///
/// Use [TaskGraph] when you need complex parallel → sequential workflows
/// that go beyond a simple linear [TaskChainBuilder].
///
/// ## Example: Parallel download → merge → upload
///
/// ```dart
/// // A and B download in parallel.
/// // When both finish, C merges the results.
/// // When merge is done, D uploads.
///
/// final graph = TaskGraph(id: 'export-workflow')
///   ..add(TaskNode(id: 'download-A', worker: HttpDownloadWorker(
///       url: 'https://cdn.example.com/part-a.zip',
///       savePath: '/tmp/part-a.zip')))
///   ..add(TaskNode(id: 'download-B', worker: HttpDownloadWorker(
///       url: 'https://cdn.example.com/part-b.zip',
///       savePath: '/tmp/part-b.zip')))
///   ..add(TaskNode(id: 'merge', worker: DartWorker(callbackId: 'mergeFiles'),
///       dependsOn: ['download-A', 'download-B']))
///   ..add(TaskNode(id: 'upload', worker: HttpUploadWorker(
///       url: 'https://api.example.com/submit',
///       filePath: '/tmp/merged.zip'),
///       dependsOn: ['merge']));
///
/// final execution = await NativeWorkManager.enqueueGraph(graph);
///
/// // Monitor completion
/// execution.result.then((r) {
///   if (r.success) print('All ${r.completedCount} tasks done!');
///   else print('Failed: ${r.failedNodes}');
/// });
/// ```
///
/// ## Constraints Per Node
///
/// ```dart
/// final graph = TaskGraph(id: 'nightly-sync')
///   ..add(TaskNode(
///       id: 'heavy-compute',
///       worker: DartWorker(callbackId: 'computeStats'),
///       constraints: Constraints(requiresCharging: true)))
///   ..add(TaskNode(
///       id: 'upload-stats',
///       worker: HttpUploadWorker(url: uploadUrl, filePath: statsFile),
///       dependsOn: ['heavy-compute'],
///       constraints: Constraints(requiresWifi: true)));
///
/// await NativeWorkManager.enqueueGraph(graph);
/// ```
///
/// ## Failure Behavior
///
/// If a node fails, all downstream nodes that depend on it (directly or
/// transitively) are **cancelled**. Nodes that do not depend on the failed
/// node continue to execute.
///
/// ## Limitations
///
/// - The graph must be a **DAG** — cycles are detected during [enqueue] and
///   throw an [ArgumentError].
/// - All node IDs must be **unique within the graph**.
/// - The implementation uses the existing [NativeWorkManager.events] stream
///   for fan-in synchronization, so the app must be running while the graph
///   executes. For graphs that must survive app termination, use individual
///   [NativeWorkManager.enqueue] calls with [TaskTrigger] instead.
class TaskGraph {
  TaskGraph({required this.id});

  /// Unique ID for this graph execution.  Used to namespace node task IDs.
  final String id;

  final List<TaskNode> _nodes = [];

  Map<String, TaskNode> get _nodeMap => {for (final n in _nodes) n.id: n};

  /// Add a [TaskNode] to the graph.
  ///
  /// Returns `this` for fluent chaining:
  /// ```dart
  /// final graph = TaskGraph(id: 'my-flow')
  ///   ..add(TaskNode(id: 'a', worker: workerA))
  ///   ..add(TaskNode(id: 'b', worker: workerB, dependsOn: ['a']));
  /// ```
  TaskGraph add(TaskNode node) {
    _nodes.add(node);
    return this;
  }

  /// Validate the graph: check for duplicate IDs, missing dependencies,
  /// and cycles.
  ///
  /// Throws [ArgumentError] if the graph is invalid.
  void validate() {
    final ids = <String>{};
    for (final n in _nodes) {
      if (!ids.add(n.id)) {
        throw ArgumentError('Duplicate node ID in TaskGraph: "${n.id}"');
      }
    }
    for (final n in _nodes) {
      for (final dep in n.dependsOn) {
        if (!ids.contains(dep)) {
          throw ArgumentError(
            'Node "${n.id}" depends on unknown node "$dep"',
          );
        }
      }
    }
    // Cycle detection via DFS
    final visited = <String>{};
    final inStack = <String>{};

    void dfs(String nodeId) {
      if (inStack.contains(nodeId)) {
        throw ArgumentError('Cycle detected in TaskGraph at node "$nodeId"');
      }
      if (visited.contains(nodeId)) return;
      inStack.add(nodeId);
      for (final dep in _nodeMap[nodeId]!.dependsOn) {
        dfs(dep);
      }
      inStack.remove(nodeId);
      visited.add(nodeId);
    }

    for (final n in _nodes) {
      dfs(n.id);
    }
  }

  /// Topologically sorted nodes (roots first).
  List<TaskNode> get _topoSorted {
    final result = <TaskNode>[];
    final visited = <String>{};

    void visit(String id) {
      if (visited.contains(id)) return;
      final node = _nodeMap[id]!;
      for (final dep in node.dependsOn) {
        visit(dep);
      }
      visited.add(id);
      result.add(node);
    }

    for (final n in _nodes) {
      visit(n.id);
    }
    return result;
  }

  /// Returns the set of node IDs that are roots (no dependencies).
  Set<String> get _roots =>
      _nodes.where((n) => n.dependsOn.isEmpty).map((n) => n.id).toSet();

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nodes': _nodes.map((n) => n.toMap()).toList(),
    };
  }
}

/// Result of a [TaskGraph] execution.
@immutable
class GraphResult {
  const GraphResult({
    required this.graphId,
    required this.success,
    required this.completedCount,
    required this.failedNodes,
    required this.cancelledNodes,
  });

  final String graphId;

  /// `true` when all nodes completed successfully.
  final bool success;

  /// Number of nodes that completed successfully.
  final int completedCount;

  /// IDs of nodes that failed.
  final List<String> failedNodes;

  /// IDs of nodes that were cancelled due to upstream failure.
  final List<String> cancelledNodes;

  @override
  String toString() => 'GraphResult($graphId: success=$success, '
      'completed=$completedCount, '
      'failed=${failedNodes.length}, '
      'cancelled=${cancelledNodes.length})';
}

/// Handle returned by [NativeWorkManager.enqueueGraph].
///
/// Exposes a [result] future that resolves when the entire graph finishes
/// (all nodes complete or any node fails).
class GraphExecution {
  GraphExecution._(this.graphId, this._result);

  final String graphId;
  final Future<GraphResult> _result;

  /// Resolves when all graph nodes have finished executing.
  Future<GraphResult> get result => _result;
}

// ── Internal executor ─────────────────────────────────────────────────────────

/// Executes a [TaskGraph] by scheduling nodes in dependency order.
///
/// Internal implementation — callers use [NativeWorkManager.enqueueGraph].
class _GraphExecutor {
  _GraphExecutor(this._graph);

  final TaskGraph _graph;

  final _completed = <String>{};
  final _failed = <String>{};
  final _cancelled = <String>{};
  final _inFlight = <String>{};

  late Completer<GraphResult> _completer;
  StreamSubscription<TaskEvent>? _eventSub;

  Future<GraphResult> execute({bool isAlreadyEnqueued = false}) async {
    _graph.validate();

    _completer = Completer<GraphResult>();
    final nodes = _graph._topoSorted;

    if (nodes.isEmpty) {
      return GraphResult(
        graphId: _graph.id,
        success: true,
        completedCount: 0,
        failedNodes: const [],
        cancelledNodes: const [],
      );
    }

    // Listen to events before scheduling to avoid race conditions.
    _eventSub = NativeWorkManagerPlatform.instance.events.listen(_onEvent);

    if (!isAlreadyEnqueued) {
      // Schedule all root nodes immediately (legacy behavior).
      for (final nodeId in _graph._roots) {
        await _scheduleNode(_graph._nodeMap[nodeId]!);
      }
    } else {
      // Mark all nodes as in-flight since they are being handled by native.
      for (final node in _graph._nodes) {
        _inFlight.add(node.id);
      }
    }

    return _completer.future;
  }

  void _onEvent(TaskEvent event) {
    final taskId = event.taskId;
    // Strip the graph namespace prefix to get the node ID.
    final prefix = '${_graph.id}__';
    if (!taskId.startsWith(prefix)) return;
    final nodeId = taskId.substring(prefix.length);

    if (!_inFlight.contains(nodeId)) return;
    _inFlight.remove(nodeId);

    if (event.success) {
      _completed.add(nodeId);
      _tryScheduleDownstream(nodeId);
    } else {
      _failed.add(nodeId);
      _cancelDownstream(nodeId);
    }

    _checkDone();
  }

  void _tryScheduleDownstream(String completedNodeId) {
    for (final node in _graph._nodes) {
      if (_completed.contains(node.id) ||
          _failed.contains(node.id) ||
          _cancelled.contains(node.id) ||
          _inFlight.contains(node.id)) {
        continue;
      }

      // All dependencies satisfied?
      final ready = node.dependsOn.every(_completed.contains);
      if (ready) {
        _scheduleNode(node);
      }
    }
  }

  Future<void> _scheduleNode(TaskNode node) async {
    _inFlight.add(node.id);
    try {
      await NativeWorkManager.enqueue(
        taskId: '${_graph.id}__${node.id}',
        trigger: TaskTrigger.oneTime(),
        worker: node.worker,
        constraints: node.constraints,
      );
    } catch (e) {
      _inFlight.remove(node.id);
      _failed.add(node.id);
      _cancelDownstream(node.id);
      _checkDone();
    }
  }

  void _cancelDownstream(String failedNodeId) {
    final allNodes = _graph._nodeMap;

    // BFS to find all transitive dependents of failedNodeId.
    final queue = <String>[failedNodeId];
    final toCancel = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final node in allNodes.values) {
        if (node.dependsOn.contains(current) &&
            !_completed.contains(node.id) &&
            !_failed.contains(node.id) &&
            !toCancel.contains(node.id)) {
          toCancel.add(node.id);
          queue.add(node.id);
        }
      }
    }

    for (final nodeId in toCancel) {
      _inFlight.remove(nodeId);
      _cancelled.add(nodeId);
    }
  }

  void _checkDone() {
    final total = _graph._nodes.length;
    final resolved = _completed.length + _failed.length + _cancelled.length;
    if (resolved < total) return;
    if (_inFlight.isNotEmpty) return;

    _eventSub?.cancel();
    _eventSub = null;

    _completer.complete(GraphResult(
      graphId: _graph.id,
      success: _failed.isEmpty && _cancelled.isEmpty,
      completedCount: _completed.length,
      failedNodes: _failed.toList(),
      cancelledNodes: _cancelled.toList(),
    ));
  }
}

/// Enqueue a [TaskGraph] for execution.
///
/// This is the internal implementation called by
/// [NativeWorkManager.enqueueGraph]. Not part of the public API.
Future<GraphExecution> enqueueTaskGraph(TaskGraph graph) async {
  graph.validate();

  // 1. Send graph to native for persistent orchestration.
  // This ensures the graph continues even if the app is killed.
  await NativeWorkManagerPlatform.instance.enqueueGraph(graph.toMap());

  // 2. Start the Dart-side listener so we can resolve the result future
  // if the app stays alive.
  final executor = _GraphExecutor(graph);
  final resultFuture = executor.execute(isAlreadyEnqueued: true);

  return GraphExecution._(graph.id, resultFuture);
}
