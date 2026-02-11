import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Security tests for URL validation.
///
/// Tests that the library properly validates URL schemes to prevent
/// security vulnerabilities like SSRF (Server-Side Request Forgery).
void main() {
  group('URL Scheme Validation', () {
    test('allows https:// scheme', () {
      // Should not throw
      final worker = NativeWorker.httpRequest(
        url: 'https://api.example.com/endpoint',
        method: HttpMethod.get,
      );

      expect(worker, isNotNull);
      expect(worker.toMap()['url'], 'https://api.example.com/endpoint');
    });

    test('allows http:// scheme', () {
      // Should not throw (but may log warning)
      final worker = NativeWorker.httpRequest(
        url: 'http://api.example.com/endpoint',
        method: HttpMethod.get,
      );

      expect(worker, isNotNull);
      expect(worker.toMap()['url'], 'http://api.example.com/endpoint');
    });

    test('blocks file:// scheme', () {
      expect(
        () => NativeWorker.httpRequest(
          url: 'file:///etc/passwd',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    test('blocks javascript: scheme', () {
      expect(
        () => NativeWorker.httpRequest(
          url: 'javascript:alert(1)',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    test('blocks data: scheme', () {
      expect(
        () => NativeWorker.httpRequest(
          url: 'data:text/html,<script>alert(1)</script>',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    test('blocks ftp: scheme', () {
      expect(
        () => NativeWorker.httpRequest(
          url: 'ftp://ftp.example.com/file.txt',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    test('blocks content:// scheme (Android)', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'content://com.android.providers.media/file',
          savePath: '/tmp/stolen',
        ),
        throwsArgumentError,
      );
    });

    test('blocks missing scheme', () {
      expect(
        () => NativeWorker.httpRequest(
          url: 'example.com/endpoint',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    test('blocks empty URL', () {
      expect(
        () => NativeWorker.httpRequest(
          url: '',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed URLs', () {
      expect(
        () => NativeWorker.httpRequest(
          url: 'not a url at all',
          method: HttpMethod.get,
        ),
        throwsArgumentError,
      );
    });

    group('HttpDownloadWorker URL validation', () {
      test('allows valid https URL', () {
        final worker = NativeWorker.httpDownload(
          url: 'https://cdn.example.com/file.zip',
          savePath: '/tmp/file.zip',
        );

        expect(worker, isNotNull);
      });

      test('blocks file:// in download', () {
        expect(
          () => NativeWorker.httpDownload(
            url: 'file:///etc/passwd',
            savePath: '/tmp/stolen',
          ),
          throwsArgumentError,
        );
      });
    });

    group('HttpUploadWorker URL validation', () {
      test('allows valid https URL', () {
        final worker = NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file.jpg',
        );

        expect(worker, isNotNull);
      });

      test('blocks invalid scheme', () {
        expect(
          () => NativeWorker.httpUpload(
            url: 'file:///etc/passwd',
            filePath: '/tmp/file.jpg',
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
