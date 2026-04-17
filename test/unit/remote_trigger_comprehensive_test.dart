import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // RemoteTriggerSource
  // ──────────────────────────────────────────────────────────────
  group('RemoteTriggerSource', () {
    test('has fcm variant', () {
      expect(RemoteTriggerSource.fcm, isNotNull);
      expect(RemoteTriggerSource.fcm.name, 'fcm');
    });

    test('has apns variant', () {
      expect(RemoteTriggerSource.apns, isNotNull);
      expect(RemoteTriggerSource.apns.name, 'apns');
    });

    test('has exactly 2 values', () {
      expect(RemoteTriggerSource.values.length, 2);
    });

    test('values are distinct', () {
      expect(RemoteTriggerSource.fcm, isNot(RemoteTriggerSource.apns));
    });
  });

  // ──────────────────────────────────────────────────────────────
  // RemoteTriggerRule – construction
  // ──────────────────────────────────────────────────────────────
  group('RemoteTriggerRule – construction', () {
    test('stores payloadKey', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'action',
        workerMappings: {},
      );
      expect(rule.payloadKey, 'action');
    });

    test('stores workerMappings map', () {
      final worker = NativeWorker.httpRequest(url: 'https://api.com/sync');
      final rule = RemoteTriggerRule(
        payloadKey: 'type',
        workerMappings: {'sync': worker},
      );
      expect(rule.workerMappings['sync'], same(worker));
    });

    test('empty workerMappings is allowed', () {
      expect(
        () => RemoteTriggerRule(payloadKey: 'k', workerMappings: {}),
        returnsNormally,
      );
    });

    test('stores secretKey', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'action',
        workerMappings: {},
        secretKey: 'my_secret_key',
      );
      expect(rule.secretKey, 'my_secret_key');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // RemoteTriggerRule – toMap
  // ──────────────────────────────────────────────────────────────
  group('RemoteTriggerRule – toMap', () {
    test('toMap contains payloadKey', () {
      final map = RemoteTriggerRule(
        payloadKey: 'msg_type',
        workerMappings: {},
      ).toMap();
      expect(map['payloadKey'], 'msg_type');
    });

    test('toMap contains workerMappings', () {
      final map = RemoteTriggerRule(
        payloadKey: 'k',
        workerMappings: {},
      ).toMap();
      expect(map.containsKey('workerMappings'), isTrue);
    });

    test('toMap workerMappings entry contains workerClassName', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'action',
        workerMappings: {
          'download': NativeWorker.httpDownload(
            url: 'https://cdn.example.com/file.zip',
            savePath: '/tmp/file.zip',
          ),
        },
      );
      final mappings = rule.toMap()['workerMappings'] as Map;
      expect((mappings['download'] as Map)['workerClassName'],
          contains('HttpDownloadWorker'));
    });

    test('toMap workerMappings entry contains workerConfig', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'action',
        workerMappings: {
          'sync': NativeWorker.httpSync(url: 'https://api.com/sync'),
        },
      );
      final mappings = rule.toMap()['workerMappings'] as Map;
      final config = (mappings['sync'] as Map)['workerConfig'] as Map;
      expect(config['url'], 'https://api.com/sync');
    });

    test('multiple workerMappings are all serialized', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'type',
        workerMappings: {
          'sync': NativeWorker.httpRequest(url: 'https://api.com/sync'),
          'download': NativeWorker.httpDownload(
            url: 'https://cdn.com/file.zip',
            savePath: '/tmp/file.zip',
          ),
          'upload': NativeWorker.httpUpload(
            url: 'https://api.com/upload',
            filePath: '/tmp/log.txt',
          ),
        },
      );
      final mappings = rule.toMap()['workerMappings'] as Map;
      expect(mappings.keys.toSet(), {'sync', 'download', 'upload'});
    });

    test(
        'worker URL template uses real URL (placeholder substituted at runtime)',
        () {
      // URL validation requires http/https — templates are substituted on native side.
      // Test that the URL value round-trips as-is via toMap.
      final rule = RemoteTriggerRule(
        payloadKey: 'action',
        workerMappings: {
          'download_update': NativeWorker.httpDownload(
            url: 'https://cdn.example.com/update.zip',
            savePath: '/tmp/update.zip',
          ),
        },
      );
      final mappings = rule.toMap()['workerMappings'] as Map;
      final config =
          (mappings['download_update'] as Map)['workerConfig'] as Map;
      expect(config['url'], 'https://cdn.example.com/update.zip');
      expect(config['savePath'], '/tmp/update.zip');
    });

    test('payload key with dots is preserved', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'data.task.type',
        workerMappings: {},
      );
      expect(rule.toMap()['payloadKey'], 'data.task.type');
    });

    test('DartWorker in mapping serializes workerConfig correctly', () {
      final rule = RemoteTriggerRule(
        payloadKey: 'trigger',
        workerMappings: {
          'run_dart': DartWorker(
            callbackId: 'my_callback',
            input: {'key': 'val'},
          ),
        },
      );
      final mappings = rule.toMap()['workerMappings'] as Map;
      final cfg = (mappings['run_dart'] as Map)['workerConfig'] as Map;
      expect(cfg['callbackId'], 'my_callback');
    });
  });
}
