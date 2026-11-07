// Issue #84 – phase 1 of the cold-start check (see scripts/issue84-cold-start.sh).
//
// This only ENQUEUES. It deliberately never cancels: the script then kills the app
// process and lets the OS start it again without an Activity / Dart initialize(), so
// the limit that applies is the persisted one, not one re-sent by this test.
//
//   flutter test integration_test/issue_84_cold_start_test.dart -d <id> \
//     --dart-define=ISSUE84_LIMIT=1
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

const _limit = int.fromEnvironment('ISSUE84_LIMIT', defaultValue: 1);
const _count = 8;
const _delaySeconds = int.fromEnvironment('ISSUE84_DELAY_S', defaultValue: 45);

@pragma('vm:entry-point')
Future<bool> _coldProbe(Map<String, dynamic>? input) async {
  final start = DateTime.now().millisecondsSinceEpoch;
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  File(input!['path'] as String).writeAsStringSync(jsonEncode({
    'start': start,
    'end': DateTime.now().millisecondsSinceEpoch,
  }));
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('issue_84: enqueue delayed probes for cold-start check',
      (tester) async {
    // Must differ from the default (4) so a lost/ignored persisted value is observable.
    expect(_limit, isNot(4));
    final dir = Directory('${Directory.systemTemp.path}/issue84_cold');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    await NativeWorkManager.initialize(
      maxConcurrentTasks: _limit,
      dartWorkers: {'issue84_cold_probe': _coldProbe},
    );
    for (var i = 0; i < _count; i++) {
      final res = await NativeWorkManager.enqueue(
        taskId: 'i84cold_$i',
        trigger: TaskTrigger.oneTime(const Duration(seconds: _delaySeconds)),
        worker: DartWorker(
          callbackId: 'issue84_cold_probe',
          input: {'path': '${dir.path}/i84cold_$i.json'},
        ),
      );
      expect(res.scheduleResult, ScheduleResult.accepted);
    }
    // Let WorkManager commit the last enqueue before the harness force-stops the app.
    await Future<void>.delayed(const Duration(seconds: 3));
    print('issue_84_cold: enqueued=$_count limit=$_limit dir=${dir.path}');
  });
}
