import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Security tests for path traversal protection.
///
/// Tests that the library properly validates file paths to prevent
/// path traversal attacks (e.g., ../../../etc/passwd).
void main() {
  group('Path Traversal Protection', () {
    group('FileDecompressionWorker', () {
      test('allows normal paths', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/tmp/archive.zip',
          targetDir: '/tmp/extracted',
        );

        expect(worker, isNotNull);
      });

      test('blocks .. in zipPath', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/tmp/../../../etc/passwd',
            targetDir: '/tmp/safe',
          ),
          throwsArgumentError,
        );
      });

      test('blocks .. in targetDir', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/tmp/safe.zip',
            targetDir: '/tmp/../../../etc',
          ),
          throwsArgumentError,
        );
      });

      test('blocks relative paths', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: 'relative/path/archive.zip',
            targetDir: '/tmp/safe',
          ),
          throwsArgumentError,
        );
      });
    });

    group('FileCompressionWorker', () {
      test('allows normal paths', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/tmp/input',
          outputPath: '/tmp/output.zip',
        );

        expect(worker, isNotNull);
      });

      test('blocks .. in inputPath', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/tmp/../../../etc/passwd',
            outputPath: '/tmp/safe.zip',
          ),
          throwsArgumentError,
        );
      });

      test('blocks .. in outputPath', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/tmp/safe',
            outputPath: '/tmp/../../../etc/evil.zip',
          ),
          throwsArgumentError,
        );
      });
    });

    group('HttpDownloadWorker', () {
      test('allows normal save paths', () {
        final worker = NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/download.zip',
        );

        expect(worker, isNotNull);
      });

      test('blocks .. in savePath', () {
        expect(
          () => NativeWorker.httpDownload(
            url: 'https://example.com/file.zip',
            savePath: '/tmp/../../../etc/passwd',
          ),
          throwsArgumentError,
        );
      });
    });

    group('HttpUploadWorker', () {
      test('allows normal file paths', () {
        final worker = NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file.jpg',
        );

        expect(worker, isNotNull);
      });

      test('blocks .. in filePath', () {
        expect(
          () => NativeWorker.httpUpload(
            url: 'https://api.example.com/upload',
            filePath: '/tmp/../../../etc/passwd',
          ),
          throwsArgumentError,
        );
      });
    });

    group('ImageProcessWorker', () {
      test('allows normal paths', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/tmp/input.jpg',
          outputPath: '/tmp/output.jpg',
        );

        expect(worker, isNotNull);
      });

      test('blocks .. in inputPath', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/tmp/../../../etc/passwd',
            outputPath: '/tmp/output.jpg',
          ),
          throwsArgumentError,
        );
      });

      test('blocks .. in outputPath', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/tmp/input.jpg',
            outputPath: '/tmp/../../../etc/evil.jpg',
          ),
          throwsArgumentError,
        );
      });
    });

    group('CryptoWorker', () {
      test('allows normal paths for encryption', () {
        final worker = NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/input.dat',
          outputPath: '/tmp/output.enc',
          password: 'password123',
        );

        expect(worker, isNotNull);
      });

      test('blocks .. in encryption inputPath', () {
        expect(
          () => NativeWorker.cryptoEncrypt(
            inputPath: '/tmp/../../../etc/passwd',
            outputPath: '/tmp/output.enc',
            password: 'password123',
          ),
          throwsArgumentError,
        );
      });

      test('allows normal paths for decryption', () {
        final worker = NativeWorker.cryptoDecrypt(
          inputPath: '/tmp/input.enc',
          outputPath: '/tmp/output.dat',
          password: 'password123',
        );

        expect(worker, isNotNull);
      });
    });

    test('blocks empty file paths', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
