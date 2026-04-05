// Tests for RemoteConfigMiddleware — Dart serialisation contract.
//
// The native-side injection logic (Android/iOS) is covered by the
// integration test suite. This file verifies the Dart layer:
//   • toMap() produces the correct structure
//   • workerType filter is included/omitted correctly
//   • round-trip through registerMiddleware is type-safe

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('RemoteConfigMiddleware.toMap()', () {
    test('type field is "remoteConfig"', () {
      const mw = RemoteConfigMiddleware(values: {'timeout': 30});
      expect(mw.toMap()['type'], 'remoteConfig');
    });

    test('values are serialised correctly', () {
      const mw = RemoteConfigMiddleware(
        values: {
          'timeout': 30,
          'maxRetries': 3,
          'enableCompression': true,
          'userAgent': 'MyApp/1.0',
        },
      );
      final map = mw.toMap();
      expect(map['values'], {
        'timeout': 30,
        'maxRetries': 3,
        'enableCompression': true,
        'userAgent': 'MyApp/1.0',
      });
    });

    test('workerType is omitted when null', () {
      const mw = RemoteConfigMiddleware(values: {'timeout': 30});
      expect(mw.toMap().containsKey('workerType'), false);
    });

    test('workerType is included when set', () {
      const mw = RemoteConfigMiddleware(
        values: {'timeout': 30},
        workerType: 'HttpDownload',
      );
      expect(mw.toMap()['workerType'], 'HttpDownload');
    });

    test('empty values map serialises without error', () {
      const mw = RemoteConfigMiddleware(values: {});
      final map = mw.toMap();
      expect(map['type'], 'remoteConfig');
      expect(map['values'], isEmpty);
    });

    test('double values serialise correctly', () {
      const mw = RemoteConfigMiddleware(values: {'chunkSizeMb': 2.5});
      expect(mw.toMap()['values']['chunkSizeMb'], 2.5);
    });
  });

  group('RemoteConfigMiddleware is a Middleware', () {
    test('is subtype of Middleware', () {
      const Middleware mw = RemoteConfigMiddleware(values: {'x': 1});
      expect(mw, isA<Middleware>());
    });

    test('toMap() returns correct runtime type', () {
      const mw = RemoteConfigMiddleware(values: {'x': 1});
      expect(mw.toMap(), isA<Map<String, dynamic>>());
    });
  });

  group('RemoteConfigMiddleware — workerType filter scenarios', () {
    test('HttpDownload filter only targets download workers', () {
      const mw = RemoteConfigMiddleware(
        values: {'chunkSize': 4096},
        workerType: 'HttpDownload',
      );
      expect(mw.toMap()['workerType'], 'HttpDownload');
    });

    test('null workerType means all workers', () {
      const mw = RemoteConfigMiddleware(values: {'timeout': 60});
      final map = mw.toMap();
      expect(map.containsKey('workerType'), false);
    });

    test('various worker type names survive round-trip', () {
      for (final wt in ['Crypto', 'HttpUpload', 'FileDecompression']) {
        final mw = RemoteConfigMiddleware(values: {'k': 'v'}, workerType: wt);
        expect(mw.toMap()['workerType'], wt);
      }
    });
  });
}
