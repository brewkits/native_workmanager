import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Feature Verification', () {
    testWidgets('registerRemoteTrigger with secretKey', (tester) async {
      await NativeWorkManager.initialize();

      // Verification: Should not crash and should complete
      await expectLater(
        NativeWorkManager.registerRemoteTrigger(
          source: RemoteTriggerSource.fcm,
          rule: RemoteTriggerRule(
            payloadKey: 'action',
            workerMappings: {
              'sync': NativeWorker.httpRequest(url: 'https://api.com/sync'),
            },
            secretKey: 'top_secret_hmac_key',
          ),
        ),
        completes,
      );
    });

    testWidgets('registerMiddleware - HeaderMiddleware', (tester) async {
      await NativeWorkManager.initialize();

      await expectLater(
        NativeWorkManager.registerMiddleware(
          HeaderMiddleware(
            headers: {'Authorization': 'Bearer token123'},
            urlPattern: '.*',
          ),
        ),
        completes,
      );
    });

    testWidgets('registerMiddleware - LoggingMiddleware', (tester) async {
      await NativeWorkManager.initialize();

      await expectLater(
        NativeWorkManager.registerMiddleware(
          LoggingMiddleware(logUrl: 'https://logs.example.com/ingest'),
        ),
        completes,
      );
    });
  });
}
