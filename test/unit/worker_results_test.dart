import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('DownloadResult', () {
    test('parses valid map', () {
      final map = {
        'filePath': '/tmp/file.zip',
        'fileName': 'file.zip',
        'fileSize': 1024,
        'contentType': 'application/zip',
        'finalUrl': 'https://example.com/file.zip',
        'serverSuggestedName': 'suggested.zip',
        'skipped': true,
      };

      final result = DownloadResult.from(map);

      expect(result, isNotNull);
      expect(result!.filePath, '/tmp/file.zip');
      expect(result.fileName, 'file.zip');
      expect(result.fileSize, 1024);
      expect(result.contentType, 'application/zip');
      expect(result.finalUrl, 'https://example.com/file.zip');
      expect(result.serverSuggestedName, 'suggested.zip');
      expect(result.skipped, isTrue);
      expect(result.toString(),
          'DownloadResult(filePath: /tmp/file.zip, fileSize: 1024, skipped: true)');
    });

    test('returns null for null or invalid map', () {
      expect(DownloadResult.from(null), isNull);
      expect(DownloadResult.from({}), isNull);
      expect(DownloadResult.from({'filePath': '/tmp'}), isNull);
    });
  });

  group('ParallelDownloadResult', () {
    test('parses valid map', () {
      final map = {
        'downloadedCount': 2,
        'failedCount': 1,
        'totalBytes': 2048,
        'fileResults': [
          {
            'url': 'https://example.com/1.jpg',
            'success': true,
            'filePath': '/tmp/1.jpg',
            'fileName': '1.jpg',
            'fileSize': 1024,
          },
          {
            'url': 'https://example.com/2.jpg',
            'success': false,
            'error': 'Network error',
          }
        ]
      };

      final result = ParallelDownloadResult.from(map);

      expect(result, isNotNull);
      expect(result!.downloadedCount, 2);
      expect(result.failedCount, 1);
      expect(result.totalBytes, 2048);
      expect(result.files.length, 2);

      expect(result.files[0].url, 'https://example.com/1.jpg');
      expect(result.files[0].success, isTrue);
      expect(result.files[0].filePath, '/tmp/1.jpg');

      expect(result.files[1].success, isFalse);
      expect(result.files[1].error, 'Network error');
    });

    test('returns null for null map', () {
      expect(ParallelDownloadResult.from(null), isNull);
    });
  });

  group('UploadResult', () {
    test('parses valid map', () {
      final map = {
        'statusCode': 200,
        'uploadedSize': 4096,
        'fileCount': 3,
        'responseBody': '{"status":"ok"}',
      };

      final result = UploadResult.from(map);

      expect(result, isNotNull);
      expect(result!.statusCode, 200);
      expect(result.uploadedSize, 4096);
      expect(result.fileCount, 3);
      expect(result.responseBody, '{"status":"ok"}');
    });

    test('returns null for null map', () {
      expect(UploadResult.from(null), isNull);
    });
  });

  group('ParallelUploadResult', () {
    test('parses valid map', () {
      final map = {
        'uploadedCount': 1,
        'failedCount': 0,
        'totalBytes': 1024,
        'fileResults': [
          {
            'fileName': '1.jpg',
            'filePath': '/tmp/1.jpg',
            'fileSize': 1024,
            'success': true,
            'statusCode': 200,
            'responseBody': 'ok',
          }
        ]
      };

      final result = ParallelUploadResult.from(map);

      expect(result, isNotNull);
      expect(result!.uploadedCount, 1);
      expect(result.files.length, 1);
      expect(result.files[0].fileName, '1.jpg');
      expect(result.files[0].success, isTrue);
    });

    test('returns null for null map', () {
      expect(ParallelUploadResult.from(null), isNull);
    });
  });

  group('HttpRequestResult', () {
    test('parses valid map', () {
      final map = {
        'statusCode': 201,
        'body': 'Created',
        'contentLength': 7,
      };

      final result = HttpRequestResult.from(map);

      expect(result, isNotNull);
      expect(result!.statusCode, 201);
      expect(result.body, 'Created');
      expect(result.contentLength, 7);
    });

    test('returns null for null map', () {
      expect(HttpRequestResult.from(null), isNull);
    });
  });

  group('CryptoResult', () {
    test('parses valid map', () {
      final map = {
        'hash': 'abc',
        'algorithm': 'SHA-256',
        'outputPath': '/tmp/out.enc',
        'fileSize': 100,
        'operation': 'encrypt',
      };

      final result = CryptoResult.from(map);

      expect(result, isNotNull);
      expect(result!.hash, 'abc');
      expect(result.operation, 'encrypt');
    });

    test('returns null for null map', () {
      expect(CryptoResult.from(null), isNull);
    });
  });

  group('CompressionResult', () {
    test('parses valid map', () {
      final map = {
        'outputPath': '/tmp/out.zip',
        'fileCount': 5,
        'totalSize': 1000,
        'compressedSize': 500,
      };

      final result = CompressionResult.from(map);

      expect(result, isNotNull);
      expect(result!.outputPath, '/tmp/out.zip');
      expect(result.compressionRatio, 0.5);
    });

    test('returns null for null or invalid map', () {
      expect(CompressionResult.from(null), isNull);
      expect(CompressionResult.from({}), isNull); // Missing outputPath
    });
  });

  group('DecompressionResult', () {
    test('parses valid map', () {
      final map = {
        'outputPath': '/tmp/out/',
        'extractedCount': 10,
        'totalSize': 2000,
      };

      final result = DecompressionResult.from(map);

      expect(result, isNotNull);
      expect(result!.outputPath, '/tmp/out/');
      expect(result.extractedCount, 10);
    });

    test('returns null for null or invalid map', () {
      expect(DecompressionResult.from(null), isNull);
      expect(DecompressionResult.from({}), isNull);
    });
  });

  group('ImageProcessResult', () {
    test('parses valid map', () {
      final map = {
        'outputPath': '/tmp/out.jpg',
        'width': 800,
        'height': 600,
        'fileSize': 40000,
        'format': 'jpeg',
      };

      final result = ImageProcessResult.from(map);

      expect(result, isNotNull);
      expect(result!.outputPath, '/tmp/out.jpg');
      expect(result.width, 800);
      expect(result.format, 'jpeg');
    });

    test('returns null for null or invalid map', () {
      expect(ImageProcessResult.from(null), isNull);
      expect(ImageProcessResult.from({}), isNull);
    });
  });

  group('FileSystemResult', () {
    test('parses valid map', () {
      final map = {
        'operation': 'copy',
        'sourcePath': '/tmp/a',
        'destinationPath': '/tmp/b',
        'entries': ['file1', 'file2'],
        'count': 2,
      };

      final result = FileSystemResult.from(map);

      expect(result, isNotNull);
      expect(result!.operation, 'copy');
      expect(result.entries, ['file1', 'file2']);
    });

    test('returns null for null or invalid map', () {
      expect(FileSystemResult.from(null), isNull);
      expect(FileSystemResult.from({}), isNull);
    });
  });
}
