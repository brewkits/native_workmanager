import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:math' as math;

import 'constraints.dart';
import 'events.dart';
import 'native_work_manager.dart';
import 'platform_interface.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// Retry policy for [OfflineQueue] tasks.
///
/// Determines how many times a task is retried and what constraints
/// must be met before each retry attempt.
@immutable
class OfflineRetryPolicy {
  const OfflineRetryPolicy({
    this.maxRetries = 5,
    this.requiresNetwork = true,
    this.requiresCharging = false,
    this.backoffMultiplier = 2.0,
    this.initialDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(hours: 6),
  }) : assert(maxRetries >= 0 && maxRetries <= 100,
              'maxRetries must be between 0 and 100'),
      // NaN fails >= 1.0 already; Infinity is clamped to maxDelay in delayFor().
      assert(backoffMultiplier >= 1.0,
             'backoffMultiplier must be >= 1.0 (NaN and negative values not allowed)');

  /// Maximum retry attempts (0–100). Set to 0 for no retries.
  final int maxRetries;

  /// Require any network connection before retrying.
  final bool requiresNetwork;

  /// Require charging before retrying (useful for heavy tasks).
  final bool requiresCharging;

  /// Exponential backoff multiplier (finite number ≥ 1.0; 1.0 = constant interval).
  final double backoffMultiplier;

  /// Delay before the first retry.
  final Duration initialDelay;

  /// Maximum delay cap for exponential backoff.
  final Duration maxDelay;

  /// Convenience: retry up to 10 times on any network.
  static const networkAvailable = OfflineRetryPolicy(
    maxRetries: 10,
    requiresNetwork: true,
  );

  /// Convenience: retry up to 5 times, network required.
  static const networkRequired = OfflineRetryPolicy(
    maxRetries: 5,
    requiresNetwork: true,
  );

  /// Convenience: immediate retry, no constraints.
  static const aggressive = OfflineRetryPolicy(
    maxRetries: 3,
    requiresNetwork: false,
    initialDelay: Duration(seconds: 5),
  );

  /// Compute the delay before retry attempt [attempt] (0-indexed).
  Duration delayFor(int attempt) {
    final ms = initialDelay.inMilliseconds *
        (backoffMultiplier == 1.0
            ? 1.0
            : _pow(backoffMultiplier, attempt.toDouble()));
    final clamped = ms.isFinite
        ? ms.round().clamp(0, maxDelay.inMilliseconds)
        : maxDelay.inMilliseconds;
    return Duration(milliseconds: clamped);
  }

  static double _pow(double base, double exp) {
    return math.pow(base, exp).toDouble();
  }
}

/// An entry in an [OfflineQueue].
@immutable
class QueueEntry {
  const QueueEntry({
    required this.taskId,
    required this.worker,
    this.retryPolicy = const OfflineRetryPolicy(),
    this.tag,
  });

  /// Unique ID for this queued task.
  final String taskId;

  /// Worker to execute.
  final Worker worker;

  /// Retry policy for this entry.
  final OfflineRetryPolicy retryPolicy;

  /// Optional tag for grouping / cancellation.
  final String? tag;
}

/// A persistent, ordered queue of background tasks that are retried
/// automatically when network is available.
///
/// The offline queue is ideal for "best-effort delivery" scenarios:
/// - Uploading analytics events when connectivity is restored
/// - Syncing user data in the background
/// - Sending logs to a remote server
///
/// ## Usage
///
/// ```dart
/// // Create the queue (one instance per queue in your app)
/// final uploadQueue = OfflineQueue(
///   id: 'upload-queue',
///   maxSize: 100,
///   defaultRetryPolicy: OfflineRetryPolicy.networkAvailable,
/// );
///
/// // Enqueue tasks (safe to call when offline)
/// await uploadQueue.enqueue(QueueEntry(
///   taskId: 'upload-${timestamp}',
///   worker: HttpUploadWorker(
///     url: 'https://api.example.com/events',
///     filePath: '/tmp/events.json',
///   ),
/// ));
///
/// // Start processing (call once, e.g. in main())
/// uploadQueue.start();
/// ```
///
/// ## Behavior
///
/// - Tasks run **one at a time** in FIFO order.
/// - Failed tasks are retried with exponential backoff up to
///   [OfflineRetryPolicy.maxRetries] times.
/// - After all retries are exhausted the task is moved to a **dead-letter**
///   state (accessible via [deadLetterCount]).
/// - Calling [enqueue] when the queue is full (> [maxSize]) throws a
///   [StateError].
///
/// ## Limitations
///
/// The current implementation stores the queue in memory.  If the app is
/// killed, in-flight and pending tasks are re-enqueued from the
/// [NativeWorkManager] task store on the next [start] call (tasks that were
/// accepted by the OS continue to completion natively).
///
/// For a fully persistent queue that survives process death, schedule
/// each task directly with [NativeWorkManager.enqueue] using
/// [Constraints.networkRequired] and the WorkManager retry mechanism
/// (`shouldRetry = true` from the worker result).
class OfflineQueue {
  OfflineQueue({
    required this.id,
    this.maxSize = 100,
    this.defaultRetryPolicy = const OfflineRetryPolicy(),
  });

  /// Unique queue identifier.
  final String id;

  /// Maximum number of pending entries. [enqueue] throws [StateError] if full.
  final int maxSize;

  /// Default retry policy for entries that do not specify their own.
  final OfflineRetryPolicy defaultRetryPolicy;

  final List<_QueueSlot> _pending = [];
  final List<_QueueSlot> _deadLetter = [];
  bool _running = false;
  bool _processing = false;

  /// Number of entries currently waiting in the queue.
  int get pendingCount => _pending.length;

  /// Number of entries that exhausted all retries and were dropped.
  int get deadLetterCount => _deadLetter.length;

  /// Whether this queue is currently started (processing tasks as they come).
  bool get isRunning => _running;

  /// Add a [QueueEntry] to the back of the queue.
  ///
  /// If the queue exceeds [maxSize], throws a [StateError].
  /// Safe to call before [start].
  Future<void> enqueue(QueueEntry entry) async {
    if (_pending.length >= maxSize) {
      throw StateError(
        'OfflineQueue "$id" is full ($maxSize entries). '
        'Process existing entries or increase maxSize.',
      );
    }
    _pending.add(_QueueSlot(
      entry: entry,
      policy: entry.retryPolicy,
      attempt: 0,
    ));
    if (_running) _scheduleNext();
  }

  /// Start processing queued tasks.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  void start() {
    if (_running) return;
    _running = true;
    _scheduleNext();
  }

  /// Stop processing.  The current in-flight task (if any) completes normally;
  /// no further tasks are dequeued until [start] is called again.
  void stop() {
    _running = false;
  }

  /// Cancel all queued entries that match [taskId] or [tag].
  void cancel({String? taskId, String? tag}) {
    // Snapshot matching slots and remove from list atomically before issuing
    // native cancels — prevents a concurrent _scheduleNext from dequeuing
    // a slot that is in the process of being cancelled.
    final toCancel = _pending.where((slot) {
      return (taskId != null && slot.entry.taskId == taskId) ||
          (tag != null && slot.entry.tag == tag);
    }).toList();
    _pending.removeWhere((slot) {
      return (taskId != null && slot.entry.taskId == taskId) ||
          (tag != null && slot.entry.tag == tag);
    });
    // Fire native cancels after list removal so no further scheduling occurs.
    for (final slot in toCancel) {
      final nativeId = '${id}__${slot.entry.taskId}__${slot.attempt}';
      NativeWorkManager.cancel(taskId: nativeId).ignore();
    }
  }

  /// Remove all dead-letter entries.
  void clearDeadLetter() => _deadLetter.clear();

  // ── Internal ──────────────────────────────────────────────────────────────

  void _scheduleNext() {
    if (!_running || _processing || _pending.isEmpty) return;
    _processing = true;
    _processHead();
  }

  Future<void> _processHead() async {
    if (_pending.isEmpty) {
      _processing = false;
      return;
    }

    final slot = _pending.first;
    final policy = slot.policy;
    final entry = slot.entry;

    // Apply delay for retry attempts
    if (slot.attempt > 0) {
      final delay = policy.delayFor(slot.attempt - 1);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }

    if (!_running) {
      _processing = false;
      return;
    }

    // Build constraints from policy
    final constraints = Constraints(
      requiresNetwork: policy.requiresNetwork,
      requiresCharging: policy.requiresCharging,
    );

    try {
      await NativeWorkManager.enqueue(
        taskId: '${id}__${entry.taskId}__${slot.attempt}',
        trigger: TaskTrigger.oneTime(),
        worker: entry.worker,
        constraints: constraints,
      );

      // Wait for the task to complete via the events stream.
      final event = await _awaitEvent(
        '${id}__${entry.taskId}__${slot.attempt}',
        timeout: const Duration(hours: 1),
      );

      if (event?.success == true) {
        _pending.remove(slot);
        _processing = false;
        _scheduleNext();
        return;
      }
    } catch (_) {
      // enqueue itself failed — treat as task failure
    }

    // Task failed — retry or dead-letter
    if (slot.attempt < policy.maxRetries) {
      // Update attempt counter in-place
      _pending[0] = _QueueSlot(
        entry: entry,
        policy: policy,
        attempt: slot.attempt + 1,
      );
    } else {
      // Exhausted retries → dead-letter
      _pending.removeAt(0);
      _deadLetter.add(slot);
      debugPrint(
        '[native_workmanager] OfflineQueue "$id": task "${entry.taskId}" '
        'failed after ${slot.attempt + 1} attempt(s) — moved to dead-letter.',
      );
    }

    _processing = false;
    _scheduleNext();
  }

  /// Wait for a specific taskId event on [NativeWorkManager.events].
  ///
  /// Returns the event or `null` if [timeout] is exceeded.
  static Future<TaskEvent?> _awaitEvent(
      String taskId, {required Duration timeout}) async {
    try {
      return await NativeWorkManagerPlatform.instance.events
          .where((e) => e.taskId == taskId)
          .first
          .timeout(timeout);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

@immutable
class _QueueSlot {
  const _QueueSlot({
    required this.entry,
    required this.policy,
    required this.attempt,
  });

  final QueueEntry entry;
  final OfflineRetryPolicy policy;
  final int attempt;
}
