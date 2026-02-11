import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Security tests for resource exhaustion protection.
///
/// Tests that the library properly limits resource usage to prevent
/// DoS attacks via excessive memory/disk usage.
void main() {
  group('Resource Exhaustion Protection', () {
    group('Timeout Validation', () {
      test('rejects unreasonably long timeouts for HTTP requests', () {
        expect(
          () => NativeWorker.httpRequest(
            url: 'https://example.com/endpoint',
            method: HttpMethod.get,
            timeout: const Duration(minutes: 10),
          ),
          throwsArgumentError,
        );
      });

      test('allows reasonable timeouts for downloads', () {
        final worker = NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/file.zip',
          timeout: const Duration(minutes: 5),
        );

        expect(worker, isNotNull);
      });

      test('rejects very long upload timeouts', () {
        expect(
          () => NativeWorker.httpUpload(
            url: 'https://api.example.com/upload',
            filePath: '/tmp/file.jpg',
            timeout: const Duration(minutes: 15),
          ),
          throwsArgumentError,
        );
      });
    });

    group('Additional Fields Validation', () {
      test('allows reasonable number of fields', () {
        final fields = Map<String, String>.fromIterable(
          List.generate(10, (i) => 'field$i'),
          value: (key) => 'value_$key',
        );

        final worker = NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file.jpg',
          additionalFields: fields,
        );

        expect(worker, isNotNull);
      });

      test('rejects too many additional fields (> 50)', () {
        final fields = Map<String, String>.fromIterable(
          List.generate(51, (i) => 'field$i'),
          value: (key) => 'value_$key',
        );

        expect(
          () => NativeWorker.httpUpload(
            url: 'https://api.example.com/upload',
            filePath: '/tmp/file.jpg',
            additionalFields: fields,
          ),
          throwsArgumentError,
        );
      });

      test('rejects empty additional field names', () {
        expect(
          () => NativeWorker.httpUpload(
            url: 'https://api.example.com/upload',
            filePath: '/tmp/file.jpg',
            additionalFields: {'': 'value'},
          ),
          throwsArgumentError,
        );
      });
    });

    group('Image Quality Validation', () {
      test('allows valid quality (0-100)', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/tmp/input.jpg',
          outputPath: '/tmp/output.jpg',
          quality: 85,
        );

        expect(worker, isNotNull);
      });

      test('rejects quality < 0', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/tmp/input.jpg',
            outputPath: '/tmp/output.jpg',
            quality: -1,
          ),
          throwsArgumentError,
        );
      });

      test('rejects quality > 100', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/tmp/input.jpg',
            outputPath: '/tmp/output.jpg',
            quality: 101,
          ),
          throwsArgumentError,
        );
      });
    });

    group('Image Dimensions Validation', () {
      test('allows positive dimensions', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/tmp/input.jpg',
          outputPath: '/tmp/output.jpg',
          maxWidth: 1920,
          maxHeight: 1080,
        );

        expect(worker, isNotNull);
      });

      test('rejects zero width', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/tmp/input.jpg',
            outputPath: '/tmp/output.jpg',
            maxWidth: 0,
          ),
          throwsArgumentError,
        );
      });

      test('rejects negative height', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/tmp/input.jpg',
            outputPath: '/tmp/output.jpg',
            maxHeight: -100,
          ),
          throwsArgumentError,
        );
      });
    });

    group('Password Strength Validation', () {
      test('allows strong passwords', () {
        final worker = NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/input.dat',
          outputPath: '/tmp/output.enc',
          password: 'MyStr0ng!Password',
        );

        expect(worker, isNotNull);
      });

      test('rejects empty passwords', () {
        expect(
          () => NativeWorker.cryptoEncrypt(
            inputPath: '/tmp/input.dat',
            outputPath: '/tmp/output.enc',
            password: '',
          ),
          throwsArgumentError,
        );
      });

      test('rejects weak passwords (< 8 chars)', () {
        expect(
          () => NativeWorker.cryptoEncrypt(
            inputPath: '/tmp/input.dat',
            outputPath: '/tmp/output.enc',
            password: 'weak',
          ),
          throwsArgumentError,
        );
      });

      test('allows minimum 8 character passwords', () {
        final worker = NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/input.dat',
          outputPath: '/tmp/output.enc',
          password: '12345678',
        );

        expect(worker, isNotNull);
      });
    });

    group('File Extension Validation', () {
      test('requires .zip extension for file compression', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/tmp/input',
            outputPath: '/tmp/output.tar.gz',
          ),
          throwsArgumentError,
        );
      });

      test('allows .zip extension', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/tmp/input',
          outputPath: '/tmp/output.zip',
        );

        expect(worker, isNotNull);
      });

      test('requires .zip extension for file decompression', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/tmp/input.tar.gz',
            targetDir: '/tmp/output',
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
