import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteTrigger', () {
    test('RemoteTriggerRule toMap', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'action',
        workerMappings: {
          'sync': NativeWorker.httpSync(url: 'https://api.com/{{id}}'),
        },
      );

      final map = rule.toMap();
      expect(map['payloadKey'], 'action');
      expect(map['workerMappings']['sync']['workerClassName'],
          contains('HttpSyncWorker'));
      expect(map['workerMappings']['sync']['workerConfig']['url'],
          'https://api.com/{{id}}');
    });

    test('RemoteTriggerSource enum values', () {
      expect(RemoteTriggerSource.fcm.name, 'fcm');
      expect(RemoteTriggerSource.apns.name, 'apns');
    });
  });
}
