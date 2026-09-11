// ignore_for_file: avoid_print
// ============================================================
// Issue #66 / #69 — Firebase Test Lab regression check
// ============================================================
//
// Deliberately separate from device_integration_test.dart: that file's full
// suite is long-running and known to hang certain CI/emulator setups on
// periodic-trigger tests (see CLAUDE.md / project memory). This file exists
// so the two cancellation-cooperation regressions from
// https://github.com/brewkits/native_workmanager/discussions/66 and
// https://github.com/brewkits/native_workmanager/issues/69 can be re-verified
// quickly and cheaply across a real device matrix on Firebase Test Lab,
// independent of the rest of the suite.
//
// Run locally the same way any integration_test file runs:
//   flutter test integration_test/issue_66_69_ftl_test.dart
//
// For Firebase Test Lab, this file is built as the app's entrypoint via
// `flutter build apk --target=integration_test/issue_66_69_ftl_test.dart`
// (Android) and the equivalent `-target` for iOS's XCTest bridge, then run
// as an instrumentation/XCTest against a real device matrix.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

String _id(String name) =>
    'ftl_${name}_${DateTime.now().millisecondsSinceEpoch}';

/// Issue #66: polls [NativeWorkManager.isTaskCancelled] between chunks of
/// "work" and writes its iteration count to [input]'s `counterFile`, so the
/// test can prove it bailed out early instead of running to completion (50
/// iterations x 200ms = 10s if never cancelled).
@pragma('vm:entry-point')
Future<bool> _ftlCancelPoll(Map<String, dynamic>? input) async {
  final taskId = input?['__taskId'] as String?;
  final counterFile = input?['counterFile'] as String?;
  for (var i = 1; i <= 50; i++) {
    if (counterFile != null) {
      File(counterFile).writeAsStringSync('$i');
    }
    if (taskId != null && await NativeWorkManager.isTaskCancelled(taskId)) {
      print('[FTL] cancel_poll: observed cancellation at iteration $i');
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  print('[FTL] cancel_poll: completed all iterations uncancelled');
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = Directory(
      '${Directory.systemTemp.path}/nwm_ftl_${DateTime.now().millisecondsSinceEpoch}',
    )..createSync();

    await NativeWorkManager.initialize(
      dartWorkers: {'ftl_cancel_poll': _ftlCancelPoll},
    );
    await NativeWorkManager.cancelAll();
  });

  tearDownAll(() async {
    await NativeWorkManager.cancelAll();
    tmpDir.deleteSync(recursive: true);
  });

  group('Issue #66/#69 — Firebase Test Lab regression check', () {
    testWidgets(
      'issue_66: cancelling a running DartWorker task is observable via isTaskCancelled',
      (tester) async {
        // See example/integration_test/device_integration_test.dart for the
        // full-detail version of this test and the history of the bug: the
        // registry backing isTaskCancelled() was cleared the instant it was
        // marked, so this passed against a mocked channel while being a
        // complete no-op on real hardware. Re-verifying on real devices is
        // exactly the point of this file.
        final id = _id('cancel_poll');
        final counterFile = File('${tmpDir.path}/issue_66_counter.txt');

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: DartWorker(
            callbackId: 'ftl_cancel_poll',
            input: {'counterFile': counterFile.path},
          ),
        );

        await Future.delayed(const Duration(milliseconds: 600));
        await NativeWorkManager.cancel(taskId: id);

        await Future.delayed(const Duration(seconds: 2));

        expect(
          counterFile.existsSync(),
          isTrue,
          reason:
              'issue_66: the callback must have started and written at '
              'least one iteration before being cancelled',
        );
        final iterationsAtCancel = int.parse(
          counterFile.readAsStringSync().trim(),
        );
        expect(
          iterationsAtCancel,
          lessThan(20),
          reason:
              'issue_66: cancelling ~600ms in must stop the callback '
              'well short of all 50 iterations — a count this high means '
              'isTaskCancelled() never observed the cancellation',
        );

        final iterationsAfterWait = int.parse(
          counterFile.readAsStringSync().trim(),
        );
        await Future.delayed(const Duration(seconds: 2));
        final iterationsStillAfterWait = int.parse(
          counterFile.readAsStringSync().trim(),
        );
        expect(
          iterationsStillAfterWait,
          equals(iterationsAfterWait),
          reason:
              'issue_66: iteration count must not still be climbing '
              '2s later — the callback should have returned, not kept '
              'working',
        );
      },
    );

    testWidgets(
      'issue_69: cancelling a background-session download actually aborts the transfer (iOS)',
      (tester) async {
        if (!Platform.isIOS) {
          markTestSkipped(
            'useBackgroundSession is iOS-only on ${Platform.operatingSystem}',
          );
          return;
        }

        final id = _id('bg_download_cancel');
        final savePath = '${tmpDir.path}/issue_69_bg_download.bin';

        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpDownloadWorker(
            url: 'https://httpbin.org/delay/6',
            savePath: savePath,
            useBackgroundSession: true,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );

        await Future.delayed(const Duration(seconds: 1));
        await NativeWorkManager.cancel(taskId: id);

        await Future.delayed(const Duration(seconds: 8));

        expect(
          File(savePath).existsSync(),
          isFalse,
          reason:
              'issue_69: a cancelled background-session download must '
              'not still write its destination file',
        );
      },
    );
  });
}
