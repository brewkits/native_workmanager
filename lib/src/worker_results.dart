import 'package:flutter/foundation.dart';

/// Typed result helpers for built-in workers.
///
/// Each class wraps the raw `resultData: Map<String, dynamic>?` returned by
/// [TaskEvent] and exposes typed, named fields.  This eliminates runtime
/// `as` casts and makes result handling refactor-safe.
///
/// ## Usage
///
/// ```dart
/// NativeWorkManager.events.listen((event) {
///   if (!event.success) return;
///
///   switch (event.workerClassName) {
///     case 'HttpDownloadWorker':
///       final r = DownloadResult.from(event.resultData);
///       print('Saved to ${r?.filePath} (${r?.fileSize} bytes)');
///     case 'HttpUploadWorker':
///       final r = UploadResult.from(event.resultData);
///       print('Uploaded ${r?.fileCount} files, ${r?.uploadedSize} bytes');
///     case 'CryptoWorker':
///       final r = CryptoResult.from(event.resultData);
///       print('Hash: ${r?.hash}');
///   }
/// });
/// ```

// ── Download ─────────────────────────────────────────────────────────────────

/// Result data from [HttpDownloadWorker] and [ParallelHttpDownloadWorker].
@immutable
class DownloadResult {
  const DownloadResult({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.contentType,
    this.finalUrl,
    this.serverSuggestedName,
    this.skipped = false,
  });

  /// Absolute path of the saved file.
  final String filePath;

  /// Filename (last segment of [filePath]).
  final String fileName;

  /// File size in bytes.
  final int fileSize;

  /// MIME type from the `Content-Type` response header, if present.
  final String? contentType;

  /// Final URL after any redirects.
  final String? finalUrl;

  /// Filename suggested by the server's `Content-Disposition` header.
  final String? serverSuggestedName;

  /// `true` when the download was skipped because the file already existed
  /// and `skipExisting` or `onDuplicate: skip` was set.
  final bool skipped;

  /// Parse from a raw [TaskEvent.resultData] map. Returns `null` if [data] is
  /// `null` or missing required fields.
  static DownloadResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final fp = data['filePath'] as String?;
    final fn = data['fileName'] as String?;
    final fs = data['fileSize'];
    if (fp == null || fn == null || fs == null) return null;
    return DownloadResult(
      filePath: fp,
      fileName: fn,
      fileSize: (fs as num).toInt(),
      contentType: data['contentType'] as String?,
      finalUrl: data['finalUrl'] as String?,
      serverSuggestedName: data['serverSuggestedName'] as String?,
      skipped: (data['skipped'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'DownloadResult(filePath: $filePath, fileSize: $fileSize, skipped: $skipped)';
}

// ── Parallel download ─────────────────────────────────────────────────────────

/// Per-file outcome inside [ParallelDownloadResult.files].
@immutable
class DownloadFileOutcome {
  const DownloadFileOutcome({
    required this.url,
    required this.success,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.error,
  });

  final String url;
  final bool success;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? error;

  static DownloadFileOutcome _from(Map<String, dynamic> m) =>
      DownloadFileOutcome(
        url: (m['url'] as String?) ?? '',
        success: (m['success'] as bool?) ?? false,
        filePath: m['filePath'] as String?,
        fileName: m['fileName'] as String?,
        fileSize: (m['fileSize'] as num?)?.toInt(),
        error: m['error'] as String?,
      );
}

/// Result data from [ParallelHttpDownloadWorker].
@immutable
class ParallelDownloadResult {
  const ParallelDownloadResult({
    required this.downloadedCount,
    required this.failedCount,
    required this.totalBytes,
    required this.files,
  });

  final int downloadedCount;
  final int failedCount;
  final int totalBytes;
  final List<DownloadFileOutcome> files;

  static ParallelDownloadResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final rawFiles = data['fileResults'] as List?;
    return ParallelDownloadResult(
      downloadedCount: (data['downloadedCount'] as num?)?.toInt() ?? 0,
      failedCount: (data['failedCount'] as num?)?.toInt() ?? 0,
      totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
      files: rawFiles
              ?.map((e) => DownloadFileOutcome._from(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}

// ── Upload ────────────────────────────────────────────────────────────────────

/// Result data from [HttpUploadWorker].
@immutable
class UploadResult {
  const UploadResult({
    required this.statusCode,
    required this.uploadedSize,
    required this.fileCount,
    this.responseBody,
  });

  final int statusCode;

  /// Total bytes sent.
  final int uploadedSize;

  /// Number of files included in the upload.
  final int fileCount;

  /// Raw response body from the server, if any.
  final String? responseBody;

  static UploadResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    return UploadResult(
      statusCode: (data['statusCode'] as num?)?.toInt() ?? 0,
      uploadedSize: (data['uploadedSize'] as num?)?.toInt() ?? 0,
      fileCount: (data['fileCount'] as num?)?.toInt() ?? 0,
      responseBody: data['responseBody'] as String?,
    );
  }
}

// ── Parallel upload ───────────────────────────────────────────────────────────

/// Per-file outcome inside [ParallelUploadResult.files].
@immutable
class UploadFileOutcome {
  const UploadFileOutcome({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.success,
    this.statusCode,
    this.responseBody,
    this.error,
  });

  final String fileName;
  final String filePath;
  final int fileSize;
  final bool success;
  final int? statusCode;
  final String? responseBody;
  final String? error;

  static UploadFileOutcome _from(Map<String, dynamic> m) => UploadFileOutcome(
        fileName: (m['fileName'] as String?) ?? '',
        filePath: (m['filePath'] as String?) ?? '',
        fileSize: (m['fileSize'] as num?)?.toInt() ?? 0,
        success: (m['success'] as bool?) ?? false,
        statusCode: (m['statusCode'] as num?)?.toInt(),
        responseBody: m['responseBody'] as String?,
        error: m['error'] as String?,
      );
}

/// Result data from [ParallelHttpUploadWorker].
@immutable
class ParallelUploadResult {
  const ParallelUploadResult({
    required this.uploadedCount,
    required this.failedCount,
    required this.totalBytes,
    required this.files,
  });

  final int uploadedCount;
  final int failedCount;
  final int totalBytes;
  final List<UploadFileOutcome> files;

  static ParallelUploadResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final rawFiles = data['fileResults'] as List?;
    return ParallelUploadResult(
      uploadedCount: (data['uploadedCount'] as num?)?.toInt() ?? 0,
      failedCount: (data['failedCount'] as num?)?.toInt() ?? 0,
      totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
      files: rawFiles
              ?.map((e) =>
                  UploadFileOutcome._from(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}

// ── HTTP request ──────────────────────────────────────────────────────────────

/// Result data from [HttpRequestWorker].
@immutable
class HttpRequestResult {
  const HttpRequestResult({
    required this.statusCode,
    required this.body,
    required this.contentLength,
  });

  final int statusCode;
  final String body;
  final int contentLength;

  static HttpRequestResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    return HttpRequestResult(
      statusCode: (data['statusCode'] as num?)?.toInt() ?? 0,
      body: (data['body'] as String?) ?? '',
      contentLength: (data['contentLength'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Crypto ────────────────────────────────────────────────────────────────────

/// Result data from [CryptoWorker] hash or encrypt/decrypt operations.
@immutable
class CryptoResult {
  const CryptoResult({
    this.hash,
    this.algorithm,
    this.outputPath,
    this.fileSize,
    this.operation,
  });

  /// Hex-encoded hash digest (for `hash` operations).
  final String? hash;

  /// Hash algorithm used (e.g. `'SHA-256'`).
  final String? algorithm;

  /// Output file path (for encrypt/decrypt operations).
  final String? outputPath;

  /// Output file size in bytes.
  final int? fileSize;

  /// Operation performed: `'hash'`, `'encrypt'`, or `'decrypt'`.
  final String? operation;

  static CryptoResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    return CryptoResult(
      hash: data['hash'] as String?,
      algorithm: data['algorithm'] as String?,
      outputPath: data['outputPath'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      operation: data['operation'] as String?,
    );
  }
}

// ── File compression / decompression ─────────────────────────────────────────

/// Result data from [FileCompressionWorker].
@immutable
class CompressionResult {
  const CompressionResult({
    required this.outputPath,
    required this.fileCount,
    required this.totalSize,
    required this.compressedSize,
  });

  final String outputPath;
  final int fileCount;
  final int totalSize;
  final int compressedSize;

  double get compressionRatio =>
      totalSize > 0 ? compressedSize / totalSize : 1.0;

  static CompressionResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final op = data['outputPath'] as String?;
    if (op == null) return null;
    return CompressionResult(
      outputPath: op,
      fileCount: (data['fileCount'] as num?)?.toInt() ?? 0,
      totalSize: (data['totalSize'] as num?)?.toInt() ?? 0,
      compressedSize: (data['compressedSize'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result data from [FileDecompressionWorker].
@immutable
class DecompressionResult {
  const DecompressionResult({
    required this.outputPath,
    required this.extractedCount,
    required this.totalSize,
  });

  final String outputPath;
  final int extractedCount;
  final int totalSize;

  static DecompressionResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final op = data['outputPath'] as String?;
    if (op == null) return null;
    return DecompressionResult(
      outputPath: op,
      extractedCount: (data['extractedCount'] as num?)?.toInt() ?? 0,
      totalSize: (data['totalSize'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Image processing ──────────────────────────────────────────────────────────

/// Result data from [ImageProcessWorker].
@immutable
class ImageProcessResult {
  const ImageProcessResult({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.fileSize,
    this.format,
  });

  final String outputPath;
  final int width;
  final int height;
  final int fileSize;

  /// Output image format (e.g. `'jpeg'`, `'png'`, `'webp'`).
  final String? format;

  static ImageProcessResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final op = data['outputPath'] as String?;
    if (op == null) return null;
    return ImageProcessResult(
      outputPath: op,
      width: (data['width'] as num?)?.toInt() ?? 0,
      height: (data['height'] as num?)?.toInt() ?? 0,
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      format: data['format'] as String?,
    );
  }
}

// ── File system ───────────────────────────────────────────────────────────────

/// Result data from [FileSystemWorker].
@immutable
class FileSystemResult {
  const FileSystemResult({
    required this.operation,
    this.sourcePath,
    this.destinationPath,
    this.entries,
    this.count,
  });

  /// Operation performed: `'copy'`, `'move'`, `'delete'`, `'list'`, `'mkdir'`.
  final String operation;
  final String? sourcePath;
  final String? destinationPath;

  /// For `'list'` operations: list of file/directory paths.
  final List<String>? entries;

  /// For `'delete'` or batch operations: number of items affected.
  final int? count;

  static FileSystemResult? from(Map<String, dynamic>? data) {
    if (data == null) return null;
    final op = data['operation'] as String?;
    if (op == null) return null;
    final rawEntries = data['entries'] as List?;
    return FileSystemResult(
      operation: op,
      sourcePath: data['sourcePath'] as String?,
      destinationPath: data['destinationPath'] as String?,
      entries: rawEntries?.map((e) => e as String).toList(),
      count: (data['count'] as num?)?.toInt(),
    );
  }
}
