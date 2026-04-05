// Tests for Media & Processing bug fixes (MEDIA-001 … MEDIA-015).
//
// Most MEDIA fixes live in native code (Android/iOS) and are verified by the
// integration-test suite. This file covers the Dart-layer contracts:
//   • Serialisation correctness (toMap round-trips)
//   • Field validation that the Dart layer enforces
//   • API contracts documented by the QA fixes

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // ImageProcessWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('ImageProcessWorker toMap serialisation', () {
    test('minimal worker serialises correctly', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
      );
      final map = w.toMap();
      expect(map['inputPath'], '/tmp/in.jpg');
      expect(map['outputPath'], '/tmp/out.jpg');
      expect(map['maintainAspectRatio'], true);
      expect(map['quality'], 85);
      expect(map['deleteOriginal'], false);
      expect(map.containsKey('cropRect'), false);
    });

    test('quality is stored as-is within valid range', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
        quality: 60,
      );
      expect(w.toMap()['quality'], 60);
    });

    test('outputFormat is serialised as enum value string', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
        outputFormat: ImageFormat.png,
      );
      expect(w.toMap()['outputFormat'], 'png');
    });

    // MEDIA-007 companion: cropRect must be serialised as integer fields so
    // the native parseConfig receives correct values.
    test('cropRect is serialised as integer x/y/width/height', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
        cropRect: const Rect.fromLTWH(10, 20, 300, 200),
      );
      final crop = w.toMap()['cropRect'] as Map<String, dynamic>;
      expect(crop['x'], 10);
      expect(crop['y'], 20);
      expect(crop['width'], 300);
      expect(crop['height'], 200);
    });

    test('deleteOriginal flag serialises correctly', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
        deleteOriginal: true,
      );
      expect(w.toMap()['deleteOriginal'], true);
    });

    test('maxWidth and maxHeight are omitted when null', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
      );
      final map = w.toMap();
      expect(map.containsKey('maxWidth'), false);
      expect(map.containsKey('maxHeight'), false);
    });

    test('maxWidth and maxHeight serialise when set', () {
      final w = ImageProcessWorker(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
        maxWidth: 1920,
        maxHeight: 1080,
      );
      expect(w.toMap()['maxWidth'], 1920);
      expect(w.toMap()['maxHeight'], 1080);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FileCompressionWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileCompressionWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      final w = FileCompressionWorker(
        inputPath: '/tmp/logs',
        outputPath: '/tmp/logs.zip',
      );
      final map = w.toMap();
      expect(map['inputPath'], '/tmp/logs');
      expect(map['outputPath'], '/tmp/logs.zip');
      expect(map['compressionLevel'], 'medium');
      expect(map['excludePatterns'], isEmpty);
      expect(map['deleteOriginal'], false);
    });

    test('high compression level serialises', () {
      final w = FileCompressionWorker(
        inputPath: '/tmp/logs',
        outputPath: '/tmp/logs.zip',
        level: CompressionLevel.high,
      );
      expect(w.toMap()['compressionLevel'], 'high');
    });

    test('excludePatterns serialises as list', () {
      final w = FileCompressionWorker(
        inputPath: '/tmp/logs',
        outputPath: '/tmp/logs.zip',
        excludePatterns: ['*.tmp', '.DS_Store'],
      );
      expect(w.toMap()['excludePatterns'], ['*.tmp', '.DS_Store']);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MoveToSharedStorageWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('MoveToSharedStorageWorker toMap serialisation', () {
    test('storageType serialises as enum name', () {
      for (final type in SharedStorageType.values) {
        final w = MoveToSharedStorageWorker(
          sourcePath: '/tmp/file.jpg',
          storageType: type,
        );
        expect(w.toMap()['storageType'], type.name,
            reason: 'storageType.$type must serialise as "${type.name}"');
      }
    });

    test('optional fields omitted when null', () {
      final w = MoveToSharedStorageWorker(
        sourcePath: '/tmp/file.jpg',
        storageType: SharedStorageType.downloads,
      );
      final map = w.toMap();
      expect(map.containsKey('fileName'), false);
      expect(map.containsKey('mimeType'), false);
      expect(map.containsKey('subDir'), false);
    });

    test('optional fields serialise when set', () {
      final w = MoveToSharedStorageWorker(
        sourcePath: '/tmp/file.jpg',
        storageType: SharedStorageType.photos,
        fileName: 'vacation.jpg',
        mimeType: 'image/jpeg',
        subDir: 'MyApp',
      );
      final map = w.toMap();
      expect(map['fileName'], 'vacation.jpg');
      expect(map['mimeType'], 'image/jpeg');
      expect(map['subDir'], 'MyApp');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NativeWorker convenience constructors for media workers
  // ──────────────────────────────────────────────────────────────────────────

  group('NativeWorker.imageProcess convenience constructor', () {
    test('produces correct workerType and class name', () {
      final w = NativeWorker.imageProcess(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
      );
      expect(w.workerClassName, 'ImageProcessWorker');
      expect(w.toMap()['workerType'], 'imageProcess');
    });

    test('quality is forwarded', () {
      final w = NativeWorker.imageProcess(
        inputPath: '/tmp/in.jpg',
        outputPath: '/tmp/out.jpg',
        quality: 50,
      );
      expect(w.toMap()['quality'], 50);
    });
  });

  group('NativeWorker.fileCompress convenience constructor', () {
    test('produces correct workerType and class name', () {
      final w = NativeWorker.fileCompress(
        inputPath: '/tmp/dir',
        outputPath: '/tmp/dir.zip',
      );
      expect(w.workerClassName, 'FileCompressionWorker');
      expect(w.toMap()['workerType'], 'fileCompress');
    });
  });
}
