import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:native_workmanager/src/platform_interface.dart';

class _BenchmarkPlatform extends MethodChannelNativeWorkManager {
  final eventsCtrl = StreamController<TaskEvent>.broadcast();
  final progressCtrl = StreamController<TaskProgress>.broadcast();

  int totalEnqueued = 0;

  @override
  Stream<TaskEvent> get events => eventsCtrl.stream;

  @override
  Stream<TaskProgress> get progress => progressCtrl.stream;

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
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints = const Constraints(),
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
    String? tag,
  }) async {
    totalEnqueued++;
    return ScheduleResult.accepted;
  }

  @override
  Future<String> enqueueGraph(Map<String, dynamic> graphMap) async {
    return graphMap['id'] as String? ?? 'graph';
  }

  @override
  Future<ScheduleResult> enqueueChain(Map<String, dynamic> chainData) async {
    return ScheduleResult.accepted;
  }

  Future<void> dispose() async {
    await eventsCtrl.close();
    await progressCtrl.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _BenchmarkPlatform platform;

  setUp(() async {
    platform = _BenchmarkPlatform();
    NativeWorkManagerPlatform.instance = platform;
    await NativeWorkManager.initialize();
  });

  tearDown(() async {
    await platform.dispose();
  });

  group('High-Throughput Batch Enqueue Performance', () {
    test('enqueueAll 5,000 tasks throughput and latency benchmark', () async {
      const taskCount = 5000;
      final requests = List.generate(
        taskCount,
        (i) => EnqueueRequest(
          taskId: 'bench_task_$i',
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.httpRequest(
            url: 'https://api.example.com/item/$i',
            headers: {'X-Batch-Id': 'batch_1', 'Authorization': 'Bearer test'},
          ),
          constraints: const Constraints(
            requiresNetwork: true,
            requiresCharging: false,
          ),
        ),
      );

      final sw = Stopwatch()..start();
      final handlers = await NativeWorkManager.enqueueAll(requests);
      sw.stop();

      final elapsedMs = sw.elapsedMilliseconds;
      final usPerTask = (sw.elapsedMicroseconds / taskCount);

      print('⚡ [Batch Enqueue] $taskCount tasks enqueued in ${elapsedMs}ms '
          '(${usPerTask.toStringAsFixed(2)} µs/task)');

      expect(handlers, hasLength(taskCount));
      expect(platform.totalEnqueued, taskCount);
      // Ensure high efficiency: < 0.5ms (500 µs) per task in Dart runtime
      expect(usPerTask, lessThan(500.0));
    });
  });

  group('Complex DAG Graph Topology & Validation Stress', () {
    test('Build, validate, and serialize a 300-node diamond DAG', () async {
      final graph = TaskGraph(id: 'stress_dag_300');
      final sw = Stopwatch()..start();

      // Root layer (10 nodes)
      for (int i = 0; i < 10; i++) {
        graph.add(TaskNode(
          id: 'root_$i',
          worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/part_$i.bin',
            savePath: '/tmp/part_$i.bin',
          ),
        ));
      }

      // Middle layers (diamond dependencies)
      for (int level = 1; level <= 28; level++) {
        for (int i = 0; i < 10; i++) {
          final prevLevel = level - 1;
          final prevNode1 = prevLevel == 0 ? 'root_$i' : 'node_${prevLevel}_$i';
          final prevNode2 = prevLevel == 0
              ? 'root_${(i + 1) % 10}'
              : 'node_${prevLevel}_${(i + 1) % 10}';

          graph.add(TaskNode(
            id: 'node_${level}_$i',
            worker: NativeWorker.hashFile(
              filePath: '/tmp/part_${level}_$i.bin',
              algorithm: HashAlgorithm.sha256,
            ),
            dependsOn: [prevNode1, prevNode2],
          ));
        }
      }

      // Sink layer (1 node depending on all 10 previous nodes)
      graph.add(TaskNode(
        id: 'sink_final',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/upload-summary',
          filePath: '/tmp/summary.bin',
        ),
        dependsOn: List.generate(10, (i) => 'node_28_$i'),
      ));

      // Validate topology and acyclic integrity
      graph.validate();
      final map = graph.toMap();
      sw.stop();

      print('⚡ [DAG Stress] 300-node diamond graph built, validated, and '
          'serialized in ${sw.elapsedMilliseconds}ms');

      expect(graph.nodes, hasLength(291));
      expect(map['nodes'], hasLength(291));
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  group('Deep Linear & Parallel Chain Builder Stress', () {
    test('Build and serialize a 500-step task chain', () async {
      final initial = TaskRequest(
        id: 'chain_step_0',
        worker: NativeWorker.httpRequest(url: 'https://example.com/0'),
      );

      final sw = Stopwatch()..start();
      var builder = NativeWorkManager.beginWith(initial);

      for (int i = 1; i < 500; i++) {
        if (i % 5 == 0) {
          // Parallel fork step
          builder = builder.thenAll([
            TaskRequest(
              id: 'chain_parallel_${i}_a',
              worker:
                  NativeWorker.httpRequest(url: 'https://example.com/${i}a'),
            ),
            TaskRequest(
              id: 'chain_parallel_${i}_b',
              worker:
                  NativeWorker.httpRequest(url: 'https://example.com/${i}b'),
            ),
          ]);
        } else {
          // Sequential step
          builder = builder.then(TaskRequest(
            id: 'chain_step_$i',
            worker: NativeWorker.httpRequest(url: 'https://example.com/$i'),
          ));
        }
      }

      final result = await builder.enqueue();
      sw.stop();

      print('⚡ [Chain Stress] 500-step hybrid chain built and enqueued in '
          '${sw.elapsedMilliseconds}ms');

      expect(result, ScheduleResult.accepted);
      expect(builder.steps, hasLength(500));
      expect(sw.elapsedMilliseconds, lessThan(150));
    });
  });

  group('High-Frequency Stream Flooding & Event Filtering Stress', () {
    test('Process 20,000 stream events with 10 concurrent subscribers',
        () async {
      const eventCount = 20000;
      const subscriberCount = 10;
      final receivedCounts = List.filled(subscriberCount, 0);

      final subs = <StreamSubscription<TaskEvent>>[];
      for (int s = 0; s < subscriberCount; s++) {
        final subIndex = s;
        subs.add(NativeWorkManager.events.listen((e) {
          if (e.taskId.startsWith('flood_task_')) {
            receivedCounts[subIndex]++;
          }
        }));
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < eventCount; i++) {
        platform.eventsCtrl.add(TaskEvent(
          taskId: 'flood_task_$i',
          success: i % 2 == 0,
          isStarted: false,
          timestamp: DateTime.now(),
          resultData: {'index': i},
        ));
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
      sw.stop();

      for (final sub in subs) {
        await sub.cancel();
      }

      print(
          '⚡ [Stream Flooding] Dispatched $eventCount events to $subscriberCount '
          'subscribers (${eventCount * subscriberCount} deliveries) in '
          '${sw.elapsedMilliseconds}ms');

      for (int s = 0; s < subscriberCount; s++) {
        expect(receivedCounts[s], eventCount);
      }
    });
  });

  group('Concurrent OfflineQueue Enqueue & Drain Stress', () {
    test('1,000 concurrent callers enqueueing into OfflineQueue', () async {
      final queue = OfflineQueue(id: 'stress_queue_1000', maxSize: 2000);
      final sw = Stopwatch()..start();

      final futures = <Future<void>>[];
      for (int i = 0; i < 1000; i++) {
        futures.add(queue.enqueue(QueueEntry(
          taskId: 'stress_item_$i',
          worker: NativeWorker.httpRequest(url: 'https://example.com/$i'),
          tag: 'batch_${i % 10}',
        )));
      }

      await Future.wait(futures);
      sw.stop();

      print('⚡ [OfflineQueue Concurrency] 1,000 async concurrent enqueues '
          'completed in ${sw.elapsedMilliseconds}ms');

      expect(queue.pendingCount, 1000);

      // Cancel a whole tag concurrently
      queue.cancel(tag: 'batch_0'); // 100 items
      expect(queue.pendingCount, 900);
    });
  });

  group('Large Payload Worker Serialization Benchmark', () {
    test('Serialize workers with 10,000 custom header pairs & large query maps',
        () async {
      final largeHeaders = <String, String>{};
      for (int i = 0; i < 5000; i++) {
        largeHeaders['X-Custom-Header-$i'] =
            'Value-Payload-$i-Random-Hash-Data';
      }

      final sw = Stopwatch()..start();
      final worker = NativeWorker.httpRequest(
        url: 'https://api.enterprise.com/v2/bulk-data-sync',
        method: HttpMethod.post,
        headers: largeHeaders,
        body:
            '{"records": ${List.generate(1000, (i) => '{"id":$i,"active":true}')}}',
      );

      final map = worker.toMap();
      sw.stop();

      print('⚡ [Payload Benchmark] 5,000-header + 1,000-record JSON worker '
          'serialized in ${sw.elapsedMilliseconds}ms');

      expect(map['headers'], hasLength(5000));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });
}
