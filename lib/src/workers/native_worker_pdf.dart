part of '../worker.dart';

Worker _buildPdfMerge({
  required List<String> inputPaths,
  required String outputPath,
}) {
  if (inputPaths.isEmpty) {
    throw ArgumentError('inputPaths cannot be empty for pdfMerge');
  }
  for (final p in inputPaths) {
    NativeWorker._validateFilePath(p, 'inputPaths entry');
  }
  NativeWorker._validateFilePath(outputPath, 'outputPath');
  return PdfMergeWorker(inputPaths: inputPaths, outputPath: outputPath);
}

Worker _buildPdfCompress({
  required String inputPath,
  required String outputPath,
  int quality = 80,
}) {
  NativeWorker._validateFilePath(inputPath, 'inputPath');
  NativeWorker._validateFilePath(outputPath, 'outputPath');
  if (quality < 1 || quality > 100) {
    throw ArgumentError('quality must be between 1 and 100, got $quality');
  }
  return PdfCompressWorker(
      inputPath: inputPath, outputPath: outputPath, quality: quality);
}

Worker _buildPdfFromImages({
  required List<String> imagePaths,
  required String outputPath,
  PdfPageSize pageSize = PdfPageSize.a4,
  int margin = 0,
}) {
  if (imagePaths.isEmpty) {
    throw ArgumentError('imagePaths cannot be empty for pdfFromImages');
  }
  for (final p in imagePaths) {
    NativeWorker._validateFilePath(p, 'imagePaths entry');
  }
  NativeWorker._validateFilePath(outputPath, 'outputPath');
  return PdfFromImagesWorker(
    imagePaths: imagePaths,
    outputPath: outputPath,
    pageSize: pageSize,
    margin: margin,
  );
}
