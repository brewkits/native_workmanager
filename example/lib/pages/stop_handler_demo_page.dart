import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

/// Issue #75 demo — the `onStopped` push hook for `DartWorker`.
///
/// The point of the side-by-side runs here is that **both callbacks are
/// identical except for one line**: `_stopDemoCooperative` polls
/// `isTaskCancelled()`, `_stopDemoStubborn` does not. Cancel either and the
/// stop handler fires for both — that is the part #75 adds. Only the
/// cooperative one actually *stops* on iOS, because a notification cannot
/// preempt a running `await`.
class StopHandlerDemoPage extends StatefulWidget {
  const StopHandlerDemoPage({super.key});

  @override
  State<StopHandlerDemoPage> createState() => _StopHandlerDemoPageState();
}

class _StopHandlerDemoPageState extends State<StopHandlerDemoPage> {
  final List<String> _log = [];
  Timer? _poll;
  String? _activeTaskId;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _addLog(String line) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, line);
      if (_log.length > 40) _log.removeLast();
    });
  }

  Future<File> _counterFile() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/stop_demo_counter.txt');
  }

  Future<File> _markerFile() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/stop_demo_stopped.txt');
  }

  Future<void> _run({required bool cooperative, Duration? cancelGrace}) async {
    _poll?.cancel();
    final counter = await _counterFile();
    final marker = await _markerFile();
    for (final f in [counter, marker]) {
      if (f.existsSync()) f.deleteSync();
    }

    final taskId = 'stop-demo-${DateTime.now().millisecondsSinceEpoch}';
    _activeTaskId = taskId;
    setState(_log.clear);
    _addLog('▶️  enqueued $taskId');
    _addLog(cooperative
        ? 'callback POLLS isTaskCancelled()'
        : 'callback does NOT poll — only the handler will fire');
    _addLog('cancelGrace: ${cancelGrace ?? "null (notify only)"}');

    await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: const TaskTrigger.oneTime(),
      worker: DartWorker(
        callbackId: cooperative ? 'stop_demo_cooperative' : 'stop_demo_stubborn',
        onStoppedId: 'stop_demo_on_stopped',
        cancelGrace: cancelGrace,
        input: {'counterFile': counter.path, 'markerFile': marker.path},
      ),
    );

    // Mirror the worker's progress into the log so the effect of cancelling is
    // visible without digging through logcat / the Xcode console.
    _poll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (!mounted) return;
      final count =
          counter.existsSync() ? counter.readAsStringSync().trim() : '–';
      final stopped = marker.existsSync()
          ? 'handler fired for ${marker.readAsStringSync().trim()}'
          : 'handler not fired';
      _addLog('iteration $count · $stopped');
    });
  }

  Future<void> _cancel() async {
    final id = _activeTaskId;
    if (id == null) return;
    _addLog('⛔ cancel($id)');
    await NativeWorkManager.cancel(taskId: id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Card(
          color: scheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Issue #75 — onStopped hook',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text(
                  'Start a run, then hit Cancel. The stop handler fires either '
                  'way — that is the hook. Whether the callback actually STOPS '
                  'depends on it cooperating (or, on Android, on cancelGrace '
                  'tearing the engine down).\n\n'
                  'cancelGrace teardown is Android-only; on iOS the callback '
                  'keeps running unless it polls isTaskCancelled() itself.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () => _run(cooperative: true),
              child: const Text('Run: polls, notify-only'),
            ),
            FilledButton.tonal(
              onPressed: () => _run(cooperative: false),
              child: const Text('Run: never polls, notify-only'),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  _run(cooperative: false, cancelGrace: Duration.zero),
              child: const Text('Run: never polls, grace 0 (teardown)'),
            ),
            FilledButton(
              onPressed: _cancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._log.map(
          (l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(l, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
      ],
    );
  }
}

// ── Worker callbacks ─────────────────────────────────────────────────────────

/// Polls `isTaskCancelled()` between chunks, so it stops on every platform.
@pragma('vm:entry-point')
Future<bool> stopDemoCooperative(Map<String, dynamic>? input) async {
  final taskId = input?['__taskId'] as String?;
  final counterFile = input?['counterFile'] as String?;
  for (var i = 1; i <= 60; i++) {
    if (counterFile != null) File(counterFile).writeAsStringSync('$i');
    if (taskId != null && await NativeWorkManager.isTaskCancelled(taskId)) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return true;
}

/// Deliberately never polls — shows that the handler still fires, and that
/// stopping the work itself needs either cooperation or (Android) a teardown.
@pragma('vm:entry-point')
Future<bool> stopDemoStubborn(Map<String, dynamic>? input) async {
  final counterFile = input?['counterFile'] as String?;
  for (var i = 1; i <= 60; i++) {
    if (counterFile != null) File(counterFile).writeAsStringSync('$i');
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return true;
}

/// The stop handler itself. Runs while the task is being torn down, so it must
/// return promptly — persist state, close handles, nothing more.
@pragma('vm:entry-point')
Future<void> stopDemoOnStopped(Map<String, dynamic>? input) async {
  final markerFile = input?['markerFile'] as String?;
  final taskId = input?['__taskId'] as String? ?? '<none>';
  if (markerFile != null) File(markerFile).writeAsStringSync(taskId);
}
