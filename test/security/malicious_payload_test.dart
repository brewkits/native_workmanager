import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Malicious Payload Protection', () {
    test('Should handle extremely large input payloads (DoS protection)', () async {
      // 1MB of data in worker config
      final largeData = 'A' * (1024 * 1024);
      
      final worker = NativeWorker.httpRequest(
        url: 'https://example.com',
        body: largeData,
      );

      // This should either be rejected by the library or handled safely
      // In Dart, it's just a string, but the native bridge might have limits.
      // Here we just ensure it doesn't crash the Dart side.
      final map = worker.toMap();
      expect(map['body'], equals(largeData));
    });

    test('Should handle null bytes in strings (Injection protection)', () async {
      const maliciousUrl = 'https://example.com/\u0000/attack';
      
      // The library should ideally sanitize or reject this
      expect(
        () => NativeWorker.httpRequest(url: maliciousUrl),
        throwsArgumentError,
        reason: 'URLs with null bytes should be rejected',
      );
    });

    test('Should handle shell injection characters in file paths', () async {
      const maliciousPath = '/data/user/0/app/files/; rm -rf /';
      
      expect(
        () => NativeWorker.fileDelete(path: maliciousPath),
        throwsArgumentError,
        reason: 'Paths with semicolon should be rejected',
      );
    });
  });
}
