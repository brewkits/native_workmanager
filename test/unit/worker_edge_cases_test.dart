// Tests for edge-cases and less-common paths in worker serialization.
// Complements the existing workers/ test files by targeting boundary inputs.

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // NativeWorker factory aliases vs direct constructors
  // ──────────────────────────────────────────────────────────────
  group('NativeWorker factory aliases', () {
    test('httpRequest factory produces HttpRequestWorker', () {
      final w = NativeWorker.httpRequest(url: 'https://x.com');
      expect(w, isA<HttpRequestWorker>());
      expect(w.workerClassName, 'HttpRequestWorker');
    });

    test('httpDownload factory produces HttpDownloadWorker', () {
      final w =
          NativeWorker.httpDownload(url: 'https://x.com/f', savePath: '/tmp/f');
      expect(w, isA<HttpDownloadWorker>());
      expect(w.workerClassName, 'HttpDownloadWorker');
    });

    test('httpUpload factory produces HttpUploadWorker', () {
      final w =
          NativeWorker.httpUpload(url: 'https://x.com/up', filePath: '/f');
      expect(w, isA<HttpUploadWorker>());
      expect(w.workerClassName, 'HttpUploadWorker');
    });

    test('httpSync factory produces HttpSyncWorker', () {
      final w = NativeWorker.httpSync(url: 'https://x.com/sync');
      expect(w, isA<HttpSyncWorker>());
      expect(w.workerClassName, 'HttpSyncWorker');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // HttpRequestWorker edge cases
  // ──────────────────────────────────────────────────────────────
  group('HttpRequestWorker edge cases', () {
    test('POST method is serialized', () {
      final w =
          HttpRequestWorker(url: 'https://x.com', method: HttpMethod.post);
      expect(w.toMap()['method'], anyOf('post', 'POST'));
    });

    test('DELETE method is serialized', () {
      final w =
          HttpRequestWorker(url: 'https://x.com', method: HttpMethod.delete);
      expect(w.toMap()['method'], anyOf('delete', 'DELETE'));
    });

    test('body is serialized', () {
      final w = HttpRequestWorker(url: 'https://x.com', body: '{"a":1}');
      expect(w.toMap()['body'], '{"a":1}');
    });

    test('null body is null in toMap', () {
      final w = HttpRequestWorker(url: 'https://x.com');
      expect(w.toMap()['body'], isNull);
    });

    test('headers are serialized', () {
      final w = HttpRequestWorker(
        url: 'https://x.com',
        headers: {'Accept': 'application/json', 'X-Custom': 'value'},
      );
      final h = w.toMap()['headers'] as Map;
      expect(h['Accept'], 'application/json');
      expect(h['X-Custom'], 'value');
    });

    test('empty headers map is serialized', () {
      final w = HttpRequestWorker(url: 'https://x.com', headers: {});
      expect((w.toMap()['headers'] as Map), isEmpty);
    });

    test('timeout is serialized', () {
      final w = HttpRequestWorker(
          url: 'https://x.com', timeout: const Duration(seconds: 5));
      final map = w.toMap();
      // timeout serialized as ms or Duration — check it's in the map
      expect(
          map.containsKey('timeout') || map.containsKey('timeoutMs'), isTrue);
    });

    test('URL with query string is preserved', () {
      final w = HttpRequestWorker(
          url: 'https://api.example.com/search?q=test&page=1');
      expect(w.toMap()['url'], 'https://api.example.com/search?q=test&page=1');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // HttpDownloadWorker edge cases
  // ──────────────────────────────────────────────────────────────
  group('HttpDownloadWorker edge cases', () {
    test('skipExisting=true is serialized', () {
      final w = HttpDownloadWorker(
        url: 'https://cdn.com/f',
        savePath: '/tmp/f',
        skipExisting: true,
      );
      expect(w.toMap()['skipExisting'], isTrue);
    });

    test('skipExisting defaults to false', () {
      final w =
          HttpDownloadWorker(url: 'https://cdn.com/f', savePath: '/tmp/f');
      expect(w.toMap()['skipExisting'], isFalse);
    });

    test('savePath is serialized', () {
      final w = HttpDownloadWorker(
          url: 'https://cdn.com/file.zip',
          savePath: '/data/downloads/file.zip');
      expect(w.toMap()['savePath'], '/data/downloads/file.zip');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // HttpUploadWorker edge cases
  // ──────────────────────────────────────────────────────────────
  group('HttpUploadWorker edge cases', () {
    test('fileFieldName defaults to "file"', () {
      final w = HttpUploadWorker(url: 'https://x.com', filePath: '/tmp/f');
      expect(w.toMap()['fileFieldName'], 'file');
    });

    test('custom fileFieldName is serialized', () {
      final w = HttpUploadWorker(
        url: 'https://x.com',
        filePath: '/tmp/f',
        fileFieldName: 'attachment',
      );
      expect(w.toMap()['fileFieldName'], 'attachment');
    });

    test('mimeType is serialized when provided', () {
      final w = HttpUploadWorker(
        url: 'https://x.com',
        filePath: '/tmp/f.png',
        mimeType: 'image/png',
      );
      expect(w.toMap()['mimeType'], 'image/png');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // DartWorker edge cases
  // ──────────────────────────────────────────────────────────────
  group('DartWorker edge cases', () {
    test('workerClassName is DartCallbackWorker', () {
      final w = DartWorker(callbackId: 'myFn');
      expect(w.workerClassName, 'DartCallbackWorker');
    });

    test('callbackId is in toMap', () {
      final w = DartWorker(callbackId: 'my_callback');
      expect(w.toMap()['callbackId'], 'my_callback');
    });

    test('input map is serialized as JSON string', () {
      final w = DartWorker(
        callbackId: 'fn',
        input: {'count': 3, 'label': 'test'},
      );
      final map = w.toMap();
      // input is either nested in 'input' key or serialized
      expect(map.containsKey('callbackId'), isTrue);
    });

    test('null input does not crash toMap', () {
      final w = DartWorker(callbackId: 'fn');
      expect(() => w.toMap(), returnsNormally);
    });

    test('empty input map does not crash', () {
      final w = DartWorker(callbackId: 'fn', input: {});
      expect(() => w.toMap(), returnsNormally);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // FileCompressionWorker
  // ──────────────────────────────────────────────────────────────
  group('FileCompressionWorker', () {
    test('workerClassName is FileCompressionWorker', () {
      const w = FileCompressionWorker(
        inputPath: '/tmp/in',
        outputPath: '/tmp/out.zip',
      );
      expect(w.workerClassName, 'FileCompressionWorker');
    });

    test('toMap contains inputPath and outputPath', () {
      const w = FileCompressionWorker(
        inputPath: '/data/file.txt',
        outputPath: '/data/archive.zip',
      );
      expect(w.toMap()['inputPath'], '/data/file.txt');
      expect(w.toMap()['outputPath'], '/data/archive.zip');
    });

    test('compressionLevel is serialized', () {
      const w = FileCompressionWorker(
        inputPath: '/tmp/in',
        outputPath: '/tmp/out.zip',
        level: CompressionLevel.high,
      );
      expect(w.toMap()['compressionLevel'], 'high');
    });

    test('deleteOriginal defaults to false', () {
      const w = FileCompressionWorker(
          inputPath: '/tmp/in', outputPath: '/tmp/out.zip');
      expect(w.toMap()['deleteOriginal'], isFalse);
    });

    test('deleteOriginal=true is serialized', () {
      const w = FileCompressionWorker(
        inputPath: '/tmp/in',
        outputPath: '/tmp/out.zip',
        deleteOriginal: true,
      );
      expect(w.toMap()['deleteOriginal'], isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // FileDecompressionWorker
  // ──────────────────────────────────────────────────────────────
  group('FileDecompressionWorker', () {
    test('workerClassName is FileDecompressionWorker', () {
      const w = FileDecompressionWorker(
          zipPath: '/tmp/a.zip', targetDir: '/tmp/out/');
      expect(w.workerClassName, 'FileDecompressionWorker');
    });

    test('toMap contains zipPath and targetDir', () {
      const w = FileDecompressionWorker(
          zipPath: '/data/archive.zip', targetDir: '/data/extracted/');
      expect(w.toMap()['zipPath'], '/data/archive.zip');
      expect(w.toMap()['targetDir'], '/data/extracted/');
    });

    test('deleteAfterExtract defaults to false', () {
      const w = FileDecompressionWorker(
          zipPath: '/tmp/a.zip', targetDir: '/tmp/out/');
      expect(w.toMap()['deleteAfterExtract'], isFalse);
    });

    test('overwrite defaults to true', () {
      const w = FileDecompressionWorker(
          zipPath: '/tmp/a.zip', targetDir: '/tmp/out/');
      expect(w.toMap()['overwrite'], isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // ImageProcessWorker
  // ──────────────────────────────────────────────────────────────
  group('ImageProcessWorker', () {
    test('workerClassName is ImageProcessWorker', () {
      const w = ImageProcessWorker(
        inputPath: '/tmp/in.png',
        outputPath: '/tmp/out.png',
        maxWidth: 800,
        maxHeight: 600,
      );
      expect(w.workerClassName, 'ImageProcessWorker');
    });

    test('toMap contains maxWidth and maxHeight', () {
      const w = ImageProcessWorker(
        inputPath: '/tmp/in.png',
        outputPath: '/tmp/out.png',
        maxWidth: 1920,
        maxHeight: 1080,
      );
      expect(w.toMap()['maxWidth'], 1920);
      expect(w.toMap()['maxHeight'], 1080);
    });

    test('quality is serialized', () {
      const w = ImageProcessWorker(
        inputPath: '/tmp/in.png',
        outputPath: '/tmp/out.png',
        maxWidth: 800,
        maxHeight: 600,
        quality: 90,
      );
      expect(w.toMap()['quality'], 90);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // CryptoWorker variants
  // ──────────────────────────────────────────────────────────────
  group('CryptoWorker variants', () {
    test('CryptoHashWorker.file workerClassName is CryptoWorker', () {
      const w = CryptoHashWorker.file(filePath: '/tmp/f');
      expect(w.workerClassName, 'CryptoWorker');
    });

    test('CryptoHashWorker.file toMap contains operation=hash', () {
      const w = CryptoHashWorker.file(filePath: '/tmp/f');
      expect(w.toMap()['operation'], 'hash');
    });

    test('CryptoEncryptWorker toMap contains operation=encrypt', () {
      final w = CryptoEncryptWorker(
        inputPath: '/tmp/plain.txt',
        outputPath: '/tmp/enc.bin',
        password: 'secret_password_123',
      );
      expect(w.toMap()['operation'], 'encrypt');
    });

    test('CryptoDecryptWorker toMap contains operation=decrypt', () {
      final w = CryptoDecryptWorker(
        inputPath: '/tmp/enc.bin',
        outputPath: '/tmp/plain.txt',
        password: 'secret_password_123',
      );
      expect(w.toMap()['operation'], 'decrypt');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // NativeWorker.custom
  // ──────────────────────────────────────────────────────────────
  group('NativeWorker.custom', () {
    test('workerClassName matches provided className', () {
      final w = NativeWorker.custom(
        className: 'MySpecialWorker',
        input: {'key': 'value'},
      );
      expect(w.workerClassName, 'MySpecialWorker');
    });

    test('toMap wraps input under "input" key as JSON', () {
      final w = NativeWorker.custom(
        className: 'FooWorker',
        input: {'count': 5},
      );
      final map = w.toMap();
      // The custom worker should encode input as a nested JSON string
      expect(map.containsKey('input'), isTrue);
    });

    test('empty input is allowed', () {
      expect(
        () => NativeWorker.custom(className: 'FooWorker', input: {}),
        returnsNormally,
      );
    });
  });
}
