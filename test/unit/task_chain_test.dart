import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Comprehensive unit tests for TaskRequest and TaskChainBuilder APIs.
///
/// Tests cover:
/// - TaskRequest construction, serialization, equality
/// - Sequential chains (then)
/// - Parallel chains (thenAll)
/// - Mixed sequential + parallel workflows
/// - Chain naming and constraints
/// - Serialization (toMap) and toString
/// - Edge cases and error handling
void main() {
  group('TaskRequest', () {
    test('should create TaskRequest with required fields', () {
      final worker = DartWorker(callbackId: 'myCallback');
      final request = TaskRequest(
        id: 'task-1',
        worker: worker,
      );

      expect(request.id, 'task-1');
      expect(request.worker, worker);
      expect(request.constraints, isA<Constraints>());
    });

    test('should create TaskRequest with custom constraints', () {
      final worker = DartWorker(callbackId: 'myCallback');
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
      );
      final request = TaskRequest(
        id: 'constrained-task',
        worker: worker,
        constraints: constraints,
      );

      expect(request.id, 'constrained-task');
      expect(request.constraints.requiresNetwork, isTrue);
      expect(request.constraints.requiresCharging, isTrue);
    });

    test('should serialize TaskRequest to map', () {
      final worker = DartWorker(callbackId: 'myCallback');
      final request = TaskRequest(
        id: 'task-1',
        worker: worker,
      );
      final map = request.toMap();

      expect(map['id'], 'task-1');
      expect(map['workerClassName'], isNotNull);
      expect(map['workerConfig'], isNotNull);
      expect(map['constraints'], isNotNull);
    });

    test('should use equality based on id only', () {
      final worker1 = DartWorker(callbackId: 'callback-A');
      final worker2 = DartWorker(callbackId: 'callback-B');

      final request1 = TaskRequest(id: 'same-id', worker: worker1);
      final request2 = TaskRequest(id: 'same-id', worker: worker2);
      final request3 = TaskRequest(id: 'different-id', worker: worker1);

      expect(request1, equals(request2));
      expect(request1, isNot(equals(request3)));
    });

    test('should use id for hashCode', () {
      final worker = DartWorker(callbackId: 'myCallback');
      final request1 = TaskRequest(id: 'task-1', worker: worker);
      final request2 = TaskRequest(id: 'task-1', worker: worker);

      expect(request1.hashCode, equals(request2.hashCode));
    });

    test('should have proper toString', () {
      final worker = DartWorker(callbackId: 'myCallback');
      final request = TaskRequest(id: 'my-task', worker: worker);
      final str = request.toString();

      expect(str, contains('TaskRequest'));
      expect(str, contains('my-task'));
    });

    test('should work with HttpDownload worker', () {
      final worker = NativeWorker.httpDownload(
        url: 'https://example.com/file.zip',
        savePath: '/tmp/file.zip',
      );
      final request = TaskRequest(id: 'download', worker: worker);

      expect(request.id, 'download');
      expect(request.worker, worker);
    });

    test('should work with HttpUpload worker', () {
      final worker = NativeWorker.httpUpload(
        url: 'https://example.com/upload',
        filePath: '/tmp/file.zip',
      );
      final request = TaskRequest(id: 'upload', worker: worker);

      expect(request.id, 'upload');
      expect(request.worker, worker);
    });

    test('should work with HttpRequest worker', () {
      final worker = NativeWorker.httpRequest(
        url: 'https://api.example.com/ping',
        method: HttpMethod.get,
      );
      final request = TaskRequest(id: 'ping', worker: worker);

      expect(request.id, 'ping');
      expect(request.worker, worker);
    });
  });

  group('TaskChainBuilder - Sequential Chains', () {
    test('should create chain with single initial task', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final chain = TaskChainBuilder.internal([taskA]);

      expect(chain.steps, hasLength(1));
      expect(chain.steps[0], hasLength(1));
      expect(chain.steps[0][0].id, 'task-a');
    });

    test('should add sequential task with then', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB = TaskRequest(
        id: 'task-b',
        worker: DartWorker(callbackId: 'callbackB'),
      );

      final chain = TaskChainBuilder.internal([taskA]).then(taskB);

      expect(chain.steps, hasLength(2));
      expect(chain.steps[0][0].id, 'task-a');
      expect(chain.steps[1][0].id, 'task-b');
    });

    test('should chain three sequential tasks A -> B -> C', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB = TaskRequest(
        id: 'task-b',
        worker: DartWorker(callbackId: 'callbackB'),
      );
      final taskC = TaskRequest(
        id: 'task-c',
        worker: DartWorker(callbackId: 'callbackC'),
      );

      final chain =
          TaskChainBuilder.internal([taskA]).then(taskB).then(taskC);

      expect(chain.steps, hasLength(3));
      expect(chain.steps[0][0].id, 'task-a');
      expect(chain.steps[1][0].id, 'task-b');
      expect(chain.steps[2][0].id, 'task-c');
    });

    test('should return same builder from then for fluent API', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB = TaskRequest(
        id: 'task-b',
        worker: DartWorker(callbackId: 'callbackB'),
      );

      final chain = TaskChainBuilder.internal([taskA]);
      final result = chain.then(taskB);

      expect(result, same(chain));
    });
  });

  group('TaskChainBuilder - Parallel Chains', () {
    test('should add parallel tasks with thenAll', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB1 = TaskRequest(
        id: 'task-b1',
        worker: DartWorker(callbackId: 'callbackB1'),
      );
      final taskB2 = TaskRequest(
        id: 'task-b2',
        worker: DartWorker(callbackId: 'callbackB2'),
      );

      final chain =
          TaskChainBuilder.internal([taskA]).thenAll([taskB1, taskB2]);

      expect(chain.steps, hasLength(2));
      expect(chain.steps[0], hasLength(1)); // single initial task
      expect(chain.steps[1], hasLength(2)); // two parallel tasks
      expect(chain.steps[1][0].id, 'task-b1');
      expect(chain.steps[1][1].id, 'task-b2');
    });

    test('should support three parallel tasks', () {
      final taskA = TaskRequest(
        id: 'prepare',
        worker: DartWorker(callbackId: 'prepare'),
      );
      final upload1 = TaskRequest(
        id: 'upload-1',
        worker: NativeWorker.httpUpload(
            url: 'https://s1.example.com', filePath: '/tmp/data'),
      );
      final upload2 = TaskRequest(
        id: 'upload-2',
        worker: NativeWorker.httpUpload(
            url: 'https://s2.example.com', filePath: '/tmp/data'),
      );
      final upload3 = TaskRequest(
        id: 'upload-3',
        worker: NativeWorker.httpUpload(
            url: 'https://s3.example.com', filePath: '/tmp/data'),
      );

      final chain = TaskChainBuilder.internal([taskA])
          .thenAll([upload1, upload2, upload3]);

      expect(chain.steps[1], hasLength(3));
    });

    test('should throw ArgumentError on empty thenAll list', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );

      final chain = TaskChainBuilder.internal([taskA]);

      expect(() => chain.thenAll([]), throwsArgumentError);
    });

    test('should return same builder from thenAll for fluent API', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB = TaskRequest(
        id: 'task-b',
        worker: DartWorker(callbackId: 'callbackB'),
      );

      final chain = TaskChainBuilder.internal([taskA]);
      final result = chain.thenAll([taskB]);

      expect(result, same(chain));
    });

    test('should start with multiple parallel initial tasks', () {
      final task1 = TaskRequest(
        id: 'download-1',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/1', savePath: '/tmp/1'),
      );
      final task2 = TaskRequest(
        id: 'download-2',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/2', savePath: '/tmp/2'),
      );

      final chain = TaskChainBuilder.internal([task1, task2]);

      expect(chain.steps, hasLength(1));
      expect(chain.steps[0], hasLength(2));
    });
  });

  group('TaskChainBuilder - Mixed Workflows', () {
    test('should support sequential -> parallel -> sequential', () {
      final fetch = TaskRequest(
        id: 'fetch',
        worker: NativeWorker.httpRequest(
            url: 'https://api.example.com/data', method: HttpMethod.get),
      );
      final download1 = TaskRequest(
        id: 'download-1',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/1', savePath: '/tmp/1'),
      );
      final download2 = TaskRequest(
        id: 'download-2',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/2', savePath: '/tmp/2'),
      );
      final process = TaskRequest(
        id: 'process',
        worker: DartWorker(callbackId: 'processData'),
      );

      final chain = TaskChainBuilder.internal([fetch])
          .thenAll([download1, download2])
          .then(process);

      // fetch -> [download-1, download-2] -> process
      expect(chain.steps, hasLength(3));
      expect(chain.steps[0], hasLength(1)); // fetch (single)
      expect(chain.steps[1], hasLength(2)); // parallel downloads
      expect(chain.steps[2], hasLength(1)); // process (single)
    });

    test('should support full ETL pipeline', () {
      // Stage 1: Fetch metadata
      final fetchMeta = TaskRequest(
        id: 'fetch-metadata',
        worker: NativeWorker.httpRequest(
            url: 'https://api.example.com/meta', method: HttpMethod.get),
      );
      // Stage 2: Download files in parallel
      final file1 = TaskRequest(
        id: 'download-file1',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/file1', savePath: '/tmp/file1'),
      );
      final file2 = TaskRequest(
        id: 'download-file2',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/file2', savePath: '/tmp/file2'),
      );
      // Stage 3: Merge
      final merge = TaskRequest(
        id: 'merge',
        worker: DartWorker(callbackId: 'mergeFiles'),
      );
      // Stage 4: Upload result
      final upload = TaskRequest(
        id: 'upload-result',
        worker: NativeWorker.httpUpload(
            url: 'https://api.example.com/results', filePath: '/tmp/result'),
      );

      final chain = TaskChainBuilder.internal([fetchMeta])
          .thenAll([file1, file2])
          .then(merge)
          .then(upload);

      expect(chain.steps, hasLength(4));
      expect(chain.steps[0][0].id, 'fetch-metadata');
      expect(chain.steps[1][0].id, 'download-file1');
      expect(chain.steps[1][1].id, 'download-file2');
      expect(chain.steps[2][0].id, 'merge');
      expect(chain.steps[3][0].id, 'upload-result');
    });

    test('should support parallel -> sequential merge', () {
      final download1 = TaskRequest(
        id: 'download-1',
        worker: NativeWorker.httpDownload(
            url: 'https://example.com/1', savePath: '/tmp/1'),
      );
      final download2 = TaskRequest(
        id: 'download-2',
        worker: NativeWorker.httpDownload(
            url: 'https://example.com/2', savePath: '/tmp/2'),
      );
      final merge = TaskRequest(
        id: 'merge',
        worker: DartWorker(callbackId: 'merge'),
      );
      final upload = TaskRequest(
        id: 'upload',
        worker: NativeWorker.httpUpload(
            url: 'https://example.com/result', filePath: '/tmp/merged'),
      );

      // Start with parallel, then sequential
      final chain = TaskChainBuilder.internal([download1, download2])
          .then(merge)
          .then(upload);

      expect(chain.steps, hasLength(3));
      expect(chain.steps[0], hasLength(2)); // parallel start
      expect(chain.steps[1], hasLength(1)); // merge
      expect(chain.steps[2], hasLength(1)); // upload
    });
  });

  group('TaskChainBuilder - Naming', () {
    test('should set chain name with named()', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]).named('my-pipeline');

      expect(chain.name, 'my-pipeline');
    });

    test('should default name to null', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]);

      expect(chain.name, isNull);
    });

    test('should return same builder from named for fluent API', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]);
      final result = chain.named('test');

      expect(result, same(chain));
    });
  });

  group('TaskChainBuilder - Constraints', () {
    test('should set chain-level constraints', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
      );

      final chain =
          TaskChainBuilder.internal([task]).withConstraints(constraints);

      expect(chain.constraints.requiresNetwork, isTrue);
      expect(chain.constraints.requiresCharging, isTrue);
    });

    test('should default to empty constraints', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]);

      expect(chain.constraints, isA<Constraints>());
    });

    test('should support heavy task constraints on chain', () {
      final download = TaskRequest(
        id: 'download',
        worker: NativeWorker.httpDownload(
            url: 'https://example.com/large.zip', savePath: '/tmp/large.zip'),
      );
      final process = TaskRequest(
        id: 'process',
        worker: DartWorker(callbackId: 'processLargeFile'),
      );

      final chain = TaskChainBuilder.internal([download])
          .then(process)
          .withConstraints(Constraints(
            requiresNetwork: true,
            requiresCharging: true,
          ));

      expect(chain.constraints.requiresNetwork, isTrue);
      expect(chain.constraints.requiresCharging, isTrue);
    });

    test('should return same builder from withConstraints', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]);
      final result =
          chain.withConstraints(Constraints(requiresNetwork: true));

      expect(result, same(chain));
    });
  });

  group('TaskChainBuilder - Serialization', () {
    test('should serialize chain to map', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain =
          TaskChainBuilder.internal([task]).named('test-chain');
      final map = chain.toMap();

      expect(map['name'], 'test-chain');
      expect(map['constraints'], isNotNull);
      expect(map['steps'], isNotNull);
    });

    test('should serialize sequential chain steps correctly', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB = TaskRequest(
        id: 'task-b',
        worker: DartWorker(callbackId: 'callbackB'),
      );

      final chain = TaskChainBuilder.internal([taskA]).then(taskB);
      final map = chain.toMap();
      final steps = map['steps'] as List;

      expect(steps, hasLength(2));
      expect(((steps[0] as List)[0] as Map)['id'], 'task-a');
      expect(((steps[1] as List)[0] as Map)['id'], 'task-b');
    });

    test('should serialize parallel tasks in single step', () {
      final taskA = TaskRequest(
        id: 'task-a',
        worker: DartWorker(callbackId: 'callbackA'),
      );
      final taskB1 = TaskRequest(
        id: 'task-b1',
        worker: DartWorker(callbackId: 'callbackB1'),
      );
      final taskB2 = TaskRequest(
        id: 'task-b2',
        worker: DartWorker(callbackId: 'callbackB2'),
      );

      final chain =
          TaskChainBuilder.internal([taskA]).thenAll([taskB1, taskB2]);
      final map = chain.toMap();
      final steps = map['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0] as List, hasLength(1)); // single initial
      expect(steps[1] as List, hasLength(2)); // parallel
    });

    test('should serialize null name when not set', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]);
      final map = chain.toMap();

      expect(map['name'], isNull);
    });

    test('should serialize constraints in chain map', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );
      final constraints = Constraints(requiresNetwork: true);

      final chain =
          TaskChainBuilder.internal([task]).withConstraints(constraints);
      final map = chain.toMap();
      final constraintsMap = map['constraints'] as Map;

      expect(constraintsMap['requiresNetwork'], isTrue);
    });
  });

  group('TaskChainBuilder - toString', () {
    test('should show unnamed chain in toString', () {
      final taskA = TaskRequest(
        id: 'download',
        worker: DartWorker(callbackId: 'cb'),
      );
      final taskB = TaskRequest(
        id: 'process',
        worker: DartWorker(callbackId: 'cb2'),
      );

      final chain = TaskChainBuilder.internal([taskA]).then(taskB);
      final str = chain.toString();

      expect(str, contains('TaskChain'));
      expect(str, contains('unnamed'));
      expect(str, contains('download'));
      expect(str, contains('process'));
    });

    test('should show named chain in toString', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'cb'),
      );

      final chain =
          TaskChainBuilder.internal([task]).named('my-pipeline');
      final str = chain.toString();

      expect(str, contains('my-pipeline'));
      expect(str, contains('task-1'));
    });

    test('should show parallel tasks in brackets in toString', () {
      final taskA = TaskRequest(
        id: 'prepare',
        worker: DartWorker(callbackId: 'cb'),
      );
      final taskB1 = TaskRequest(
        id: 'upload-1',
        worker: DartWorker(callbackId: 'cb1'),
      );
      final taskB2 = TaskRequest(
        id: 'upload-2',
        worker: DartWorker(callbackId: 'cb2'),
      );

      final chain =
          TaskChainBuilder.internal([taskA]).thenAll([taskB1, taskB2]);
      final str = chain.toString();

      expect(str, contains('prepare'));
      expect(str, contains('['));
      expect(str, contains('upload-1'));
      expect(str, contains('upload-2'));
    });
  });

  group('TaskChainBuilder - enqueue', () {
    test('should throw StateError when not initialized', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      // Ensure callback is null (not initialized)
      final savedCallback = TaskChainBuilder.enqueueCallback;
      TaskChainBuilder.enqueueCallback = null;

      final chain = TaskChainBuilder.internal([task]);

      expect(() => chain.enqueue(), throwsStateError);

      // Restore
      TaskChainBuilder.enqueueCallback = savedCallback;
    });
  });

  group('TaskChainBuilder - steps immutability', () {
    test('should return unmodifiable steps list', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'callback'),
      );

      final chain = TaskChainBuilder.internal([task]);
      final steps = chain.steps;

      expect(() => steps.add([task]), throwsUnsupportedError);
    });
  });

  group('Common Chain Patterns', () {
    test('should create download -> process -> upload pipeline', () {
      final download = TaskRequest(
        id: 'download',
        worker: NativeWorker.httpDownload(
            url: 'https://cdn.example.com/data.zip',
            savePath: '/tmp/data.zip'),
      );
      final process = TaskRequest(
        id: 'process',
        worker: DartWorker(callbackId: 'processZipFile'),
      );
      final upload = TaskRequest(
        id: 'upload',
        worker: NativeWorker.httpUpload(
            url: 'https://api.example.com/results',
            filePath: '/tmp/results.json'),
      );

      final chain = TaskChainBuilder.internal([download])
          .then(process)
          .then(upload)
          .named('data-pipeline')
          .withConstraints(Constraints(requiresNetwork: true));

      expect(chain.name, 'data-pipeline');
      expect(chain.steps, hasLength(3));
      expect(chain.constraints.requiresNetwork, isTrue);
    });

    test('should create redundant backup to multiple servers', () {
      final prepare = TaskRequest(
        id: 'prepare-backup',
        worker: DartWorker(callbackId: 'prepareBackup'),
      );
      final server1 = TaskRequest(
        id: 'backup-server1',
        worker: NativeWorker.httpUpload(
            url: 'https://s1.example.com/backup', filePath: '/data/backup'),
      );
      final server2 = TaskRequest(
        id: 'backup-server2',
        worker: NativeWorker.httpUpload(
            url: 'https://s2.example.com/backup', filePath: '/data/backup'),
      );
      final cloud = TaskRequest(
        id: 'backup-cloud',
        worker: NativeWorker.httpUpload(
            url: 'https://cloud.example.com/backup', filePath: '/data/backup'),
      );
      final verify = TaskRequest(
        id: 'verify-backup',
        worker: DartWorker(callbackId: 'verifyBackup'),
      );

      final chain = TaskChainBuilder.internal([prepare])
          .thenAll([server1, server2, cloud])
          .then(verify)
          .named('redundant-backup');

      expect(chain.name, 'redundant-backup');
      expect(chain.steps, hasLength(3));
      expect(chain.steps[1], hasLength(3)); // 3 parallel uploads
    });

    test('should create simple two-step sync chain', () {
      final fetch = TaskRequest(
        id: 'fetch-remote',
        worker: NativeWorker.httpSync(
            url: 'https://api.example.com/sync', method: HttpMethod.post),
      );
      final process = TaskRequest(
        id: 'update-local',
        worker: DartWorker(callbackId: 'updateLocalDB'),
      );

      final chain = TaskChainBuilder.internal([fetch])
          .then(process)
          .named('sync')
          .withConstraints(Constraints(requiresNetwork: true));

      expect(chain.steps, hasLength(2));
      expect(chain.name, 'sync');
    });
  });
}
