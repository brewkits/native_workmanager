import 'package:flutter/foundation.dart';
import '../worker.dart';

/// File decompression worker configuration.
///
/// Extracts files from ZIP archives with streaming extraction and security protections.
///
/// **Note:** Password-protected ZIPs and selective extraction will be added in v1.1.0.
/// Current version supports basic ZIP extraction only.
@immutable
final class FileDecompressionWorker extends Worker {
  const FileDecompressionWorker({
    required this.zipPath,
    required this.targetDir,
    this.deleteAfterExtract = false,
    this.overwrite = true,
  });

  /// Path to ZIP archive to extract.
  final String zipPath;

  /// Destination directory where files will be extracted.
  final String targetDir;

  /// Whether to delete archive after successful extraction.
  final bool deleteAfterExtract;

  /// Whether to overwrite existing files in destination.
  final bool overwrite;

  @override
  String get workerClassName => 'FileDecompressionWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileDecompress',
        'zipPath': zipPath,
        'targetDir': targetDir,
        'deleteAfterExtract': deleteAfterExtract,
        'overwrite': overwrite,
      };
}
