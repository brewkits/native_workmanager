// Tests for File System & Archives bug fixes (FS-C-001..FS-L-004).
//
// Most FS fixes live in native code (Android/iOS) and are verified by the
// integration-test suite. This file covers the Dart-layer contracts:
//   • Serialisation correctness (toMap round-trips)
//   • Empty-path assertions enforced at construction time (FS-L-002)

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // FileSystemCopyWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileSystemCopyWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      const w = FileSystemCopyWorker(
        sourcePath: '/tmp/src',
        destinationPath: '/tmp/dst',
      );
      final map = w.toMap();
      expect(map['operation'], 'copy');
      expect(map['sourcePath'], '/tmp/src');
      expect(map['destinationPath'], '/tmp/dst');
      expect(map['overwrite'], false);
      expect(map['recursive'], true);
      expect(map['workerType'], 'fileSystem');
    });

    test('overwrite=true serialises', () {
      const w = FileSystemCopyWorker(
        sourcePath: '/tmp/src',
        destinationPath: '/tmp/dst',
        overwrite: true,
      );
      expect(w.toMap()['overwrite'], true);
    });

    test('recursive=false serialises', () {
      const w = FileSystemCopyWorker(
        sourcePath: '/tmp/src',
        destinationPath: '/tmp/dst',
        recursive: false,
      );
      expect(w.toMap()['recursive'], false);
    });

    // FS-L-002: empty-path assertions
    test('empty sourcePath throws assertion in debug mode', () {
      expect(
        () => FileSystemCopyWorker(sourcePath: '', destinationPath: '/tmp/dst'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('empty destinationPath throws assertion in debug mode', () {
      expect(
        () => FileSystemCopyWorker(sourcePath: '/tmp/src', destinationPath: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FileSystemMoveWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileSystemMoveWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      const w = FileSystemMoveWorker(
        sourcePath: '/tmp/src',
        destinationPath: '/tmp/dst',
      );
      final map = w.toMap();
      expect(map['operation'], 'move');
      expect(map['overwrite'], false);
    });

    // FS-L-002
    test('empty sourcePath throws assertion', () {
      expect(
        () => FileSystemMoveWorker(sourcePath: '', destinationPath: '/tmp/dst'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('empty destinationPath throws assertion', () {
      expect(
        () => FileSystemMoveWorker(sourcePath: '/tmp/src', destinationPath: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FileSystemDeleteWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileSystemDeleteWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      const w = FileSystemDeleteWorker(path: '/tmp/file.txt');
      final map = w.toMap();
      expect(map['operation'], 'delete');
      expect(map['path'], '/tmp/file.txt');
      expect(map['recursive'], false);
    });

    test('recursive=true serialises', () {
      const w = FileSystemDeleteWorker(path: '/tmp/dir', recursive: true);
      expect(w.toMap()['recursive'], true);
    });

    // FS-L-002
    test('empty path throws assertion', () {
      expect(
        () => FileSystemDeleteWorker(path: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FileSystemListWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileSystemListWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      const w = FileSystemListWorker(path: '/tmp/dir');
      final map = w.toMap();
      expect(map['operation'], 'list');
      expect(map['path'], '/tmp/dir');
      expect(map['recursive'], false);
      expect(map.containsKey('pattern'), false);
    });

    test('pattern is included when set', () {
      const w = FileSystemListWorker(path: '/tmp/dir', pattern: '*.log');
      expect(w.toMap()['pattern'], '*.log');
    });

    // FS-L-002
    test('empty path throws assertion', () {
      expect(
        () => FileSystemListWorker(path: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FileSystemMkdirWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileSystemMkdirWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      const w = FileSystemMkdirWorker(path: '/tmp/newdir');
      final map = w.toMap();
      expect(map['operation'], 'mkdir');
      expect(map['path'], '/tmp/newdir');
      expect(map['createParents'], true);
    });

    test('createParents=false serialises', () {
      const w =
          FileSystemMkdirWorker(path: '/tmp/newdir', createParents: false);
      expect(w.toMap()['createParents'], false);
    });

    // FS-L-002
    test('empty path throws assertion', () {
      expect(
        () => FileSystemMkdirWorker(path: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FileDecompressionWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('FileDecompressionWorker toMap serialisation', () {
    test('defaults serialise correctly', () {
      const w = FileDecompressionWorker(
        zipPath: '/tmp/archive.zip',
        targetDir: '/tmp/extracted/',
      );
      final map = w.toMap();
      expect(map['zipPath'], '/tmp/archive.zip');
      expect(map['targetDir'], '/tmp/extracted/');
      expect(map['deleteAfterExtract'], false);
      expect(map['overwrite'], true);
      expect(map['workerType'], 'fileDecompress');
    });

    test('deleteAfterExtract=true serialises', () {
      const w = FileDecompressionWorker(
        zipPath: '/tmp/archive.zip',
        targetDir: '/tmp/extracted/',
        deleteAfterExtract: true,
      );
      expect(w.toMap()['deleteAfterExtract'], true);
    });

    test('overwrite=false serialises', () {
      const w = FileDecompressionWorker(
        zipPath: '/tmp/archive.zip',
        targetDir: '/tmp/extracted/',
        overwrite: false,
      );
      expect(w.toMap()['overwrite'], false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NativeWorker convenience constructors — fileCopy / fileMove / etc.
  // ──────────────────────────────────────────────────────────────────────────

  group('NativeWorker.fileCopy convenience constructor', () {
    test('produces correct workerType and class name', () {
      final w = NativeWorker.fileCopy(
        sourcePath: '/tmp/src',
        destinationPath: '/tmp/dst',
      );
      expect(w.workerClassName, 'FileSystemWorker');
      expect(w.toMap()['workerType'], 'fileSystem');
      expect(w.toMap()['operation'], 'copy');
    });
  });

  group('NativeWorker.fileMove convenience constructor', () {
    test('produces correct workerType and operation', () {
      final w = NativeWorker.fileMove(
        sourcePath: '/tmp/src',
        destinationPath: '/tmp/dst',
      );
      expect(w.workerClassName, 'FileSystemWorker');
      expect(w.toMap()['operation'], 'move');
    });
  });

  group('NativeWorker.fileDelete convenience constructor', () {
    test('produces correct workerType and operation', () {
      final w = NativeWorker.fileDelete(path: '/tmp/file.txt');
      expect(w.workerClassName, 'FileSystemWorker');
      expect(w.toMap()['operation'], 'delete');
      expect(w.toMap()['path'], '/tmp/file.txt');
    });
  });

  group('NativeWorker.fileDecompress convenience constructor', () {
    test('produces correct workerType and class name', () {
      final w = NativeWorker.fileDecompress(
        zipPath: '/tmp/archive.zip',
        targetDir: '/tmp/out/',
      );
      expect(w.workerClassName, 'FileDecompressionWorker');
      expect(w.toMap()['workerType'], 'fileDecompress');
    });
  });
}
