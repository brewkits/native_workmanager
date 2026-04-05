import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Middleware', () {
    test('HeaderMiddleware toMap', () {
      const middleware = HeaderMiddleware(
        headers: {'Authorization': 'Bearer test-token'},
        urlPattern: 'https://api.com/.*',
      );

      final map = middleware.toMap();
      expect(map['type'], 'header');
      expect(map['headers']['Authorization'], 'Bearer test-token');
      expect(map['urlPattern'], 'https://api.com/.*');
    });

    test('LoggingMiddleware toMap', () {
      const middleware = LoggingMiddleware(
        logUrl: 'https://logs.com',
        includeConfig: true,
      );

      final map = middleware.toMap();
      expect(map['type'], 'logging');
      expect(map['logUrl'], 'https://logs.com');
      expect(map['includeConfig'], true);
    });
  });
}
