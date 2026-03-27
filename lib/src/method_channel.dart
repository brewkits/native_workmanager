import 'dart:async';
import 'dart:convert';
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

  /// Task IDs that have reached a terminal state (completed / failed / cancelled).
  ///
  /// Progress events can arrive *after* the completion event due to async
  /// queueing in the native bridge (time-travel progress). Any progress event
  /// for a task already in this set is dropped.  The set is cleared on each
  /// call to [_initEventStreams] so that re-initialisation (e.g. hot restart)
  /// starts clean.
  final _completedTaskIds = <String>{};

  Future<bool> Function(String, Map<String, dynamic>?)? _callbackExecutor;

  @override
  Future<void> initialize({
    int? callbackHandle,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
  }) async {
    // Setup method call handler for Dart callbacks
    methodChannel.setMethodCallHandler(_handleMethodCall);

    // Initialize event streams
    _initEventStreams();

    // Pass config to native side.
    final args = <String, dynamic>{
      'maxConcurrentTasks': maxConcurrentTasks,
      'diskSpaceBufferMB': diskSpaceBufferMB,
      'cleanupAfterDays': cleanupAfterDays,
      'enforceHttps': enforceHttps,
      'blockPrivateIPs': blockPrivateIPs,
    };
    if (callbackHandle != null) args['callbackHandle'] = callbackHandle;
    if (debugMode) args['debugMode'] = debugMode;
    await methodChannel.invokeMethod<void>('initialize', args);
  }

  void _initEventStreams() {
    // Clear stale terminal-state entries from any previous session so that
    // re-initialisation (hot restart, engine re-attach) starts clean.
    _completedTaskIds.clear();

    _eventController = StreamController<TaskEvent>.broadcast();
    _progressController = StreamController<TaskProgress>.broadcast();

    _eventSubscription =
        eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);
        final taskEvent = TaskEvent.fromMap(map);
        // Any TaskEvent (success or failure) is a terminal event for this
        // execution. Track the taskId so stale progress events that arrive
        // afterward (due to bridge queueing) are silently dropped below.
        _completedTaskIds.add(taskEvent.taskId);
        _eventController?.add(taskEvent);
      }
    }, onError: (error) {
      developer.log('Event channel error: $error', error: error);
    });

    _progressSubscription =
        progressChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);
        final taskProgress = TaskProgress.fromMap(map);
        // Drop stale progress events for already-completed tasks.
        if (_completedTaskIds.contains(taskProgress.taskId)) return;
        _progressController?.add(taskProgress);
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
    if (inputJson != null && inputJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(inputJson);
        if (decoded is Map) {
          input = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Non-JSON scalar — wrap so callbacks always receive a Map
        input = {'value': inputJson};
      }
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
      if (tag != null) 'tag': tag,
    });

    return _parseScheduleResult(result);
  }

  @override
  Future<void> cancelByTag({required String tag}) async {
    await methodChannel.invokeMethod<void>('cancelByTag', {'tag': tag});
  }

  @override
  Future<List<String>> getTasksByTag({required String tag}) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>('getTasksByTag', {'tag': tag});
    return result?.cast<String>() ?? [];
  }

  @override
  Future<List<String>> getAllTags() async {
    final result = await methodChannel.invokeMethod<List<dynamic>>('getAllTags');
    return result?.cast<String>() ?? [];
  }

  @override
  Future<void> cancel({required String taskId}) async {
    await methodChannel.invokeMethod<void>('cancel', {'taskId': taskId});
  }

  @override
  Future<void> cancelAll() async {
    await methodChannel.invokeMethod<void>('cancelAll');
  }

  @override
  Future<TaskStatus?> getTaskStatus({required String taskId}) async {
    final result = await methodChannel.invokeMethod<String?>(
      'getTaskStatus',
      {'taskId': taskId},
    );

    if (result == null) return null;
    return TaskStatus.values.where((e) => e.name == result).firstOrNull;
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
  Future<void> pauseTask({required String taskId}) async {
    await methodChannel.invokeMethod<void>('pause', {'taskId': taskId});
  }

  @override
  Future<void> resumeTask({required String taskId}) async {
    await methodChannel.invokeMethod<void>('resume', {'taskId': taskId});
  }

  @override
  Future<String?> getServerFilename({
    required String url,
    Map<String, String>? headers,
    int timeoutMs = 30000,
  }) async {
    return methodChannel.invokeMethod<String>('getServerFilename', {
      'url': url,
      if (headers != null) 'headers': headers,
      'timeoutMs': timeoutMs,
    });
  }

  @override
  Future<List<TaskRecord>> allTasks() async {
    final result =
        await methodChannel.invokeMethod<List<dynamic>>('allTasks');
    if (result == null) return [];
    return result
        .map((e) => TaskRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Stream<TaskEvent> get events =>
      _eventController?.stream ?? const Stream.empty();

  @override
  Stream<TaskProgress> get progress =>
      _progressController?.stream ?? const Stream.empty();

  ScheduleResult _parseScheduleResult(String? result) {
    if (result == null) return ScheduleResult.accepted;

    final lower = result.toLowerCase();
    if (lower == 'accepted') return ScheduleResult.accepted;
    if (lower == 'rejected_os_policy' || lower == 'rejectedospolicy') {
      return ScheduleResult.rejectedOsPolicy;
    }
    if (lower == 'throttled') return ScheduleResult.throttled;

    // FIX L1: Log unknown values instead of silently treating them as accepted.
    // This surfaces native-side bugs (e.g. typos, new values) during development.
    developer.log(
      'NativeWorkManager: Unrecognised schedule result "$result" — defaulting to accepted. '
      'This may indicate a platform bug or version mismatch.',
      name: 'NativeWorkManager',
      level: 900, // WARNING
    );
    return ScheduleResult.accepted;
  }

  @override
  Future<void> openFile(String path, {String? mimeType}) async {
    await methodChannel.invokeMethod<void>('openFile', {
      'filePath': path,
      if (mimeType != null) 'mimeType': mimeType,
    });
  }

  @override
  Future<void> setMaxConcurrentPerHost(int max) async {
    await methodChannel.invokeMethod<void>('setMaxConcurrentPerHost', {'max': max});
  }

  /// Dispose resources.
  void dispose() {
    _eventSubscription?.cancel();
    _progressSubscription?.cancel();
    _eventController?.close();
    _progressController?.close();
    _completedTaskIds.clear();
  }
}
