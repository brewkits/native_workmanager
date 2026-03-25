import 'package:flutter/foundation.dart';

import 'constraints.dart';
import 'events.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// A single task request for use with [NativeWorkManager.enqueueAll].
///
/// Bundles all parameters needed to call `NativeWorkManager.enqueue` so that
/// multiple tasks can be submitted in a single [NativeWorkManager.enqueueAll]
/// call.
///
/// ## Example
///
/// ```dart
/// final paths = ['/data/a.zip', '/data/b.zip'];
/// final urls  = ['https://cdn.example.com/a.zip',
///                'https://cdn.example.com/b.zip'];
///
/// final results = await NativeWorkManager.enqueueAll([
///   for (var i = 0; i < paths.length; i++)
///     EnqueueRequest(
///       taskId: 'dl-$i',
///       trigger: TaskTrigger.oneTime(),
///       worker: NativeWorker.httpDownload(url: urls[i], savePath: paths[i]),
///       tag: 'batch-download',
///     ),
/// ]);
///
/// final accepted = results.where((r) => r == ScheduleResult.accepted).length;
/// print('$accepted / ${results.length} tasks accepted');
/// ```
@immutable
class EnqueueRequest {
  const EnqueueRequest({
    required this.taskId,
    required this.trigger,
    required this.worker,
    this.constraints = const Constraints(),
    this.existingPolicy = ExistingTaskPolicy.replace,
    this.tag,
  });

  /// Unique identifier for this task.
  final String taskId;

  /// When to run the task.
  final TaskTrigger trigger;

  /// The worker implementation to execute.
  final Worker worker;

  /// Device constraints (network, battery, etc.).
  final Constraints constraints;

  /// What to do when a task with [taskId] already exists.
  final ExistingTaskPolicy existingPolicy;

  /// Optional tag for grouping (see [NativeWorkManager.cancelByTag]).
  final String? tag;
}
