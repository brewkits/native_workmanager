// Tests for all HTTP-category workers — Dart serialisation contract.
//
// Covers: HttpRequestWorker, HttpUploadWorker, HttpDownloadWorker,
// ParallelHttpDownloadWorker, ParallelHttpUploadWorker, HttpSyncWorker,
// MultiUploadWorker, MoveToSharedStorageWorker.

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ── HttpRequestWorker ──────────────────────────────────────────────────────

  group('NativeWorker.httpRequest()', () {
    test('GET defaults serialise correctly', () {
      final w = NativeWorker.httpRequest(url: 'https://api.example.com/status');
      final map = w.toMap();
      expect(map['url'], 'https://api.example.com/status');
      expect(map['method'], 'get'); // enum .name → lowercase
      expect(map['workerType'], 'httpRequest');
    });

    test('POST with body and headers', () {
      final w = NativeWorker.httpRequest(
        url: 'https://api.example.com/events',
        method: HttpMethod.post,
        headers: {'Content-Type': 'application/json', 'X-Token': 'abc'},
        body: '{"event":"click"}',
      );
      final map = w.toMap();
      expect(map['method'], 'post');
      expect(map['headers']['Content-Type'], 'application/json');
      expect(map['body'], '{"event":"click"}');
    });

    test('PUT method serialises', () {
      final w = NativeWorker.httpRequest(
        url: 'https://api.example.com/users/1',
        method: HttpMethod.put,
      );
      expect(w.toMap()['method'], 'put');
    });

    test('DELETE method serialises', () {
      final w = NativeWorker.httpRequest(
        url: 'https://api.example.com/users/1',
        method: HttpMethod.delete,
      );
      expect(w.toMap()['method'], 'delete');
    });

    test('PATCH method serialises', () {
      final w = NativeWorker.httpRequest(
        url: 'https://api.example.com/users/1',
        method: HttpMethod.patch,
      );
      expect(w.toMap()['method'], 'patch');
    });

    test('empty url throws ArgumentError', () {
      expect(
        () => NativeWorker.httpRequest(url: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('non-http url throws ArgumentError', () {
      expect(
        () => NativeWorker.httpRequest(url: 'ftp://example.com'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('workerClassName is HttpRequestWorker', () {
      final w = NativeWorker.httpRequest(url: 'https://example.com');
      expect(w.workerClassName, 'HttpRequestWorker');
    });

    test('copyWith creates new instance with updated values', () {
      final w1 = NativeWorker.httpRequest(
        url: 'https://api.example.com',
        method: HttpMethod.get,
      ) as HttpRequestWorker;

      final w2 = w1.copyWith(
        url: 'https://api.example.com/v2',
        method: HttpMethod.post,
        timeout: const Duration(seconds: 45),
      );

      expect(w2.url, 'https://api.example.com/v2');
      expect(w2.method, HttpMethod.post);
      expect(w2.timeout, const Duration(seconds: 45));
      expect(w1.url, 'https://api.example.com'); // Original unchanged
    });

    test('withHeaders merges headers', () {
      final w1 = NativeWorker.httpRequest(
        url: 'https://api.example.com',
        headers: {'Accept': 'application/json'},
      ) as HttpRequestWorker;

      final w2 = w1.withHeaders({'X-Custom': 'value'});

      expect(w2.headers, {
        'Accept': 'application/json',
        'X-Custom': 'value',
      });
    });

    test('withAuth adds Authorization header', () {
      final w1 = NativeWorker.httpRequest(url: 'https://api.example.com')
          as HttpRequestWorker;

      final w2 = w1.withAuth(token: 'my-token');
      expect(w2.headers['Authorization'], 'Bearer my-token');

      final w3 =
          w1.withAuth(token: 'my-token', template: 'Basic {accessToken}');
      expect(w3.headers['Authorization'], 'Basic my-token');
    });

    test('withBody sets body and Content-Type', () {
      final w1 = NativeWorker.httpRequest(url: 'https://api.example.com')
          as HttpRequestWorker;

      final w2 = w1.withBody('{"key":"value"}');

      expect(w2.body, '{"key":"value"}');
      expect(w2.headers['Content-Type'], 'application/json');
    });

    test('withSigning and withTokenRefresh set config', () {
      final w1 = NativeWorker.httpRequest(url: 'https://api.example.com')
          as HttpRequestWorker;

      final w2 =
          w1.withSigning(const RequestSigning(secretKey: '1234567890123456'));
      expect(w2.requestSigning, isNotNull);

      final w3 = w1
          .withTokenRefresh(const TokenRefreshConfig(url: 'https://auth.com'));
      expect(w3.tokenRefresh, isNotNull);
    });
  });

  // ── HttpUploadWorker ───────────────────────────────────────────────────────

  group('NativeWorker.httpUpload()', () {
    test('required fields serialise', () {
      final w = NativeWorker.httpUpload(
        url: 'https://upload.example.com/files',
        filePath: '/tmp/photo.jpg',
      );
      final map = w.toMap();
      expect(map['url'], 'https://upload.example.com/files');
      expect(map['filePath'], '/tmp/photo.jpg');
      expect(map['workerType'], 'httpUpload');
    });

    test('optional fields serialise', () {
      final w = NativeWorker.httpUpload(
        url: 'https://upload.example.com/files',
        filePath: '/tmp/photo.jpg',
        fileFieldName: 'attachment',
        fileName: 'renamed.jpg',
        mimeType: 'image/jpeg',
        headers: {'Authorization': 'Bearer tok'},
        additionalFields: {'userId': '42'},
      );
      final map = w.toMap();
      expect(map['fileFieldName'], 'attachment');
      expect(map['fileName'], 'renamed.jpg');
      expect(map['mimeType'], 'image/jpeg');
      expect(map['headers']['Authorization'], 'Bearer tok');
    });

    test('empty url throws ArgumentError', () {
      expect(
        () => NativeWorker.httpUpload(url: '', filePath: '/tmp/f.jpg'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty filePath throws ArgumentError', () {
      expect(
        () => NativeWorker.httpUpload(url: 'https://example.com', filePath: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('workerClassName is HttpUploadWorker', () {
      final w = NativeWorker.httpUpload(
        url: 'https://example.com',
        filePath: '/tmp/f.jpg',
      );
      expect(w.workerClassName, 'HttpUploadWorker');
    });

    test('copyWith updates fields', () {
      final w1 = NativeWorker.httpUpload(
        url: 'https://example.com',
        filePath: '/tmp/f.jpg',
      ) as HttpUploadWorker;

      final w2 = w1.copyWith(
        url: 'https://example.com/v2',
        filePath: '/tmp/v2.jpg',
        timeout: const Duration(minutes: 10),
      );

      expect(w2.url, 'https://example.com/v2');
      expect(w2.filePath, '/tmp/v2.jpg');
      expect(w2.timeout, const Duration(minutes: 10));
      expect(w1.url, 'https://example.com'); // Original unchanged
    });

    test('withHeaders merges headers', () {
      final w1 = NativeWorker.httpUpload(
        url: 'https://example.com',
        filePath: '/tmp/f.jpg',
        headers: {'Accept': 'application/json'},
      ) as HttpUploadWorker;

      final w2 = w1.withHeaders({'X-Custom': 'value'});

      expect(w2.headers, {
        'Accept': 'application/json',
        'X-Custom': 'value',
      });
    });

    test('withAuth adds Authorization header', () {
      final w1 = NativeWorker.httpUpload(
        url: 'https://example.com',
        filePath: '/tmp/f.jpg',
      ) as HttpUploadWorker;

      final w2 = w1.withAuth(token: 'token123');
      expect(w2.headers['Authorization'], 'Bearer token123');

      final w3 = w1.withAuth(token: 'token123', template: 'Auth {accessToken}');
      expect(w3.headers['Authorization'], 'Auth token123');
    });

    test('withSigning sets requestSigning', () {
      final w1 = NativeWorker.httpUpload(
        url: 'https://example.com',
        filePath: '/tmp/f.jpg',
      ) as HttpUploadWorker;

      final w2 =
          w1.withSigning(const RequestSigning(secretKey: 'key1234567890123'));
      expect(w2.requestSigning, isNotNull);
    });
  });

  // ── HttpDownloadWorker ─────────────────────────────────────────────────────

  group('NativeWorker.httpDownload()', () {
    test('required fields serialise', () {
      final w = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/file.zip',
        savePath: '/tmp/file.zip',
      );
      final map = w.toMap();
      expect(map['url'], 'https://cdn.example.com/file.zip');
      expect(map['savePath'], '/tmp/file.zip');
      expect(map['workerType'], 'httpDownload');
    });

    test('enableResume defaults true', () {
      final w = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      );
      expect(w.toMap()['enableResume'], true);
    });

    test('checksum fields serialise', () {
      final w = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
        expectedChecksum: 'abc123',
        checksumAlgorithm: 'SHA-512',
      );
      final map = w.toMap();
      expect(map['expectedChecksum'], 'abc123');
      expect(map['checksumAlgorithm'], 'SHA-512');
    });

    test('empty url throws ArgumentError', () {
      expect(
        () => NativeWorker.httpDownload(url: '', savePath: '/tmp/f.zip'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty savePath throws ArgumentError', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'https://cdn.example.com/f.zip',
          savePath: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('workerClassName is HttpDownloadWorker', () {
      final w = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      );
      expect(w.workerClassName, 'HttpDownloadWorker');
    });

    test('copyWith updates fields', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      ) as HttpDownloadWorker;

      final w2 = w1.copyWith(
        url: 'https://cdn.example.com/v2.zip',
        savePath: '/tmp/v2.zip',
        timeout: const Duration(minutes: 10),
      );

      expect(w2.url, 'https://cdn.example.com/v2.zip');
      expect(w2.savePath, '/tmp/v2.zip');
      expect(w2.timeout, const Duration(minutes: 10));
      expect(w1.url, 'https://cdn.example.com/f.zip'); // Original unchanged
    });

    test('withNotification sets notification fields', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      ) as HttpDownloadWorker;

      final w2 =
          w1.withNotification(title: 'Title', body: 'Body', allowPause: true);

      expect(w2.showNotification, isTrue);
      expect(w2.notificationTitle, 'Title');
      expect(w2.notificationBody, 'Body');
      expect(w2.allowPause, isTrue);
    });

    test('withAuth sets auth fields', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      ) as HttpDownloadWorker;

      final w2 = w1.withAuth(token: 'token123');
      expect(w2.authToken, 'token123');
      expect(w2.authHeaderTemplate, 'Bearer {accessToken}');

      final w3 = w1.withAuth(token: 'token123', template: 'Auth {accessToken}');
      expect(w3.authHeaderTemplate, 'Auth {accessToken}');
    });

    test('withResume sets resume and skip options', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
        enableResume: false,
      ) as HttpDownloadWorker;

      final w2 = w1.withResume(skipIfExists: true);
      expect(w2.enableResume, isTrue);
      expect(w2.skipExisting, isTrue);
    });

    test('withChecksum sets checksum fields', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      ) as HttpDownloadWorker;

      final w2 = w1.withChecksum(expected: 'abc');
      expect(w2.expectedChecksum, 'abc');
      expect(w2.checksumAlgorithm, 'SHA-256');

      final w3 = w1.withChecksum(expected: 'def', algorithm: 'MD5');
      expect(w3.expectedChecksum, 'def');
      expect(w3.checksumAlgorithm, 'MD5');
    });

    test('withBandwidthLimit sets limit', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      ) as HttpDownloadWorker;

      final w2 = w1.withBandwidthLimit(1024);
      expect(w2.bandwidthLimitBytesPerSecond, 1024);
    });

    test('withSigning sets requestSigning', () {
      final w1 = NativeWorker.httpDownload(
        url: 'https://cdn.example.com/f.zip',
        savePath: '/tmp/f.zip',
      ) as HttpDownloadWorker;

      final w2 =
          w1.withSigning(const RequestSigning(secretKey: 'key1234567890123'));
      expect(w2.requestSigning, isNotNull);
    });
  });

  // ── ParallelHttpDownloadWorker ─────────────────────────────────────────────

  group('NativeWorker.parallelHttpDownload()', () {
    test('required fields serialise', () {
      final w = NativeWorker.parallelHttpDownload(
        url: 'https://cdn.example.com/big.zip',
        savePath: '/tmp/big.zip',
      );
      final map = w.toMap();
      expect(map['url'], 'https://cdn.example.com/big.zip');
      expect(map['savePath'], '/tmp/big.zip');
      expect(map['workerType'], 'parallelHttpDownload');
    });

    test('numChunks defaults to 4', () {
      final w = NativeWorker.parallelHttpDownload(
        url: 'https://cdn.example.com/big.zip',
        savePath: '/tmp/big.zip',
      );
      expect(w.toMap()['numChunks'], 4);
    });

    test('custom numChunks is preserved', () {
      final w = NativeWorker.parallelHttpDownload(
        url: 'https://cdn.example.com/big.zip',
        savePath: '/tmp/big.zip',
        numChunks: 8,
      );
      expect(w.toMap()['numChunks'], 8);
    });

    test('workerClassName is ParallelHttpDownloadWorker', () {
      final w = NativeWorker.parallelHttpDownload(
        url: 'https://cdn.example.com/big.zip',
        savePath: '/tmp/big.zip',
      );
      expect(w.workerClassName, 'ParallelHttpDownloadWorker');
    });
  });

  // ── MultiUploadWorker ──────────────────────────────────────────────────────

  group('NativeWorker.multiUpload()', () {
    test('required fields serialise', () {
      final w = NativeWorker.multiUpload(
        url: 'https://upload.example.com/batch',
        files: [
          const UploadFile(filePath: '/tmp/a.jpg'),
          const UploadFile(filePath: '/tmp/b.jpg', fieldName: 'attachment'),
        ],
      );
      final map = w.toMap();
      expect(map['url'], 'https://upload.example.com/batch');
      expect(map['workerType'], 'httpUpload');
      final filesList = map['files'] as List;
      expect(filesList, hasLength(2));
    });

    test('UploadFile with all fields serialises', () {
      final w = NativeWorker.multiUpload(
        url: 'https://upload.example.com/batch',
        files: [
          const UploadFile(
            filePath: '/tmp/doc.pdf',
            fieldName: 'document',
            fileName: 'renamed.pdf',
            mimeType: 'application/pdf',
          ),
        ],
      );
      final files = w.toMap()['files'] as List;
      final f = files.first as Map;
      expect(f['filePath'], '/tmp/doc.pdf');
      expect(f['fileFieldName'], 'document');
      expect(f['fileName'], 'renamed.pdf');
      expect(f['mimeType'], 'application/pdf');
    });

    test('empty files list throws ArgumentError', () {
      expect(
        () => NativeWorker.multiUpload(
          url: 'https://upload.example.com/batch',
          files: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('workerClassName is HttpUploadWorker', () {
      final w = NativeWorker.multiUpload(
        url: 'https://upload.example.com/batch',
        files: [const UploadFile(filePath: '/tmp/a.jpg')],
      );
      expect(w.workerClassName, 'HttpUploadWorker');
    });
  });

  // ── ParallelHttpUploadWorker ─────────────────────────────────────────────

  group('ParallelHttpUploadWorker', () {
    test('required fields serialise', () {
      final w = ParallelHttpUploadWorker(
        url: 'https://upload.example.com/batch',
        files: [
          const UploadFile(filePath: '/tmp/a.jpg'),
        ],
      );
      final map = w.toMap();
      expect(map['url'], 'https://upload.example.com/batch');
      expect(map['workerType'], 'parallelHttpUpload');
      expect(map['maxConcurrent'], 3);
      expect(map['maxRetries'], 1);
    });

    test('optional fields serialise', () {
      final w = ParallelHttpUploadWorker(
        url: 'https://upload.example.com/batch',
        files: [
          const UploadFile(
              filePath: '/tmp/a.jpg',
              fieldName: 'file1',
              fileName: 'f1.jpg',
              mimeType: 'image/jpeg'),
        ],
        headers: {'X-Auth': 'token'},
        fields: {'user': '123'},
        maxConcurrent: 5,
        maxRetries: 3,
        timeout: const Duration(minutes: 10),
        showNotification: true,
        notificationTitle: 'Uploading',
        notificationBody: 'Please wait',
      );
      final map = w.toMap();
      expect(map['headers']['X-Auth'], 'token');
      expect(map['fields']['user'], '123');
      expect(map['maxConcurrent'], 5);
      expect(map['maxRetries'], 3);
      expect(map['timeoutMs'], 600000);
      expect(map['showNotification'], true);
      expect(map['notificationTitle'], 'Uploading');
      expect(map['notificationBody'], 'Please wait');

      final files = map['files'] as List;
      expect(files.first['filePath'], '/tmp/a.jpg');
      expect(files.first['fieldName'], 'file1');
      expect(files.first['fileName'], 'f1.jpg');
      expect(files.first['mimeType'], 'image/jpeg');
    });

    test('empty files throws ArgumentError', () {
      expect(
        () => ParallelHttpUploadWorker(url: 'https://example.com', files: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid maxConcurrent throws RangeError', () {
      expect(
        () => ParallelHttpUploadWorker(
            url: 'https://example.com',
            files: [const UploadFile(filePath: '/tmp/a.jpg')],
            maxConcurrent: 0),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => ParallelHttpUploadWorker(
            url: 'https://example.com',
            files: [const UploadFile(filePath: '/tmp/a.jpg')],
            maxConcurrent: 17),
        throwsA(isA<RangeError>()),
      );
    });

    test('invalid maxRetries throws RangeError', () {
      expect(
        () => ParallelHttpUploadWorker(
            url: 'https://example.com',
            files: [const UploadFile(filePath: '/tmp/a.jpg')],
            maxRetries: -1),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => ParallelHttpUploadWorker(
            url: 'https://example.com',
            files: [const UploadFile(filePath: '/tmp/a.jpg')],
            maxRetries: 6),
        throwsA(isA<RangeError>()),
      );
    });

    test('workerClassName is ParallelHttpUploadWorker', () {
      final w = ParallelHttpUploadWorker(
        url: 'https://upload.example.com/batch',
        files: [const UploadFile(filePath: '/tmp/a.jpg')],
      );
      expect(w.workerClassName, 'ParallelHttpUploadWorker');
    });
  });

  // ── HttpSyncWorker ─────────────────────────────────────────────────────────

  group('NativeWorker.httpSync()', () {
    test('required fields serialise', () {
      final w = NativeWorker.httpSync(url: 'https://api.example.com/sync');
      final map = w.toMap();
      expect(map['url'], 'https://api.example.com/sync');
      expect(map['workerType'], 'httpSync');
    });

    test('POST method is default', () {
      final w = NativeWorker.httpSync(url: 'https://api.example.com/sync');
      expect(w.toMap()['method'], 'post'); // enum .name → lowercase
    });

    test('requestBody is serialised', () {
      final w = NativeWorker.httpSync(
        url: 'https://api.example.com/sync',
        requestBody: {'userId': '42', 'action': 'sync'},
      );
      final body = w.toMap()['requestBody'];
      expect(body, isNotNull);
    });

    test('empty url throws ArgumentError', () {
      expect(
        () => NativeWorker.httpSync(url: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('non-serializable requestBody throws ArgumentError', () {
      expect(
        () => NativeWorker.httpSync(
          url: 'https://api.example.com',
          requestBody: {'data': Object()}, // Not JSON-serializable
        ).toMap(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('requestSigning and tokenRefresh serialise', () {
      final w = NativeWorker.httpSync(
        url: 'https://api.example.com/sync',
        requestSigning: const RequestSigning(secretKey: '1234567890123456'),
        tokenRefresh: const TokenRefreshConfig(url: 'https://auth.com'),
      );
      final map = w.toMap();
      expect(map['requestSigning'], isNotNull);
      expect(map['tokenRefresh'], isNotNull);
    });

    test('workerClassName is HttpSyncWorker', () {
      final w = NativeWorker.httpSync(url: 'https://api.example.com/sync');
      expect(w.workerClassName, 'HttpSyncWorker');
    });
  });

  // ── MoveToSharedStorageWorker ──────────────────────────────────────────────

  group('NativeWorker.moveToSharedStorage()', () {
    test('downloads type serialises', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/file.pdf',
        storageType: SharedStorageType.downloads,
      );
      final map = w.toMap();
      expect(map['storageType'], 'downloads');
      expect(map['sourcePath'], '/tmp/file.pdf');
      expect(map['workerType'], 'moveToSharedStorage');
    });

    test('photos type serialises', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/photo.jpg',
        storageType: SharedStorageType.photos,
      );
      expect(w.toMap()['storageType'], 'photos');
    });

    test('music type serialises', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/song.mp3',
        storageType: SharedStorageType.music,
      );
      expect(w.toMap()['storageType'], 'music');
    });

    test('video type serialises', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/clip.mp4',
        storageType: SharedStorageType.video,
      );
      expect(w.toMap()['storageType'], 'video');
    });

    test('optional fields included when set', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/file.pdf',
        storageType: SharedStorageType.downloads,
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
        subDir: 'MyApp',
      );
      final map = w.toMap();
      expect(map['fileName'], 'report.pdf');
      expect(map['mimeType'], 'application/pdf');
      expect(map['subDir'], 'MyApp');
    });

    test('optional fields omitted when null', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/file.pdf',
        storageType: SharedStorageType.downloads,
      );
      final map = w.toMap();
      expect(map.containsKey('fileName'), false);
      expect(map.containsKey('mimeType'), false);
      expect(map.containsKey('subDir'), false);
    });

    test('workerClassName is MoveToSharedStorageWorker', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/file.pdf',
        storageType: SharedStorageType.downloads,
      );
      expect(w.workerClassName, 'MoveToSharedStorageWorker');
    });

    test('sourcePath is preserved in map', () {
      // Note: empty-path validation is not enforced at the Dart layer for
      // MoveToSharedStorageWorker — it is validated natively.
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/file.pdf',
        storageType: SharedStorageType.downloads,
      );
      expect(w.toMap()['sourcePath'], '/tmp/file.pdf');
    });
  });
}
