import 'dart:convert';
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

/// A multi-file download summary that **no worker currently produces**.
///
/// [ParallelHttpDownloadWorker] downloads a *single* file using several parallel
/// range requests, so it reports the single-file shape — use [DownloadResult] for
/// it. This class describes a batch of files (`downloadedCount`, `failedCount`,
/// `fileResults`), and neither platform emits those keys, so
/// [ParallelDownloadResult.from] returns zeroes and an empty [files] list for
/// every real payload.
///
/// Kept, rather than removed, because it is exported public API. It will be
/// removed once a batch-download worker exists to fill it, or deprecated
/// formally in a later release.
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
    final rawFiles = _listOf(data, const ['fileResults']);
    return ParallelDownloadResult(
      downloadedCount: (data['downloadedCount'] as num?)?.toInt() ?? 0,
      failedCount: (data['failedCount'] as num?)?.toInt() ?? 0,
      totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
      files: rawFiles
              ?.whereType<Map>()
              .map((e) =>
                  DownloadFileOutcome._from(Map<String, dynamic>.from(e)))
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
    // Only iOS emits the per-file breakdown; Android reports the counters
    // (`uploadedCount` / `failedCount` / `totalBytes`) without it, so [files] is
    // empty there. Read the counters regardless — they are the part both
    // platforms agree on.
    final rawFiles = _listOf(data, const ['fileResults', 'files']);
    return ParallelUploadResult(
      uploadedCount: (data['uploadedCount'] as num?)?.toInt() ?? 0,
      failedCount: (data['failedCount'] as num?)?.toInt() ?? 0,
      totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
      files: rawFiles
              ?.whereType<Map>()
              .map((e) => UploadFileOutcome._from(Map<String, dynamic>.from(e)))
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

/// Result data from [CryptoHashWorker], [CryptoEncryptWorker], or [CryptoDecryptWorker] operations.
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
      fileSize: _intOf(data, const ['fileSize', 'outputSize', 'inputSize']),
      // iOS echoes `operation`; Android does not. Infer it from the payload so
      // the field is not permanently null there.
      operation: data['operation'] as String? ??
          (data['hash'] != null ? 'hash' : null),
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
      // Android emits `filesCompressed` / `originalSize`; only `compressedSize`
      // and `outputPath` ever matched. iOS emits `size` for the archive.
      fileCount: _intOf(data, const ['fileCount', 'filesCompressed']) ?? 0,
      totalSize: _intOf(data, const ['totalSize', 'originalSize']) ?? 0,
      compressedSize: _intOf(data, const ['compressedSize', 'size']) ?? 0,
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
    // Not one of the three keys this used to read is emitted by either platform:
    // Android sends `targetDir` / `extractedFiles` / `totalBytes`, iOS sends
    // `filesExtracted`. The result was an unconditional null on every platform.
    final op = _stringOf(data, const ['outputPath', 'targetDir']);
    if (op == null) return null;
    return DecompressionResult(
      outputPath: op,
      extractedCount: _intOf(
            data,
            const ['extractedCount', 'extractedFiles', 'filesExtracted'],
          ) ??
          0,
      totalSize: _intOf(data, const ['totalSize', 'totalBytes']) ?? 0,
    );
  }
}

/// Reads the first key present out of [keys].
///
/// The native workers do not agree on field names — Android's decompression
/// worker calls the destination `targetDir` while iOS reports `filesExtracted`
/// and the Dart API calls it `outputPath` — and until v1.6.0 nobody noticed,
/// because `TaskEvent.resultData` never reached Dart on Android at all (it was
/// null on kmpworkmanager 3.3.1 and an unflattened envelope on 3.4.1). Reading a
/// list of accepted spellings, most-specific first, is what makes these helpers
/// return data on both platforms without widening the native payloads.
Object? _firstOf(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null) return value;
  }
  return null;
}

/// Reads a list field that may arrive already decoded **or** as a JSON string.
///
/// The two delivery paths disagree: the event channel hands nested values over as
/// real Dart collections, while the `getTaskRecord` fallback — used whenever the
/// event is missed and the task is read back from the store — hands them over as
/// the JSON text they were persisted as. A plain `as List?` therefore throws a
/// `TypeError` on the fallback path only, which is both intermittent and worse
/// than returning nothing: a result parser must never take down the caller that
/// is trying to read a task that actually succeeded.
List<dynamic>? _listOf(Map<String, dynamic> data, List<String> keys) {
  final value = _firstOf(data, keys);
  if (value is List) return value;
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {
      // Not JSON, or not a list. Fall through to null rather than throwing.
    }
  }
  return null;
}

int? _intOf(Map<String, dynamic> data, List<String> keys) =>
    (_firstOf(data, keys) as num?)?.toInt();

String? _stringOf(Map<String, dynamic> data, List<String> keys) =>
    _firstOf(data, keys) as String?;

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
      // Android reports the post-processing dimensions as `processedWidth` /
      // `processedHeight` and the output size as `processedSize`; iOS uses the
      // plain names. Neither sends `fileSize`.
      width: _intOf(data, const ['width', 'processedWidth']) ?? 0,
      height: _intOf(data, const ['height', 'processedHeight']) ?? 0,
      fileSize: _intOf(data, const ['fileSize', 'processedSize']) ?? 0,
      format: _stringOf(data, const ['format', 'outputFormat']),
    );
  }
}

// ── File system ───────────────────────────────────────────────────────────────

/// Result data from file system workers ([FileSystemCopyWorker], [FileSystemMoveWorker], etc.).
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

    // The two platforms do not agree on this payload, and neither sends `count`:
    //   iOS      → `entries` (paths), `files` (objects), `fileCount`
    //   Android  → `files` (objects), `fileCount`   — no `entries`
    // Reading only `entries`/`count` left both fields null on Android and `count`
    // null everywhere. Rather than widen the native payload — `files` already
    // carries the paths, and duplicating them costs room against WorkManager's
    // Data budget — the shared `files` list is the source of truth here, with the
    // platform-specific keys preferred when present.
    final explicitEntries = _listOf(data, const ['entries']);
    final files = _listOf(data, const ['files']);
    final entries = explicitEntries?.map((e) => '$e').toList() ??
        files
            ?.whereType<Map>()
            .map((f) => f['path'])
            .whereType<String>()
            .toList();

    return FileSystemResult(
      operation: op,
      sourcePath: data['sourcePath'] as String?,
      destinationPath: data['destinationPath'] as String?,
      entries: entries,
      count: (data['count'] as num?)?.toInt() ??
          (data['fileCount'] as num?)?.toInt(),
    );
  }
}
