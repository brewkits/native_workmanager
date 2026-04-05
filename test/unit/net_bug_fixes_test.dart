// Tests for Networking & Sync bug fixes (NET-001 … NET-028).
//
// Each test group maps to one or more NET issue IDs. Tests are Dart-only
// (no platform channel required) and verify:
//   • Dart-layer validation, serialisation, and error handling.
//   • Worker API contracts that were changed by the fixes.
//
// Platform-specific fixes (iOS force-unwraps, Android concurrency) are
// verified by the existing integration tests and build verification below.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // NET-016 + NET-009 — HttpSyncWorker JSON body validation
  // ──────────────────────────────────────────────────────────────────────────

  group('NET-016 HttpSyncWorker requestBody JSON validation', () {
    test('serialisable Map is accepted', () {
      final w = HttpSyncWorker(
        url: 'https://example.com/sync',
        requestBody: {'key': 'value', 'count': 42},
      );
      final map = w.toMap();
      // requestBody must be JSON-encoded when present
      final encoded = map['requestBody'] as String?;
      expect(encoded, isNotNull);
      final decoded = jsonDecode(encoded!);
      expect(decoded['key'], 'value');
    });

    test('null requestBody produces null in map', () {
      final w = HttpSyncWorker(url: 'https://example.com/sync');
      expect(w.toMap()['requestBody'], isNull);
    });

    test('non-serialisable object in requestBody throws ArgumentError', () {
      // Using a custom class that is not JSON-serialisable
      // We simulate this by directly calling toMap on a worker whose
      // requestBody contains a Dart object that jsonEncode cannot handle.
      // We can test this by creating a valid worker and checking the map
      // serialises; the failure path is tested separately below.
      expect(
        () => HttpSyncWorker(
          url: 'https://example.com',
          requestBody: {'fn': Object()}, // Object() is not JSON-serialisable
        ).toMap(),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NET-028 — ParallelHttpUploadWorker runtime validation
  // ──────────────────────────────────────────────────────────────────────────

  group('NET-028 ParallelHttpUploadWorker runtime validation', () {
    final validFile = UploadFile(filePath: '/tmp/a.jpg');

    test('valid construction succeeds', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://example.com/up',
          files: [validFile],
          maxConcurrent: 4,
          maxRetries: 2,
        ),
        returnsNormally,
      );
    });

    test('empty files list throws ArgumentError', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://example.com/up',
          files: const [],
        ),
        throwsArgumentError,
      );
    });

    test('maxConcurrent = 0 throws RangeError', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://example.com/up',
          files: [validFile],
          maxConcurrent: 0,
        ),
        throwsRangeError,
      );
    });

    test('maxConcurrent = 17 throws RangeError', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://example.com/up',
          files: [validFile],
          maxConcurrent: 17,
        ),
        throwsRangeError,
      );
    });

    test('maxRetries = -1 throws RangeError', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://example.com/up',
          files: [validFile],
          maxRetries: -1,
        ),
        throwsRangeError,
      );
    });

    test('maxRetries = 6 throws RangeError', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://example.com/up',
          files: [validFile],
          maxRetries: 6,
        ),
        throwsRangeError,
      );
    });

    test('toMap serialises correctly for valid worker', () {
      final w = ParallelHttpUploadWorker(
        url: 'https://example.com/up',
        files: [UploadFile(filePath: '/tmp/photo.jpg', fieldName: 'photo')],
        maxConcurrent: 3,
        maxRetries: 1,
        timeout: const Duration(minutes: 3),
      );
      final map = w.toMap();
      expect(map['maxConcurrent'], 3);
      expect(map['maxRetries'], 1);
      expect((map['files'] as List).length, 1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NET-027 — Timeout documentation (per-attempt semantics)
  // ──────────────────────────────────────────────────────────────────────────

  group('NET-027 timeout is serialised correctly', () {
    test('HttpDownloadWorker timeout round-trips in toMap', () {
      final w = HttpDownloadWorker(
        url: 'https://example.com/file.zip',
        savePath: '/tmp/file.zip',
        timeout: const Duration(minutes: 10),
      );
      expect(w.toMap()['timeoutMs'], 10 * 60 * 1000);
    });

    test('HttpRequestWorker timeout round-trips in toMap', () {
      final w = HttpRequestWorker(
        url: 'https://example.com/api',
        timeout: const Duration(seconds: 45),
      );
      expect(w.toMap()['timeoutMs'], 45000);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NET-024 — moveToPublicDownloads / saveToGallery in toMap
  // ──────────────────────────────────────────────────────────────────────────

  group('NET-024 post-processing flags serialised', () {
    test('moveToPublicDownloads serialised', () {
      final w = HttpDownloadWorker(
        url: 'https://example.com/file.zip',
        savePath: '/tmp/file.zip',
        moveToPublicDownloads: true,
      );
      expect(w.toMap()['moveToPublicDownloads'], true);
    });

    test('saveToGallery serialised', () {
      final w = HttpDownloadWorker(
        url: 'https://example.com/photo.jpg',
        savePath: '/tmp/photo.jpg',
        saveToGallery: true,
      );
      expect(w.toMap()['saveToGallery'], true);
    });

    test('both default to false', () {
      final w = HttpDownloadWorker(
        url: 'https://example.com/file.zip',
        savePath: '/tmp/file.zip',
      );
      expect(w.toMap()['moveToPublicDownloads'], false);
      expect(w.toMap()['saveToGallery'], false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NET-011 — MultiUploadWorker uses HttpUploadWorker class name
  // ──────────────────────────────────────────────────────────────────────────

  group('NET-011 MultiUploadWorker class name', () {
    test('workerClassName is HttpUploadWorker (intentional reuse)', () {
      final w = MultiUploadWorker(
        url: 'https://example.com/upload',
        files: [UploadFile(filePath: '/tmp/a.jpg')],
      );
      expect(w.workerClassName, 'HttpUploadWorker');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NET-003 — HttpDownloadWorker toMap includes url (for native ETag sidecar)
  // ──────────────────────────────────────────────────────────────────────────

  group('NET-003 / NET-021 HttpDownloadWorker url in toMap', () {
    test('url is included in toMap for native ETag sidecar naming', () {
      final w = HttpDownloadWorker(
        url: 'https://example.com/file.zip',
        savePath: '/tmp/downloads/',
      );
      expect(w.toMap()['url'], 'https://example.com/file.zip');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // General worker serialisation round-trips
  // ──────────────────────────────────────────────────────────────────────────

  group('Worker serialisation round-trips', () {
    test('HttpSyncWorker with all fields', () {
      final w = HttpSyncWorker(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer tok'},
        requestBody: {'action': 'sync', 'version': 2},
        timeout: const Duration(seconds: 30),
      );
      final map = w.toMap();
      expect(map['url'], 'https://api.example.com/sync');
      expect(map['method'], 'post');
      expect(map['timeoutMs'], 30000);
      final body = jsonDecode(map['requestBody'] as String);
      expect(body['action'], 'sync');
    });

    test('HttpRequestWorker with body sets Content-Type', () {
      final w = HttpRequestWorker(
        url: 'https://api.example.com',
      ).withBody('{"hello": "world"}');
      expect(w.headers['Content-Type'], 'application/json');
      expect(w.body, '{"hello": "world"}');
    });

    test('MultiUploadWorker toMap includes all files', () {
      final w = MultiUploadWorker(
        url: 'https://example.com/upload',
        files: [
          UploadFile(filePath: '/tmp/a.jpg', fieldName: 'files'),
          UploadFile(filePath: '/tmp/b.png', fieldName: 'files'),
        ],
      );
      final map = w.toMap();
      expect((map['files'] as List).length, 2);
    });
  });
}
