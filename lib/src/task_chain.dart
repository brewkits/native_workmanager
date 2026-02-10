import 'package:flutter/foundation.dart';

import 'constraints.dart';
import 'events.dart';
import 'worker.dart';

/// A single task request in a chain.
///
/// Represents one step in a multi-step workflow. Combine multiple TaskRequests
/// using [TaskChainBuilder] to create complex sequential or parallel workflows.
///
/// ## Basic Usage
///
/// ```dart
/// final downloadTask = TaskRequest(
///   id: 'download-file',
///   worker: NativeWorker.httpDownload(
///     url: 'https://cdn.example.com/data.zip',
///     savePath: '/tmp/data.zip',
///   ),
/// );
///
/// final processTask = TaskRequest(
///   id: 'process-data',
///   worker: DartWorker(callbackId: 'processZipFile'),
/// );
///
/// // Combine into a chain
/// await NativeWorkManager.beginWith(downloadTask)
///     .then(processTask)
///     .enqueue();
/// ```
///
/// ## With Constraints
///
/// ```dart
/// final uploadTask = TaskRequest(
///   id: 'upload-results',
///   worker: NativeWorker.httpUpload(
///     url: 'https://api.example.com/results',
///     filePath: '/tmp/results.json',
///   ),
///   constraints: Constraints(
///     requiresWifi: true,
///     requiresCharging: true,
///   ),
/// );
/// ```
///
/// ## See Also
///
/// - [TaskChainBuilder] - Builder for creating task chains
/// - [NativeWorkManager.beginWith] - Start a task chain
@immutable
class TaskRequest {
  const TaskRequest({
    required this.id,
    required this.worker,
    this.constraints = const Constraints(),
  });

  /// Unique identifier for this task.
  ///
  /// Must be unique within the chain. Used for tracking execution and debugging.
  final String id;

  /// Worker configuration.
  ///
  /// Can be any [Worker] type: NativeWorker or DartWorker.
  final Worker worker;

  /// Constraints for this task.
  ///
  /// These constraints apply only to this specific task, not the entire chain.
  /// To set constraints for the whole chain, use [TaskChainBuilder.withConstraints].
  final Constraints constraints;

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() => {
        'id': id,
        'workerClassName': worker.workerClassName,
        'workerConfig': worker.toMap(),
        'constraints': constraints.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TaskRequest && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TaskRequest(id: $id, worker: ${worker.workerClassName})';
}

/// Builder for creating task chains (A -> B -> C workflows).
///
/// Task chains allow you to define complex multi-step workflows where tasks
/// execute in sequence or parallel. Perfect for data processing pipelines,
/// ETL operations, or any multi-stage background work.
///
/// ## Sequential Chain (A → B → C)
///
/// ```dart
/// await NativeWorkManager.beginWith(
///   TaskRequest(
///     id: 'download',
///     worker: NativeWorker.httpDownload(
///       url: 'https://cdn.example.com/video.mp4',
///       savePath: '/tmp/video.mp4',
///     ),
///   ),
/// )
/// .then(TaskRequest(
///   id: 'compress',
///   worker: DartWorker(callbackId: 'compressVideo'),
/// ))
/// .then(TaskRequest(
///   id: 'upload',
///   worker: NativeWorker.httpUpload(
///     url: 'https://api.example.com/videos',
///     filePath: '/tmp/compressed.mp4',
///   ),
/// ))
/// .named('video-pipeline')
/// .withConstraints(Constraints.heavyTask)
/// .enqueue();
/// ```
///
/// ## Parallel Tasks (A → [B1, B2, B3])
///
/// ```dart
/// await NativeWorkManager.beginWith(
///   TaskRequest(
///     id: 'prepare-data',
///     worker: DartWorker(callbackId: 'prepareData'),
///   ),
/// )
/// .thenAll([
///   // These 3 uploads run in parallel
///   TaskRequest(
///     id: 'upload-server1',
///     worker: NativeWorker.httpUpload(
///       url: 'https://server1.example.com/backup',
///       filePath: '/data/backup.zip',
///     ),
///   ),
///   TaskRequest(
///     id: 'upload-server2',
///     worker: NativeWorker.httpUpload(
///       url: 'https://server2.example.com/backup',
///       filePath: '/data/backup.zip',
///     ),
///   ),
///   TaskRequest(
///     id: 'upload-cloud',
///     worker: NativeWorker.httpUpload(
///       url: 'https://cloud.example.com/backup',
///       filePath: '/data/backup.zip',
///     ),
///   ),
/// ])
/// .enqueue();
/// ```
///
/// ## Complex Multi-Stage Pipeline
///
/// ```dart
/// // Stage 1: Fetch metadata
/// // Stage 2: Download files in parallel
/// // Stage 3: Merge and process
/// // Stage 4: Upload result
///
/// await NativeWorkManager.beginWith(
///   TaskRequest(
///     id: 'fetch-metadata',
///     worker: NativeWorker.httpRequest(
///       url: 'https://api.example.com/metadata',
///       method: HttpMethod.get,
///     ),
///   ),
/// )
/// .thenAll([
///   TaskRequest(
///     id: 'download-file1',
///     worker: NativeWorker.httpDownload(
///       url: 'https://cdn.example.com/file1.dat',
///       savePath: '/tmp/file1.dat',
///     ),
///   ),
///   TaskRequest(
///     id: 'download-file2',
///     worker: NativeWorker.httpDownload(
///       url: 'https://cdn.example.com/file2.dat',
///       savePath: '/tmp/file2.dat',
///     ),
///   ),
/// ])
/// .then(TaskRequest(
///   id: 'merge-process',
///   worker: DartWorker(callbackId: 'mergeAndProcess'),
/// ))
/// .then(TaskRequest(
///   id: 'upload-result',
///   worker: NativeWorker.httpUpload(
///     url: 'https://api.example.com/results',
///     filePath: '/tmp/result.json',
///   ),
/// ))
/// .named('etl-pipeline')
/// .withConstraints(Constraints.heavyTask)
/// .enqueue();
/// ```
///
/// ## Chain Execution Rules
///
/// - **Sequential tasks**: Execute one after another (A → B → C)
/// - **Parallel tasks**: All start together, next step waits for ALL to complete
/// - **Failure handling**: If ANY task fails, entire chain stops
/// - **Constraints**: Applied to entire chain (use withConstraints)
///
/// ## Builder Methods
///
/// - [then] - Add single task (sequential)
/// - [thenAll] - Add multiple tasks (parallel)
/// - [named] - Set chain name for debugging
/// - [withConstraints] - Set constraints for entire chain
/// - [enqueue] - Schedule the chain for execution
///
/// ## Common Pitfalls
///
/// ❌ **Don't** make chains too long (increases failure risk)
/// ❌ **Don't** use chains for independent tasks
/// ❌ **Don't** forget to call enqueue() at the end
/// ✅ **Do** handle failures gracefully
/// ✅ **Do** keep chains focused on related tasks
/// ✅ **Do** use constraints appropriately
///
/// ## See Also
///
/// - [NativeWorkManager.beginWith] - Start chain with single task
/// - [NativeWorkManager.beginWithAll] - Start chain with parallel tasks
/// - [TaskRequest] - Individual task in chain
class TaskChainBuilder {
  /// Creates a new TaskChainBuilder with initial tasks.
  ///
  /// This constructor is intended for internal use by NativeWorkManager.
  TaskChainBuilder.internal(List<TaskRequest> initialTasks)
      : _steps = [initialTasks],
        _name = null,
        _constraints = const Constraints();

  final List<List<TaskRequest>> _steps;
  String? _name;
  Constraints _constraints;

  /// Internal: Callback to actually enqueue the chain.
  /// Set by NativeWorkManager during initialization.
  static Future<ScheduleResult> Function(TaskChainBuilder)? enqueueCallback;

  /// Add a single task to run after the previous step completes.
  ///
  /// Creates a sequential dependency: current step → new task.
  /// The new task will only start after ALL tasks in the previous step complete.
  ///
  /// ```dart
  /// NativeWorkManager.beginWith(taskA)
  ///     .then(taskB)  // Runs after A completes
  ///     .then(taskC)  // Runs after B completes
  ///     .enqueue();
  /// // Execution: A → B → C
  /// ```
  ///
  /// See also: [thenAll] for parallel tasks.
  TaskChainBuilder then(TaskRequest task) {
    _steps.add([task]);
    return this;
  }

  /// Add multiple tasks to run in parallel after the previous step completes.
  ///
  /// Creates parallel execution: current step → [task1, task2, task3].
  /// All tasks in the list start simultaneously. The next step waits for
  /// ALL parallel tasks to complete.
  ///
  /// ```dart
  /// NativeWorkManager.beginWith(prepareTask)
  ///     .thenAll([uploadTask1, uploadTask2, uploadTask3])  // Parallel
  ///     .then(cleanupTask)  // Waits for all 3 uploads
  ///     .enqueue();
  /// // Execution: prepare → [upload1, upload2, upload3] → cleanup
  /// ```
  ///
  /// **Important:** If ANY task in the parallel group fails, the entire chain stops.
  ///
  /// Throws [ArgumentError] if tasks list is empty.
  ///
  /// See also: [then] for sequential tasks.
  TaskChainBuilder thenAll(List<TaskRequest> tasks) {
    if (tasks.isEmpty) {
      throw ArgumentError('Tasks list cannot be empty');
    }
    _steps.add(tasks);
    return this;
  }

  /// Set a name for this chain (for debugging/monitoring).
  ///
  /// The chain name appears in logs and can be used for tracking execution.
  /// Useful when running multiple chains to identify which one is executing.
  ///
  /// ```dart
  /// NativeWorkManager.beginWith(downloadTask)
  ///     .then(processTask)
  ///     .named('data-sync-pipeline')  // Name for debugging
  ///     .enqueue();
  /// ```
  TaskChainBuilder named(String name) {
    _name = name;
    return this;
  }

  /// Set constraints for the entire chain.
  ///
  /// These constraints apply to ALL tasks in the chain. The chain will only
  /// start executing when these constraints are met.
  ///
  /// **Note:** Individual tasks can have their own constraints via [TaskRequest],
  /// but chain-level constraints must be satisfied first.
  ///
  /// ```dart
  /// // Heavy processing chain - only run when charging + WiFi
  /// NativeWorkManager.beginWith(downloadTask)
  ///     .then(processTask)
  ///     .then(uploadTask)
  ///     .withConstraints(Constraints.heavyTask)
  ///     .enqueue();
  /// ```
  ///
  /// Common patterns:
  /// - `Constraints.networkRequired` - For API chains
  /// - `Constraints.heavyTask` - For large uploads/processing
  /// - `Constraints(requiresDeviceIdle: true)` - For maintenance chains
  TaskChainBuilder withConstraints(Constraints constraints) {
    _constraints = constraints;
    return this;
  }

  /// Schedule the chain for execution.
  ///
  /// Submits the chain to the OS scheduler. The chain will execute according
  /// to the defined sequence and constraints.
  ///
  /// **Returns:** [ScheduleResult.ACCEPTED] if successfully scheduled.
  ///
  /// **Throws:** [StateError] if NativeWorkManager is not initialized.
  ///
  /// ```dart
  /// final result = await NativeWorkManager.beginWith(taskA)
  ///     .then(taskB)
  ///     .enqueue();
  ///
  /// if (result == ScheduleResult.ACCEPTED) {
  ///   print('Chain scheduled successfully');
  /// }
  /// ```
  ///
  /// **Important:** You MUST call this method to actually schedule the chain.
  /// Building the chain without calling enqueue() does nothing.
  Future<ScheduleResult> enqueue() async {
    if (enqueueCallback == null) {
      throw StateError(
        'NativeWorkManager not initialized. '
        'Call NativeWorkManager.initialize() first.',
      );
    }
    return enqueueCallback!(this);
  }

  /// Get all steps in the chain.
  List<List<TaskRequest>> get steps => List.unmodifiable(_steps);

  /// Get the chain name.
  String? get name => _name;

  /// Get the chain constraints.
  Constraints get constraints => _constraints;

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() => {
        'name': _name,
        'constraints': _constraints.toMap(),
        'steps': _steps
            .map((step) => step.map((task) => task.toMap()).toList())
            .toList(),
      };

  @override
  String toString() {
    final stepDescriptions = _steps.map((step) {
      if (step.length == 1) {
        return step.first.id;
      }
      return '[${step.map((t) => t.id).join(', ')}]';
    }).join(' -> ');
    return 'TaskChain(${_name ?? 'unnamed'}: $stepDescriptions)';
  }
}
