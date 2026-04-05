// Tests for PdfMergeWorker, PdfCompressWorker, PdfFromImagesWorker —
// Dart serialisation contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ── PdfMergeWorker ─────────────────────────────────────────────────────────

  group('PdfMergeWorker', () {
    test('workerClassName is PdfWorker', () {
      const w = PdfMergeWorker(
        inputPaths: ['/tmp/a.pdf', '/tmp/b.pdf'],
        outputPath: '/tmp/out.pdf',
      );
      expect(w.workerClassName, 'PdfWorker');
    });

    test('toMap() has correct operation and fields', () {
      const w = PdfMergeWorker(
        inputPaths: ['/tmp/a.pdf', '/tmp/b.pdf'],
        outputPath: '/tmp/merged.pdf',
      );
      final map = w.toMap();
      expect(map['workerType'], 'pdf');
      expect(map['operation'], 'merge');
      expect(map['inputPaths'], ['/tmp/a.pdf', '/tmp/b.pdf']);
      expect(map['outputPath'], '/tmp/merged.pdf');
    });

    test('single inputPath is valid', () {
      const w = PdfMergeWorker(
        inputPaths: ['/tmp/only.pdf'],
        outputPath: '/tmp/out.pdf',
      );
      expect(w.toMap()['inputPaths'], hasLength(1));
    });
  });

  group('NativeWorker.pdfMerge()', () {
    test('returns PdfMergeWorker', () {
      final w = NativeWorker.pdfMerge(
        inputPaths: ['/tmp/a.pdf', '/tmp/b.pdf'],
        outputPath: '/tmp/out.pdf',
      );
      expect(w, isA<PdfMergeWorker>());
    });

    test('empty inputPaths throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfMerge(inputPaths: [], outputPath: '/tmp/out.pdf'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty outputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfMerge(inputPaths: ['/tmp/a.pdf'], outputPath: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('relative outputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfMerge(
          inputPaths: ['/tmp/a.pdf'],
          outputPath: 'relative/out.pdf',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── PdfCompressWorker ──────────────────────────────────────────────────────

  group('PdfCompressWorker', () {
    test('workerClassName is PdfWorker', () {
      const w = PdfCompressWorker(
        inputPath: '/tmp/in.pdf',
        outputPath: '/tmp/out.pdf',
      );
      expect(w.workerClassName, 'PdfWorker');
    });

    test('toMap() has correct operation and fields', () {
      const w = PdfCompressWorker(
        inputPath: '/tmp/in.pdf',
        outputPath: '/tmp/out.pdf',
        quality: 70,
      );
      final map = w.toMap();
      expect(map['workerType'], 'pdf');
      expect(map['operation'], 'compress');
      expect(map['inputPath'], '/tmp/in.pdf');
      expect(map['outputPath'], '/tmp/out.pdf');
      expect(map['quality'], 70);
    });

    test('default quality is 80', () {
      const w = PdfCompressWorker(
        inputPath: '/tmp/in.pdf',
        outputPath: '/tmp/out.pdf',
      );
      expect(w.toMap()['quality'], 80);
    });
  });

  group('NativeWorker.pdfCompress()', () {
    test('returns PdfCompressWorker', () {
      final w = NativeWorker.pdfCompress(
        inputPath: '/tmp/in.pdf',
        outputPath: '/tmp/out.pdf',
      );
      expect(w, isA<PdfCompressWorker>());
    });

    test('quality < 1 throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfCompress(
          inputPath: '/tmp/in.pdf',
          outputPath: '/tmp/out.pdf',
          quality: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('quality > 100 throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfCompress(
          inputPath: '/tmp/in.pdf',
          outputPath: '/tmp/out.pdf',
          quality: 101,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('quality = 1 is valid', () {
      final w = NativeWorker.pdfCompress(
        inputPath: '/tmp/in.pdf',
        outputPath: '/tmp/out.pdf',
        quality: 1,
      );
      expect(w.toMap()['quality'], 1);
    });

    test('quality = 100 is valid', () {
      final w = NativeWorker.pdfCompress(
        inputPath: '/tmp/in.pdf',
        outputPath: '/tmp/out.pdf',
        quality: 100,
      );
      expect(w.toMap()['quality'], 100);
    });

    test('empty inputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfCompress(inputPath: '', outputPath: '/tmp/out.pdf'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── PdfFromImagesWorker ────────────────────────────────────────────────────

  group('PdfFromImagesWorker', () {
    test('workerClassName is PdfWorker', () {
      const w = PdfFromImagesWorker(
        imagePaths: ['/tmp/img.jpg'],
        outputPath: '/tmp/out.pdf',
      );
      expect(w.workerClassName, 'PdfWorker');
    });

    test('toMap() has correct operation and fields (A4 default)', () {
      const w = PdfFromImagesWorker(
        imagePaths: ['/tmp/1.jpg', '/tmp/2.png'],
        outputPath: '/tmp/album.pdf',
      );
      final map = w.toMap();
      expect(map['workerType'], 'pdf');
      expect(map['operation'], 'imagesToPdf');
      expect(map['imagePaths'], ['/tmp/1.jpg', '/tmp/2.png']);
      expect(map['outputPath'], '/tmp/album.pdf');
      expect(map['pageSize'], 'A4');
      expect(map['margin'], 0);
    });

    test('letter page size serialises as "letter"', () {
      const w = PdfFromImagesWorker(
        imagePaths: ['/tmp/img.jpg'],
        outputPath: '/tmp/out.pdf',
        pageSize: PdfPageSize.letter,
      );
      expect(w.toMap()['pageSize'], 'letter');
    });

    test('a4 page size serialises as "A4"', () {
      const w = PdfFromImagesWorker(
        imagePaths: ['/tmp/img.jpg'],
        outputPath: '/tmp/out.pdf',
        pageSize: PdfPageSize.a4,
      );
      expect(w.toMap()['pageSize'], 'A4');
    });

    test('margin is preserved', () {
      const w = PdfFromImagesWorker(
        imagePaths: ['/tmp/img.jpg'],
        outputPath: '/tmp/out.pdf',
        margin: 20,
      );
      expect(w.toMap()['margin'], 20);
    });
  });

  group('NativeWorker.pdfFromImages()', () {
    test('returns PdfFromImagesWorker', () {
      final w = NativeWorker.pdfFromImages(
        imagePaths: ['/tmp/img.jpg'],
        outputPath: '/tmp/out.pdf',
      );
      expect(w, isA<PdfFromImagesWorker>());
    });

    test('empty imagePaths throws ArgumentError', () {
      expect(
        () =>
            NativeWorker.pdfFromImages(imagePaths: [], outputPath: '/tmp/out.pdf'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty outputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfFromImages(
          imagePaths: ['/tmp/img.jpg'],
          outputPath: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('relative imagePath throws ArgumentError', () {
      expect(
        () => NativeWorker.pdfFromImages(
          imagePaths: ['relative/img.jpg'],
          outputPath: '/tmp/out.pdf',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
