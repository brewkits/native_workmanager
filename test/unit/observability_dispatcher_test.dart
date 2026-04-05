import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// Helper factory for TaskEvent
TaskEvent _event({
  required String taskId,
  required bool success,
  bool isStarted = false,
  String? message,
  String? workerType,
  Map<String, dynamic>? resultData,
}) =>
    TaskEvent(
      taskId: taskId,
      success: success,
      isStarted: isStarted,
      message: message,
      workerType: workerType,
      resultData: resultData,
      timestamp: DateTime(2026, 4, 1, 12, 0),
    );

TaskProgress _progress(String taskId, {int bytes = 100, int total = 1000}) =>
    TaskProgress(
      taskId: taskId,
      progress: (bytes * 100 ~/ total).clamp(0, 100),
      bytesDownloaded: bytes,
      totalBytes: total,
    );

void main() {
  // ──────────────────────────────────────────────────────────────
  // ObservabilityConfig construction
  // ──────────────────────────────────────────────────────────────
  group('ObservabilityConfig', () {
    test('all callbacks default to null', () {
      const cfg = ObservabilityConfig();
      expect(cfg.onTaskStart, isNull);
      expect(cfg.onTaskComplete, isNull);
      expect(cfg.onTaskFail, isNull);
      expect(cfg.onProgress, isNull);
    });

    test('stores onTaskStart callback', () {
      void startCb(String id, String type) {}
      final cfg = ObservabilityConfig(onTaskStart: startCb);
      expect(cfg.onTaskStart, same(startCb));
    });

    test('stores onTaskComplete callback', () {
      void completeCb(TaskEvent e) {}
      final cfg = ObservabilityConfig(onTaskComplete: completeCb);
      expect(cfg.onTaskComplete, same(completeCb));
    });

    test('stores onTaskFail callback', () {
      void failCb(TaskEvent e) {}
      final cfg = ObservabilityConfig(onTaskFail: failCb);
      expect(cfg.onTaskFail, same(failCb));
    });

    test('stores onProgress callback', () {
      void progressCb(TaskProgress p) {}
      final cfg = ObservabilityConfig(onProgress: progressCb);
      expect(cfg.onProgress, same(progressCb));
    });
  });

  // ──────────────────────────────────────────────────────────────
  // ObservabilityDispatcher – event routing
  // ──────────────────────────────────────────────────────────────
  group('ObservabilityDispatcher – event routing', () {
    test('isStarted event triggers onTaskStart with correct taskId', () {
      String? receivedId;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskStart: (id, type) => receivedId = id),
      );
      dispatcher.dispatchEvent(_event(taskId: 'task-1', success: false, isStarted: true));
      expect(receivedId, 'task-1');
    });

    test('isStarted event triggers onTaskStart with workerType', () {
      String? receivedType;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(
            onTaskStart: (id, type) => receivedType = type),
      );
      dispatcher.dispatchEvent(
        _event(taskId: 't', success: false, isStarted: true, workerType: 'HttpDownloadWorker'),
      );
      expect(receivedType, 'HttpDownloadWorker');
    });

    test('isStarted event with null workerType passes empty string to onTaskStart', () {
      String? receivedType;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskStart: (id, type) => receivedType = type),
      );
      dispatcher.dispatchEvent(
        _event(taskId: 't', success: false, isStarted: true, workerType: null),
      );
      expect(receivedType, '');
    });

    test('isStarted event does NOT trigger onTaskComplete', () {
      var called = false;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskComplete: (_) => called = true),
      );
      dispatcher.dispatchEvent(_event(taskId: 't', success: true, isStarted: true));
      expect(called, isFalse);
    });

    test('isStarted event does NOT trigger onTaskFail', () {
      var called = false;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskFail: (_) => called = true),
      );
      dispatcher.dispatchEvent(_event(taskId: 't', success: false, isStarted: true));
      expect(called, isFalse);
    });

    test('success completion event triggers onTaskComplete', () {
      TaskEvent? received;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskComplete: (e) => received = e),
      );
      final ev = _event(taskId: 'done', success: true);
      dispatcher.dispatchEvent(ev);
      expect(received, ev);
    });

    test('failure event triggers onTaskFail', () {
      TaskEvent? received;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskFail: (e) => received = e),
      );
      final ev = _event(taskId: 'fail', success: false, message: 'oops');
      dispatcher.dispatchEvent(ev);
      expect(received, ev);
    });

    test('success event does NOT trigger onTaskFail', () {
      var called = false;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskFail: (_) => called = true),
      );
      dispatcher.dispatchEvent(_event(taskId: 't', success: true));
      expect(called, isFalse);
    });

    test('failure event does NOT trigger onTaskComplete', () {
      var called = false;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskComplete: (_) => called = true),
      );
      dispatcher.dispatchEvent(_event(taskId: 't', success: false));
      expect(called, isFalse);
    });

    test('null onTaskStart callback does not throw for isStarted event', () {
      final dispatcher = ObservabilityDispatcher(const ObservabilityConfig());
      expect(
        () => dispatcher.dispatchEvent(
          _event(taskId: 't', success: false, isStarted: true),
        ),
        returnsNormally,
      );
    });

    test('null onTaskComplete callback does not throw for success event', () {
      final dispatcher = ObservabilityDispatcher(const ObservabilityConfig());
      expect(
        () => dispatcher.dispatchEvent(_event(taskId: 't', success: true)),
        returnsNormally,
      );
    });

    test('null onTaskFail callback does not throw for failure event', () {
      final dispatcher = ObservabilityDispatcher(const ObservabilityConfig());
      expect(
        () => dispatcher.dispatchEvent(_event(taskId: 't', success: false)),
        returnsNormally,
      );
    });

    test('exception in onTaskStart is swallowed', () {
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskStart: (id, type) => throw Exception('boom')),
      );
      expect(
        () => dispatcher.dispatchEvent(
          _event(taskId: 't', success: false, isStarted: true),
        ),
        returnsNormally,
      );
    });

    test('exception in onTaskComplete is swallowed', () {
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskComplete: (_) => throw Exception('boom')),
      );
      expect(
        () => dispatcher.dispatchEvent(_event(taskId: 't', success: true)),
        returnsNormally,
      );
    });

    test('exception in onTaskFail is swallowed', () {
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onTaskFail: (_) => throw Exception('boom')),
      );
      expect(
        () => dispatcher.dispatchEvent(_event(taskId: 't', success: false)),
        returnsNormally,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // ObservabilityDispatcher – progress routing
  // ──────────────────────────────────────────────────────────────
  group('ObservabilityDispatcher – progress routing', () {
    test('progress update triggers onProgress', () {
      TaskProgress? received;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onProgress: (p) => received = p),
      );
      final p = _progress('t1');
      dispatcher.dispatchProgress(p);
      expect(received, p);
    });

    test('progress taskId is forwarded correctly', () {
      String? receivedId;
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onProgress: (p) => receivedId = p.taskId),
      );
      dispatcher.dispatchProgress(_progress('my-task-id'));
      expect(receivedId, 'my-task-id');
    });

    test('null onProgress does not throw', () {
      final dispatcher = ObservabilityDispatcher(const ObservabilityConfig());
      expect(
        () => dispatcher.dispatchProgress(_progress('t')),
        returnsNormally,
      );
    });

    test('exception in onProgress is swallowed', () {
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onProgress: (_) => throw Exception('boom')),
      );
      expect(
        () => dispatcher.dispatchProgress(_progress('t')),
        returnsNormally,
      );
    });

    test('multiple progress events all reach onProgress', () {
      final received = <String>[];
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(onProgress: (p) => received.add(p.taskId)),
      );
      dispatcher.dispatchProgress(_progress('a'));
      dispatcher.dispatchProgress(_progress('b'));
      dispatcher.dispatchProgress(_progress('c'));
      expect(received, ['a', 'b', 'c']);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // ObservabilityDispatcher – multiple callbacks in sequence
  // ──────────────────────────────────────────────────────────────
  group('ObservabilityDispatcher – multiple events', () {
    test('start then complete both fire', () {
      final log = <String>[];
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(
          onTaskStart: (id, _) => log.add('start:$id'),
          onTaskComplete: (e) => log.add('complete:${e.taskId}'),
        ),
      );
      dispatcher.dispatchEvent(
          _event(taskId: 'job1', success: true, isStarted: true));
      dispatcher.dispatchEvent(_event(taskId: 'job1', success: true));
      expect(log, ['start:job1', 'complete:job1']);
    });

    test('start then fail both fire', () {
      final log = <String>[];
      final dispatcher = ObservabilityDispatcher(
        ObservabilityConfig(
          onTaskStart: (id, _) => log.add('start'),
          onTaskFail: (e) => log.add('fail'),
        ),
      );
      dispatcher.dispatchEvent(
          _event(taskId: 't', success: false, isStarted: true));
      dispatcher.dispatchEvent(_event(taskId: 't', success: false));
      expect(log, ['start', 'fail']);
    });
  });
}
