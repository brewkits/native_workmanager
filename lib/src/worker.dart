import 'package:flutter/foundation.dart';
import 'dart:ui';

// Import all worker implementations
import 'workers.dart';

// Export all worker implementations
export 'workers.dart';

// Per-category part files for NativeWorker factory methods
part 'workers/native_worker_http.dart';
part 'workers/native_worker_custom.dart';
part 'workers/native_worker_file.dart';
part 'workers/native_worker_crypto.dart';
part 'workers/native_worker_image.dart';

/// HTTP methods for network workers.
enum HttpMethod { get, post, put, delete, patch }

/// Compression levels for file compression.
enum CompressionLevel {
  /// Low compression (faster, larger file).
  low,

  /// Medium compression (balanced).
  medium,

  /// High compression (slower, smaller file).
  high,
}

/// Base class for all worker configurations.
///
/// All built-in workers (HttpDownloadWorker, FileCompressWorker, etc.) extend
/// this class. Custom native workers use [CustomNativeWorker].
@immutable
abstract class Worker {
  const Worker();

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap();

  /// Get the worker class name for native side.
  String get workerClassName;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NATIVE WORKERS (Mode 1) - Zero Flutter Engine
// ═══════════════════════════════════════════════════════════════════════════════

/// Built-in native workers that run WITHOUT Flutter Engine.
///
/// These workers execute using KMP native code, saving ~50MB RAM
/// compared to Dart-based workers.
class NativeWorker {
  NativeWorker._();

  /// Validate URL format and throw helpful error if invalid.
  static void _validateUrl(String url) {
    if (url.isEmpty) {
      throw ArgumentError(
        'URL cannot be empty.\n'
        'Provide a valid HTTP/HTTPS URL like "https://api.example.com/endpoint"',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      throw ArgumentError(
        'Invalid URL format: "$url"\n'
        'URL must start with http:// or https://\n'
        'Example: "https://api.example.com/endpoint"',
      );
    }
  }

  /// Validate file path and throw helpful error if invalid.
  static void _validateFilePath(String path, String parameterName) {
    if (path.isEmpty) {
      throw ArgumentError(
        '$parameterName cannot be empty.\n'
        'Provide a valid file path like "/path/to/file.jpg"',
      );
    }

    // SECURITY: Prevent path traversal attacks
    if (path.contains('..')) {
      throw ArgumentError(
        'Path traversal detected in $parameterName: "$path"\n'
        'Paths containing ".." are not allowed for security reasons.\n'
        'This prevents attacks like "../../../etc/passwd"',
      );
    }

    // SECURITY: Require absolute paths (relative paths can be manipulated)
    if (!path.startsWith('/')) {
      throw ArgumentError(
        'Relative path not allowed in $parameterName: "$path"\n'
        'Use absolute paths like "/path/to/file.jpg"\n'
        'Relative paths are blocked to prevent path traversal attacks',
      );
    }
  }

  // ── HTTP workers ────────────────────────────────────────────────────────────

  /// HTTP request worker (GET, POST, PUT, DELETE).
  /// See [_buildHttpRequest] (in native_worker_http.dart) for full documentation.
  static Worker httpRequest({
    required String url,
    HttpMethod method = HttpMethod.get,
    Map<String, String> headers = const {},
    String? body,
    Duration timeout = const Duration(seconds: 30),
  }) => _buildHttpRequest(
    url: url,
    method: method,
    headers: headers,
    body: body,
    timeout: timeout,
  );

  /// HTTP file upload worker (multipart).
  /// See [_buildHttpUpload] (in native_worker_http.dart) for full documentation.
  static Worker httpUpload({
    required String url,
    required String filePath,
    String fileFieldName = 'file',
    String? fileName,
    String? mimeType,
    Map<String, String> headers = const {},
    Map<String, String> additionalFields = const {},
    Duration timeout = const Duration(minutes: 5),
    bool useBackgroundSession = false,
  }) => _buildHttpUpload(
    url: url,
    filePath: filePath,
    fileFieldName: fileFieldName,
    fileName: fileName,
    mimeType: mimeType,
    headers: headers,
    additionalFields: additionalFields,
    timeout: timeout,
    useBackgroundSession: useBackgroundSession,
  );

  /// Upload multiple files in a single multipart/form-data HTTP request.
  /// See [_buildMultiUpload] (in native_worker_http.dart) for full documentation.
  static MultiUploadWorker multiUpload({
    required String url,
    required List<UploadFile> files,
    Map<String, String> headers = const {},
    Map<String, String> additionalFields = const {},
    Duration timeout = const Duration(minutes: 10),
    bool useBackgroundSession = false,
  }) => _buildMultiUpload(
    url: url,
    files: files,
    headers: headers,
    additionalFields: additionalFields,
    timeout: timeout,
    useBackgroundSession: useBackgroundSession,
  );

  /// Move a file from app-private storage to a shared / public location.
  /// See [_buildMoveToSharedStorage] (in native_worker_http.dart) for full documentation.
  static MoveToSharedStorageWorker moveToSharedStorage({
    required String sourcePath,
    required SharedStorageType storageType,
    String? fileName,
    String? mimeType,
    String? subDir,
  }) => _buildMoveToSharedStorage(
    sourcePath: sourcePath,
    storageType: storageType,
    fileName: fileName,
    mimeType: mimeType,
    subDir: subDir,
  );

  /// HTTP file download worker.
  /// See [_buildHttpDownload] (in native_worker_http.dart) for full documentation.
  static Worker httpDownload({
    required String url,
    required String savePath,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(minutes: 5),
    bool enableResume = true,
    String? expectedChecksum,
    String checksumAlgorithm = 'SHA-256',
    bool useBackgroundSession = false,
    bool skipExisting = false,
    bool allowPause = false,
    Map<String, String>? cookies,
    String? authToken,
    String authHeaderTemplate = 'Bearer {accessToken}',
    DuplicatePolicy onDuplicate = DuplicatePolicy.overwrite,
    bool moveToPublicDownloads = false,
    bool saveToGallery = false,
    bool extractAfterDownload = false,
    String? extractPath,
    bool deleteArchiveAfterExtract = false,
  }) => _buildHttpDownload(
    url: url,
    savePath: savePath,
    headers: headers,
    timeout: timeout,
    enableResume: enableResume,
    expectedChecksum: expectedChecksum,
    checksumAlgorithm: checksumAlgorithm,
    useBackgroundSession: useBackgroundSession,
    skipExisting: skipExisting,
    allowPause: allowPause,
    cookies: cookies,
    authToken: authToken,
    authHeaderTemplate: authHeaderTemplate,
    onDuplicate: onDuplicate,
    moveToPublicDownloads: moveToPublicDownloads,
    saveToGallery: saveToGallery,
    extractAfterDownload: extractAfterDownload,
    extractPath: extractPath,
    deleteArchiveAfterExtract: deleteArchiveAfterExtract,
  );

  /// Parallel chunked HTTP download worker.
  /// See [_buildParallelHttpDownload] (in native_worker_http.dart) for full documentation.
  static Worker parallelHttpDownload({
    required String url,
    required String savePath,
    int numChunks = 4,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(minutes: 10),
    String? expectedChecksum,
    String checksumAlgorithm = 'SHA-256',
    bool showNotification = false,
    String? notificationTitle,
    String? notificationBody,
    bool skipExisting = false,
  }) => _buildParallelHttpDownload(
    url: url,
    savePath: savePath,
    numChunks: numChunks,
    headers: headers,
    timeout: timeout,
    expectedChecksum: expectedChecksum,
    checksumAlgorithm: checksumAlgorithm,
    showNotification: showNotification,
    notificationTitle: notificationTitle,
    notificationBody: notificationBody,
    skipExisting: skipExisting,
  );

  /// Data sync worker (POST JSON, receive JSON).
  /// See [_buildHttpSync] (in native_worker_http.dart) for full documentation.
  static Worker httpSync({
    required String url,
    HttpMethod method = HttpMethod.post,
    Map<String, String> headers = const {},
    Map<String, dynamic>? requestBody,
    Duration timeout = const Duration(seconds: 60),
  }) => _buildHttpSync(
    url: url,
    method: method,
    headers: headers,
    requestBody: requestBody,
    timeout: timeout,
  );

  // ── Custom worker ────────────────────────────────────────────────────────────

  /// Custom native worker for user-defined implementations.
  /// See [_buildCustom] (in native_worker_custom.dart) for full documentation.
  static Worker custom({
    required String className,
    Map<String, dynamic>? input,
  }) => _buildCustom(className: className, input: input);

  // ── File workers ─────────────────────────────────────────────────────────────

  /// File compression worker (ZIP format).
  /// See [_buildFileCompress] (in native_worker_file.dart) for full documentation.
  static Worker fileCompress({
    required String inputPath,
    required String outputPath,
    CompressionLevel level = CompressionLevel.medium,
    List<String> excludePatterns = const [],
    bool deleteOriginal = false,
  }) => _buildFileCompress(
    inputPath: inputPath,
    outputPath: outputPath,
    level: level,
    excludePatterns: excludePatterns,
    deleteOriginal: deleteOriginal,
  );

  /// File decompression worker (ZIP extraction).
  /// See [_buildFileDecompress] (in native_worker_file.dart) for full documentation.
  static Worker fileDecompress({
    required String zipPath,
    required String targetDir,
    bool deleteAfterExtract = false,
    bool overwrite = true,
  }) => _buildFileDecompress(
    zipPath: zipPath,
    targetDir: targetDir,
    deleteAfterExtract: deleteAfterExtract,
    overwrite: overwrite,
  );

  /// Copy file or directory worker.
  /// See [_buildFileCopy] (in native_worker_file.dart) for full documentation.
  static Worker fileCopy({
    required String sourcePath,
    required String destinationPath,
    bool overwrite = false,
    bool recursive = true,
  }) => _buildFileCopy(
    sourcePath: sourcePath,
    destinationPath: destinationPath,
    overwrite: overwrite,
    recursive: recursive,
  );

  /// Move file or directory worker.
  /// See [_buildFileMove] (in native_worker_file.dart) for full documentation.
  static Worker fileMove({
    required String sourcePath,
    required String destinationPath,
    bool overwrite = false,
  }) => _buildFileMove(
    sourcePath: sourcePath,
    destinationPath: destinationPath,
    overwrite: overwrite,
  );

  /// Delete file or directory worker.
  /// See [_buildFileDelete] (in native_worker_file.dart) for full documentation.
  static Worker fileDelete({required String path, bool recursive = false}) =>
      _buildFileDelete(path: path, recursive: recursive);

  /// List directory contents worker.
  /// See [_buildFileList] (in native_worker_file.dart) for full documentation.
  static Worker fileList({
    required String path,
    String? pattern,
    bool recursive = false,
  }) => _buildFileList(path: path, pattern: pattern, recursive: recursive);

  /// Create directory worker (mkdir).
  /// See [_buildFileMkdir] (in native_worker_file.dart) for full documentation.
  static Worker fileMkdir({required String path, bool createParents = true}) =>
      _buildFileMkdir(path: path, createParents: createParents);

  // ── Crypto workers ───────────────────────────────────────────────────────────

  /// Cryptographic hash of a file.
  /// See [_buildHashFile] (in native_worker_crypto.dart) for full documentation.
  static Worker hashFile({
    required String filePath,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) => _buildHashFile(filePath: filePath, algorithm: algorithm);

  /// Hash string data.
  /// See [_buildHashString] (in native_worker_crypto.dart) for full documentation.
  static Worker hashString({
    required String data,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) => _buildHashString(data: data, algorithm: algorithm);

  /// File encryption worker (AES-256-GCM).
  /// See [_buildCryptoEncrypt] (in native_worker_crypto.dart) for full documentation.
  static Worker cryptoEncrypt({
    required String inputPath,
    required String outputPath,
    required String password,
  }) => _buildCryptoEncrypt(
    inputPath: inputPath,
    outputPath: outputPath,
    password: password,
  );

  /// File decryption worker (AES-256-GCM).
  /// See [_buildCryptoDecrypt] (in native_worker_crypto.dart) for full documentation.
  static Worker cryptoDecrypt({
    required String inputPath,
    required String outputPath,
    required String password,
  }) => _buildCryptoDecrypt(
    inputPath: inputPath,
    outputPath: outputPath,
    password: password,
  );

  // ── Image workers ────────────────────────────────────────────────────────────

  /// Image processing worker (resize, compress, convert).
  /// See [_buildImageProcess] (in native_worker_image.dart) for full documentation.
  static Worker imageProcess({
    required String inputPath,
    required String outputPath,
    int? maxWidth,
    int? maxHeight,
    bool maintainAspectRatio = true,
    int quality = 85,
    ImageFormat? outputFormat,
    Rect? cropRect,
    bool deleteOriginal = false,
  }) => _buildImageProcess(
    inputPath: inputPath,
    outputPath: outputPath,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    maintainAspectRatio: maintainAspectRatio,
    quality: quality,
    outputFormat: outputFormat,
    cropRect: cropRect,
    deleteOriginal: deleteOriginal,
  );
}
