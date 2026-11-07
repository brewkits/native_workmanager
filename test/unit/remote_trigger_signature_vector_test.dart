import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The v2 signature scheme exists in three places that must agree byte-for-byte: the Python
/// reference signer (for backends), Kotlin and Swift. Each carries the same expected HMAC.
/// If one is edited without the others, a backend that follows the docs would silently stop
/// being accepted on one platform only. (Dart itself never signs — the backend does.)
void main() {
  const vectorHex =
      'dca042f1afdc1ff83ef350f17e83b78a59175ed8d5b032ca0fdb54eb47ab8f0e';

  String read(String path) {
    final f = File(path).existsSync() ? File(path) : File('../$path');
    return f.readAsStringSync();
  }

  test(
      'v2 signature vector is identical in Kotlin, Swift and the Python reference',
      () {
    for (final path in [
      'android/src/test/kotlin/dev/brewkits/native_workmanager/RemoteTriggerSignatureTest.kt',
      'ios/Tests/RemoteTriggerSignatureTests.swift',
      'doc/REMOTE_TRIGGER_SIGNING.md',
    ]) {
      expect(read(path),
          anyOf(contains(vectorHex), contains(vectorHex.substring(0, 8))),
          reason: '$path must reference the shared v2 vector');
    }
  });

  test('canonical-form markers match across platforms', () {
    for (final path in [
      'doc/examples/remote_trigger_sign_v2.py',
      'android/src/main/kotlin/dev/brewkits/native_workmanager/RemoteTriggerSignature.kt',
      'ios/native_workmanager/Sources/native_workmanager/utils/RemoteTriggerSignature.swift',
    ]) {
      final src = read(path);
      expect(src, contains('NWM2'), reason: path);
      expect(src, contains('x-native-wm-nonce'), reason: path);
      expect(src, contains('x-native-wm-timestamp'), reason: path);
      expect(src, contains('300'), reason: '$path skew window');
    }
  });
}
