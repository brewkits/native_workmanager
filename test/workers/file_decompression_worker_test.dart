import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('FileDecompressionWorker', () {
    group('Constructor and Basic Properties', () {
      test('should create FileDecompressionWorker with required fields', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/downloads/archive.zip',
          targetDir: '/data/extracted',
        );

        expect(worker.zipPath, '/downloads/archive.zip');
        expect(worker.targetDir, '/data/extracted');
        expect(worker.deleteAfterExtract, false); // default
        expect(worker.overwrite, true); // default
      });

      test('should create FileDecompressionWorker with all fields', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/temp/download.zip',
          targetDir: '/data/files',
          deleteAfterExtract: true,
          overwrite: false,
        );

        expect(worker.zipPath, '/temp/download.zip');
        expect(worker.targetDir, '/data/files');
        expect(worker.deleteAfterExtract, true);
        expect(worker.overwrite, false);
      });

      test('should have correct workerClassName', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/archive.zip',
          targetDir: '/extracted',
        );

        expect(worker.workerClassName, 'FileDecompressionWorker');
      });
    });

    group('NativeWorker.fileDecompress Factory', () {
      test('should create worker through NativeWorker factory', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/downloads/data.zip',
          targetDir: '/data',
        );

        expect(worker, isA<FileDecompressionWorker>());
        expect((worker as FileDecompressionWorker).zipPath, '/downloads/data.zip');
        expect(worker.targetDir, '/data');
      });

      test('should create worker with deleteAfterExtract flag', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/temp/archive.zip',
          targetDir: '/data',
          deleteAfterExtract: true,
        );

        expect((worker as FileDecompressionWorker).deleteAfterExtract, true);
      });

      test('should create worker with overwrite flag set to false', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/backup/data.zip',
          targetDir: '/restore',
          overwrite: false,
        );

        expect((worker as FileDecompressionWorker).overwrite, false);
      });

      test('should create worker with both flags set', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/temp/oneshot.zip',
          targetDir: '/data',
          deleteAfterExtract: true,
          overwrite: true,
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.deleteAfterExtract, true);
        expect(decompression.overwrite, true);
      });
    });

    group('Validation', () {
      test('should throw ArgumentError for empty zipPath', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '',
            targetDir: '/data',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty targetDir', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/archive.zip',
            targetDir: '',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError if zipPath does not end with .zip', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/data/archive.tar',
            targetDir: '/extracted',
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

      test('should throw ArgumentError if zipPath has no extension', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/data/archive',
            targetDir: '/extracted',
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

      test('should accept zipPath with uppercase .ZIP extension', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/data/ARCHIVE.ZIP',
            targetDir: '/extracted',
          ),
          returnsNormally,
        );
      });

      test('should accept zipPath with mixed case .Zip extension', () {
        expect(
          () => NativeWorker.fileDecompress(
            zipPath: '/data/archive.Zip',
            targetDir: '/extracted',
          ),
          returnsNormally,
        );
      });
    });

    group('Boolean Flags', () {
      test('should default deleteAfterExtract to false', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/archive.zip',
          targetDir: '/extracted',
        );

        expect(worker.deleteAfterExtract, false);
      });

      test('should default overwrite to true', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/archive.zip',
          targetDir: '/extracted',
        );

        expect(worker.overwrite, true);
      });

      test('should support deleteAfterExtract = true', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/temp.zip',
          targetDir: '/data',
          deleteAfterExtract: true,
        );

        expect(worker.deleteAfterExtract, true);
      });

      test('should support overwrite = false', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/archive.zip',
          targetDir: '/data',
          overwrite: false,
        );

        expect(worker.overwrite, false);
      });
    });

    group('Serialization', () {
      test('should serialize to map correctly with minimal fields', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/downloads/data.zip',
          targetDir: '/data/extracted',
        );

        final map = worker.toMap();

        expect(map['workerType'], 'fileDecompress');
        expect(map['zipPath'], '/downloads/data.zip');
        expect(map['targetDir'], '/data/extracted');
        expect(map['deleteAfterExtract'], false);
        expect(map['overwrite'], true);
      });

      test('should serialize to map correctly with all fields', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/temp/archive.zip',
          targetDir: '/restore',
          deleteAfterExtract: true,
          overwrite: false,
        );

        final map = worker.toMap();

        expect(map['workerType'], 'fileDecompress');
        expect(map['zipPath'], '/temp/archive.zip');
        expect(map['targetDir'], '/restore');
        expect(map['deleteAfterExtract'], true);
        expect(map['overwrite'], false);
      });

      test('should serialize deleteAfterExtract flag correctly', () {
        final worker1 = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          deleteAfterExtract: true,
        );
        final worker2 = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          deleteAfterExtract: false,
        );

        expect(worker1.toMap()['deleteAfterExtract'], true);
        expect(worker2.toMap()['deleteAfterExtract'], false);
      });

      test('should serialize overwrite flag correctly', () {
        final worker1 = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          overwrite: true,
        );
        final worker2 = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          overwrite: false,
        );

        expect(worker1.toMap()['overwrite'], true);
        expect(worker2.toMap()['overwrite'], false);
      });
    });

    group('Edge Cases', () {
      test('should handle very long paths', () {
        final longPath = '/data/${'very_long_directory_name/' * 20}archive.zip';
        final worker = NativeWorker.fileDecompress(
          zipPath: longPath,
          targetDir: '/extracted',
        );

        expect((worker as FileDecompressionWorker).zipPath, longPath);
      });

      test('should handle paths with special characters', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/downloads/file with spaces (copy 1).zip',
          targetDir: '/data/extracted files',
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.zipPath, '/downloads/file with spaces (copy 1).zip');
        expect(decompression.targetDir, '/data/extracted files');
      });

      test('should handle unicode paths', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/архивы/文件.zip',
          targetDir: '/データ/извлечено',
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.zipPath, '/архивы/文件.zip');
        expect(decompression.targetDir, '/データ/извлечено');
      });

      test('should handle paths with dots', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/data/file.name.with.dots.backup.zip',
          targetDir: '/extracted.files',
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.zipPath, '/data/file.name.with.dots.backup.zip');
        expect(decompression.targetDir, '/extracted.files');
      });

      test('should handle nested directory paths', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/a/b/c/d/e/f/archive.zip',
          targetDir: '/x/y/z/extracted',
        );

        expect((worker as FileDecompressionWorker).zipPath, '/a/b/c/d/e/f/archive.zip');
      });
    });

    group('Real-world Scenarios', () {
      test('should configure for extracting downloaded update', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/downloads/app-update-v2.0.zip',
          targetDir: '/app/updates',
          overwrite: true,
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.overwrite, true);
        expect(decompression.deleteAfterExtract, false); // Keep for rollback
      });

      test('should configure for one-time archive extraction with cleanup', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/temp/import-data.zip',
          targetDir: '/data/imported',
          deleteAfterExtract: true,
          overwrite: true,
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.deleteAfterExtract, true);
        expect(decompression.overwrite, true);
      });

      test('should configure for safe extraction without overwriting', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/backups/restore.zip',
          targetDir: '/data',
          overwrite: false,
          deleteAfterExtract: false,
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.overwrite, false);
        expect(decompression.deleteAfterExtract, false);
      });

      test('should configure for restoring backup', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/backups/full-backup-2024-02-10.zip',
          targetDir: '/restore/data',
          overwrite: true,
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.zipPath, contains('full-backup'));
        expect(decompression.targetDir, '/restore/data');
      });

      test('should configure for temporary file extraction', () {
        final worker = NativeWorker.fileDecompress(
          zipPath: '/cache/temp-download-12345.zip',
          targetDir: '/cache/extracted',
          deleteAfterExtract: true,
        );

        final decompression = worker as FileDecompressionWorker;
        expect(decompression.deleteAfterExtract, true);
        expect(decompression.zipPath, contains('cache'));
      });
    });

    group('Flag Combinations', () {
      test('should support deleteAfterExtract=true, overwrite=true', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          deleteAfterExtract: true,
          overwrite: true,
        );

        expect(worker.deleteAfterExtract, true);
        expect(worker.overwrite, true);
      });

      test('should support deleteAfterExtract=true, overwrite=false', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          deleteAfterExtract: true,
          overwrite: false,
        );

        expect(worker.deleteAfterExtract, true);
        expect(worker.overwrite, false);
      });

      test('should support deleteAfterExtract=false, overwrite=true', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          deleteAfterExtract: false,
          overwrite: true,
        );

        expect(worker.deleteAfterExtract, false);
        expect(worker.overwrite, true);
      });

      test('should support deleteAfterExtract=false, overwrite=false', () {
        final worker = const FileDecompressionWorker(
          zipPath: '/a.zip',
          targetDir: '/data',
          deleteAfterExtract: false,
          overwrite: false,
        );

        expect(worker.deleteAfterExtract, false);
        expect(worker.overwrite, false);
      });
    });
  });
}
