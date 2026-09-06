import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Regression tests for `getTasksByStatus` and the two APIs built on it.
///
/// The bug: `getTasksByStatus` invoked a `getTasksByStatus` method-channel
/// method that **neither Android nor iOS implemented**, so it threw
/// `MissingPluginException` on every call — and took `pauseAll()` and
/// `resumeAll()` down with it, since both route through it. Three public APIs,
/// broken on both platforms, caught only by an iOS integration test that had
/// been red on `main` since before v1.5.0 shipped.
///
/// These tests answer the channel with an `allTasks` payload and nothing else.
/// If the implementation ever goes back to invoking a dedicated
/// `getTasksByStatus` method, the mock returns null for it and the filtering
/// assertions below fail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.brewkits/native_workmanager');

  Map<String, Object?> record(String taskId, String status) => {
        'taskId': taskId,
        'status': status,
        'workerClassName': 'HttpRequestWorker',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  late List<String> invoked;

  void installHandler(List<Map<String, Object?>> tasks) {
    invoked = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      invoked.add(call.method);
      switch (call.method) {
        case 'initialize':
          return null;
        case 'allTasks':
          return tasks;
        case 'pause':
        case 'resume':
          return null;
        default:
          // Deliberately unimplemented — mirrors the real platforms, which
          // answer nothing for a method they never registered.
          return null;
      }
    });
  }

  setUp(() => installHandler([
        record('a', 'running'),
        record('b', 'paused'),
        record('c', 'running'),
        record('d', 'completed'),
      ]));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('getTasksByStatus', () {
    test('returns only the records matching the requested status', () async {
      await NativeWorkManager.initialize();

      final running =
          await NativeWorkManager.getTasksByStatus(TaskStatus.running);

      expect(running.map((r) => r.taskId), containsAll(<String>['a', 'c']));
      expect(running.length, equals(2));
    });

    test('does not call a dedicated getTasksByStatus channel method', () async {
      // The whole bug: that method exists on neither platform. Sourcing the
      // data from allTasks() is what keeps this working on both.
      await NativeWorkManager.initialize();
      await NativeWorkManager.getTasksByStatus(TaskStatus.running);

      expect(invoked, contains('allTasks'));
      expect(
        invoked,
        isNot(contains('getTasksByStatus')),
        reason: 'no platform implements a getTasksByStatus handler — invoking '
            'one throws MissingPluginException',
      );
    });

    test('an unmatched status yields an empty list, not an error', () async {
      await NativeWorkManager.initialize();

      expect(
        await NativeWorkManager.getTasksByStatus(TaskStatus.cancelled),
        isEmpty,
      );
    });

    test('no tasks at all yields an empty list', () async {
      installHandler([]);
      await NativeWorkManager.initialize();

      expect(
        await NativeWorkManager.getTasksByStatus(TaskStatus.running),
        isEmpty,
      );
    });
  });

  group('pauseAll / resumeAll', () {
    test('pauseAll completes and pauses exactly the running tasks', () async {
      await NativeWorkManager.initialize();

      await expectLater(NativeWorkManager.pauseAll(), completes);

      // Two running tasks in the fixture — 'a' and 'c'.
      expect(invoked.where((m) => m == 'pause').length, equals(2));
    });

    test('resumeAll completes and resumes exactly the paused tasks', () async {
      await NativeWorkManager.initialize();

      await expectLater(NativeWorkManager.resumeAll(), completes);

      // One paused task in the fixture — 'b'.
      expect(invoked.where((m) => m == 'resume').length, equals(1));
    });

    test('both complete when there are no tasks', () async {
      installHandler([]);
      await NativeWorkManager.initialize();

      await expectLater(NativeWorkManager.pauseAll(), completes);
      await expectLater(NativeWorkManager.resumeAll(), completes);
    });
  });
}
