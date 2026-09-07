import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Parses the `worker_results.dart` helpers against the payload shapes the native
/// workers **actually emit**, rather than hand-written maps.
///
/// This matters because until v1.6.0 these helpers had never received a real
/// payload on Android: `TaskEvent.resultData` arrived as `null` on kmpworkmanager
/// 3.3.1, and as a `{kmp_step_output: "<json>"}` envelope on 3.4.1 before the
/// plugin learned to flatten it. Every existing test fed them maps written by
/// hand, so a key the native side never sends — or one it sends under a different
/// name — would not have shown up.
///
/// The key sets below are lifted from the `buildJsonObject { put(...) }` blocks in
/// the Android workers, and the `CryptoResult` payload is a verbatim capture from
/// a Pixel 6 Pro run. When a worker changes what it emits, these fail.
void main() {
  group('payloads captured from the Android workers', () {
    test('CryptoResult parses a real SHA-256 payload', () {
      // Verbatim from a Pixel 6 Pro, hashing a 5-byte file.
      final result = CryptoResult.from(const {
        'hash':
            '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
        'algorithm': 'SHA-256',
        'filePath': '/data/user/0/app/code_cache/probe/a.txt',
        'fileSize': 5,
      });

      expect(result, isNotNull);
      expect(result!.hash, hasLength(64));
      expect(result.algorithm, equals('SHA-256'));
      expect(result.fileSize, equals(5));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(result.hash!), isTrue);
    });

    test('DownloadResult reads every key HttpDownloadWorker emits', () {
      final result = DownloadResult.from(const {
        'filePath': '/data/user/0/app/files/report.pdf',
        'fileSize': 204800,
        'fileName': 'report.pdf',
        'contentType': 'application/pdf',
        'finalUrl': 'https://cdn.example.com/report.pdf',
        'serverSuggestedName': 'report-2026.pdf',
        'skipped': false,
      });

      expect(result, isNotNull);
      expect(result!.filePath, endsWith('report.pdf'));
      expect(result.fileSize, equals(204800));
    });

    test('UploadResult reads every key HttpUploadWorker emits', () {
      final result = UploadResult.from(const {
        'statusCode': 201,
        'fileCount': 2,
        'uploadedSize': 38,
        'contentType': 'multipart/form-data',
        'responseBody': '{"ok":true}',
      });

      expect(result, isNotNull);
      expect(result!.statusCode, equals(201));
    });

    test('ImageProcessResult reads every key ImageProcessWorker emits', () {
      final result = ImageProcessResult.from(const {
        'inputPath': '/tmp/in.png',
        'outputPath': '/tmp/out.jpg',
        'format': 'jpeg',
        'originalWidth': 4032,
        'originalHeight': 3024,
        'processedWidth': 512,
        'processedHeight': 384,
        'originalSize': 3200000,
        'processedSize': 48000,
        'compressionRatio': 0.015,
      });

      expect(result, isNotNull);
      expect(result!.outputPath, equals('/tmp/out.jpg'));
    });

    test('FileSystemResult reads the list-operation payload', () {
      final result = FileSystemResult.from(const {
        'operation': 'list',
        'path': '/tmp/dir',
        'fileCount': 2,
        'totalSize': 1024,
        'files': [
          {
            'name': 'a.txt',
            'path': '/tmp/dir/a.txt',
            'size': 512,
            'isDirectory': false,
            'lastModified': 1788739000000,
          },
          {
            'name': 'b.txt',
            'path': '/tmp/dir/b.txt',
            'size': 512,
            'isDirectory': false,
            'lastModified': 1788739000001,
          },
        ],
      });

      expect(result, isNotNull);
      // Android sends `fileCount` and `files`, never `count`/`entries`; both must
      // still surface through the public fields.
      expect(result!.count, equals(2));
      expect(result.entries, equals(['/tmp/dir/a.txt', '/tmp/dir/b.txt']));
      expect(result.operation, equals('list'));
    });

    test('FileSystemResult reads the iOS list payload too', () {
      // iOS additionally sends an explicit `entries` array of paths. When present
      // it wins over deriving them from `files`.
      final result = FileSystemResult.from(const {
        'operation': 'list',
        'entries': ['/tmp/dir/a.txt', '/tmp/dir/b.txt'],
        'files': [
          {'name': 'a.txt', 'path': '/tmp/dir/a.txt'},
          {'name': 'b.txt', 'path': '/tmp/dir/b.txt'},
        ],
        'fileCount': 2,
      });

      expect(result!.entries, hasLength(2));
      expect(result.count, equals(2));
    });
  });

  group('parsers that read a different key on each platform', () {
    test('CompressionResult reads the Android compression payload', () {
      // Android: filesCompressed / originalSize — not fileCount / totalSize.
      final r = CompressionResult.from(const {
        'outputPath': '/tmp/out.zip',
        'filesCompressed': 3,
        'originalSize': 9000,
        'compressedSize': 3000,
        'compressionRatio': 0.33,
      });

      expect(r, isNotNull);
      expect(r!.fileCount, equals(3));
      expect(r.totalSize, equals(9000));
      expect(r.compressedSize, equals(3000));
      expect(r.compressionRatio, closeTo(0.333, 0.01));
    });

    test('DecompressionResult reads the Android payload', () {
      // Every key this parser used to read was absent on both platforms, so it
      // returned null for every real payload. Android sends targetDir /
      // extractedFiles / totalBytes.
      final r = DecompressionResult.from(const {
        'targetDir': '/tmp/out',
        'extractedFiles': 7,
        'extractedDirs': 2,
        'totalBytes': 40960,
        'zipDeleted': false,
      });

      expect(r, isNotNull);
      expect(r!.outputPath, equals('/tmp/out'));
      expect(r.extractedCount, equals(7));
      expect(r.totalSize, equals(40960));
    });

    test('DecompressionResult reads the iOS payload', () {
      final r = DecompressionResult.from(const {
        'outputPath': '/tmp/out',
        'filesExtracted': 4,
      });

      expect(r!.extractedCount, equals(4));
    });

    test('ImageProcessResult reads Android processed* dimensions', () {
      // Android reports post-processing size as processedWidth/Height/Size;
      // width/height/fileSize are never sent.
      final r = ImageProcessResult.from(const {
        'outputPath': '/tmp/out.jpg',
        'processedWidth': 512,
        'processedHeight': 384,
        'processedSize': 48000,
        'format': 'jpeg',
      });

      expect(r, isNotNull);
      expect(r!.width, equals(512));
      expect(r.height, equals(384));
      expect(r.fileSize, equals(48000));
    });

    test('CryptoResult infers operation on Android, echoes it on iOS', () {
      // Android never sends `operation`; a hash payload implies it.
      final android = CryptoResult.from(const {'hash': 'abc', 'fileSize': 5});
      expect(android!.operation, equals('hash'));

      final ios = CryptoResult.from(const {
        'operation': 'encrypt',
        'outputPath': '/tmp/a.enc',
        'outputSize': 128,
      });
      expect(ios!.operation, equals('encrypt'));
      expect(ios.fileSize, equals(128));
    });

    test('ParallelUploadResult reads Android counters without fileResults', () {
      // Only iOS emits the per-file breakdown. The counters must still parse.
      final r = ParallelUploadResult.from(const {
        'uploadedCount': 3,
        'failedCount': 0,
        'totalBytes': 123,
      });

      expect(r, isNotNull);
      expect(r!.uploadedCount, equals(3));
      expect(r.totalBytes, equals(123));
      expect(r.files, isEmpty);
    });
  });

  group('robustness of every parser', () {
    test('null input yields null, never a throw', () {
      expect(DownloadResult.from(null), isNull);
      expect(UploadResult.from(null), isNull);
      expect(CryptoResult.from(null), isNull);
      expect(HttpRequestResult.from(null), isNull);
      expect(ImageProcessResult.from(null), isNull);
      expect(FileSystemResult.from(null), isNull);
      expect(CompressionResult.from(null), isNull);
      expect(DecompressionResult.from(null), isNull);
      expect(ParallelDownloadResult.from(null), isNull);
      expect(ParallelUploadResult.from(null), isNull);
    });

    test('an empty map does not throw', () {
      // A worker can succeed with no data at all — WorkManager also drops output
      // that exceeds its Data budget, which surfaces here as an empty payload.
      expect(() => CryptoResult.from(const {}), returnsNormally);
      expect(() => DownloadResult.from(const {}), returnsNormally);
      expect(() => UploadResult.from(const {}), returnsNormally);
      expect(() => ImageProcessResult.from(const {}), returnsNormally);
      expect(() => FileSystemResult.from(const {}), returnsNormally);
    });

    test('the envelope shape is not silently accepted as a result', () {
      // If the Android plugin ever stops flattening kmpworkmanager's
      // `kmp_step_output` envelope, resultData arrives looking like this. The
      // parser must not pretend it understood it — every field stays null, which
      // is the signal a caller can actually detect.
      final result = CryptoResult.from(const {
        'kmp_step_output': '{"hash":"2cf24dba","algorithm":"SHA-256"}',
      });

      expect(result, isNotNull);
      expect(result!.hash, isNull);
      expect(result.algorithm, isNull);
    });
  });
}
