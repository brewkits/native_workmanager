import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constraints.dart';
import 'events.dart';
import 'platform_interface.dart';
import 'remote_trigger.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// Method channel implementation of [NativeWorkManagerPlatform].
class MethodChannelNativeWorkManager extends NativeWorkManagerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  late final methodChannel =
      const MethodChannel('dev.brewkits/native_workmanager');

  /// Event channel for task completion events.
  @visibleForTesting
  final eventChannel =
      const EventChannel('dev.brewkits/native_workmanager/events');

  /// Event channel for task progress updates.
  @visibleForTesting
  final progressChannel =
      const EventChannel('dev.brewkits/native_workmanager/progress');

  /// Event channel for system-level errors.
  @visibleForTesting
  final systemErrorChannel =
      const EventChannel('dev.brewkits/native_workmanager/system_errors');

  StreamController<TaskEvent>? _eventController;
  StreamController<TaskProgress>? _progressController;
  StreamController<SystemError>? _systemErrorController;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _progressSubscription;
  StreamSubscription? _systemErrorSubscription;

  /// Task IDs that have reached a terminal state (completed / failed / cancelled).
  ///
  /// Progress events can arrive *after* the completion event due to async
  /// queueing in the native bridge (time-travel progress). Any progress event
  /// for a task already in this set is dropped.  The set is cleared on each
  /// call to [_initEventStreams] so that re-initialisation (e.g. hot restart)
  /// starts clean.
  final _completedTaskIds = <String>{};

  Future<bool> Function(String, Map<String, dynamic>?)? _callbackExecutor;

  /// Session start time (ms). Used to drop stale events from previous app runs.
  int _sessionStartTime = 0;

  @override
  Future<void> initialize({
    int? callbackHandle,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
    bool registerPlugins = false,
  }) async {
    // Setup method call handler for Dart callbacks
    methodChannel.setMethodCallHandler(_handleMethodCall);

    // Record session start time to filter out "zombie" events from previous runs.
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;

    // Initialize event streams
    _initEventStreams();

    // Pass config to native side.
    final args = <String, dynamic>{
      'maxConcurrentTasks': maxConcurrentTasks,
      'diskSpaceBufferMB': diskSpaceBufferMB,
      'cleanupAfterDays': cleanupAfterDays,
      'enforceHttps': enforceHttps,
      'blockPrivateIPs': blockPrivateIPs,
      'registerPlugins': registerPlugins,
    };
    if (callbackHandle != null) args['callbackHandle'] = callbackHandle;
    if (debugMode) args['debugMode'] = debugMode;
    await methodChannel.invokeMethod<void>('initialize', args);
  }

  void _initEventStreams() {
    // Cancel existing subscriptions and close old controllers before re-initializing.
    // This prevents memory leaks and duplicate event emissions during hot restarts.
    _eventSubscription?.cancel();
    _progressSubscription?.cancel();
    _systemErrorSubscription?.cancel();
    _eventController?.close();
    _progressController?.close();
    _systemErrorController?.close();

    // Clear stale terminal-state entries from any previous session so that
    // re-initialisation (hot restart, engine re-attach) starts clean.
    _completedTaskIds.clear();

    _eventController = StreamController<TaskEvent>.broadcast();
    _progressController = StreamController<TaskProgress>.broadcast();
    _systemErrorController = StreamController<SystemError>.broadcast();

    _eventSubscription =
        eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);

        // Drop stale zombie events from previous sessions (pre-hot-restart).
        final timestamp = map['timestamp'] as int? ?? 0;
        if (timestamp < _sessionStartTime) return;

        final taskEvent = TaskEvent.fromMap(map);
        // Only terminal events (success/failure) block future progress events.
        if (!taskEvent.isStarted) {
          _completedTaskIds.add(taskEvent.taskId);
        }
        _eventController?.add(taskEvent);
      }
    }, onError: (error) {
      developer.log('Event channel error: $error', error: error);
    });

    _progressSubscription =
        progressChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);

        // Drop stale progress events (stale session or already completed).
        final timestamp = map['timestamp'] as int? ?? 0;
        if (timestamp < _sessionStartTime) return;

        final taskProgress = TaskProgress.fromMap(map);
        if (_completedTaskIds.contains(taskProgress.taskId)) return;
        _progressController?.add(taskProgress);
      }
    }, onError: (error) {
      developer.log('Progress channel error: $error', error: error);
    });

    _systemErrorSubscription =
        systemErrorChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event);
        final systemError = SystemError.fromMap(map);
        _systemErrorController?.add(systemError);
      }
    }, onError: (error) {
      developer.log('System error channel error: $error', error: error);
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
    final result = await methodChannel
        .invokeMethod<List<dynamic>>('getTasksByTag', {'tag': tag});
    return result?.cast<String>() ?? [];
  }

  @override
  Future<List<String>> getAllTags() async {
    final result =
        await methodChannel.invokeMethod<List<dynamic>>('getAllTags');
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
  Future<TaskRecord?> getTaskRecord({required String taskId}) async {
    developer.log(
        'MethodChannel[${methodChannel.name}]: invoking getTaskRecord for $taskId');
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'getTaskRecord',
        {'taskId': taskId},
      );
      developer.log(
          'MethodChannel[${methodChannel.name}]: getTaskRecord result: ${result != null}');

      if (result == null) return null;
      return TaskRecord.fromMap(result);
    } catch (e, s) {
      developer.log(
          'MethodChannel[${methodChannel.name}]: error in getTaskRecord: $e\n$s');
      return null;
    }
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
    final result = await methodChannel.invokeMethod<List<dynamic>>('allTasks');
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

  @override
  Stream<SystemError> get systemErrors =>
      _systemErrorController?.stream ?? const Stream.empty();

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
  Future<Map<String, dynamic>> getRunningProgress() async {
    final result = await methodChannel
        .invokeMethod<Map<Object?, Object?>>('getRunningProgress');
    if (result == null) return {};
    return result.map((key, value) => MapEntry(key.toString(), value));
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
    await methodChannel
        .invokeMethod<void>('setMaxConcurrentPerHost', {'max': max});
  }

  @override
  Future<void> registerRemoteTrigger({
    required RemoteTriggerSource source,
    required RemoteTriggerRule rule,
  }) async {
    await methodChannel.invokeMethod<void>('registerRemoteTrigger', {
      'source': source.name,
      'rule': rule.toMap(),
    });
  }

  @override
  Future<String> enqueueGraph(Map<String, dynamic> graphMap) async {
    return await methodChannel.invokeMethod<String>('enqueueGraph', {
          'graph': graphMap,
        }) ??
        'ACCEPTED';
  }

  @override
  Future<void> offlineQueueEnqueue(
      String queueId, Map<String, dynamic> entryMap) async {
    await methodChannel.invokeMethod<void>('offlineQueueEnqueue', {
      'queueId': queueId,
      'entry': entryMap,
    });
  }

  @override
  Future<void> registerMiddleware(Map<String, dynamic> middlewareMap) async {
    await methodChannel.invokeMethod<void>('registerMiddleware', middlewareMap);
  }

  @override
  Future<Map<String, dynamic>> getMetrics() async {
    final result =
        await methodChannel.invokeMethod<Map<dynamic, dynamic>>('getMetrics');
    if (result == null) return {};
    return result.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<bool> syncOfflineQueue() async {
    final result = await methodChannel.invokeMethod<bool>('syncOfflineQueue');
    return result ?? false;
  }

  /// Dispose resources.
  void dispose() {
    _eventSubscription?.cancel();
    _progressSubscription?.cancel();
    _systemErrorSubscription?.cancel();
    _eventController?.close();
    _progressController?.close();
    _systemErrorController?.close();
    _completedTaskIds.clear();
  }
}
