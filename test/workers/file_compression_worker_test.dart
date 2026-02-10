import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('FileCompressionWorker', () {
    group('Constructor and Basic Properties', () {
      test('should create FileCompressionWorker with required fields', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
        );

        expect(worker.inputPath, '/data/files');
        expect(worker.outputPath, '/data/archive.zip');
        expect(worker.level, CompressionLevel.medium); // default
        expect(worker.excludePatterns, isEmpty);
        expect(worker.deleteOriginal, false); // default
      });

      test('should create FileCompressionWorker with all fields', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/documents',
          outputPath: '/backup/docs.zip',
          level: CompressionLevel.high,
          excludePatterns: ['*.tmp', '*.log'],
          deleteOriginal: true,
        );

        expect(worker.inputPath, '/data/documents');
        expect(worker.outputPath, '/backup/docs.zip');
        expect(worker.level, CompressionLevel.high);
        expect(worker.excludePatterns, ['*.tmp', '*.log']);
        expect(worker.deleteOriginal, true);
      });

      test('should have correct workerClassName', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
        );

        expect(worker.workerClassName, 'FileCompressionWorker');
      });
    });

    group('NativeWorker.fileCompress Factory', () {
      test('should create worker through NativeWorker factory', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/photos',
          outputPath: '/backup/photos.zip',
        );

        expect(worker, isA<FileCompressionWorker>());
        expect((worker as FileCompressionWorker).inputPath, '/data/photos');
        expect(worker.outputPath, '/backup/photos.zip');
      });

      test('should create worker with custom compression level', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.low,
        );

        expect((worker as FileCompressionWorker).level, CompressionLevel.low);
      });

      test('should create worker with exclude patterns', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/logs',
          outputPath: '/backup/logs.zip',
          excludePatterns: ['*.tmp', '*.cache', 'node_modules/**'],
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.excludePatterns, ['*.tmp', '*.cache', 'node_modules/**']);
      });

      test('should create worker with deleteOriginal flag', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/old_files',
          outputPath: '/archive/old.zip',
          deleteOriginal: true,
        );

        expect((worker as FileCompressionWorker).deleteOriginal, true);
      });
    });

    group('Compression Levels', () {
      test('should support CompressionLevel.low', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.low,
        );

        expect(worker.level, CompressionLevel.low);
      });

      test('should support CompressionLevel.medium', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.medium,
        );

        expect(worker.level, CompressionLevel.medium);
      });

      test('should support CompressionLevel.high', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.high,
        );

        expect(worker.level, CompressionLevel.high);
      });

      test('should default to CompressionLevel.medium', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
        );

        expect(worker.level, CompressionLevel.medium);
      });
    });

    group('Validation', () {
      test('should throw ArgumentError for empty inputPath', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '',
            outputPath: '/data/archive.zip',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty outputPath', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/data/files',
            outputPath: '',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError if outputPath does not end with .zip', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/data/files',
            outputPath: '/data/archive.tar',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must end with .zip'),
            ),
          ),
        );
      });

      test('should throw ArgumentError if outputPath does not end with .zip (no extension)', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/data/files',
            outputPath: '/data/archive',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must end with .zip'),
            ),
          ),
        );
      });

      test('should accept outputPath with uppercase .ZIP extension', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/data/files',
            outputPath: '/data/ARCHIVE.ZIP',
          ),
          returnsNormally,
        );
      });

      test('should accept outputPath with mixed case .Zip extension', () {
        expect(
          () => NativeWorker.fileCompress(
            inputPath: '/data/files',
            outputPath: '/data/archive.Zip',
          ),
          returnsNormally,
        );
      });
    });

    group('Exclude Patterns', () {
      test('should handle empty exclude patterns list', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          excludePatterns: [],
        );

        expect((worker as FileCompressionWorker).excludePatterns, isEmpty);
      });

      test('should handle single exclude pattern', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          excludePatterns: ['*.log'],
        );

        expect((worker as FileCompressionWorker).excludePatterns, ['*.log']);
      });

      test('should handle multiple exclude patterns', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          excludePatterns: ['*.tmp', '*.cache', '*.log', '*.bak'],
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.excludePatterns, hasLength(4));
        expect(compression.excludePatterns, contains('*.tmp'));
        expect(compression.excludePatterns, contains('*.cache'));
      });

      test('should handle glob patterns', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/project',
          outputPath: '/backup/project.zip',
          excludePatterns: [
            'node_modules/**',
            '.git/**',
            'build/**',
            '**/*.log',
          ],
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.excludePatterns, contains('node_modules/**'));
        expect(compression.excludePatterns, contains('.git/**'));
      });
    });

    group('Serialization', () {
      test('should serialize to map correctly with minimal fields', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
        );

        final map = worker.toMap();

        expect(map['workerType'], 'fileCompress');
        expect(map['inputPath'], '/data/files');
        expect(map['outputPath'], '/data/archive.zip');
        expect(map['compressionLevel'], 'medium');
        expect(map['excludePatterns'], isEmpty);
        expect(map['deleteOriginal'], false);
      });

      test('should serialize to map correctly with all fields', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/documents',
          outputPath: '/backup/docs.zip',
          level: CompressionLevel.high,
          excludePatterns: ['*.tmp', '*.log'],
          deleteOriginal: true,
        );

        final map = worker.toMap();

        expect(map['workerType'], 'fileCompress');
        expect(map['inputPath'], '/data/documents');
        expect(map['outputPath'], '/backup/docs.zip');
        expect(map['compressionLevel'], 'high');
        expect(map['excludePatterns'], ['*.tmp', '*.log']);
        expect(map['deleteOriginal'], true);
      });

      test('should serialize CompressionLevel.low correctly', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.low,
        );

        expect(worker.toMap()['compressionLevel'], 'low');
      });

      test('should serialize CompressionLevel.medium correctly', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.medium,
        );

        expect(worker.toMap()['compressionLevel'], 'medium');
      });

      test('should serialize CompressionLevel.high correctly', () {
        final worker = const FileCompressionWorker(
          inputPath: '/data/files',
          outputPath: '/data/archive.zip',
          level: CompressionLevel.high,
        );

        expect(worker.toMap()['compressionLevel'], 'high');
      });
    });

    group('Edge Cases', () {
      test('should handle very long file paths', () {
        final longPath = '/data/${'very_long_directory_name/' * 20}file.txt';
        final worker = NativeWorker.fileCompress(
          inputPath: longPath,
          outputPath: '/backup/archive.zip',
        );

        expect((worker as FileCompressionWorker).inputPath, longPath);
      });

      test('should handle paths with special characters', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/files with spaces/special-chars_123',
          outputPath: '/backup/archive (2024).zip',
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.inputPath, '/data/files with spaces/special-chars_123');
        expect(compression.outputPath, '/backup/archive (2024).zip');
      });

      test('should handle unicode paths', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/文件/ファイル/файлы',
          outputPath: '/backup/архив.zip',
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.inputPath, '/data/文件/ファイル/файлы');
        expect(compression.outputPath, '/backup/архив.zip');
      });

      test('should handle paths with dots', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/data/file.name.with.dots',
          outputPath: '/backup/archive.backup.zip',
        );

        expect((worker as FileCompressionWorker).inputPath, '/data/file.name.with.dots');
      });

      test('should handle complex exclude patterns', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/project',
          outputPath: '/backup/project.zip',
          excludePatterns: [
            '**/*.pyc',
            '__pycache__/**',
            '.pytest_cache/**',
            '*.egg-info/**',
            'venv/**',
            '.venv/**',
          ],
        );

        expect((worker as FileCompressionWorker).excludePatterns, hasLength(6));
      });
    });

    group('Real-world Scenarios', () {
      test('should configure for backing up photos with low compression', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/storage/DCIM',
          outputPath: '/backups/photos-2024-02.zip',
          level: CompressionLevel.low, // Photos already compressed
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.level, CompressionLevel.low);
        expect(compression.inputPath, '/storage/DCIM');
      });

      test('should configure for compressing documents with high compression', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/documents',
          outputPath: '/archives/documents-2024.zip',
          level: CompressionLevel.high,
          deleteOriginal: true,
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.level, CompressionLevel.high);
        expect(compression.deleteOriginal, true);
      });

      test('should configure for project backup excluding build artifacts', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/projects/my-app',
          outputPath: '/backups/my-app-2024-02-10.zip',
          excludePatterns: [
            'node_modules/**',
            'build/**',
            'dist/**',
            '.git/**',
            '*.log',
            '*.tmp',
          ],
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.excludePatterns, hasLength(6));
        expect(compression.excludePatterns, contains('node_modules/**'));
      });

      test('should configure for log rotation with deletion', () {
        final worker = NativeWorker.fileCompress(
          inputPath: '/var/log/app',
          outputPath: '/var/log/archives/app-2024-02.zip',
          level: CompressionLevel.high,
          deleteOriginal: true,
          excludePatterns: ['*.tmp'],
        );

        final compression = worker as FileCompressionWorker;
        expect(compression.deleteOriginal, true);
        expect(compression.level, CompressionLevel.high);
        expect(compression.excludePatterns, contains('*.tmp'));
      });
    });
  });
}
