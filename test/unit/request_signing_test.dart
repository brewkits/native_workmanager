import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  const minKey = 'a1b2c3d4e5f6g7h8'; // exactly 16 chars

  // ──────────────────────────────────────────────────────────────
  // Construction & defaults
  // ──────────────────────────────────────────────────────────────
  group('RequestSigning – construction', () {
    test('stores secretKey', () {
      final rs = RequestSigning(secretKey: minKey);
      expect(rs.secretKey, minKey);
    });

    test('default headerName is X-Signature', () {
      final rs = RequestSigning(secretKey: minKey);
      expect(rs.headerName, 'X-Signature');
    });

    test('default signaturePrefix is empty string', () {
      final rs = RequestSigning(secretKey: minKey);
      expect(rs.signaturePrefix, '');
    });

    test('default includeTimestamp is true', () {
      final rs = RequestSigning(secretKey: minKey);
      expect(rs.includeTimestamp, isTrue);
    });

    test('default signBody is true', () {
      final rs = RequestSigning(secretKey: minKey);
      expect(rs.signBody, isTrue);
    });

    test('custom headerName stored correctly', () {
      final rs = RequestSigning(
        secretKey: minKey,
        headerName: 'X-Hub-Signature-256',
      );
      expect(rs.headerName, 'X-Hub-Signature-256');
    });

    test('custom signaturePrefix stored (GitHub style)', () {
      final rs = RequestSigning(
        secretKey: minKey,
        signaturePrefix: 'sha256=',
      );
      expect(rs.signaturePrefix, 'sha256=');
    });

    test('includeTimestamp=false stored', () {
      final rs = RequestSigning(
        secretKey: minKey,
        includeTimestamp: false,
      );
      expect(rs.includeTimestamp, isFalse);
    });

    test('signBody=false stored', () {
      final rs = RequestSigning(
        secretKey: minKey,
        signBody: false,
      );
      expect(rs.signBody, isFalse);
    });

    test('longer secretKey accepted', () {
      const longKey = 'supersecretkey_that_is_very_long_and_secure_1234567890';
      expect(() => RequestSigning(secretKey: longKey), returnsNormally);
    });

    test('secretKey shorter than 16 chars fails assert in debug', () {
      expect(
        () => RequestSigning(secretKey: 'tooshort'),
        throwsA(anything),
      );
    }, skip: 'assert only triggers in debug mode');
  });

  // ──────────────────────────────────────────────────────────────
  // toMap serialization
  // ──────────────────────────────────────────────────────────────
  group('RequestSigning – toMap', () {
    test('toMap contains secretKey', () {
      final map = RequestSigning(secretKey: minKey).toMap();
      expect(map['secretKey'], minKey);
    });

    test('toMap contains headerName', () {
      final map = RequestSigning(secretKey: minKey).toMap();
      expect(map['headerName'], 'X-Signature');
    });

    test('toMap contains signaturePrefix', () {
      final map = RequestSigning(secretKey: minKey).toMap();
      expect(map['signaturePrefix'], '');
    });

    test('toMap contains includeTimestamp=true', () {
      final map = RequestSigning(secretKey: minKey).toMap();
      expect(map['includeTimestamp'], isTrue);
    });

    test('toMap contains signBody=true', () {
      final map = RequestSigning(secretKey: minKey).toMap();
      expect(map['signBody'], isTrue);
    });

    test('toMap reflects custom values', () {
      const rs = RequestSigning(
        secretKey: 'mysupersecretkey!', // 17 chars
        headerName: 'X-Auth',
        signaturePrefix: 'hmac=',
        includeTimestamp: false,
        signBody: false,
      );
      final map = rs.toMap();
      expect(map['headerName'], 'X-Auth');
      expect(map['signaturePrefix'], 'hmac=');
      expect(map['includeTimestamp'], isFalse);
      expect(map['signBody'], isFalse);
    });

    test('toMap has exactly 5 keys', () {
      final map = RequestSigning(secretKey: minKey).toMap();
      expect(map.keys.toSet(), {
        'secretKey',
        'headerName',
        'signaturePrefix',
        'includeTimestamp',
        'signBody',
      });
    });

    test('GitHub-style config round-trips through toMap', () {
      const rs = RequestSigning(
        secretKey: 'github_webhook_secret_key!!', // 26 chars
        headerName: 'X-Hub-Signature-256',
        signaturePrefix: 'sha256=',
      );
      final map = rs.toMap();
      expect(map['headerName'], 'X-Hub-Signature-256');
      expect(map['signaturePrefix'], 'sha256=');
      expect(map['includeTimestamp'], isTrue);
      expect(map['signBody'], isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Integration with HTTP workers
  // ──────────────────────────────────────────────────────────────
  group('RequestSigning – HTTP worker integration', () {
    test('HttpDownloadWorker accepts requestSigning', () {
      const rs = RequestSigning(secretKey: minKey);
      expect(
        () => HttpDownloadWorker(
          url: 'https://api.example.com/file',
          savePath: '/tmp/file.bin',
          requestSigning: rs,
        ),
        returnsNormally,
      );
    });

    test('HttpDownloadWorker.toMap includes requestSigning', () {
      const rs = RequestSigning(secretKey: minKey, headerName: 'X-Auth');
      final worker = HttpDownloadWorker(
        url: 'https://api.example.com/file',
        savePath: '/tmp/file.bin',
        requestSigning: rs,
      );
      final map = worker.toMap();
      expect(map['requestSigning'], isA<Map>());
      expect((map['requestSigning'] as Map)['headerName'], 'X-Auth');
    });

    test('HttpUploadWorker accepts requestSigning', () {
      const rs = RequestSigning(secretKey: minKey);
      expect(
        () => HttpUploadWorker(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/data.csv',
          requestSigning: rs,
        ),
        returnsNormally,
      );
    });

    test('HttpRequestWorker without requestSigning has null in toMap', () {
      final worker = HttpRequestWorker(url: 'https://api.example.com');
      final map = worker.toMap();
      expect(map['requestSigning'], isNull);
    });
  });
}
