import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  RemoteTriggerRule rule({bool? reject, String? secret}) => RemoteTriggerRule(
        payloadKey: 'type',
        workerMappings: const {},
        secretKey: secret,
        rejectUnsignedCommands: reject ?? false,
      );

  test('rejectUnsignedCommands defaults to false and is omitted from the map',
      () {
    expect(rule().rejectUnsignedCommands, isFalse);
    expect(rule().toMap().containsKey('rejectUnsignedCommands'), isFalse);
  });

  test('rejectUnsignedCommands: true is serialized for the platform channel',
      () {
    expect(rule(reject: true).toMap()['rejectUnsignedCommands'], isTrue);
  });

  // The toMap test above cannot catch a bridge that stops reading the key (issue #30 lesson).
  test('both native bridges read the same rejectUnsignedCommands key', () {
    String read(String path) {
      final f = File(path).existsSync() ? File(path) : File('../$path');
      return f.readAsStringSync();
    }

    expect(
        read('android/src/main/kotlin/dev/brewkits/native_workmanager/'
            'NativeWorkmanagerPlugin+RemoteTrigger.kt'),
        contains('ruleMap["rejectUnsignedCommands"]'));
    expect(
        read('ios/native_workmanager/Sources/native_workmanager/'
            'NativeWorkmanagerPlugin+RemoteTrigger.swift'),
        contains('ruleMap["rejectUnsignedCommands"]'));
  });
}
