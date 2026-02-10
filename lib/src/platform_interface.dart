import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'constraints.dart';
import 'events.dart';
import 'method_channel.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// Platform interface for native_workmanager plugin.
abstract class NativeWorkManagerPlatform extends PlatformInterface {
  NativeWorkManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeWorkManagerPlatform _instance = MethodChannelNativeWorkManager();

  /// The default instance of [NativeWorkManagerPlatform].
  static NativeWorkManagerPlatform get instance => _instance;

  /// Platform-specific implementations should set this.
  static set instance(NativeWorkManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the work manager.
  ///
  /// [callbackHandle] - Handle of the Dart callback dispatcher for Dart workers.
  /// If null, only native workers can be used.
  ///
  /// [debugMode] - Enable debug notifications for task events.
  /// Only works in debug builds.
  Future<void> initialize({int? callbackHandle, bool debugMode = false}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Schedule a task.
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    required Constraints constraints,
    required ExistingTaskPolicy existingPolicy,
    String? tag,
  }) {
    throw UnimplementedError('enqueue() has not been implemented.');
  }

  /// Cancel all tasks with a specific tag.
  Future<void> cancelByTag(String tag) {
    throw UnimplementedError('cancelByTag() has not been implemented.');
  }

  /// Get all tasks with a specific tag.
  Future<List<String>> getTasksByTag(String tag) {
    throw UnimplementedError('getTasksByTag() has not been implemented.');
  }

  /// Get all tags currently in use.
  Future<List<String>> getAllTags() {
    throw UnimplementedError('getAllTags() has not been implemented.');
  }

  /// Cancel a task by ID.
  Future<void> cancel(String taskId) {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Cancel all tasks.
  Future<void> cancelAll() {
    throw UnimplementedError('cancelAll() has not been implemented.');
  }

  /// Get task status.
  Future<TaskStatus?> getTaskStatus(String taskId) {
    throw UnimplementedError('getTaskStatus() has not been implemented.');
  }

  /// Schedule a task chain.
  Future<ScheduleResult> enqueueChain(Map<String, dynamic> chainData) {
    throw UnimplementedError('enqueueChain() has not been implemented.');
  }

  /// Stream of task completion events.
  Stream<TaskEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Stream of task progress updates.
  Stream<TaskProgress> get progress {
    throw UnimplementedError('progress has not been implemented.');
  }

  /// Set the Dart callback executor.
  void setCallbackExecutor(
      Future<bool> Function(String callbackId, Map<String, dynamic>? input)
          executor) {
    throw UnimplementedError('setCallbackExecutor() has not been implemented.');
  }
}
