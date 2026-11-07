import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  test('issue_84: non-positive concurrency fails before platform initialization',
      () async {
    for (final value in [0, -1]) {
      await expectLater(
        NativeWorkManager.initialize(maxConcurrentTasks: value),
        throwsRangeError,
      );
    }
  });
}
