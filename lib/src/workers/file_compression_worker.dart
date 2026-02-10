import 'package:flutter/foundation.dart';
import '../worker.dart';

/// File compression worker configuration.
///
/// Compresses files or directories into ZIP archives.
@immutable
final class FileCompressionWorker extends Worker {
  const FileCompressionWorker({
    required this.inputPath,
    required this.outputPath,
    this.level = CompressionLevel.medium,
    this.excludePatterns = const [],
    this.deleteOriginal = false,
  });

  /// Path to file or directory to compress.
  final String inputPath;

  /// Path where ZIP file will be saved.
  final String outputPath;

  /// Compression level (low, medium, high).
  final CompressionLevel level;

  /// Patterns to exclude from compression.
  final List<String> excludePatterns;

  /// Whether to delete original files after compression.
  final bool deleteOriginal;

  @override
  String get workerClassName => 'FileCompressionWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileCompress',
        'inputPath': inputPath,
        'outputPath': outputPath,
        'compressionLevel': level.name,
        'excludePatterns': excludePatterns,
        'deleteOriginal': deleteOriginal,
      };
}
