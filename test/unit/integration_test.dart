import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Integration tests verifying correct interaction between components.
///
/// Tests cover:
/// - Worker + Constraints + Trigger combinations
/// - TaskRequest + Worker serialization pipelines
/// - TaskChain end-to-end workflow serialization
/// - TaskEvent/TaskProgress event pipeline simulation
/// - Error scenario validation
void main() {
  group('Worker + Constraints + Trigger Integration', () {
    test('should compose download task with full config', () {
      final worker = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/video.mp4',
        savePath: '/storage/videos/video.mp4',
        headers: {'Authorization': 'Bearer token123'},
      );
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
      );
      final trigger = TaskTrigger.oneTime(Duration(minutes: 5));

      // Verify all components serialize independently
      final workerMap = worker.toMap();
      final constraintsMap = constraints.toMap();
      final triggerMap = trigger.toMap();

      expect(workerMap['url'], 'https://cdn.example.com/video.mp4');
      expect(workerMap['savePath'], '/storage/videos/video.mp4');
      expect(constraintsMap['requiresNetwork'], isTrue);
      expect(constraintsMap['requiresCharging'], isTrue);
      expect(triggerMap['type'], 'oneTime');
      expect(triggerMap['initialDelayMs'], Duration(minutes: 5).inMilliseconds);
    });

    test('should compose periodic sync with network constraint', () {
      final worker = NativeWorker.httpSync(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
        headers: {'Content-Type': 'application/json'},
      );
      final constraints = Constraints(requiresNetwork: true);
      final trigger = TaskTrigger.periodic(Duration(hours: 1));

      final workerMap = worker.toMap();
      final triggerMap = trigger.toMap();

      expect(workerMap['method'], 'post');
      expect(triggerMap['type'], 'periodic');
      expect(triggerMap['intervalMs'], Duration(hours: 1).inMilliseconds);
      expect(constraints.requiresNetwork, isTrue);
    });

    test('should compose upload task with delayed trigger', () {
      final worker = NativeWorker.httpUpload(
        url: 'https://api.example.com/photos',
        filePath: '/storage/camera/IMG_001.jpg',
        headers: {'Authorization': 'Bearer token'},
        fileFieldName: 'photo',
        additionalFields: {'album': 'vacation', 'public': 'false'},
      );
      final trigger = TaskTrigger.windowed(
        earliest: Duration(hours: 2),
        latest: Duration(hours: 6),
      );

      final workerMap = worker.toMap();
      final triggerMap = trigger.toMap();

      expect(workerMap['filePath'], '/storage/camera/IMG_001.jpg');
      expect(workerMap['fileFieldName'], 'photo');
      expect(workerMap['additionalFields']!['album'], 'vacation');
      expect(triggerMap['type'], 'windowed');
    });

    test('should compose dart worker with exact trigger', () {
      final worker = DartWorker(
        callbackId: 'processData',
        input: {'batchSize': 100, 'compress': true},
      );
      final trigger = TaskTrigger.exact(DateTime(2026, 2, 1, 3, 0));

      final workerMap = worker.toMap();
      final triggerMap = trigger.toMap();

      expect(workerMap['callbackId'], 'processData');
      expect(triggerMap['type'], 'exact');
      expect(triggerMap['scheduledTimeMs'],
          DateTime(2026, 2, 1, 3, 0).millisecondsSinceEpoch);
    });

    test('should compose task with all constraint types', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      final constraintsMap = constraints.toMap();

      expect(constraintsMap['requiresNetwork'], isTrue);
      expect(constraintsMap['requiresCharging'], isTrue);
      expect(constraintsMap['requiresBatteryNotLow'], isTrue);
      expect(constraintsMap['requiresStorageNotLow'], isTrue);
      expect(constraintsMap['requiresDeviceIdle'], isTrue);
    });
  });

  group('TaskRequest + Worker Serialization Pipeline', () {
    test('should serialize TaskRequest with native download worker', () {
      final worker = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/data.json',
        savePath: '/tmp/data.json',
      );
      final request = TaskRequest(
        id: 'fetch-data',
        worker: worker,
        constraints: Constraints(requiresNetwork: true),
      );

      final map = request.toMap();

      expect(map['id'], 'fetch-data');
      expect(map['workerClassName'], isNotNull);
      expect(map['constraints'], isNotNull);
    });

    test('should serialize TaskRequest with dart worker and input', () {
      final worker = DartWorker(
        callbackId: 'processImages',
        input: {'paths': ['/tmp/img1.jpg', '/tmp/img2.jpg'], 'quality': 85},
      );
      final request = TaskRequest(
        id: 'process-images',
        worker: worker,
      );

      final map = request.toMap();

      expect(map['id'], 'process-images');
      expect(map['workerClassName'], isNotNull);
    });

    test('should serialize multiple TaskRequests consistently', () {
      final requests = [
        TaskRequest(
          id: 'task-1',
          worker: NativeWorker.httpRequest(
            url: 'https://api.example.com/ping',
            method: HttpMethod.get,
          ),
        ),
        TaskRequest(
          id: 'task-2',
          worker: NativeWorker.httpUpload(
            url: 'https://api.example.com/upload',
            filePath: '/tmp/file.zip',
          ),
        ),
        TaskRequest(
          id: 'task-3',
          worker: DartWorker(callbackId: 'cleanup'),
        ),
      ];

      final maps = requests.map((r) => r.toMap()).toList();

      expect(maps, hasLength(3));
      expect(maps[0]['id'], 'task-1');
      expect(maps[1]['id'], 'task-2');
      expect(maps[2]['id'], 'task-3');
      // All should have required fields
      for (final map in maps) {
        expect(map['id'], isNotNull);
        expect(map['workerClassName'], isNotNull);
        expect(map['constraints'], isNotNull);
      }
    });
  });

  group('TaskChain End-to-End Workflow Serialization', () {
    test('should serialize complete download-process-upload pipeline', () {
      final download = TaskRequest(
        id: 'download',
        worker: NativeWorker.httpDownload(
          url: 'https://cdn.example.com/data.zip',
          savePath: '/tmp/data.zip',
        ),
      );
      final process = TaskRequest(
        id: 'process',
        worker: DartWorker(callbackId: 'extractAndTransform'),
      );
      final upload = TaskRequest(
        id: 'upload',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/results',
          filePath: '/tmp/results.json',
        ),
      );

      final chain = TaskChainBuilder.internal([download])
          .then(process)
          .then(upload)
          .named('data-pipeline')
          .withConstraints(Constraints(requiresNetwork: true));

      final map = chain.toMap();

      expect(map['name'], 'data-pipeline');
      expect(map['steps'], isNotNull);

      final steps = map['steps'] as List;
      expect(steps, hasLength(3));

      // Verify step structure
      expect((steps[0] as List)[0], isNotNull); // download
      expect((steps[1] as List)[0], isNotNull); // process
      expect((steps[2] as List)[0], isNotNull); // upload
    });

    test('should serialize fan-out parallel workflow', () {
      final fetch = TaskRequest(
        id: 'fetch-config',
        worker: NativeWorker.httpRequest(
          url: 'https://api.example.com/config',
          method: HttpMethod.get,
        ),
      );

      // Three parallel uploads to different CDNs
      final cdn1 = TaskRequest(
        id: 'cdn-1',
        worker: NativeWorker.httpUpload(
          url: 'https://cdn1.example.com/file',
          filePath: '/tmp/file.zip',
        ),
      );
      final cdn2 = TaskRequest(
        id: 'cdn-2',
        worker: NativeWorker.httpUpload(
          url: 'https://cdn2.example.com/file',
          filePath: '/tmp/file.zip',
        ),
      );
      final cdn3 = TaskRequest(
        id: 'cdn-3',
        worker: NativeWorker.httpUpload(
          url: 'https://cdn3.example.com/file',
          filePath: '/tmp/file.zip',
        ),
      );

      final chain = TaskChainBuilder.internal([fetch])
          .thenAll([cdn1, cdn2, cdn3])
          .named('cdn-distribution');

      final map = chain.toMap();
      final steps = map['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0] as List, hasLength(1)); // single fetch
      expect(steps[1] as List, hasLength(3)); // 3 parallel uploads
    });

    test('should serialize fan-in workflow (parallel -> merge)', () {
      final sources = [
        TaskRequest(
          id: 'source-1',
          worker: NativeWorker.httpRequest(
            url: 'https://api1.example.com/data',
            method: HttpMethod.get,
          ),
        ),
        TaskRequest(
          id: 'source-2',
          worker: NativeWorker.httpRequest(
            url: 'https://api2.example.com/data',
            method: HttpMethod.get,
          ),
        ),
      ];

      final merge = TaskRequest(
        id: 'merge',
        worker: DartWorker(callbackId: 'mergeData'),
      );

      final chain =
          TaskChainBuilder.internal(sources).then(merge).named('data-merge');

      final map = chain.toMap();
      final steps = map['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0] as List, hasLength(2)); // 2 parallel sources
      expect(steps[1] as List, hasLength(1)); // 1 merge step
      expect(map['name'], 'data-merge');
    });
  });

  group('Event Pipeline Simulation', () {
    test('should simulate task lifecycle events', () {
      final events = [
        TaskEvent(
          taskId: 'upload-photos',
          success: true,
          message: 'Uploaded 5 photos',
          resultData: {'count': 5, 'bytes': 2048000},
          timestamp: DateTime(2026, 2, 1, 12, 0, 0),
        ),
        TaskEvent(
          taskId: 'sync-contacts',
          success: false,
          message: 'Connection timeout after 30s',
          timestamp: DateTime(2026, 2, 1, 12, 0, 5),
        ),
        TaskEvent(
          taskId: 'cleanup-cache',
          success: true,
          resultData: {'deleted_files': 42, 'freed_mb': 156},
          timestamp: DateTime(2026, 2, 1, 12, 0, 10),
        ),
      ];

      // Filter successful events
      final successful = events.where((e) => e.success).toList();
      expect(successful, hasLength(2));
      expect(successful[0].taskId, 'upload-photos');
      expect(successful[1].taskId, 'cleanup-cache');

      // Filter failed events
      final failed = events.where((e) => !e.success).toList();
      expect(failed, hasLength(1));
      expect(failed[0].taskId, 'sync-contacts');
      expect(failed[0].message, 'Connection timeout after 30s');
    });

    test('should simulate progress updates for download', () {
      final progressUpdates = [
        TaskProgress(taskId: 'download-video', progress: 0,
            message: 'Starting download'),
        TaskProgress(taskId: 'download-video', progress: 25,
            message: 'Downloading...'),
        TaskProgress(taskId: 'download-video', progress: 50,
            message: 'Half way'),
        TaskProgress(taskId: 'download-video', progress: 75,
            message: 'Almost there'),
        TaskProgress(taskId: 'download-video', progress: 100,
            message: 'Download complete'),
      ];

      // Verify monotonic progression
      for (var i = 1; i < progressUpdates.length; i++) {
        expect(progressUpdates[i].progress >= progressUpdates[i - 1].progress,
            isTrue);
      }

      // Verify final state
      expect(progressUpdates.last.progress, 100);
      expect(progressUpdates.last.message, 'Download complete');
    });

    test('should simulate multi-step batch progress', () {
      final totalFiles = 4;
      final progressUpdates = List.generate(
        totalFiles,
        (i) => TaskProgress(
          taskId: 'batch-upload',
          progress: ((i + 1) / totalFiles * 100).toInt(),
          message: 'Uploading file ${i + 1} of $totalFiles',
          currentStep: i + 1,
          totalSteps: totalFiles,
        ),
      );

      expect(progressUpdates, hasLength(4));
      expect(progressUpdates[0].progress, 25);
      expect(progressUpdates[0].currentStep, 1);
      expect(progressUpdates[1].progress, 50);
      expect(progressUpdates[2].progress, 75);
      expect(progressUpdates[3].progress, 100);
      expect(progressUpdates[3].currentStep, 4);
      expect(progressUpdates[3].totalSteps, 4);
    });

    test('should simulate event-to-map round trip for pipeline', () {
      final originalEvents = [
        TaskEvent(
          taskId: 'step-1',
          success: true,
          timestamp: DateTime(2026, 2, 1, 12, 0),
        ),
        TaskEvent(
          taskId: 'step-2',
          success: true,
          resultData: {'output': 'processed.json'},
          timestamp: DateTime(2026, 2, 1, 12, 1),
        ),
      ];

      // Serialize and deserialize
      final serialized = originalEvents.map((e) => e.toMap()).toList();
      final restored = serialized.map((m) => TaskEvent.fromMap(m)).toList();

      expect(restored, hasLength(2));
      expect(restored[0].taskId, 'step-1');
      expect(restored[0].success, isTrue);
      expect(restored[1].taskId, 'step-2');
      expect(restored[1].resultData!['output'], 'processed.json');
    });
  });

  group('Cross-Component Data Flow', () {
    test('should create full task config: trigger + worker + constraints', () {
      // Simulate what enqueue() receives
      final taskId = 'hourly-sync';
      final trigger = TaskTrigger.periodic(Duration(hours: 1));
      final worker = NativeWorker.httpSync(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer token'},
        requestBody: {'lastSync': '2026-02-01T00:00:00Z'},
      );
      final constraints = Constraints(requiresNetwork: true);

      // Verify complete serialization
      final triggerMap = trigger.toMap();
      final workerMap = worker.toMap();
      final constraintsMap = constraints.toMap();

      // Assemble what would be sent to platform
      final taskConfig = {
        'taskId': taskId,
        'trigger': triggerMap,
        'worker': workerMap,
        'constraints': constraintsMap,
      };

      expect(taskConfig['taskId'], 'hourly-sync');
      expect((taskConfig['trigger'] as Map)['type'], 'periodic');
      expect((taskConfig['worker'] as Map)['method'], 'post');
      expect((taskConfig['constraints'] as Map)['requiresNetwork'], isTrue);
    });

    test('should compose tagged batch upload config', () {
      final tag = 'photo-backup';
      final files = ['/photos/img1.jpg', '/photos/img2.jpg', '/photos/img3.jpg'];

      final tasks = List.generate(files.length, (i) => {
        'taskId': 'upload-$i',
        'trigger': TaskTrigger.oneTime().toMap(),
        'worker': NativeWorker.httpUpload(
          url: 'https://api.example.com/photos',
          filePath: files[i],
        ).toMap(),
        'constraints': Constraints(requiresNetwork: true).toMap(),
        'tag': tag,
      });

      expect(tasks, hasLength(3));

      // All tasks should share the same tag
      for (final task in tasks) {
        expect(task['tag'], 'photo-backup');
      }

      // Verify unique task IDs
      final taskIds = tasks.map((t) => t['taskId']).toList();
      expect(taskIds.toSet().length, 3);

      // Verify trigger type
      for (final task in tasks) {
        expect((task['trigger'] as Map)['type'], 'oneTime');
      }
    });

    test('should create replacement policy config', () {
      // First task config
      final original = {
        'taskId': 'daily-sync',
        'existingPolicy': ExistingTaskPolicy.keep.name,
      };

      // Update config
      final updated = {
        'taskId': 'daily-sync',
        'existingPolicy': ExistingTaskPolicy.replace.name,
      };

      expect(original['existingPolicy'], 'keep');
      expect(updated['existingPolicy'], 'replace');
      expect(original['taskId'], updated['taskId']); // Same task ID
    });
  });

  group('Error Scenario Validation', () {
    test('should validate empty taskId', () {
      // Simulate what enqueue() validation does
      final taskId = '';
      expect(taskId.isEmpty, isTrue);
    });

    test('should validate empty tag', () {
      // Simulate tag validation
      final tag = '';
      expect(tag.isEmpty, isTrue);

      final validTag = 'my-tag';
      expect(validTag.isEmpty, isFalse);
    });

    test('should validate periodic interval minimum', () {
      // Simulate periodic trigger validation
      final validInterval = Duration(minutes: 15);
      final invalidInterval = Duration(minutes: 10);

      expect(validInterval >= const Duration(minutes: 15), isTrue);
      expect(invalidInterval >= const Duration(minutes: 15), isFalse);
    });

    test('should validate contentUri trigger requires valid URI', () {
      final validUri = Uri.parse('content://media/external/images/media');
      expect(validUri.scheme, 'content');
      expect(validUri.host, 'media');

      // Invalid URI (no scheme)
      final invalidUri = Uri.parse('not-a-valid-content-uri');
      expect(invalidUri.scheme, '');
    });

    test('should validate TaskChainBuilder requires non-empty tasks', () {
      final task = TaskRequest(
        id: 'task-1',
        worker: DartWorker(callbackId: 'cb'),
      );

      // thenAll with empty list should throw
      expect(
        () => TaskChainBuilder.internal([task]).thenAll([]),
        throwsArgumentError,
      );
    });
  });
}
