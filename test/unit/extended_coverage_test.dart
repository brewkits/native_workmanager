import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:native_workmanager/src/platform_interface.dart';
import 'package:native_workmanager/testing.dart';

class _FakeClientPlatform extends MethodChannelNativeWorkManager {
  final eventsController = StreamController<TaskEvent>.broadcast();
  final progressController = StreamController<TaskProgress>.broadcast();

  final List<String> cancelledTasks = [];
  final List<String> cancelledTags = [];
  bool cancelAllCalled = false;
  final List<String> pausedTasks = [];
  final List<String> resumedTasks = [];

  @override
  Stream<TaskEvent> get events => eventsController.stream;

  @override
  Stream<TaskProgress> get progress => progressController.stream;

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
  }) async {}

  @override
  Future<String> enqueueGraph(Map<String, dynamic> graphMap) async {
    return 'graph_id';
  }

  @override
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints = const Constraints(),
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
    String? tag,
  }) async {
    return ScheduleResult.accepted;
  }

  @override
  Future<Map<String, dynamic>> getRunningProgress() async => {
        't1': {'taskId': 't1', 'progress': 50},
      };

  @override
  Future<void> cancel({required String taskId}) async {
    cancelledTasks.add(taskId);
  }

  @override
  Future<void> cancelByTag({required String tag}) async {
    cancelledTags.add(tag);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
  }

  @override
  Future<void> pauseTask({required String taskId}) async {
    pausedTasks.add(taskId);
  }

  @override
  Future<void> resumeTask({required String taskId}) async {
    resumedTasks.add(taskId);
  }

  @override
  Future<TaskStatus?> getTaskStatus({required String taskId}) async =>
      TaskStatus.running;

  @override
  Future<TaskRecord?> getTaskRecord({required String taskId}) async =>
      TaskRecord(
        taskId: taskId,
        status: 'running',
        workerClassName: 'HttpRequestWorker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<List<String>> getTasksByTag({required String tag}) async =>
      ['task_for_$tag'];

  @override
  Future<List<String>> getAllTags() async => ['tag1', 'tag2'];

  @override
  Future<List<TaskRecord>> allTasks() async => [
        TaskRecord(
          taskId: 't_all',
          status: 'completed',
          workerClassName: 'HttpRequestWorker',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

  Future<void> dispose() async {
    await eventsController.close();
    await progressController.close();
  }
}

class _TestLogger implements WorkManagerLogger {
  final List<String> starts = [];
  final List<String> completions = [];
  final List<String> failures = [];

  @override
  void onTaskStart(String taskId, String workerType) {
    starts.add('$taskId:$workerType');
  }

  @override
  void onTaskComplete(TaskEvent event) {
    completions.add(event.taskId);
  }

  @override
  void onTaskFail(TaskEvent event) {
    failures.add(event.taskId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskId Extension Type', () {
    test('valid and invalid states', () {
      const valid = TaskId('sync-task-1');
      expect(valid.value, 'sync-task-1');
      expect(valid.isValid, isTrue);
      expect(valid.length, 11);
      expect(valid.startsWith('sync'), isTrue);

      const empty = TaskId('');
      expect(empty.value, '');
      expect(empty.isValid, isFalse);
    });

    test('implements String seamlessly', () {
      const id = TaskId('my-id');
      String asString = id;
      expect(asString, 'my-id');
      expect('$id', 'my-id');
    });
  });

  group('WorkerCallback Annotation', () {
    test('constructs with id and inputType', () {
      const callback = WorkerCallback('worker_1', inputType: Map);
      expect(callback.id, 'worker_1');
      expect(callback.inputType, Map);

      const noType = WorkerCallback('worker_2');
      expect(noType.id, 'worker_2');
      expect(noType.inputType, isNull);
    });
  });

  group('AuthConfig', () {
    test('default Bearer template', () {
      const auth = AuthConfig(accessToken: 'secret_123');
      expect(auth.accessToken, 'secret_123');
      expect(auth.headerTemplate, 'Bearer {accessToken}');
      expect(auth.resolvedHeader, 'Bearer secret_123');
    });

    test('custom header template', () {
      const auth = AuthConfig(
        accessToken: 'api_key_xyz',
        headerTemplate: 'ApiKey {accessToken}',
      );
      expect(auth.resolvedHeader, 'ApiKey api_key_xyz');
    });
  });

  group('TokenRefreshConfig', () {
    test('default configuration values', () {
      const config = TokenRefreshConfig(url: 'https://api.example.com/refresh');
      expect(config.url, 'https://api.example.com/refresh');
      expect(config.method, 'POST');
      expect(config.headers, isEmpty);
      expect(config.body, isEmpty);
      expect(config.responseKey, 'access_token');
      expect(config.tokenHeaderName, 'Authorization');
      expect(config.tokenPrefix, 'Bearer ');
      expect(config.toString(), contains('https://api.example.com/refresh'));

      final map = config.toMap();
      expect(map['url'], 'https://api.example.com/refresh');
      expect(map['method'], 'POST');
      expect(map['responseKey'], 'access_token');
      expect(map['tokenPrefix'], 'Bearer ');
    });

    test('custom configuration and map serialization', () {
      const config = TokenRefreshConfig(
        url: 'https://auth.example.com/token',
        method: 'PUT',
        headers: {'X-Custom': '1'},
        body: {'refresh': 'abc'},
        responseKey: 'data.token',
        tokenHeaderName: 'X-Auth-Token',
        tokenPrefix: 'Token ',
      );

      final map = config.toMap();
      expect(map['method'], 'PUT');
      expect(map['headers'], {'X-Custom': '1'});
      expect(map['body'], {'refresh': 'abc'});
      expect(map['responseKey'], 'data.token');
      expect(map['tokenHeaderName'], 'X-Auth-Token');
      expect(map['tokenPrefix'], 'Token ');
    });
  });

  group('ForegroundNotificationConfig', () {
    test('default values, equals, hashCode, toString', () {
      const config1 = ForegroundNotificationConfig(
        title: 'Title',
        body: 'Body',
      );
      const config2 = ForegroundNotificationConfig(
        title: 'Title',
        body: 'Body',
      );
      const config3 = ForegroundNotificationConfig(
        title: 'Other',
        body: 'Body',
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
      expect(config1.toString(), contains('ForegroundNotificationConfig'));
      expect(config1.showCancelButton, isTrue);
      expect(config1.cancelText, 'Cancel');

      final map = config1.toMap();
      expect(map['title'], 'Title');
      expect(map['body'], 'Body');
      expect(map['showCancelButton'], isTrue);
      expect(map['cancelText'], 'Cancel');

      final fromMap = ForegroundNotificationConfig.fromMap(map);
      expect(fromMap, equals(config1));
    });

    test('fromMap with partial / custom values', () {
      final fromEmpty = ForegroundNotificationConfig.fromMap(const {});
      expect(fromEmpty.title, 'Background Task');
      expect(fromEmpty.body, 'Running...');
      expect(fromEmpty.showCancelButton, isTrue);
      expect(fromEmpty.cancelText, 'Cancel');

      final custom = ForegroundNotificationConfig.fromMap({
        'title': 'Download',
        'body': 'In progress',
        'iconName': 'ic_download',
        'colorHex': '#00FF00',
        'showCancelButton': false,
        'cancelText': 'Stop',
      });
      expect(custom.iconName, 'ic_download');
      expect(custom.colorHex, '#00FF00');
      expect(custom.showCancelButton, isFalse);
      expect(custom.cancelText, 'Stop');
    });
  });

  group('CustomNativeWorker', () {
    test('valid instantiation and toMap', () {
      final worker = CustomNativeWorker(
        className: 'com.example.workers.MyCustomWorker',
        input: {'key': 'val'},
      );
      expect(worker.workerClassName, 'com.example.workers.MyCustomWorker');
      final map = worker.toMap();
      expect(map['workerType'], 'custom');
      expect(map['className'], 'com.example.workers.MyCustomWorker');
      expect(map['input'], '{"key":"val"}');

      final noInput = CustomNativeWorker(className: 'SimpleWorker');
      expect(noInput.toMap()['input'], isNull);
    });

    test('throws on invalid class name format', () {
      expect(
        () => CustomNativeWorker(className: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CustomNativeWorker(className: '123StartsWithDigit'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CustomNativeWorker(className: 'Worker With Spaces'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CustomNativeWorker(className: 'Worker;injection'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CustomNativeWorker(className: 'A' * 300),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TaskHandler Extensions', () {
    test('networkSpeedHuman formatting', () {
      const pNull = TaskProgress(taskId: 't', progress: 50);
      expect(pNull.networkSpeedHuman, 'n/a');

      const pBytes =
          TaskProgress(taskId: 't', progress: 50, networkSpeed: 512.0);
      expect(pBytes.networkSpeedHuman, '512.0 B/s');

      const pKb =
          TaskProgress(taskId: 't', progress: 50, networkSpeed: 1024 * 5.5);
      expect(pKb.networkSpeedHuman, '5.5 KB/s');

      const pMb = TaskProgress(
          taskId: 't', progress: 50, networkSpeed: 1024 * 1024 * 3.25);
      expect(pMb.networkSpeedHuman, '3.3 MB/s');
    });

    test('timeRemainingHuman formatting', () {
      const pNull = TaskProgress(taskId: 't', progress: 50);
      expect(pNull.timeRemainingHuman, 'unknown');

      const pSec = TaskProgress(
          taskId: 't', progress: 50, timeRemaining: Duration(seconds: 45));
      expect(pSec.timeRemainingHuman, '45s');

      const pMin = TaskProgress(
          taskId: 't',
          progress: 50,
          timeRemaining: Duration(minutes: 5, seconds: 12));
      expect(pMin.timeRemainingHuman, '5m 12s');

      const pHour = TaskProgress(
          taskId: 't',
          progress: 50,
          timeRemaining: Duration(hours: 2, minutes: 15));
      expect(pHour.timeRemainingHuman, '2h 15m');
    });
  });

  group('FakeWorkManager Comprehensive Coverage', () {
    late FakeWorkManager wm;

    setUp(() {
      wm = FakeWorkManager();
    });

    tearDown(() {
      wm.dispose();
    });

    test('FakeChainRecord formatting', () {
      final task1 = TaskRequest(
        id: 't1',
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      final task2 = TaskRequest(
        id: 't2',
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      final record = FakeChainRecord(
        firstTask: task1,
        steps: [
          [task1],
          [task2]
        ],
      );
      expect(record.allTasks, [task1, task2]);
      expect(record.toString(), 'FakeChainRecord(t1 → t2)');
    });

    test('getRunningProgress returns empty map', () async {
      final progress = await wm.getRunningProgress();
      expect(progress, isEmpty);
    });

    test('enqueueGraph records root nodes', () async {
      final graph = TaskGraph(id: 'test_dag');
      graph.add(TaskNode(
        id: 'node_1',
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      ));
      final execution = await wm.enqueueGraph(graph);
      expect(execution.graphId, 'test_dag');
      expect(wm.enqueued, hasLength(1));
      expect(wm.enqueued.first.taskId, 'node_1');
    });

    test('pause, resume, cancel, cancelByTag, cancelAll', () async {
      await wm.pause(taskId: 't_pause');
      expect(wm.paused, contains('t_pause'));

      await wm.resume(taskId: 't_pause');
      expect(wm.resumed, contains('t_pause'));

      await wm.cancel(taskId: 't_cancel');
      expect(wm.cancelled, contains('t_cancel'));

      await wm.cancelByTag(tag: 'tag_a');
      expect(wm.cancelledTags, contains('tag_a'));

      await wm.cancelAll();
      expect(wm.cancelAllCalled, isTrue);
    });

    test('task status, records, tags, allTasks queries', () async {
      final worker = NativeWorker.httpRequest(url: 'https://example.com');
      await wm.enqueue(
        taskId: 'task_query',
        trigger: const TaskTrigger.oneTime(),
        worker: worker,
        tag: 'query_tag',
      );

      wm.taskStatuses['task_query'] = TaskStatus.running;
      final status = await wm.getTaskStatus(taskId: 'task_query');
      expect(status, TaskStatus.running);

      wm.allTasksResult = [
        TaskRecord(
          taskId: 'task_query',
          status: 'running',
          workerClassName: 'HttpRequestWorker',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];
      final record = await wm.getTaskRecord(taskId: 'task_query');
      expect(record?.taskId, 'task_query');

      wm.tasksByTag['query_tag'] = ['task_query'];
      final tasksWithTag = await wm.getTasksByTag(tag: 'query_tag');
      expect(tasksWithTag, contains('task_query'));

      wm.allTagsResult = ['query_tag'];
      final tags = await wm.getAllTags();
      expect(tags, contains('query_tag'));

      final all = await wm.allTasks();
      expect(all, isNotEmpty);
    });

    test('emitEvent and emitProgress dispatch to streams', () async {
      final events = <TaskEvent>[];
      final progresses = <TaskProgress>[];

      final sub1 = wm.events.listen(events.add);
      final sub2 = wm.progress.listen(progresses.add);

      wm.emitProgress(const TaskProgress(taskId: 't1', progress: 50));
      wm.emitEvent(TaskEvent(
        taskId: 't1',
        success: true,
        timestamp: DateTime.now(),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(progresses, hasLength(1));
      expect(events, hasLength(1));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('reset clears internal state and recreates streams', () async {
      await wm.enqueue(
        taskId: 't_reset',
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      expect(wm.enqueued, hasLength(1));

      wm.reset();
      expect(wm.enqueued, isEmpty);
      expect(wm.cancelled, isEmpty);
      expect(wm.cancelledTags, isEmpty);
      expect(wm.cancelAllCalled, isFalse);
    });
  });

  group('Observability & WorkManagerLogger', () {
    test('ObservabilityConfig.fromLogger routes callbacks', () {
      final logger = _TestLogger();
      final config = ObservabilityConfig.fromLogger(logger);
      final dispatcher = ObservabilityDispatcher(config);

      dispatcher.dispatchEvent(TaskEvent(
        taskId: 'task_obs_1',
        success: false,
        isStarted: true,
        workerType: 'HttpDownloadWorker',
        timestamp: DateTime.now(),
      ));
      expect(logger.starts, contains('task_obs_1:HttpDownloadWorker'));

      dispatcher.dispatchEvent(TaskEvent(
        taskId: 'task_obs_1',
        success: true,
        isStarted: false,
        timestamp: DateTime.now(),
      ));
      expect(logger.completions, contains('task_obs_1'));

      dispatcher.dispatchEvent(TaskEvent(
        taskId: 'task_obs_2',
        success: false,
        isStarted: false,
        timestamp: DateTime.now(),
      ));
      expect(logger.failures, contains('task_obs_2'));
    });

    test('ObservabilityDispatcher catches exceptions in user callbacks safely',
        () {
      final config = ObservabilityConfig(
        onTaskStart: (taskId, workerType) => throw Exception('crash in start'),
        onTaskComplete: (event) => throw Exception('crash in complete'),
        onTaskFail: (event) => throw Exception('crash in fail'),
        onProgress: (progress) => throw Exception('crash in progress'),
      );
      final dispatcher = ObservabilityDispatcher(config);

      expect(
        () => dispatcher.dispatchEvent(TaskEvent(
          taskId: 't',
          success: false,
          isStarted: true,
          timestamp: DateTime.now(),
        )),
        returnsNormally,
      );

      expect(
        () => dispatcher.dispatchEvent(TaskEvent(
          taskId: 't',
          success: true,
          isStarted: false,
          timestamp: DateTime.now(),
        )),
        returnsNormally,
      );

      expect(
        () => dispatcher.dispatchEvent(TaskEvent(
          taskId: 't',
          success: false,
          isStarted: false,
          timestamp: DateTime.now(),
        )),
        returnsNormally,
      );

      expect(
        () => dispatcher
            .dispatchProgress(const TaskProgress(taskId: 't', progress: 20)),
        returnsNormally,
      );
    });

    test('registerDevToolsExtensions registers without error', () {
      expect(registerDevToolsExtensions, returnsNormally);
    });
  });

  group('NativeWorkManagerClient Delegation', () {
    late _FakeClientPlatform platform;

    setUp(() async {
      platform = _FakeClientPlatform();
      NativeWorkManagerPlatform.instance = platform;
      await NativeWorkManager.initialize();
    });

    tearDown(() async {
      await platform.dispose();
    });

    test('delegates all methods to NativeWorkManager', () async {
      const client = NativeWorkManagerClient();
      expect(client.events, isA<Stream<TaskEvent>>());
      expect(client.progress, isA<Stream<TaskProgress>>());

      final runningProgress = await client.getRunningProgress();
      expect(runningProgress, contains('t1'));

      final handler = await client.enqueue(
        taskId: 't_client',
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      expect(handler.taskId, 't_client');

      final handlers = await client.enqueueAll([
        EnqueueRequest(
          taskId: 't_client_batch',
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.httpRequest(url: 'https://example.com'),
        )
      ]);
      expect(handlers, hasLength(1));

      final chain = client.beginWith(TaskRequest(
        id: 't_chain',
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      ));
      expect(chain, isA<TaskChainBuilder>());

      final graph = TaskGraph(id: 'graph_client');
      graph.add(TaskNode(
        id: 'n1',
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      ));
      final graphExec = await client.enqueueGraph(graph);
      expect(graphExec.graphId, 'graph_client');

      await client.cancel(taskId: 't_cancel');
      expect(platform.cancelledTasks, contains('t_cancel'));

      await client.cancelByTag(tag: 'tag_cancel');
      expect(platform.cancelledTags, contains('tag_cancel'));

      await client.cancelAll();
      expect(platform.cancelAllCalled, isTrue);

      await client.pause(taskId: 't_pause');
      expect(platform.pausedTasks, contains('t_pause'));

      await client.resume(taskId: 't_pause');
      expect(platform.resumedTasks, contains('t_pause'));

      final status = await client.getTaskStatus(taskId: 't_client');
      expect(status, TaskStatus.running);

      final record = await client.getTaskRecord(taskId: 't_client');
      expect(record?.taskId, 't_client');

      final byTag = await client.getTasksByTag(tag: 'my_tag');
      expect(byTag, contains('task_for_my_tag'));

      final tags = await client.getAllTags();
      expect(tags, contains('tag1'));

      final all = await client.allTasks();
      expect(all, hasLength(1));

      expect(() => client.dispose(), returnsNormally);
    });
  });

  group('TaskHandler Full Lifecycle', () {
    late _FakeClientPlatform platform;

    setUp(() async {
      platform = _FakeClientPlatform();
      NativeWorkManagerPlatform.instance = platform;
      await NativeWorkManager.initialize();
    });

    tearDown(() async {
      await platform.dispose();
    });

    test('TaskHandler properties, progress, events, result and actions',
        () async {
      const handler = TaskHandler(
        taskId: 't_handler',
        scheduleResult: ScheduleResult.accepted,
      );
      expect(handler.taskId, 't_handler');
      expect(handler.scheduleResult, ScheduleResult.accepted);

      final progressList = <TaskProgress>[];
      final eventsList = <TaskEvent>[];

      final sub1 = handler.progress.listen(progressList.add);
      final sub2 = handler.events.listen(eventsList.add);

      platform.progressController
          .add(const TaskProgress(taskId: 't_handler', progress: 40));
      platform.progressController
          .add(const TaskProgress(taskId: 'other_task', progress: 80));

      platform.eventsController.add(TaskEvent(
        taskId: 't_handler',
        success: false,
        isStarted: true,
        timestamp: DateTime.now(),
      ));

      final resultFuture = handler.result;

      platform.eventsController.add(TaskEvent(
        taskId: 't_handler',
        success: true,
        isStarted: false,
        timestamp: DateTime.now(),
      ));

      final completedEvent = await resultFuture;
      expect(completedEvent.success, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(progressList, hasLength(1));
      expect(progressList.first.progress, 40);
      expect(eventsList, hasLength(2));

      await sub1.cancel();
      await sub2.cancel();

      await handler.cancel();
      expect(platform.cancelledTasks, contains('t_handler'));

      final status = await handler.getStatus();
      expect(status, TaskStatus.running);
    });
  });

  group('NativeWorkManagerPlatform Default Implementations', () {
    late _DefaultPlatform platform;

    setUp(() {
      platform = _DefaultPlatform();
    });

    test('all default methods throw UnimplementedError', () {
      expect(
        () => platform.initialize(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.enqueue(
          taskId: 't',
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.httpRequest(url: 'https://example.com'),
          constraints: const Constraints(),
          existingPolicy: ExistingTaskPolicy.replace,
        ),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.cancelByTag(tag: 'tag'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getTasksByTag(tag: 'tag'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getAllTags(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.cancel(taskId: 't'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.cancelAll(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getTaskStatus(taskId: 't'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getTaskRecord(taskId: 't'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getTasksByStatus(status: TaskStatus.running),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.enqueueChain(const {}),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.events,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.progress,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.systemErrors,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.pauseTask(taskId: 't'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.resumeTask(taskId: 't'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.allTasks(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getServerFilename(url: 'https://example.com'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getRunningProgress(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.openFile('/tmp/file.txt'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.setMaxConcurrentPerHost(2),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.registerRemoteTrigger(
          source: RemoteTriggerSource.fcm,
          rule: RemoteTriggerRule(
            payloadKey: 'type',
            workerMappings: {
              'sync': NativeWorker.httpRequest(url: 'https://example.com'),
            },
          ),
        ),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.enqueueGraph(const {}),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.offlineQueueEnqueue('q1', const {}),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.registerMiddleware(const {}),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.setCallbackExecutor((id, input) async => true),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.getMetrics(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.syncOfflineQueue(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform.reportTestEvent(
            TaskEvent(taskId: 't', success: true, timestamp: DateTime.now())),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => platform
            .reportTestProgress(const TaskProgress(taskId: 't', progress: 50)),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}

class _DefaultPlatform extends NativeWorkManagerPlatform {}
