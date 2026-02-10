import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('DartWorker', () {
    test('should create DartWorker with required fields', () {
      final worker = const DartWorker(callbackId: 'testCallback');

      expect(worker.callbackId, 'testCallback');
      expect(worker.input, isNull);
    });

    test('should create DartWorker with input', () {
      final input = {'key': 'value', 'count': 42};
      final worker = DartWorker(callbackId: 'testCallback', input: input);

      expect(worker.callbackId, 'testCallback');
      expect(worker.input, input);
      expect(worker.input?['key'], 'value');
      expect(worker.input?['count'], 42);
    });

    test('should have correct workerClassName', () {
      final worker = const DartWorker(callbackId: 'test');
      expect(worker.workerClassName, 'DartCallbackWorker');
    });

    test('should serialize to map correctly', () {
      final worker = DartWorker(
        callbackId: 'testCallback',
        input: {'key': 'value'},
      );

      final map = worker.toMap();

      expect(map['workerType'], 'dartCallback');
      expect(map['callbackId'], 'testCallback');
      expect(map['input'], isA<String>());
      expect(map['input'], contains('key'));
    });

    test('should serialize to map without input', () {
      final worker = const DartWorker(callbackId: 'testCallback');
      final map = worker.toMap();

      expect(map['workerType'], 'dartCallback');
      expect(map['callbackId'], 'testCallback');
      expect(map['input'], isNull);
    });

    test('should handle complex input data', () {
      final complexInput = {
        'string': 'hello',
        'number': 123,
        'double': 45.67,
        'bool': true,
        'list': [1, 2, 3],
        'nested': {'inner': 'value'},
      };

      final worker = DartWorker(callbackId: 'complex', input: complexInput);

      final map = worker.toMap();
      expect(map['input'], isA<String>());
      expect(map['input'], contains('string'));
      expect(map['input'], contains('nested'));
    });

    test('should handle empty input map', () {
      final worker = const DartWorker(callbackId: 'empty', input: {});

      final map = worker.toMap();
      expect(map['input'], isA<String>());
      expect(map['input'], '{}');
    });
  });

  group('HttpRequestWorker', () {
    test('should create HttpRequestWorker with GET request', () {
      final worker = const HttpRequestWorker(
        url: 'https://api.example.com/data',
        method: HttpMethod.get,
      );

      expect(worker.url, 'https://api.example.com/data');
      expect(worker.method, HttpMethod.get);
      expect(worker.headers, isEmpty);
      expect(worker.body, isNull);
    });

    test('should create HttpRequestWorker with POST request', () {
      final worker = const HttpRequestWorker(
        url: 'https://api.example.com/users',
        method: HttpMethod.post,
        headers: {'Content-Type': 'application/json'},
        body: '{"name": "John"}',
      );

      expect(worker.url, 'https://api.example.com/users');
      expect(worker.method, HttpMethod.post);
      expect(worker.headers, isNotEmpty);
      expect(worker.headers['Content-Type'], 'application/json');
      expect(worker.body, '{"name": "John"}');
    });

    test('should have correct workerClassName', () {
      final worker = const HttpRequestWorker(
        url: 'https://example.com',
        method: HttpMethod.get,
      );
      expect(worker.workerClassName, 'HttpRequestWorker');
    });

    test('should serialize GET request correctly', () {
      final worker = const HttpRequestWorker(
        url: 'https://api.example.com/data',
        method: HttpMethod.get,
      );

      final map = worker.toMap();

      expect(map['workerType'], 'httpRequest');
      expect(map['url'], 'https://api.example.com/data');
      expect(map['method'], 'get');
    });

    test('should serialize POST request correctly', () {
      final worker = const HttpRequestWorker(
        url: 'https://api.example.com/users',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer token123'},
        body: '{"name": "Alice"}',
      );

      final map = worker.toMap();

      expect(map['workerType'], 'httpRequest');
      expect(map['url'], 'https://api.example.com/users');
      expect(map['method'], 'post');
      expect(map['headers'], isA<Map>());
      expect(map['body'], '{"name": "Alice"}');
    });

    test('should handle all HTTP methods', () {
      final methods = [
        HttpMethod.get,
        HttpMethod.post,
        HttpMethod.put,
        HttpMethod.delete,
        HttpMethod.patch,
      ];

      for (final method in methods) {
        final worker = HttpRequestWorker(
          url: 'https://example.com',
          method: method,
        );
        final map = worker.toMap();
        expect(map['method'], method.name);
      }
    });

    test('should handle multiple headers', () {
      final worker = const HttpRequestWorker(
        url: 'https://api.example.com',
        method: HttpMethod.get,
        headers: {
          'Authorization': 'Bearer token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Custom-Header': 'custom-value',
        },
      );

      final map = worker.toMap();
      expect(map['headers'], isA<Map>());
      final headers = map['headers'] as Map;
      expect(headers['Authorization'], 'Bearer token');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['X-Custom-Header'], 'custom-value');
    });
  });

  group('HttpUploadWorker', () {
    test('should create HttpUploadWorker with required fields', () {
      final worker = const HttpUploadWorker(
        url: 'https://api.example.com/upload',
        filePath: '/path/to/file.jpg',
      );

      expect(worker.url, 'https://api.example.com/upload');
      expect(worker.filePath, '/path/to/file.jpg');
      expect(worker.fileFieldName, 'file'); // default
      expect(worker.headers, isEmpty);
      expect(worker.additionalFields, isEmpty);
    });

    test('should create HttpUploadWorker with custom fileFieldName', () {
      final worker = const HttpUploadWorker(
        url: 'https://api.example.com/upload',
        filePath: '/path/to/image.png',
        fileFieldName: 'photo',
      );

      expect(worker.fileFieldName, 'photo');
    });

    test(
      'should create HttpUploadWorker with headers and additionalFields',
      () {
        final worker = const HttpUploadWorker(
          url: 'https://api.example.com/upload',
          filePath: '/path/to/document.pdf',
          headers: {'Authorization': 'Bearer token'},
          additionalFields: {'userId': '123', 'category': 'documents'},
        );

        expect(worker.headers, isNotEmpty);
        expect(worker.headers['Authorization'], 'Bearer token');
        expect(worker.additionalFields, isNotEmpty);
        expect(worker.additionalFields['userId'], '123');
        expect(worker.additionalFields['category'], 'documents');
      },
    );

    test('should have correct workerClassName', () {
      final worker = const HttpUploadWorker(
        url: 'https://example.com/upload',
        filePath: '/path/to/file.jpg',
      );
      expect(worker.workerClassName, 'HttpUploadWorker');
    });

    test('should serialize to map correctly', () {
      final worker = const HttpUploadWorker(
        url: 'https://api.example.com/upload',
        filePath: '/storage/photos/image.jpg',
        fileFieldName: 'photo',
        headers: {'Authorization': 'Bearer token'},
        additionalFields: {'userId': '456', 'description': 'My photo'},
      );

      final map = worker.toMap();

      expect(map['workerType'], 'httpUpload');
      expect(map['url'], 'https://api.example.com/upload');
      expect(map['filePath'], '/storage/photos/image.jpg');
      expect(map['fileFieldName'], 'photo');
      expect(map['headers'], isA<Map>());
      expect(map['additionalFields'], isA<Map>());
    });

    test('should handle upload without optional fields', () {
      final worker = const HttpUploadWorker(
        url: 'https://example.com/upload',
        filePath: '/file.jpg',
      );

      final map = worker.toMap();

      expect(map['url'], 'https://example.com/upload');
      expect(map['filePath'], '/file.jpg');
      expect(map['fileFieldName'], 'file');
      expect(map['headers'], isEmpty);
      expect(map['additionalFields'], isEmpty);
    });

    test('should create HttpUploadWorker with background session enabled', () {
      final worker = const HttpUploadWorker(
        url: 'https://cdn.example.com/videos',
        filePath: '/videos/large-video.mp4',
        useBackgroundSession: true,
      );

      expect(worker.useBackgroundSession, isTrue);

      final map = worker.toMap();
      expect(map['useBackgroundSession'], isTrue);
    });

    test('should default useBackgroundSession to false for uploads', () {
      final worker = const HttpUploadWorker(
        url: 'https://api.example.com/upload',
        filePath: '/files/document.pdf',
      );

      expect(worker.useBackgroundSession, isFalse);

      final map = worker.toMap();
      expect(map['useBackgroundSession'], isFalse);
    });

    test('should combine background session with headers and fields', () {
      final worker = const HttpUploadWorker(
        url: 'https://cdn.example.com/media',
        filePath: '/videos/backup.mp4',
        fileFieldName: 'video',
        headers: {'Authorization': 'Bearer token'},
        additionalFields: {'userId': '789'},
        useBackgroundSession: true,
      );

      expect(worker.fileFieldName, 'video');
      expect(worker.headers['Authorization'], 'Bearer token');
      expect(worker.additionalFields['userId'], '789');
      expect(worker.useBackgroundSession, isTrue);

      final map = worker.toMap();
      expect(map['fileFieldName'], 'video');
      expect(map['headers'], isNotEmpty);
      expect(map['additionalFields'], isNotEmpty);
      expect(map['useBackgroundSession'], isTrue);
    });
  });

  group('HttpDownloadWorker', () {
    test('should create HttpDownloadWorker with required fields', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/file.pdf',
        savePath: '/downloads/file.pdf',
      );

      expect(worker.url, 'https://example.com/file.pdf');
      expect(worker.savePath, '/downloads/file.pdf');
      expect(worker.headers, isEmpty);
    });

    test('should create HttpDownloadWorker with headers', () {
      final worker = const HttpDownloadWorker(
        url: 'https://api.example.com/secure/file.zip',
        savePath: '/downloads/file.zip',
        headers: {'Authorization': 'Bearer token123'},
      );

      expect(worker.headers, isNotEmpty);
      expect(worker.headers['Authorization'], 'Bearer token123');
    });

    test('should have correct workerClassName', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/file.pdf',
        savePath: '/downloads/file.pdf',
      );
      expect(worker.workerClassName, 'HttpDownloadWorker');
    });

    test('should serialize to map correctly', () {
      final worker = const HttpDownloadWorker(
        url: 'https://cdn.example.com/videos/video.mp4',
        savePath: '/storage/videos/video.mp4',
        headers: {'Range': 'bytes=0-1023'},
      );

      final map = worker.toMap();

      expect(map['workerType'], 'httpDownload');
      expect(map['url'], 'https://cdn.example.com/videos/video.mp4');
      expect(map['savePath'], '/storage/videos/video.mp4');
      expect(map['headers'], isA<Map>());
    });

    test('should handle download without headers', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/public/file.txt',
        savePath: '/downloads/file.txt',
      );

      final map = worker.toMap();

      expect(map['url'], 'https://example.com/public/file.txt');
      expect(map['savePath'], '/downloads/file.txt');
      expect(map['headers'], isEmpty);
    });

    test('should handle various file types', () {
      final fileTypes = [
        {'url': 'https://example.com/doc.pdf', 'save': '/downloads/doc.pdf'},
        {'url': 'https://example.com/video.mp4', 'save': '/videos/video.mp4'},
        {'url': 'https://example.com/audio.mp3', 'save': '/music/audio.mp3'},
        {'url': 'https://example.com/image.jpg', 'save': '/photos/image.jpg'},
        {'url': 'https://example.com/data.json', 'save': '/data/data.json'},
      ];

      for (final fileType in fileTypes) {
        final worker = HttpDownloadWorker(
          url: fileType['url']!,
          savePath: fileType['save']!,
        );

        final map = worker.toMap();
        expect(map['url'], fileType['url']);
        expect(map['savePath'], fileType['save']);
      }
    });

    test('should create HttpDownloadWorker with resume enabled', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/large-file.zip',
        savePath: '/downloads/large-file.zip',
        enableResume: true,
      );

      expect(worker.enableResume, isTrue);

      final map = worker.toMap();
      expect(map['enableResume'], isTrue);
    });

    test('should create HttpDownloadWorker with resume disabled', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/small-file.txt',
        savePath: '/downloads/small-file.txt',
        enableResume: false,
      );

      expect(worker.enableResume, isFalse);

      final map = worker.toMap();
      expect(map['enableResume'], isFalse);
    });

    test('should create HttpDownloadWorker with checksum verification', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/update.apk',
        savePath: '/downloads/update.apk',
        expectedChecksum: 'a3b2c1d4e5f67890abcdef1234567890',
        checksumAlgorithm: 'SHA-256',
      );

      expect(worker.expectedChecksum, 'a3b2c1d4e5f67890abcdef1234567890');
      expect(worker.checksumAlgorithm, 'SHA-256');

      final map = worker.toMap();
      expect(map['expectedChecksum'], 'a3b2c1d4e5f67890abcdef1234567890');
      expect(map['checksumAlgorithm'], 'SHA-256');
    });

    test('should create HttpDownloadWorker with MD5 checksum', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/file.zip',
        savePath: '/downloads/file.zip',
        expectedChecksum: 'abc123def456',
        checksumAlgorithm: 'MD5',
      );

      expect(worker.checksumAlgorithm, 'MD5');

      final map = worker.toMap();
      expect(map['checksumAlgorithm'], 'MD5');
    });

    test('should not include expectedChecksum in map when null', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/file.pdf',
        savePath: '/downloads/file.pdf',
      );

      final map = worker.toMap();
      expect(map.containsKey('expectedChecksum'), isFalse);
      expect(map['checksumAlgorithm'], 'SHA-256'); // Default algorithm
    });

    test('should handle all parameters together', () {
      final worker = const HttpDownloadWorker(
        url: 'https://cdn.example.com/app-v2.0.0.apk',
        savePath: '/downloads/app.apk',
        headers: {'Authorization': 'Bearer xyz'},
        timeout: Duration(minutes: 30),
        enableResume: true,
        expectedChecksum: 'a3b2c1d4e5f67890',
        checksumAlgorithm: 'SHA-512',
      );

      expect(worker.url, 'https://cdn.example.com/app-v2.0.0.apk');
      expect(worker.savePath, '/downloads/app.apk');
      expect(worker.headers['Authorization'], 'Bearer xyz');
      expect(worker.timeout, const Duration(minutes: 30));
      expect(worker.enableResume, isTrue);
      expect(worker.expectedChecksum, 'a3b2c1d4e5f67890');
      expect(worker.checksumAlgorithm, 'SHA-512');

      final map = worker.toMap();
      expect(map['enableResume'], isTrue);
      expect(map['expectedChecksum'], 'a3b2c1d4e5f67890');
      expect(map['checksumAlgorithm'], 'SHA-512');
    });

    test('should create HttpDownloadWorker with background session enabled', () {
      final worker = const HttpDownloadWorker(
        url: 'https://cdn.example.com/large-file.mp4',
        savePath: '/downloads/video.mp4',
        useBackgroundSession: true,
      );

      expect(worker.useBackgroundSession, isTrue);

      final map = worker.toMap();
      expect(map['useBackgroundSession'], isTrue);
    });

    test('should default useBackgroundSession to false', () {
      final worker = const HttpDownloadWorker(
        url: 'https://example.com/file.txt',
        savePath: '/downloads/file.txt',
      );

      expect(worker.useBackgroundSession, isFalse);

      final map = worker.toMap();
      expect(map['useBackgroundSession'], isFalse);
    });

    test('should combine background session with resume and checksum', () {
      final worker = const HttpDownloadWorker(
        url: 'https://cdn.example.com/app-update.apk',
        savePath: '/downloads/update.apk',
        enableResume: true,
        expectedChecksum: 'abc123',
        checksumAlgorithm: 'SHA-256',
        useBackgroundSession: true,
      );

      expect(worker.enableResume, isTrue);
      expect(worker.expectedChecksum, 'abc123');
      expect(worker.useBackgroundSession, isTrue);

      final map = worker.toMap();
      expect(map['enableResume'], isTrue);
      expect(map['expectedChecksum'], 'abc123');
      expect(map['checksumAlgorithm'], 'SHA-256');
      expect(map['useBackgroundSession'], isTrue);
    });
  });

  group('HttpSyncWorker', () {
    test('should create HttpSyncWorker with required fields', () {
      final worker = const HttpSyncWorker(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
      );

      expect(worker.url, 'https://api.example.com/sync');
      expect(worker.method, HttpMethod.post);
      expect(worker.headers, isEmpty);
      expect(worker.requestBody, isNull);
    });

    test('should create HttpSyncWorker with headers and requestBody', () {
      final worker = const HttpSyncWorker(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
        headers: {'Content-Type': 'application/json'},
        requestBody: {'data': 'sync'},
      );

      expect(worker.headers, isNotEmpty);
      expect(worker.headers['Content-Type'], 'application/json');
      expect(worker.requestBody, isNotNull);
      expect(worker.requestBody?['data'], 'sync');
    });

    test('should have correct workerClassName', () {
      final worker = const HttpSyncWorker(
        url: 'https://example.com/sync',
        method: HttpMethod.post,
      );
      expect(worker.workerClassName, 'HttpSyncWorker');
    });

    test('should serialize to map correctly', () {
      final worker = const HttpSyncWorker(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer token'},
        requestBody: {
          'items': [1, 2, 3],
        },
      );

      final map = worker.toMap();

      expect(map['workerType'], 'httpSync');
      expect(map['url'], 'https://api.example.com/sync');
      expect(map['method'], 'post');
      expect(map['headers'], isA<Map>());
      expect(map['requestBody'], isA<String>());
      expect(map['requestBody'], contains('items'));
    });

    test('should handle all HTTP methods for sync', () {
      final methods = [
        HttpMethod.get,
        HttpMethod.post,
        HttpMethod.put,
        HttpMethod.patch,
      ];

      for (final method in methods) {
        final worker = HttpSyncWorker(
          url: 'https://example.com/sync',
          method: method,
        );
        final map = worker.toMap();
        expect(map['method'], method.name);
      }
    });

    test('should serialize without requestBody', () {
      final worker = const HttpSyncWorker(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
      );

      final map = worker.toMap();
      expect(map['requestBody'], isNull);
    });

    test('should handle complex JSON requestBody', () {
      final complexBody = {
        'user': {'name': 'John Doe', 'age': 30},
        'preferences': ['option1', 'option2'],
      };

      final worker = HttpSyncWorker(
        url: 'https://api.example.com/sync',
        method: HttpMethod.post,
        requestBody: complexBody,
      );

      final map = worker.toMap();
      expect(map['requestBody'], isA<String>());
      expect(map['requestBody'], contains('John Doe'));
    });
  });

  group('CustomNativeWorker', () {
    test('should create CustomNativeWorker with className only', () {
      final worker = const CustomNativeWorker(className: 'ImageCompressWorker');

      expect(worker.className, 'ImageCompressWorker');
      expect(worker.input, isNull);
    });

    test('should create CustomNativeWorker with input', () {
      final worker = const CustomNativeWorker(
        className: 'ImageCompressWorker',
        input: {'path': '/photo.jpg', 'quality': 85},
      );

      expect(worker.className, 'ImageCompressWorker');
      expect(worker.input, isNotNull);
      expect(worker.input?['path'], '/photo.jpg');
      expect(worker.input?['quality'], 85);
    });

    test('should have correct workerClassName', () {
      final worker = const CustomNativeWorker(className: 'MyCustomWorker');
      expect(worker.workerClassName, 'MyCustomWorker');
    });

    test('should serialize to map correctly', () {
      final worker = const CustomNativeWorker(
        className: 'ImageCompressWorker',
        input: {'inputPath': '/photo.jpg', 'quality': 90},
      );

      final map = worker.toMap();

      expect(map['workerType'], 'custom');
      expect(map['className'], 'ImageCompressWorker');
      expect(map['input'], isA<String>());
      expect(map['input'], contains('inputPath'));
      expect(map['input'], contains('quality'));
    });

    test('should serialize without input', () {
      final worker = const CustomNativeWorker(className: 'SimpleWorker');

      final map = worker.toMap();

      expect(map['workerType'], 'custom');
      expect(map['className'], 'SimpleWorker');
      expect(map['input'], isNull);
    });

    test('should handle complex input data', () {
      final complexInput = {
        'files': ['/photo1.jpg', '/photo2.jpg'],
        'settings': {'quality': 85, 'format': 'jpeg', 'preserveMetadata': true},
        'outputDir': '/compressed/',
      };

      final worker = CustomNativeWorker(
        className: 'BatchCompressWorker',
        input: complexInput,
      );

      final map = worker.toMap();
      expect(map['input'], isA<String>());
      expect(map['input'], contains('files'));
      expect(map['input'], contains('settings'));
    });

    test('should throw on empty className via NativeWorker.custom()', () {
      expect(
        () => NativeWorker.custom(className: '', input: {}),
        throwsArgumentError,
      );
    });

    test('should create via NativeWorker.custom() factory', () {
      final worker = NativeWorker.custom(
        className: 'TestWorker',
        input: {'test': true},
      );

      expect(worker, isA<CustomNativeWorker>());
      expect(worker.workerClassName, 'TestWorker');
    });

    test('should support various worker names', () {
      final workerNames = [
        'ImageCompressWorker',
        'EncryptionWorker',
        'DatabaseWorker',
        'FileArchiveWorker',
        'MLInferenceWorker',
      ];

      for (final name in workerNames) {
        final worker = CustomNativeWorker(className: name);
        expect(worker.className, name);
        expect(worker.workerClassName, name);
      }
    });
  });

  group('Worker edge cases', () {
    test('should handle very long URLs', () {
      final longUrl =
          'https://example.com/api/v1/very/long/path/${'with/many/segments/' * 10}';

      final worker = HttpRequestWorker(url: longUrl, method: HttpMethod.get);

      expect(worker.url, longUrl);
      final map = worker.toMap();
      expect(map['url'], longUrl);
    });

    test('should handle special characters in URLs', () {
      final specialUrl = 'https://example.com/api?param=value&other=123';

      final worker = HttpRequestWorker(url: specialUrl, method: HttpMethod.get);

      expect(worker.url, specialUrl);
      final map = worker.toMap();
      expect(map['url'], specialUrl);
    });

    test('should handle empty string body', () {
      final worker = const HttpRequestWorker(
        url: 'https://example.com',
        method: HttpMethod.post,
        body: '',
      );

      final map = worker.toMap();
      expect(map['body'], '');
    });

    test('should handle null values in DartWorker input', () {
      final worker = const DartWorker(
        callbackId: 'test',
        input: {'key': null, 'value': 'not null'},
      );

      final map = worker.toMap();
      expect(map['input'], isA<String>());
    });

    test('should handle timeout durations', () {
      final worker = const HttpRequestWorker(
        url: 'https://example.com',
        method: HttpMethod.get,
        timeout: Duration(minutes: 2),
      );

      final map = worker.toMap();
      expect(map['timeoutMs'], 120000); // 2 minutes in milliseconds
    });
  });
}
