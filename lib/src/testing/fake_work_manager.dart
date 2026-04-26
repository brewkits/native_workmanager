import 'dart:async';

import '../constraints.dart';
import '../enqueue_request.dart';
import '../events.dart';
import '../task_chain.dart';
import '../task_graph.dart';
import '../task_handler.dart';
import '../task_trigger.dart';
import '../worker.dart';
import 'i_work_manager.dart';

/// A full record of a chain that was enqueued via [FakeWorkManager.beginWith].
class FakeChainRecord {
  const FakeChainRecord({
    required this.firstTask,
    required this.steps,
  });

  /// The task passed to [FakeWorkManager.beginWith].
  final TaskRequest firstTask;

  /// All steps of the built chain (each step is a list of parallel tasks).
  /// Mirrors [TaskChainBuilder.steps].
  final List<List<TaskRequest>> steps;

  /// Flat list of all tasks across all steps, in order.
  List<TaskRequest> get allTasks => steps.expand((s) => s).toList();

  @override
  String toString() {
    final desc = steps
        .map((s) =>
            s.length == 1 ? s.first.id : '[${s.map((t) => t.id).join(', ')}]')
        .join(' → ');
    return 'FakeChainRecord($desc)';
  }
}

/// In-memory [IWorkManager] test double.
///
/// Records every call and lets you inject [TaskEvent]s / [TaskProgress] updates
/// via [emitEvent] and [emitProgress].
///
/// **Important lifecycle rules:**
/// - Always call [dispose] in `tearDown` to prevent resource leaks and
///   to restore [TaskChainBuilder.enqueueCallback] to its original value.
/// - Calling [reset] recreates the stream controllers; existing stream
///   subscriptions are cancelled. Re-subscribe after [reset] if needed.
///
/// ## Example
///
/// ```dart
/// group('SyncService', () {
///   late FakeWorkManager wm;
///   late SyncService service;
///
///   setUp(() {
///     wm = FakeWorkManager();
///     service = SyncService(wm);
///   });
///
///   tearDown(wm.dispose); // ← always required
///
///   test('schedules one task on start', () async {
///     await service.start();
///     expect(wm.enqueued, hasLength(1));
///     expect(wm.enqueued.first.taskId, 'periodic-sync');
///   });
///
///   test('reacts to task failure', () async {
///     await service.start();
///     wm.emitEvent(TaskEvent(
///       taskId: 'periodic-sync',
///       success: false,
///       message: 'Network error',
///       timestamp: DateTime.now(),
///     ));
///     expect(service.lastError, 'Network error');
///   });
///
///   test('cancels on stop', () async {
///     await service.start();
///     await service.stop();
///     expect(wm.cancelAllCalled, isTrue);
///   });
///
///   test('full chain structure is visible', () async {
///     await service.startWithChain();
///     expect(wm.chains, hasLength(1));
///     expect(wm.chains.first.allTasks.map((t) => t.id), ['step1', 'step2', 'step3']);
///   });
/// });
/// ```
class FakeWorkManager implements IWorkManager {
  /// Creates a new [FakeWorkManager].
  ///
  /// Saves the current [TaskChainBuilder.enqueueCallback] so it can be restored
  /// on [dispose]. This prevents test contamination when multiple test cases run
  /// in the same process.
  FakeWorkManager() {
    _savedEnqueueCallback = TaskChainBuilder.enqueueCallback;
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  StreamController<TaskEvent> _eventsController =
      StreamController<TaskEvent>.broadcast();
  StreamController<TaskProgress> _progressController =
      StreamController<TaskProgress>.broadcast();

  @override
  Stream<TaskEvent> get events => _eventsController.stream;

  @override
  Stream<TaskProgress> get progress => _progressController.stream;

  @override
  Future<Map<String, TaskProgress>> getRunningProgress() async => {};

  // ── Scheduling ─────────────────────────────────────────────────────────────

  /// All [enqueue] / [enqueueAll] calls in order.
  final List<EnqueueCall> enqueued = [];

  /// All recorded chains from [beginWith], with their full step structures.
  final List<FakeChainRecord> chains = [];

  /// All [cancel] task IDs in order.
  final List<String> cancelled = [];

  /// All [cancelByTag] values in order.
  final List<String> cancelledTags = [];

  /// Whether [cancelAll] was called.
  bool cancelAllCalled = false;

  /// All [pause] task IDs in order.
  final List<String> paused = [];

  /// All [resume] task IDs in order.
  final List<String> resumed = [];

  // ── Configurable responses ─────────────────────────────────────────────────

  /// Default return value for [enqueue] / [enqueueAll].
  ScheduleResult enqueueResult = ScheduleResult.accepted;

  /// Per-task result overrides. Falls back to [enqueueResult] if not set.
  ///
  /// Use this to simulate mixed results in [enqueueAll]:
  /// ```dart
  /// wm.enqueueResultByTaskId['task-2'] = ScheduleResult.rejectedOsPolicy;
  /// final results = await wm.enqueueAll([req1, req2, req3]);
  /// // [accepted, rejectedOsPolicy, accepted]
  /// ```
  final Map<String, ScheduleResult> enqueueResultByTaskId = {};

  /// Stub task statuses. [getTaskStatus] returns `null` for unknown IDs.
  final Map<String, TaskStatus> taskStatuses = {};

  /// Stub tasks-by-tag. [getTasksByTag] returns `[]` for unknown tags.
  final Map<String, List<String>> tasksByTag = {};

  /// Return value for [getAllTags].
  List<String> allTagsResult = [];

  /// Return value for [allTasks].
  List<TaskRecord> allTasksResult = [];

  // ── Internal ───────────────────────────────────────────────────────────────

  // Saved so dispose() can restore it — prevents C-02 test contamination.
  Future<ScheduleResult> Function(TaskChainBuilder)? _savedEnqueueCallback;

  // ── IWorkManager ───────────────────────────────────────────────────────────
  @override
  Future<TaskHandler> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints = const Constraints(),
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
    String? tag,
  }) async {
    enqueued.add(
      EnqueueCall(
        taskId: taskId,
        trigger: trigger,
        worker: worker,
        constraints: constraints,
        existingPolicy: existingPolicy,
        tag: tag,
      ),
    );
    return TaskHandler(
      taskId: taskId,
      scheduleResult: enqueueResultByTaskId[taskId] ?? enqueueResult,
    );
  }

  @override
  Future<List<TaskHandler>> enqueueAll(List<EnqueueRequest> requests) async {
    return [
      for (final r in requests)
        await enqueue(
          taskId: r.taskId,
          trigger: r.trigger,
          worker: r.worker,
          constraints: r.constraints,
          existingPolicy: r.existingPolicy,
          tag: r.tag,
        ),
    ];
  }

  /// Records the chain start and intercepts [TaskChainBuilder.enqueue] so the
  /// full chain structure (all steps from all `.then()` / `.thenAll()` calls)
  /// is captured in [chains].
  ///
  /// **Note:** This overwrites [TaskChainBuilder.enqueueCallback]. The original
  /// value is restored when [dispose] is called.
  @override
  TaskChainBuilder beginWith(TaskRequest task) {
    final builder = TaskChainBuilder.internal([task]);

    // Intercept enqueue() on the builder to capture the complete chain.
    // C-02 fix: we saved the original callback in the constructor; it is
    // restored in dispose() so tests can't contaminate each other.
    TaskChainBuilder.enqueueCallback = (b) async {
      final record = FakeChainRecord(firstTask: task, steps: b.steps);
      chains.add(record);

      // Also record each task in enqueued for easy assertion.
      for (final step in b.steps) {
        for (final t in step) {
          enqueued.add(EnqueueCall(
            taskId: t.id,
            trigger: const TaskTrigger.oneTime(),
            worker: t.worker,
            constraints: t.constraints,
            existingPolicy: ExistingTaskPolicy.replace,
            tag: null,
          ));
        }
      }

      return enqueueResultByTaskId[task.id] ?? enqueueResult;
    };

    return builder;
  }

  @override
  Future<GraphExecution> enqueueGraph(TaskGraph graph) async {
    graph.validate();

    // Record root nodes as enqueued (since they start immediately)
    final rootNodes = graph.nodes.where((n) => n.dependsOn.isEmpty);
    for (final node in rootNodes) {
      enqueued.add(EnqueueCall(
        taskId: node.id,
        trigger: const TaskTrigger.oneTime(),
        worker: node.worker,
        constraints: node.constraints,
        existingPolicy: ExistingTaskPolicy.replace,
        tag: null,
      ));
    }

    // In a fake, we don't actually run the DAG logic unless requested.
    // For now just return a handle that never completes automatically.
    return GraphExecution.internal(graph.id, Completer<GraphResult>().future);
  }

  @override
  Future<void> cancel({required String taskId}) async => cancelled.add(taskId);

  @override
  Future<void> cancelByTag({required String tag}) async =>
      cancelledTags.add(tag);

  @override
  Future<void> cancelAll() async => cancelAllCalled = true;

  @override
  Future<void> pause({required String taskId}) async => paused.add(taskId);

  @override
  Future<void> resume({required String taskId}) async => resumed.add(taskId);

  @override
  Future<TaskStatus?> getTaskStatus({required String taskId}) async =>
      taskStatuses[taskId];

  @override
  Future<TaskRecord?> getTaskRecord({required String taskId}) async {
    return allTasksResult.where((t) => t.taskId == taskId).firstOrNull;
  }

  @override
  Future<List<String>> getTasksByTag({required String tag}) async =>
      tasksByTag[tag] ?? [];

  @override
  Future<List<String>> getAllTags() async => allTagsResult;

  @override
  Future<List<TaskRecord>> allTasks() async => allTasksResult;

  // ── Test helpers ───────────────────────────────────────────────────────────

  /// Push a [TaskEvent] into the [events] stream.
  void emitEvent(TaskEvent event) => _eventsController.add(event);

  /// Push a [TaskProgress] into the [progress] stream.
  void emitProgress(TaskProgress p) => _progressController.add(p);

  /// Clear all recorded state and recreate stream controllers.
  ///
  /// Existing stream subscriptions are cancelled when the old controllers are
  /// closed — re-subscribe to [events] and [progress] after calling [reset].
  void reset() {
    // M-04 fix: close and recreate stream controllers so old subscriptions
    // (from a previous test phase) do not receive events from the new phase.
    _eventsController.close();
    _eventsController = StreamController<TaskEvent>.broadcast();
    _progressController.close();
    _progressController = StreamController<TaskProgress>.broadcast();

    enqueued.clear();
    chains.clear();
    cancelled.clear();
    cancelledTags.clear();
    cancelAllCalled = false;
    paused.clear();
    resumed.clear();
    taskStatuses.clear();
    tasksByTag.clear();
    enqueueResultByTaskId.clear();
    allTagsResult = [];
    allTasksResult = [];
    enqueueResult = ScheduleResult.accepted;
  }

  /// Close stream controllers and restore [TaskChainBuilder.enqueueCallback].
  ///
  /// **Must** be called in `tearDown` to prevent:
  /// - Stream subscription leaks.
  /// - Test contamination via the static [TaskChainBuilder.enqueueCallback].
  @override
  void dispose() {
    // C-02 fix: restore the original enqueueCallback so subsequent tests
    // (or production code) are not affected by this fake.
    TaskChainBuilder.enqueueCallback = _savedEnqueueCallback;
    _eventsController.close();
    _progressController.close();
  }
}

// ── Support types ──────────────────────────────────────────────────────────

/// A single recorded [FakeWorkManager.enqueue] invocation.
class EnqueueCall {
  const EnqueueCall({
    required this.taskId,
    required this.trigger,
    required this.worker,
    required this.constraints,
    required this.existingPolicy,
    this.tag,
  });

  final String taskId;
  final TaskTrigger trigger;
  final Worker worker;
  final Constraints constraints;
  final ExistingTaskPolicy existingPolicy;
  final String? tag;

  // L-02 fix: implement == and hashCode so expect(wm.enqueued, contains(...))
  // works correctly in tests.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnqueueCall &&
        other.taskId == taskId &&
        other.tag == tag &&
        other.existingPolicy == existingPolicy;
  }

  @override
  int get hashCode => Object.hash(taskId, tag, existingPolicy);

  @override
  String toString() =>
      'EnqueueCall(taskId: $taskId, trigger: ${trigger.runtimeType}, tag: $tag)';
}
