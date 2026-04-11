import '../constraints.dart';
import '../enqueue_request.dart';
import '../events.dart';
import '../task_chain.dart';
import '../task_graph.dart';
import '../task_trigger.dart';
import '../worker.dart';

/// Testable interface for [NativeWorkManager].
///
/// Inject this into services/repositories that need to schedule tasks.
/// In production code, use [NativeWorkManagerClient] (wraps the real plugin).
/// In tests, use [FakeWorkManager] (in-memory test double).
///
/// ## Migration
///
/// Before (untestable static calls):
/// ```dart
/// class SyncService {
///   Future<void> syncNow() async {
///     await NativeWorkManager.enqueue(
///       taskId: 'sync',
///       trigger: TaskTrigger.oneTime(),
///       worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///     );
///   }
/// }
/// ```
///
/// After (injectable, testable):
/// ```dart
/// class SyncService {
///   const SyncService(this._workManager);
///   final IWorkManager _workManager;
///
///   Future<void> syncNow() async {
///     await _workManager.enqueue(
///       taskId: 'sync',
///       trigger: TaskTrigger.oneTime(),
///       worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///     );
///   }
/// }
///
/// // Production:
/// final service = SyncService(NativeWorkManagerClient());
///
/// // Test:
/// final fake = FakeWorkManager();
/// final service = SyncService(fake);
/// await service.syncNow();
/// expect(fake.enqueued.length, 1);
/// expect(fake.enqueued.first.taskId, 'sync');
/// ```
abstract interface class IWorkManager {
  // ── Streams ────────────────────────────────────────────────────────────────

  /// Task completion and lifecycle events.
  Stream<TaskEvent> get events;

  /// Task progress updates (downloads, uploads, chains).
  Stream<TaskProgress> get progress;

  // ── Scheduling ─────────────────────────────────────────────────────────────

  /// Schedule a single background task.
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints,
    ExistingTaskPolicy existingPolicy,
    String? tag,
  });

  /// Schedule multiple tasks at once.
  Future<List<ScheduleResult>> enqueueAll(List<EnqueueRequest> requests);

  /// Begin a task chain starting with [task].
  ///
  /// Returns a [TaskChainBuilder] to append further steps.
  TaskChainBuilder beginWith(TaskRequest task);

  /// Schedule a [TaskGraph] (directed acyclic graph) of background tasks.
  Future<GraphExecution> enqueueGraph(TaskGraph graph);

  // ── Cancellation ───────────────────────────────────────────────────────────

  /// Cancel a specific task by ID.
  Future<void> cancel({required String taskId});

  /// Cancel all tasks with the given tag.
  Future<void> cancelByTag({required String tag});

  /// Cancel all pending and running tasks.
  Future<void> cancelAll();

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  /// Pause a running task (best-effort; effective for download workers).
  Future<void> pause({required String taskId});

  /// Resume a previously paused task.
  Future<void> resume({required String taskId});

  // ── Query ──────────────────────────────────────────────────────────────────

  /// Returns the current status of a task, or `null` if not found.
  Future<TaskStatus?> getTaskStatus({required String taskId});

  /// Returns the detailed record of a task, or `null` if not found.
  Future<TaskRecord?> getTaskRecord({required String taskId});

  /// Returns all task IDs associated with [tag].
  Future<List<String>> getTasksByTag({required String tag});

  /// Returns all active tags.
  Future<List<String>> getAllTags();

  /// Returns all task records from the persistent store.
  Future<List<TaskRecord>> allTasks();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Release resources held by this instance.
  ///
  /// For [FakeWorkManager]: closes stream controllers and restores
  /// [TaskChainBuilder.enqueueCallback].
  ///
  /// For [NativeWorkManagerClient]: no-op (lifecycle is managed by the
  /// underlying [NativeWorkManager] which is process-scoped).
  ///
  /// Always call this in `tearDown` when using [FakeWorkManager].
  void dispose();
}
