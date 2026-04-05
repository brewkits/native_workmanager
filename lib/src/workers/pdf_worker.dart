import 'package:flutter/foundation.dart';

import '../worker.dart';

/// PDF page size for [PdfFromImagesWorker].
enum PdfPageSize {
  /// ISO A4 (210×297 mm / 595×842 pt).
  a4,

  /// US Letter (215.9×279.4 mm / 612×792 pt).
  letter,
}

/// Merge multiple PDF files into a single output PDF.
///
/// Uses Android `PdfRenderer`→`PdfDocument` (API 21+)
/// and iOS `PDFKit` (iOS 11+).
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'merge-pdfs',
///   worker: NativeWorker.pdfMerge(
///     inputPaths: ['/data/.../a.pdf', '/data/.../b.pdf'],
///     outputPath: '/data/.../merged.pdf',
///   ),
/// );
/// ```
///
/// **Result data:**
/// ```json
/// { "outputPath": "...", "outputSize": 102400, "pageCount": 5 }
/// ```
@immutable
final class PdfMergeWorker extends Worker {
  const PdfMergeWorker({
    required this.inputPaths,
    required this.outputPath,
  });

  /// Ordered list of absolute paths to the PDF files to merge.
  final List<String> inputPaths;

  /// Absolute path for the merged output PDF.
  final String outputPath;

  @override
  String get workerClassName => 'PdfWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'pdf',
        'operation': 'merge',
        'inputPaths': inputPaths,
        'outputPath': outputPath,
      };
}

/// Re-render a PDF at reduced quality to shrink its file size.
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'compress-pdf',
///   worker: NativeWorker.pdfCompress(
///     inputPath: '/data/.../original.pdf',
///     outputPath: '/data/.../compressed.pdf',
///     quality: 60,
///   ),
/// );
/// ```
///
/// **[quality]:** 1–100. Default `80`. Lower values produce smaller files.
///
/// **Result data:**
/// ```json
/// { "outputPath": "...", "outputSize": 51200, "pageCount": 3 }
/// ```
@immutable
final class PdfCompressWorker extends Worker {
  const PdfCompressWorker({
    required this.inputPath,
    required this.outputPath,
    this.quality = 80,
  });

  /// Absolute path to the input PDF.
  final String inputPath;

  /// Absolute path for the compressed output PDF.
  final String outputPath;

  /// JPEG render quality (1–100). Default `80`.
  final int quality;

  @override
  String get workerClassName => 'PdfWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'pdf',
        'operation': 'compress',
        'inputPath': inputPath,
        'outputPath': outputPath,
        'quality': quality,
      };
}

/// Convert a list of image files into a PDF (one image per page).
///
/// Supported image formats: JPEG, PNG, and any format supported by the
/// platform's native image decoder.
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'images-to-pdf',
///   worker: NativeWorker.pdfFromImages(
///     imagePaths: ['/data/.../1.jpg', '/data/.../2.png'],
///     outputPath: '/data/.../album.pdf',
///     pageSize: PdfPageSize.a4,
///   ),
/// );
/// ```
///
/// **Result data:**
/// ```json
/// { "outputPath": "...", "outputSize": 204800, "pageCount": 2 }
/// ```
@immutable
final class PdfFromImagesWorker extends Worker {
  const PdfFromImagesWorker({
    required this.imagePaths,
    required this.outputPath,
    this.pageSize = PdfPageSize.a4,
    this.margin = 0,
  });

  /// Ordered list of absolute paths to the source images.
  final List<String> imagePaths;

  /// Absolute path for the output PDF.
  final String outputPath;

  /// Page dimensions. Defaults to [PdfPageSize.a4].
  final PdfPageSize pageSize;

  /// Page margin in PDF points (1 pt = 1/72 inch). Default `0`.
  final int margin;

  @override
  String get workerClassName => 'PdfWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'pdf',
        'operation': 'imagesToPdf',
        'imagePaths': imagePaths,
        'outputPath': outputPath,
        'pageSize': pageSize == PdfPageSize.a4 ? 'A4' : 'letter',
        'margin': margin,
      };
}
