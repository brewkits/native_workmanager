import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('ImageProcessWorker', () {
    group('Constructor and Basic Properties', () {
      test('should create ImageProcessWorker with required fields only', () {
        final worker = const ImageProcessWorker(
          inputPath: '/photos/image.jpg',
          outputPath: '/processed/output.jpg',
        );

        expect(worker.inputPath, '/photos/image.jpg');
        expect(worker.outputPath, '/processed/output.jpg');
        expect(worker.maxWidth, isNull);
        expect(worker.maxHeight, isNull);
        expect(worker.maintainAspectRatio, true); // default
        expect(worker.quality, 85); // default
        expect(worker.outputFormat, isNull);
        expect(worker.cropRect, isNull);
        expect(worker.deleteOriginal, false); // default
      });

      test('should create ImageProcessWorker with all fields', () {
        final worker = ImageProcessWorker(
          inputPath: '/photos/large.png',
          outputPath: '/photos/thumb.webp',
          maxWidth: 1920,
          maxHeight: 1080,
          maintainAspectRatio: false,
          quality: 90,
          outputFormat: ImageFormat.webp,
          cropRect: const Rect.fromLTWH(100, 100, 800, 600),
          deleteOriginal: true,
        );

        expect(worker.inputPath, '/photos/large.png');
        expect(worker.outputPath, '/photos/thumb.webp');
        expect(worker.maxWidth, 1920);
        expect(worker.maxHeight, 1080);
        expect(worker.maintainAspectRatio, false);
        expect(worker.quality, 90);
        expect(worker.outputFormat, ImageFormat.webp);
        expect(worker.cropRect, isNotNull);
        expect(worker.deleteOriginal, true);
      });

      test('should have correct workerClassName', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
        );

        expect(worker.workerClassName, 'ImageProcessWorker');
      });
    });

    group('NativeWorker.imageProcess Factory', () {
      test('should create worker through NativeWorker factory', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/original.jpg',
          outputPath: '/photos/resized.jpg',
        );

        expect(worker, isA<ImageProcessWorker>());
        expect((worker as ImageProcessWorker).inputPath, '/photos/original.jpg');
        expect(worker.outputPath, '/photos/resized.jpg');
      });

      test('should create worker with resize dimensions', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/4k.jpg',
          outputPath: '/photos/hd.jpg',
          maxWidth: 1920,
          maxHeight: 1080,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, 1920);
        expect(image.maxHeight, 1080);
      });

      test('should create worker with custom quality', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/image.jpg',
          outputPath: '/photos/compressed.jpg',
          quality: 60,
        );

        expect((worker as ImageProcessWorker).quality, 60);
      });

      test('should create worker with output format conversion', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/image.png',
          outputPath: '/photos/image.webp',
          outputFormat: ImageFormat.webp,
        );

        expect((worker as ImageProcessWorker).outputFormat, ImageFormat.webp);
      });
    });

    group('ImageFormat Enum', () {
      test('should support ImageFormat.jpeg', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.png',
          outputPath: '/image.jpg',
          outputFormat: ImageFormat.jpeg,
        );

        expect(worker.outputFormat, ImageFormat.jpeg);
        expect(worker.outputFormat!.value, 'jpeg');
      });

      test('should support ImageFormat.png', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/image.png',
          outputFormat: ImageFormat.png,
        );

        expect(worker.outputFormat, ImageFormat.png);
        expect(worker.outputFormat!.value, 'png');
      });

      test('should support ImageFormat.webp', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/image.webp',
          outputFormat: ImageFormat.webp,
        );

        expect(worker.outputFormat, ImageFormat.webp);
        expect(worker.outputFormat!.value, 'webp');
      });

      test('should allow null outputFormat (keep original format)', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/resized.jpg',
          outputFormat: null,
        );

        expect(worker.outputFormat, isNull);
      });
    });

    group('Validation', () {
      test('should throw ArgumentError for empty inputPath', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '',
            outputPath: '/output.jpg',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty outputPath', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for invalid quality (<0)', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            quality: -1,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('quality must be between 0 and 100'),
            ),
          ),
        );
      });

      test('should throw ArgumentError for invalid quality (>100)', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            quality: 101,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('quality must be between 0 and 100'),
            ),
          ),
        );
      });

      test('should accept quality = 0', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            quality: 0,
          ),
          returnsNormally,
        );
      });

      test('should accept quality = 100', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            quality: 100,
          ),
          returnsNormally,
        );
      });

      test('should throw ArgumentError for negative maxWidth', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            maxWidth: -100,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for negative maxHeight', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            maxHeight: -100,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for zero maxWidth', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            maxWidth: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for zero maxHeight', () {
        expect(
          () => NativeWorker.imageProcess(
            inputPath: '/image.jpg',
            outputPath: '/output.jpg',
            maxHeight: 0,
          ),
          throwsArgumentError,
        );
      });
    });

    group('Resize Operations', () {
      test('should support width-only resize', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/image.jpg',
          outputPath: '/resized.jpg',
          maxWidth: 800,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, 800);
        expect(image.maxHeight, isNull);
      });

      test('should support height-only resize', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/image.jpg',
          outputPath: '/resized.jpg',
          maxHeight: 600,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, isNull);
        expect(image.maxHeight, 600);
      });

      test('should support both width and height resize', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/image.jpg',
          outputPath: '/resized.jpg',
          maxWidth: 1920,
          maxHeight: 1080,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, 1920);
        expect(image.maxHeight, 1080);
      });

      test('should maintain aspect ratio by default', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/resized.jpg',
        );

        expect(worker.maintainAspectRatio, true);
      });

      test('should allow disabling aspect ratio', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/resized.jpg',
          maintainAspectRatio: false,
        );

        expect(worker.maintainAspectRatio, false);
      });
    });

    group('Quality Settings', () {
      test('should default quality to 85', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
        );

        expect(worker.quality, 85);
      });

      test('should support low quality (60)', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
          quality: 60,
        );

        expect(worker.quality, 60);
      });

      test('should support high quality (95)', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
          quality: 95,
        );

        expect(worker.quality, 95);
      });
    });

    group('Crop Rectangle', () {
      test('should support crop rectangle', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/cropped.jpg',
          cropRect: const Rect.fromLTWH(0, 0, 500, 500),
        );

        expect(worker.cropRect, isNotNull);
        expect(worker.cropRect!.left, 0);
        expect(worker.cropRect!.top, 0);
        expect(worker.cropRect!.width, 500);
        expect(worker.cropRect!.height, 500);
      });

      test('should support crop with offset', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/cropped.jpg',
          cropRect: const Rect.fromLTWH(100, 200, 300, 400),
        );

        expect(worker.cropRect!.left, 100);
        expect(worker.cropRect!.top, 200);
        expect(worker.cropRect!.width, 300);
        expect(worker.cropRect!.height, 400);
      });

      test('should allow null cropRect (no cropping)', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
          cropRect: null,
        );

        expect(worker.cropRect, isNull);
      });
    });

    group('Serialization', () {
      test('should serialize to map with minimal fields', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
        );

        final map = worker.toMap();

        expect(map['workerType'], 'imageProcess');
        expect(map['inputPath'], '/image.jpg');
        expect(map['outputPath'], '/output.jpg');
        expect(map['maintainAspectRatio'], true);
        expect(map['quality'], 85);
        expect(map['deleteOriginal'], false);
        expect(map['maxWidth'], isNull);
        expect(map['maxHeight'], isNull);
        expect(map['outputFormat'], isNull);
        expect(map['cropRect'], isNull);
      });

      test('should serialize to map with all fields', () {
        final worker = ImageProcessWorker(
          inputPath: '/large.jpg',
          outputPath: '/small.webp',
          maxWidth: 800,
          maxHeight: 600,
          maintainAspectRatio: false,
          quality: 90,
          outputFormat: ImageFormat.webp,
          cropRect: const Rect.fromLTWH(50, 50, 400, 300),
          deleteOriginal: true,
        );

        final map = worker.toMap();

        expect(map['workerType'], 'imageProcess');
        expect(map['inputPath'], '/large.jpg');
        expect(map['outputPath'], '/small.webp');
        expect(map['maxWidth'], 800);
        expect(map['maxHeight'], 600);
        expect(map['maintainAspectRatio'], false);
        expect(map['quality'], 90);
        expect(map['outputFormat'], 'webp');
        expect(map['deleteOriginal'], true);
        expect(map['cropRect'], isNotNull);
      });

      test('should serialize cropRect correctly', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/cropped.jpg',
          cropRect: const Rect.fromLTWH(100, 200, 300, 400),
        );

        final map = worker.toMap();
        final cropRect = map['cropRect'] as Map<String, dynamic>;

        expect(cropRect['x'], 100);
        expect(cropRect['y'], 200);
        expect(cropRect['width'], 300);
        expect(cropRect['height'], 400);
      });

      test('should serialize ImageFormat.jpeg correctly', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.png',
          outputPath: '/image.jpg',
          outputFormat: ImageFormat.jpeg,
        );

        expect(worker.toMap()['outputFormat'], 'jpeg');
      });

      test('should serialize ImageFormat.png correctly', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/image.png',
          outputFormat: ImageFormat.png,
        );

        expect(worker.toMap()['outputFormat'], 'png');
      });

      test('should serialize ImageFormat.webp correctly', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/image.webp',
          outputFormat: ImageFormat.webp,
        );

        expect(worker.toMap()['outputFormat'], 'webp');
      });
    });

    group('Edge Cases', () {
      test('should handle very large dimensions', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/huge.jpg',
          outputPath: '/large.jpg',
          maxWidth: 8192,
          maxHeight: 8192,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, 8192);
        expect(image.maxHeight, 8192);
      });

      test('should handle very small dimensions', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/large.jpg',
          outputPath: '/thumb.jpg',
          maxWidth: 32,
          maxHeight: 32,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, 32);
        expect(image.maxHeight, 32);
      });

      test('should handle paths with special characters', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/image (copy 1).jpg',
          outputPath: '/processed/output-final.jpg',
        );

        final image = worker as ImageProcessWorker;
        expect(image.inputPath, '/photos/image (copy 1).jpg');
        expect(image.outputPath, '/processed/output-final.jpg');
      });

      test('should handle unicode paths', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/фото/изображение.jpg',
          outputPath: '/処理済み/画像.jpg',
        );

        final image = worker as ImageProcessWorker;
        expect(image.inputPath, '/фото/изображение.jpg');
        expect(image.outputPath, '/処理済み/画像.jpg');
      });

      test('should handle decimal crop coordinates', () {
        final worker = ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/cropped.jpg',
          cropRect: const Rect.fromLTWH(10.5, 20.7, 100.3, 200.9),
        );

        final map = worker.toMap();
        final cropRect = map['cropRect'] as Map<String, dynamic>;

        // Should be converted to integers
        expect(cropRect['x'], isA<int>());
        expect(cropRect['y'], isA<int>());
        expect(cropRect['width'], isA<int>());
        expect(cropRect['height'], isA<int>());
      });
    });

    group('Real-world Scenarios', () {
      test('should configure for creating thumbnail', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/DSC_1234.jpg',
          outputPath: '/photos/thumbs/DSC_1234_thumb.jpg',
          maxWidth: 200,
          maxHeight: 200,
          quality: 80,
        );

        final image = worker as ImageProcessWorker;
        expect(image.maxWidth, 200);
        expect(image.maxHeight, 200);
        expect(image.quality, 80);
      });

      test('should configure for web optimization', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/uploads/photo.jpg',
          outputPath: '/web/photo.webp',
          maxWidth: 1920,
          quality: 85,
          outputFormat: ImageFormat.webp,
        );

        final image = worker as ImageProcessWorker;
        expect(image.outputFormat, ImageFormat.webp);
        expect(image.maxWidth, 1920);
      });

      test('should configure for avatar crop', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/uploads/profile.jpg',
          outputPath: '/avatars/user_123.jpg',
          cropRect: const Rect.fromLTWH(100, 50, 400, 400),
          maxWidth: 256,
          maxHeight: 256,
          quality: 90,
        );

        final image = worker as ImageProcessWorker;
        expect(image.cropRect, isNotNull);
        expect(image.maxWidth, 256);
        expect(image.maxHeight, 256);
      });

      test('should configure for format conversion only', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/images/photo.png',
          outputPath: '/images/photo.jpg',
          outputFormat: ImageFormat.jpeg,
          quality: 90,
        );

        final image = worker as ImageProcessWorker;
        expect(image.outputFormat, ImageFormat.jpeg);
        expect(image.maxWidth, isNull); // No resize
        expect(image.maxHeight, isNull);
      });

      test('should configure for heavy compression', () {
        final worker = NativeWorker.imageProcess(
          inputPath: '/photos/4k_photo.jpg',
          outputPath: '/compressed/small.jpg',
          maxWidth: 800,
          quality: 60,
          deleteOriginal: true,
        );

        final image = worker as ImageProcessWorker;
        expect(image.quality, 60);
        expect(image.deleteOriginal, true);
        expect(image.maxWidth, 800);
      });
    });

    group('Boolean Flags', () {
      test('should default deleteOriginal to false', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
        );

        expect(worker.deleteOriginal, false);
      });

      test('should support deleteOriginal = true', () {
        final worker = const ImageProcessWorker(
          inputPath: '/image.jpg',
          outputPath: '/output.jpg',
          deleteOriginal: true,
        );

        expect(worker.deleteOriginal, true);
      });
    });
  });
}
