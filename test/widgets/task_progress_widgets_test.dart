import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/platform_interface.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'dart:async';

class FakeNativeWorkManagerPlatform extends MethodChannelNativeWorkManager {
  final progressController = StreamController<TaskProgress>.broadcast();

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
  }) async {
    // No-op to avoid MissingPluginException in unit tests
  }

  @override
  void reportTestProgress(TaskProgress progress) {
    progressController.add(progress);
  }

  Future<void> dispose() async {
    await progressController.close();
  }
}

void main() {
  group('TaskProgressBuilder', () {
    late StreamController<TaskProgress> controller;
    late TaskHandler handler;
    late FakeNativeWorkManagerPlatform fakePlatform;

    setUp(() async {
      fakePlatform = FakeNativeWorkManagerPlatform();
      NativeWorkManagerPlatform.instance = fakePlatform;
      NativeWorkManager.resetInitializedState();
      await NativeWorkManager.initialize();

      controller = fakePlatform.progressController;

      handler = const TaskHandler(
        taskId: 'test-task',
        scheduleResult: ScheduleResult.accepted,
      );
    });

    tearDown(() async {
      await fakePlatform.dispose();
    });

    testWidgets('builds with initial progress', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskProgressBuilder(
              handler: handler,
              initialProgress:
                  const TaskProgress(taskId: 'test-task', progress: 10),
              builder: (context, progress) {
                return Text('Progress: ${progress?.progress}%');
              },
            ),
          ),
        ),
      );

      expect(find.text('Progress: 10%'), findsOneWidget);
    });

    testWidgets('updates when stream emits', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskProgressBuilder(
              handler: handler,
              builder: (context, progress) {
                return Text('Progress: ${progress?.progress ?? 0}%');
              },
            ),
          ),
        ),
      );

      expect(find.text('Progress: 0%'), findsOneWidget);

      controller.add(const TaskProgress(taskId: 'test-task', progress: 50));
      await tester.pump(); // Handle stream emission
      await tester.pump(); // Handle build

      expect(find.text('Progress: 50%'), findsOneWidget);
    });
  });

  group('TaskProgressCard', () {
    late StreamController<TaskProgress> controller;
    late TaskHandler handler;
    late FakeNativeWorkManagerPlatform fakePlatform;

    setUp(() async {
      fakePlatform = FakeNativeWorkManagerPlatform();
      NativeWorkManagerPlatform.instance = fakePlatform;
      NativeWorkManager.resetInitializedState();
      await NativeWorkManager.initialize();

      controller = fakePlatform.progressController;

      handler = const TaskHandler(
        taskId: 'test-task',
        scheduleResult: ScheduleResult.accepted,
      );
    });

    tearDown(() async {
      await fakePlatform.dispose();
    });

    testWidgets('displays title and percentage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskProgressCard(
              handler: handler,
              title: 'My Task',
            ),
          ),
        ),
      );

      expect(find.text('My Task'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      controller.add(const TaskProgress(taskId: 'test-task', progress: 75));
      await tester.pump();
      await tester.pump();

      expect(find.text('75%'), findsOneWidget);

      // Verify progress bar
      final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicator.value, 0.75);
    });

    testWidgets('displays metrics when available', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskProgressCard(
              handler: handler,
            ),
          ),
        ),
      );

      controller.add(const TaskProgress(
        taskId: 'test-task',
        progress: 50,
        networkSpeed: 1024 * 1024, // 1 MB/s
        timeRemaining: Duration(seconds: 60), // 1 min
        message: 'Downloading...',
        currentStep: 1,
        totalSteps: 2,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Downloading...'), findsOneWidget);
      expect(find.text('1.0 MB/s'), findsOneWidget);
      expect(find.text('1m 0s'), findsOneWidget);
      expect(find.text('Step 1/2'), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    });

    testWidgets('respects showMetrics and showMessage flags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskProgressCard(
              handler: handler,
              showMetrics: false,
              showMessage: false,
            ),
          ),
        ),
      );

      controller.add(const TaskProgress(
        taskId: 'test-task',
        progress: 50,
        networkSpeed: 1024,
        message: 'Secret message',
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Secret message'), findsNothing);
      expect(find.text('1.0 KB/s'), findsNothing);
    });

    testWidgets('displays icon if provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskProgressCard(
              handler: handler,
              icon: const Icon(Icons.download),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download), findsOneWidget);
    });
  });
}
