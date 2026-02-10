import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constraints.dart';
import 'events.dart';
import 'platform_interface.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// Method channel implementation of [NativeWorkManagerPlatform].
class MethodChannelNativeWorkManager extends NativeWorkManagerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.brewkits/native_workmanager');

  /// Event channel for task completion events.
  @visibleForTesting
  final eventChannel =
      const EventChannel('dev.brewkits/native_workmanager/events');

  /// Event channel for task progress updates.
  @visibleForTesting
  final progressChannel =
      const EventChannel('dev.brewkits/native_workmanager/progress');

  StreamController<TaskEvent>? _eventController;
  StreamController<TaskProgress>? _progressController;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _progressSubscription;

  Future<bool> Function(String, Map<String, dynamic>?)? _callbackExecutor;

  @override
  Future<void> initialize({int? callbackHandle, bool debugMode = false}) async {
    // Setup method call handler for Dart callbacks
    methodChannel.setMethodCallHandler(_handleMethodCall);

    // Initialize event streams
    _initEventStreams();

    // Initialize native side with optional callback handle and debug mode
    final args = <String, dynamic>{};
    if (callbackHandle != null) {
      args['callbackHandle'] = callbackHandle;
    }
    if (debugMode) {
      args['debugMode'] = debugMode;
    }
    await methodChannel.invokeMethod<void>('initialize', args.isNotEmpty ? args : null);
  }

  void _initEventStreams() {
    _eventController = StreamController<TaskEvent>.broadcast();
    _progressController = StreamController<TaskProgress>.broadcast();

    _eventSubscription =
        eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);
        _eventController?.add(TaskEvent.fromMap(map));
      }
    }, onError: (error) {
      developer.log('Event channel error: $error', error: error);
    });

    _progressSubscription =
        progressChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);
        _progressController?.add(TaskProgress.fromMap(map));
      }
    }, onError: (error) {
      developer.log('Progress channel error: $error', error: error);
    });
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'executeDartCallback':
        return _executeDartCallback(call.arguments as Map<dynamic, dynamic>);
      default:
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  Future<bool> _executeDartCallback(Map<dynamic, dynamic> args) async {
    final callbackId = args['callbackId'] as String;
    final inputJson = args['input'] as String?;

    if (_callbackExecutor == null) {
      throw StateError('No callback executor registered for: $callbackId');
    }

    Map<String, dynamic>? input;
    if (inputJson != null) {
      // Parse JSON input - will be handled by the callback
      input = {'raw': inputJson};
    }

    return _callbackExecutor!(callbackId, input);
  }

  @override
  void setCallbackExecutor(
      Future<bool> Function(String callbackId, Map<String, dynamic>? input)
          executor) {
    _callbackExecutor = executor;
  }

  @override
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    required Constraints constraints,
    required ExistingTaskPolicy existingPolicy,
    String? tag,
  }) async {
    final result = await methodChannel.invokeMethod<String>('enqueue', {
      'taskId': taskId,
      'trigger': trigger.toMap(),
      'workerClassName': worker.workerClassName,
      'workerConfig': worker.toMap(),
      'constraints': constraints.toMap(),
      'existingPolicy': existingPolicy.name,
      'tag': ?tag,
    });

    return _parseScheduleResult(result);
  }

  @override
  Future<void> cancelByTag(String tag) async {
    await methodChannel.invokeMethod<void>('cancelByTag', {'tag': tag});
  }

  @override
  Future<List<String>> getTasksByTag(String tag) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>('getTasksByTag', {'tag': tag});
    return result?.cast<String>() ?? [];
  }

  @override
  Future<List<String>> getAllTags() async {
    final result = await methodChannel.invokeMethod<List<dynamic>>('getAllTags');
    return result?.cast<String>() ?? [];
  }

  @override
  Future<void> cancel(String taskId) async {
    await methodChannel.invokeMethod<void>('cancel', {'taskId': taskId});
  }

  @override
  Future<void> cancelAll() async {
    await methodChannel.invokeMethod<void>('cancelAll');
  }

  @override
  Future<TaskStatus?> getTaskStatus(String taskId) async {
    final result = await methodChannel.invokeMethod<String?>(
      'getTaskStatus',
      {'taskId': taskId},
    );

    if (result == null) return null;
    return TaskStatus.values.byName(result);
  }

  @override
  Future<ScheduleResult> enqueueChain(Map<String, dynamic> chainData) async {
    final result = await methodChannel.invokeMethod<String>(
      'enqueueChain',
      chainData,
    );

    return _parseScheduleResult(result);
  }

  @override
  Stream<TaskEvent> get events =>
      _eventController?.stream ?? const Stream.empty();

  @override
  Stream<TaskProgress> get progress =>
      _progressController?.stream ?? const Stream.empty();

  ScheduleResult _parseScheduleResult(String? result) {
    if (result == null) return ScheduleResult.accepted;

    return switch (result.toLowerCase()) {
      'accepted' => ScheduleResult.accepted,
      'rejected_os_policy' || 'rejectedospolicy' => ScheduleResult.rejectedOsPolicy,
      'throttled' => ScheduleResult.throttled,
      _ => ScheduleResult.accepted,
    };
  }

  /// Dispose resources.
  void dispose() {
    _eventSubscription?.cancel();
    _progressSubscription?.cancel();
    _eventController?.close();
    _progressController?.close();
  }
}
