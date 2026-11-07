import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  test(
      'issue_84: non-positive concurrency fails before platform initialization',
      () async {
    for (final value in [0, -1]) {
      await expectLater(
        NativeWorkManager.initialize(maxConcurrentTasks: value),
        throwsRangeError,
      );
    }
  });

  // Key-name parity: Dart sends 'maxConcurrentTasks' and BOTH native bridges must read
  // exactly that key. A renamed/misspelled key would silently fall back to the default 4
  // while every Dart-side test (mocked channel) stays green.
  test(
      'issue_84: Dart sends and both platforms read the same maxConcurrentTasks key',
      () {
    String read(String path) {
      final f = File(path).existsSync() ? File(path) : File('../$path');
      return f.readAsStringSync();
    }

    expect(
        read('lib/src/method_channel.dart'), contains("'maxConcurrentTasks':"));
    expect(
        read('android/src/main/kotlin/dev/brewkits/native_workmanager/'
            'NativeWorkmanagerPlugin+Initialize.kt'),
        contains('argument<Int>("maxConcurrentTasks")'));
    expect(
        read('ios/native_workmanager/Sources/native_workmanager/'
            'NativeWorkmanagerPlugin.swift'),
        contains('["maxConcurrentTasks"]'));
  });
}
