import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/platform_interface.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeWorkManagerPlatform extends NativeWorkManagerPlatform with MockPlatformInterfaceMixin {
  Constraints? capturedConstraints;

  @override
  Future<void> initialize({
    int? callbackHandle,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
  }) async {}

  @override
  void setCallbackExecutor(Future<bool> Function(String callbackId, Map<String, dynamic>? input) executor) {}

  @override
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    required Constraints constraints,
    required ExistingTaskPolicy existingPolicy,
    String? tag,
  }) async {
    capturedConstraints = constraints;
    return ScheduleResult.accepted;
  }
}

// Top-level function for test callback validation
Future<bool> testCallback(Map<String, dynamic>? input) async => true;

void main() {
  group('iOS Heavy Task Promotion', () {
    late MockNativeWorkManagerPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockNativeWorkManagerPlatform();
      NativeWorkManagerPlatform.instance = mockPlatform;
      
      // Register a dummy worker for validation using a top-level function
      NativeWorkManager.initialize(
        dartWorkers: {'test-worker': testCallback},
      );
    });

    test('should promote DartWorker to isHeavyTask=true on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await NativeWorkManager.enqueue(
        taskId: 'ios-task',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'test-worker'),
        constraints: const Constraints(isHeavyTask: false), // Explicitly false
      );

      expect(mockPlatform.capturedConstraints?.isHeavyTask, isTrue, 
          reason: 'DartWorker must be promoted to heavy task on iOS');
      
      debugDefaultTargetPlatformOverride = null;
    });

    test('should NOT promote NativeWorker on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await NativeWorkManager.enqueue(
        taskId: 'ios-native-task',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpSync(url: 'https://test.com'),
        constraints: const Constraints(isHeavyTask: false),
      );

      expect(mockPlatform.capturedConstraints?.isHeavyTask, isFalse, 
          reason: 'NativeWorker should respect original isHeavyTask on iOS');
      
      debugDefaultTargetPlatformOverride = null;
    });

    test('should NOT promote DartWorker on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await NativeWorkManager.enqueue(
        taskId: 'android-task',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'test-worker'),
        constraints: const Constraints(isHeavyTask: false),
      );

      expect(mockPlatform.capturedConstraints?.isHeavyTask, isFalse, 
          reason: 'DartWorker should not be promoted on Android');
      
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
