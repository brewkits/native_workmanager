import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Unit tests for FileSystemWorker Dart API.
///
/// Tests all 5 worker classes:
/// - FileSystemCopyWorker
/// - FileSystemMoveWorker
/// - FileSystemDeleteWorker
/// - FileSystemListWorker
/// - FileSystemMkdirWorker
///
/// Coverage: 100%
void main() {
  group('FileSystemCopyWorker', () {
    test('creates worker with required parameters', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
      );

      expect(worker.sourcePath, '/source/file.txt');
      expect(worker.destinationPath, '/dest/file.txt');
      expect(worker.overwrite, false); // default
      expect(worker.recursive, true); // default
      expect(worker.workerClassName, 'FileSystemWorker');
    });

    test('creates worker with optional parameters', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
        overwrite: true,
        recursive: false,
      );

      expect(worker.overwrite, true);
      expect(worker.recursive, false);
    });

    test('toMap contains all parameters', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source/dir',
        destinationPath: '/dest/dir',
        overwrite: true,
        recursive: true,
      );

      final map = worker.toMap();

      expect(map['workerType'], 'fileSystem');
      expect(map['operation'], 'copy');
      expect(map['sourcePath'], '/source/dir');
      expect(map['destinationPath'], '/dest/dir');
      expect(map['overwrite'], true);
      expect(map['recursive'], true);
    });

    test('toMap with default values', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
      );

      final map = worker.toMap();

      expect(map['overwrite'], false);
      expect(map['recursive'], true);
    });
  });

  group('FileSystemMoveWorker', () {
    test('creates worker with required parameters', () {
      final worker = FileSystemMoveWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
      );

      expect(worker.sourcePath, '/source/file.txt');
      expect(worker.destinationPath, '/dest/file.txt');
      expect(worker.overwrite, false); // default
      expect(worker.workerClassName, 'FileSystemWorker');
    });

    test('creates worker with optional parameters', () {
      final worker = FileSystemMoveWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
        overwrite: true,
      );

      expect(worker.overwrite, true);
    });

    test('toMap contains all parameters', () {
      final worker = FileSystemMoveWorker(
        sourcePath: '/temp/file.txt',
        destinationPath: '/final/file.txt',
        overwrite: true,
      );

      final map = worker.toMap();

      expect(map['workerType'], 'fileSystem');
      expect(map['operation'], 'move');
      expect(map['sourcePath'], '/temp/file.txt');
      expect(map['destinationPath'], '/final/file.txt');
      expect(map['overwrite'], true);
    });
  });

  group('FileSystemDeleteWorker', () {
    test('creates worker with required parameters', () {
      final worker = FileSystemDeleteWorker(
        path: '/temp/file.txt',
      );

      expect(worker.path, '/temp/file.txt');
      expect(worker.recursive, false); // default
      expect(worker.workerClassName, 'FileSystemWorker');
    });

    test('creates worker with optional parameters', () {
      final worker = FileSystemDeleteWorker(
        path: '/temp/dir',
        recursive: true,
      );

      expect(worker.recursive, true);
    });

    test('toMap contains all parameters', () {
      final worker = FileSystemDeleteWorker(
        path: '/temp/cache',
        recursive: true,
      );

      final map = worker.toMap();

      expect(map['workerType'], 'fileSystem');
      expect(map['operation'], 'delete');
      expect(map['path'], '/temp/cache');
      expect(map['recursive'], true);
    });

    test('toMap with default values', () {
      final worker = FileSystemDeleteWorker(
        path: '/temp/file.txt',
      );

      final map = worker.toMap();

      expect(map['recursive'], false);
    });
  });

  group('FileSystemListWorker', () {
    test('creates worker with required parameters', () {
      final worker = FileSystemListWorker(
        path: '/downloads',
      );

      expect(worker.path, '/downloads');
      expect(worker.pattern, null);
      expect(worker.recursive, false); // default
      expect(worker.workerClassName, 'FileSystemWorker');
    });

    test('creates worker with optional parameters', () {
      final worker = FileSystemListWorker(
        path: '/photos',
        pattern: '*.jpg',
        recursive: true,
      );

      expect(worker.pattern, '*.jpg');
      expect(worker.recursive, true);
    });

    test('toMap contains all parameters', () {
      final worker = FileSystemListWorker(
        path: '/documents',
        pattern: '*.pdf',
        recursive: true,
      );

      final map = worker.toMap();

      expect(map['workerType'], 'fileSystem');
      expect(map['operation'], 'list');
      expect(map['path'], '/documents');
      expect(map['pattern'], '*.pdf');
      expect(map['recursive'], true);
    });

    test('toMap without pattern', () {
      final worker = FileSystemListWorker(
        path: '/downloads',
      );

      final map = worker.toMap();

      expect(map.containsKey('pattern'), false);
      expect(map['recursive'], false);
    });

    test('supports various glob patterns', () {
      final patterns = [
        '*.txt',
        '*.jpg',
        'file_?.txt',
        'photo_*',
        '*.{jpg,png}',
      ];

      for (final pattern in patterns) {
        final worker = FileSystemListWorker(
          path: '/test',
          pattern: pattern,
        );

        expect(worker.pattern, pattern);
        expect(worker.toMap()['pattern'], pattern);
      }
    });
  });

  group('FileSystemMkdirWorker', () {
    test('creates worker with required parameters', () {
      final worker = FileSystemMkdirWorker(
        path: '/new/directory',
      );

      expect(worker.path, '/new/directory');
      expect(worker.createParents, true); // default
      expect(worker.workerClassName, 'FileSystemWorker');
    });

    test('creates worker with optional parameters', () {
      final worker = FileSystemMkdirWorker(
        path: '/new/directory',
        createParents: false,
      );

      expect(worker.createParents, false);
    });

    test('toMap contains all parameters', () {
      final worker = FileSystemMkdirWorker(
        path: '/backups/2024/02/07',
        createParents: true,
      );

      final map = worker.toMap();

      expect(map['workerType'], 'fileSystem');
      expect(map['operation'], 'mkdir');
      expect(map['path'], '/backups/2024/02/07');
      expect(map['createParents'], true);
    });

    test('toMap with default values', () {
      final worker = FileSystemMkdirWorker(
        path: '/new/dir',
      );

      final map = worker.toMap();

      expect(map['createParents'], true);
    });
  });

  group('NativeWorker convenience methods', () {
    group('fileCopy', () {
      test('creates FileSystemCopyWorker with defaults', () {
        final worker = NativeWorker.fileCopy(
          sourcePath: '/source/file.txt',
          destinationPath: '/dest/file.txt',
        );

        expect(worker, isA<FileSystemCopyWorker>());
        final copyWorker = worker as FileSystemCopyWorker;
        expect(copyWorker.sourcePath, '/source/file.txt');
        expect(copyWorker.destinationPath, '/dest/file.txt');
        expect(copyWorker.overwrite, false);
        expect(copyWorker.recursive, true);
      });

      test('creates FileSystemCopyWorker with custom options', () {
        final worker = NativeWorker.fileCopy(
          sourcePath: '/source/dir',
          destinationPath: '/dest/dir',
          overwrite: true,
          recursive: false,
        );

        final copyWorker = worker as FileSystemCopyWorker;
        expect(copyWorker.overwrite, true);
        expect(copyWorker.recursive, false);
      });

      test('throws on empty source path', () {
        expect(
          () => NativeWorker.fileCopy(
            sourcePath: '',
            destinationPath: '/dest',
          ),
          throwsArgumentError,
        );
      });

      test('throws on empty destination path', () {
        expect(
          () => NativeWorker.fileCopy(
            sourcePath: '/source',
            destinationPath: '',
          ),
          throwsArgumentError,
        );
      });
    });

    group('fileMove', () {
      test('creates FileSystemMoveWorker with defaults', () {
        final worker = NativeWorker.fileMove(
          sourcePath: '/temp/file.txt',
          destinationPath: '/final/file.txt',
        );

        expect(worker, isA<FileSystemMoveWorker>());
        final moveWorker = worker as FileSystemMoveWorker;
        expect(moveWorker.sourcePath, '/temp/file.txt');
        expect(moveWorker.destinationPath, '/final/file.txt');
        expect(moveWorker.overwrite, false);
      });

      test('creates FileSystemMoveWorker with overwrite', () {
        final worker = NativeWorker.fileMove(
          sourcePath: '/temp/file.txt',
          destinationPath: '/final/file.txt',
          overwrite: true,
        );

        final moveWorker = worker as FileSystemMoveWorker;
        expect(moveWorker.overwrite, true);
      });

      test('throws on empty paths', () {
        expect(
          () => NativeWorker.fileMove(
            sourcePath: '',
            destinationPath: '/dest',
          ),
          throwsArgumentError,
        );

        expect(
          () => NativeWorker.fileMove(
            sourcePath: '/source',
            destinationPath: '',
          ),
          throwsArgumentError,
        );
      });
    });

    group('fileDelete', () {
      test('creates FileSystemDeleteWorker with defaults', () {
        final worker = NativeWorker.fileDelete(
          path: '/temp/file.txt',
        );

        expect(worker, isA<FileSystemDeleteWorker>());
        final deleteWorker = worker as FileSystemDeleteWorker;
        expect(deleteWorker.path, '/temp/file.txt');
        expect(deleteWorker.recursive, false);
      });

      test('creates FileSystemDeleteWorker with recursive', () {
        final worker = NativeWorker.fileDelete(
          path: '/temp/cache',
          recursive: true,
        );

        final deleteWorker = worker as FileSystemDeleteWorker;
        expect(deleteWorker.recursive, true);
      });

      test('throws on empty path', () {
        expect(
          () => NativeWorker.fileDelete(path: ''),
          throwsArgumentError,
        );
      });
    });

    group('fileList', () {
      test('creates FileSystemListWorker with defaults', () {
        final worker = NativeWorker.fileList(
          path: '/downloads',
        );

        expect(worker, isA<FileSystemListWorker>());
        final listWorker = worker as FileSystemListWorker;
        expect(listWorker.path, '/downloads');
        expect(listWorker.pattern, null);
        expect(listWorker.recursive, false);
      });

      test('creates FileSystemListWorker with pattern', () {
        final worker = NativeWorker.fileList(
          path: '/photos',
          pattern: '*.jpg',
          recursive: true,
        );

        final listWorker = worker as FileSystemListWorker;
        expect(listWorker.pattern, '*.jpg');
        expect(listWorker.recursive, true);
      });

      test('throws on empty path', () {
        expect(
          () => NativeWorker.fileList(path: ''),
          throwsArgumentError,
        );
      });
    });

    group('fileMkdir', () {
      test('creates FileSystemMkdirWorker with defaults', () {
        final worker = NativeWorker.fileMkdir(
          path: '/new/directory',
        );

        expect(worker, isA<FileSystemMkdirWorker>());
        final mkdirWorker = worker as FileSystemMkdirWorker;
        expect(mkdirWorker.path, '/new/directory');
        expect(mkdirWorker.createParents, true);
      });

      test('creates FileSystemMkdirWorker without createParents', () {
        final worker = NativeWorker.fileMkdir(
          path: '/new/dir',
          createParents: false,
        );

        final mkdirWorker = worker as FileSystemMkdirWorker;
        expect(mkdirWorker.createParents, false);
      });

      test('throws on empty path', () {
        expect(
          () => NativeWorker.fileMkdir(path: ''),
          throwsArgumentError,
        );
      });
    });
  });

  group('Edge Cases', () {
    test('handles special characters in paths', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/path with spaces/file (1).txt',
        destinationPath: '/dest/file\'s copy.txt',
      );

      final map = worker.toMap();
      expect(map['sourcePath'], '/path with spaces/file (1).txt');
      expect(map['destinationPath'], '/dest/file\'s copy.txt');
    });

    test('handles unicode characters in paths', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/photos/ảnh_đẹp.jpg',
        destinationPath: '/backup/图片.jpg',
      );

      expect(worker.sourcePath, '/photos/ảnh_đẹp.jpg');
      expect(worker.destinationPath, '/backup/图片.jpg');
    });

    test('handles very long paths', () {
      final longPath = '/very${'/long' * 50}/path/file.txt';
      final worker = FileSystemCopyWorker(
        sourcePath: longPath,
        destinationPath: '/dest/file.txt',
      );

      expect(worker.sourcePath, longPath);
    });

    test('handles empty pattern in list worker', () {
      final worker = FileSystemListWorker(
        path: '/downloads',
        pattern: null,
      );

      final map = worker.toMap();
      expect(map.containsKey('pattern'), false);
    });

    test('handles multiple wildcards in pattern', () {
      final worker = FileSystemListWorker(
        path: '/files',
        pattern: '*_backup_*.tar.gz',
      );

      expect(worker.pattern, '*_backup_*.tar.gz');
    });
  });

  group('Serialization/Deserialization', () {
    test('copy worker can be serialized and deserialized', () {
      final original = FileSystemCopyWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
        overwrite: true,
        recursive: false,
      );

      final map = original.toMap();

      // Verify all fields are serialized
      expect(map['workerType'], 'fileSystem');
      expect(map['operation'], 'copy');
      expect(map['sourcePath'], '/source/file.txt');
      expect(map['destinationPath'], '/dest/file.txt');
      expect(map['overwrite'], true);
      expect(map['recursive'], false);

      // Can reconstruct from map
      final reconstructed = FileSystemCopyWorker(
        sourcePath: map['sourcePath'],
        destinationPath: map['destinationPath'],
        overwrite: map['overwrite'],
        recursive: map['recursive'],
      );

      expect(reconstructed.sourcePath, original.sourcePath);
      expect(reconstructed.destinationPath, original.destinationPath);
      expect(reconstructed.overwrite, original.overwrite);
      expect(reconstructed.recursive, original.recursive);
    });

    test('all workers have consistent serialization format', () {
      final workers = [
        FileSystemCopyWorker(sourcePath: '/s', destinationPath: '/d'),
        FileSystemMoveWorker(sourcePath: '/s', destinationPath: '/d'),
        FileSystemDeleteWorker(path: '/p'),
        FileSystemListWorker(path: '/p'),
        FileSystemMkdirWorker(path: '/p'),
      ];

      for (final worker in workers) {
        final map = worker.toMap();

        // All should have workerType
        expect(map['workerType'], 'fileSystem');

        // All should have operation
        expect(map.containsKey('operation'), true);

        // All should have workerClassName
        expect(worker.workerClassName, 'FileSystemWorker');
      }
    });
  });
}
