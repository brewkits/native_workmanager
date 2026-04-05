import '../constraints.dart';
import '../enqueue_request.dart';
import '../events.dart';
import '../native_work_manager.dart';
import '../task_chain.dart';
import '../task_graph.dart';
import '../task_trigger.dart';
import '../worker.dart';
import 'i_work_manager.dart';

/// Production [IWorkManager] that delegates to [NativeWorkManager].
///
/// Use this class as the real implementation in production code.
/// Pass [FakeWorkManager] in tests instead.
///
/// ## DI registration examples
///
/// ### get_it
/// ```dart
/// GetIt.instance.registerLazySingleton<IWorkManager>(
///   () => NativeWorkManagerClient(),
/// );
/// ```
///
/// ### Riverpod
/// ```dart
/// final workManagerProvider = Provider<IWorkManager>(
///   (ref) => NativeWorkManagerClient(),
/// );
/// ```
///
/// ### Flutter InheritedWidget / Provider package
/// ```dart
/// Provider<IWorkManager>(
///   create: (_) => NativeWorkManagerClient(),
///   child: MyApp(),
/// )
/// ```
class NativeWorkManagerClient implements IWorkManager {
  const NativeWorkManagerClient();

  @override
  Stream<TaskEvent> get events => NativeWorkManager.events;

  @override
  Stream<TaskProgress> get progress => NativeWorkManager.progress;

  @override
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints = const Constraints(),
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
    String? tag,
  }) =>
      NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: trigger,
        worker: worker,
        constraints: constraints,
        existingPolicy: existingPolicy,
        tag: tag,
      );

  @override
  Future<List<ScheduleResult>> enqueueAll(List<EnqueueRequest> requests) =>
      NativeWorkManager.enqueueAll(requests);

  @override
  TaskChainBuilder beginWith(TaskRequest task) =>
      NativeWorkManager.beginWith(task);

  @override
  Future<GraphExecution> enqueueGraph(TaskGraph graph) =>
      NativeWorkManager.enqueueGraph(graph);

  @override
  Future<void> cancel({required String taskId}) =>
      NativeWorkManager.cancel(taskId: taskId);

  @override
  Future<void> cancelByTag({required String tag}) =>
      NativeWorkManager.cancelByTag(tag: tag);

  @override
  Future<void> cancelAll() => NativeWorkManager.cancelAll();

  @override
  Future<void> pause({required String taskId}) =>
      NativeWorkManager.pause(taskId: taskId);

  @override
  Future<void> resume({required String taskId}) async =>
      NativeWorkManager.resume(taskId: taskId);

  @override
  Future<TaskStatus?> getTaskStatus({required String taskId}) =>
      NativeWorkManager.getTaskStatus(taskId: taskId);

  @override
  Future<List<String>> getTasksByTag({required String tag}) =>
      NativeWorkManager.getTasksByTag(tag: tag);

  @override
  Future<List<String>> getAllTags() => NativeWorkManager.getAllTags();

  @override
  Future<List<TaskRecord>> allTasks() => NativeWorkManager.allTasks();

  /// No-op for the real client — [NativeWorkManager] is process-scoped.
  @override
  void dispose() {}
}
