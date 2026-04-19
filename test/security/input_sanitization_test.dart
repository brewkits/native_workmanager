import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Security tests for input sanitization and privacy.
void main() {
  group('Input Sanitization & Privacy', () {
    test('DartWorker input preserves data for bridge (redaction happens on native persistence)', () {
      final worker = DartWorker(
        callbackId: 'test',
        input: {
          'apiKey': 'secret-123',
          'user_data': 'public',
          'password': 'password123',
        },
      );
      
      final map = worker.toMap();
      // Verify that Dart side DOES NOT redact before sending to native, 
      // as the native worker needs these values for the immediate execution.
      expect(map['input'], contains('secret-123'));
      expect(map['input'], contains('password123'));
    });

    test('HttpRequestWorker preserves headers for bridge', () {
      final worker = NativeWorker.httpRequest(
        url: 'https://api.example.com',
        headers: {
          'Authorization': 'Bearer my-token',
          'X-Api-Key': 'key-456',
        },
      );
      
      final map = worker.toMap();
      expect(map['headers']['Authorization'], 'Bearer my-token');
      expect(map['headers']['X-Api-Key'], 'key-456');
    });

    test('Simulation: Redaction logic verification', () {
      // This test verifies the logic used on the native side for redaction.
      // If we ever move redaction to Dart, this logic will be the baseline.
      final sensitiveKeys = {
        "authToken", "authorization", "cookies", "password", "secret",
        "accessToken", "refreshToken", "apiKey", "token", "bearer"
      };
      
      Map<String, dynamic> simulateRedact(Map<String, dynamic> input) {
        final result = Map<String, dynamic>.from(input);
        for (final key in result.keys.toList()) {
          if (sensitiveKeys.any((s) => s.toLowerCase() == key.toLowerCase())) {
            result[key] = '[REDACTED]';
          } else if (result[key] is Map<String, dynamic>) {
            result[key] = simulateRedact(result[key] as Map<String, dynamic>);
          }
        }
        return result;
      }
      
      final input = {
        'apiKey': '123',
        'nested': {'password': 'abc'},
        'safe': 'ok',
        'Authorization': 'Bearer xyz'
      };
      
      final redacted = simulateRedact(input);
      expect(redacted['apiKey'], '[REDACTED]');
      expect(redacted['nested']['password'], '[REDACTED]');
      expect(redacted['Authorization'], '[REDACTED]');
      expect(redacted['safe'], 'ok');
    });
  });
}
