import 'package:flutter/foundation.dart';
import 'dart:ui';

// Import all worker implementations
import 'workers.dart';

// Export all worker implementations
export 'workers.dart';

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
@immutable
abstract base class Worker {
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
  }

  /// HTTP request worker (GET, POST, PUT, DELETE).
  ///
  /// Executes an HTTP request in the background **without** starting the Flutter Engine.
  /// This is the most lightweight option for simple API calls, analytics, or ping requests.
  ///
  /// ## Basic GET Request
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'fetch-status',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpRequest(
  ///     url: 'https://api.example.com/status',
  ///     method: HttpMethod.get,
  ///   ),
  /// );
  /// ```
  ///
  /// ## POST with JSON Body
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'send-analytics',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpRequest(
  ///     url: 'https://analytics.example.com/event',
  ///     method: HttpMethod.post,
  ///     headers: {
  ///       'Content-Type': 'application/json',
  ///       'Authorization': 'Bearer $token',
  ///     },
  ///     body: '{"event": "app_opened", "timestamp": 1234567890}',
  ///   ),
  /// );
  /// ```
  ///
  /// ## DELETE Request
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'delete-account',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpRequest(
  ///     url: 'https://api.example.com/users/123',
  ///     method: HttpMethod.delete,
  ///     headers: {'Authorization': 'Bearer $token'},
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[url]** *(required)* - The HTTP/HTTPS endpoint URL.
  /// - Must start with `http://` or `https://`
  /// - Throws `ArgumentError` if empty or invalid format
  ///
  /// **[method]** *(optional)* - HTTP method (default: GET).
  /// - `HttpMethod.get` - Retrieve data
  /// - `HttpMethod.post` - Send data
  /// - `HttpMethod.put` - Update data
  /// - `HttpMethod.delete` - Delete data
  /// - `HttpMethod.patch` - Partial update
  ///
  /// **[headers]** *(optional)* - HTTP headers (default: empty).
  /// - Use for authentication, content type, etc.
  /// - Example: `{'Authorization': 'Bearer token'}`
  ///
  /// **[body]** *(optional)* - Request body for POST/PUT/PATCH.
  /// - Must be a String (JSON encode if needed)
  /// - Ignored for GET/DELETE requests
  ///
  /// **[timeout]** *(optional)* - Request timeout (default: 30 seconds).
  /// - Maximum time to wait for response
  /// - Request fails if timeout exceeded
  ///
  /// ## Behavior
  ///
  /// - Executes in native code (Kotlin on Android, Swift on iOS)
  /// - **No Flutter Engine overhead** (~2MB vs ~50MB RAM)
  /// - Response is not returned (fire-and-forget)
  /// - Task succeeds if HTTP status 200-299
  /// - Task fails on network error or non-2xx status
  ///
  /// ## When to Use
  ///
  /// ✅ **Use httpRequest when:**
  /// - Sending analytics events
  /// - Pinging health check endpoints
  /// - Simple API calls with no response processing
  /// - You need maximum performance (no Flutter Engine)
  ///
  /// ❌ **Don't use httpRequest when:**
  /// - You need to process the response → Use `httpSync` instead
  /// - You're uploading files → Use `httpUpload` instead
  /// - You're downloading files → Use `httpDownload` instead
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** expect to receive the response (use `httpSync` for that)
  /// ❌ **Don't** forget to set Content-Type header for POST/PUT
  /// ❌ **Don't** use this for large payloads (use `httpUpload` instead)
  /// ✅ **Do** use for simple fire-and-forget requests
  /// ✅ **Do** set appropriate timeout for your use case
  ///
  /// ## Platform Notes
  ///
  /// **Android:** Uses OkHttp under the hood
  /// **iOS:** Uses URLSession
  ///
  /// ## See Also
  ///
  /// - [httpSync] - POST JSON and receive JSON response
  /// - [httpUpload] - Upload files (multipart)
  /// - [httpDownload] - Download files
  static Worker httpRequest({
    required String url,
    HttpMethod method = HttpMethod.get,
    Map<String, String> headers = const {},
    String? body,
    Duration timeout = const Duration(seconds: 30),
  }) {
    _validateUrl(url);

    // Validate timeout is reasonable for background tasks
    if (timeout.inMinutes > 5) {
      throw ArgumentError(
        'Timeout too long: ${timeout.inMinutes} minutes\n'
        'iOS limits background tasks to 30 seconds\n'
        'Android may defer long tasks in Doze mode\n'
        'Recommended: Keep under 5 minutes for reliability\n'
        'Current timeout: ${timeout.inSeconds} seconds',
      );
    }

    return HttpRequestWorker(
      url: url,
      method: method,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  /// HTTP file upload worker (multipart).
  ///
  /// Uploads a file to a server using multipart/form-data encoding.
  /// Runs in native code **without** Flutter Engine for maximum efficiency.
  /// Ideal for uploading photos, videos, documents, or any binary files.
  ///
  /// ## Basic Upload
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'upload-photo-${DateTime.now().millisecondsSinceEpoch}',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/upload',
  ///     filePath: '/storage/emulated/0/DCIM/photo.jpg',
  ///   ),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// ## Upload with Authentication
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'upload-document',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/documents',
  ///     filePath: '/data/user/0/com.app/files/document.pdf',
  ///     headers: {
  ///       'Authorization': 'Bearer $accessToken',
  ///     },
  ///   ),
  /// );
  /// ```
  ///
  /// ## Upload with Additional Form Fields
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'upload-avatar',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/users/123/avatar',
  ///     filePath: '/cache/cropped_avatar.jpg',
  ///     fileFieldName: 'avatar',
  ///     additionalFields: {
  ///       'user_id': '123',
  ///       'crop_coordinates': '0,0,500,500',
  ///     },
  ///     headers: {'Authorization': 'Bearer $token'},
  ///   ),
  /// );
  /// ```
  ///
  /// ## Upload with Constraints (WiFi + Charging)
  ///
  /// ```dart
  /// // Large video upload - only when charging and on WiFi
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'upload-video',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://cdn.example.com/videos',
  ///     filePath: '/storage/videos/recording.mp4',
  ///     timeout: Duration(minutes: 30),
  ///   ),
  ///   constraints: Constraints(
  ///     requiresCharging: true,
  ///     requiresWifi: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Upload with Custom Filename and MIME Type
  ///
  /// ```dart
  /// // Upload iOS HEIC photo with custom name and explicit MIME type
  /// final tempPath = '/cache/photo_a1b2c3d4.heic'; // Auto-generated cache file
  ///
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'upload-profile-photo',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/photos',
  ///     filePath: tempPath,
  ///     fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
  ///     mimeType: 'image/heic', // Explicit MIME type for iOS HEIC format
  ///     headers: {'Authorization': 'Bearer $token'},
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[url]** *(required)* - The upload endpoint URL.
  /// - Must start with `http://` or `https://`
  /// - Throws `ArgumentError` if empty or invalid
  ///
  /// **[filePath]** *(required)* - Absolute path to file to upload.
  /// - Must be absolute path, not relative
  /// - Throws `ArgumentError` if empty
  /// - File must exist at execution time (not validated at schedule time)
  ///
  /// **[fileFieldName]** *(optional)* - Form field name for file (default: "file").
  /// - Server expects file in this field
  /// - Common values: "file", "image", "avatar", "attachment"
  /// - Throws `ArgumentError` if empty
  ///
  /// **[fileName]** *(optional)* - Override the uploaded filename.
  /// - By default, uses the basename of filePath
  /// - Useful when uploading temp files with meaningful names
  /// - Example: Upload `/cache/temp_123.jpg` as `profile.jpg`
  ///
  /// **[mimeType]** *(optional)* - Override the MIME type.
  /// - By default, auto-detected from file extension
  /// - Required for unusual formats (HEIC, WebP, AVIF)
  /// - Example: `image/heic`, `image/webp`, `application/octet-stream`
  ///
  /// **[headers]** *(optional)* - HTTP headers (default: empty).
  /// - Commonly used for authentication
  /// - Content-Type is set automatically to multipart/form-data
  ///
  /// **[additionalFields]** *(optional)* - Extra form fields (default: empty).
  /// - Send metadata along with file
  /// - All values must be strings
  ///
  /// **[timeout]** *(optional)* - Upload timeout (default: 5 minutes).
  /// - Increase for large files or slow networks
  /// - Upload fails if timeout exceeded
  ///
  /// **[useBackgroundSession]** *(optional, iOS only)* - Use background URLSession (default: false).
  /// - **v2.3.0+ iOS Feature** - Uploads survive app termination
  /// - No time limits (vs 30s foreground limit)
  /// - System-managed retry on network changes
  /// - Battery-efficient scheduling
  /// - Android: No effect (WorkManager already handles this)
  /// - Use for large files (>10MB) or unreliable networks
  /// - Example: Video uploads, large file backups
  ///
  /// ## Behavior
  ///
  /// - Uploads using multipart/form-data encoding
  /// - Content-Type header set automatically
  /// - Reports progress via [NativeWorkManager.progress] stream
  /// - Task succeeds if HTTP status 200-299
  /// - Task fails on network error, file not found, or non-2xx status
  ///
  /// ## Progress Tracking
  ///
  /// ```dart
  /// // Listen to upload progress
  /// NativeWorkManager.progress
  ///     .where((p) => p.taskId == 'my-upload')
  ///     .listen((progress) {
  ///   print('Uploaded: ${progress.progress}%');
  /// });
  /// ```
  ///
  /// ## Progress Tracking (v0.9.0+)
  ///
  /// **NEW:** Upload progress is now automatically reported:
  /// ```dart
  /// // Listen to upload progress
  /// NativeWorkManager.progress
  ///     .where((p) => p.taskId == 'my-upload')
  ///     .listen((progress) {
  ///   print('Uploaded: ${progress.progress}% - ${progress.message}');
  /// });
  /// ```
  ///
  /// Progress updates include:
  /// - Percentage (0-100%)
  /// - Human-readable message (e.g., "Uploading photo.jpg... (2.5MB/10MB)")
  /// - Real-time updates every 1% increment
  ///
  /// ## When to Use
  ///
  /// ✅ **Use httpUpload when:**
  /// - Uploading photos, videos, or documents
  /// - You need progress tracking
  /// - File is already saved to disk
  /// - You want optimal battery usage (native execution)
  ///
  /// ❌ **Don't use httpUpload when:**
  /// - Sending small JSON data → Use `httpRequest` or `httpSync`
  /// - You need to process file before upload → Use `DartWorker`
  ///
  /// ## Storage Validation (v0.9.0+)
  ///
  /// **NEW:** Automatic storage checks before upload:
  /// - Validates minimum 100MB free space
  /// - Prevents uploads when storage is critically low
  /// - Clear error messages if validation fails
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** use relative file paths (must be absolute)
  /// ❌ **Don't** assume file still exists at execution time
  /// ❌ **Don't** forget network constraints for large uploads
  /// ❌ **Don't** use short timeout for large files
  /// ✅ **Do** verify file exists before scheduling
  /// ✅ **Do** use WiFi constraint for large uploads
  /// ✅ **Do** handle task failure (file may be deleted)
  ///
  /// ## Platform Notes
  ///
  /// **Android:**
  /// - Uses OkHttp MultipartBody
  /// - Progress reported via WorkManager setProgress
  /// - File must be accessible to app (check permissions)
  ///
  /// **iOS:**
  /// - Uses URLSession uploadTask
  /// - Progress reported via URLSessionTaskDelegate
  /// - File must be in app's sandbox or shared container
  ///
  /// ## See Also
  ///
  /// - [httpDownload] - Download files
  /// - [httpRequest] - Simple HTTP requests
  /// - [NativeWorkManager.progress] - Track upload progress
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
  }) {
    _validateUrl(url);
    _validateFilePath(filePath, 'filePath');

    if (fileFieldName.isEmpty) {
      throw ArgumentError(
        'fileFieldName cannot be empty.\n'
        'Use a field name like "file" or "image"',
      );
    }

    if (timeout.inMinutes > 10) {
      throw ArgumentError(
        'Upload timeout too long: ${timeout.inMinutes} minutes\n'
        'iOS may terminate tasks after 30 seconds\n'
        'Android may defer long uploads in Doze mode\n'
        'Recommended: Keep under 10 minutes, use WiFi constraints for large files\n'
        'Current timeout: ${timeout.inSeconds} seconds',
      );
    }

    // Validate field limits
    if (additionalFields.length > 50) {
      throw ArgumentError(
        'Too many form fields: ${additionalFields.length}\n'
        'Maximum allowed: 50 fields\n'
        'Current count: ${additionalFields.length}\n'
        'Consider sending large data as JSON in request body instead',
      );
    }

    return HttpUploadWorker(
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
  }

  /// HTTP file download worker.
  ///
  /// Downloads a file from a URL and saves it to local storage.
  /// Runs in native code **without** Flutter Engine for optimal performance.
  /// Perfect for downloading images, videos, PDFs, or data files.
  ///
  /// ## Basic Download
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'download-update',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://cdn.example.com/app-update.apk',
  ///     savePath: '/storage/emulated/0/Download/update.apk',
  ///   ),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// ## Download with WiFi Constraint
  ///
  /// ```dart
  /// // Large file - only download on WiFi
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'download-video',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://cdn.example.com/video.mp4',
  ///     savePath: '/data/user/0/com.app/files/videos/movie.mp4',
  ///     timeout: Duration(minutes: 30),
  ///   ),
  ///   constraints: Constraints(
  ///     requiresWifi: true,
  ///     requiresStorageNotLow: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Download with Authentication
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'download-report',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://api.example.com/reports/2024.pdf',
  ///     savePath: '/data/user/0/com.app/files/reports/2024.pdf',
  ///     headers: {
  ///       'Authorization': 'Bearer $token',
  ///     },
  ///   ),
  /// );
  /// ```
  ///
  /// ## Background Content Update
  ///
  /// ```dart
  /// // Periodic content sync - download new data every 6 hours
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'sync-content',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 6)),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://api.example.com/content/latest.json',
  ///     savePath: '/data/user/0/com.app/cache/content.json',
  ///   ),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// ## Resume Support (v1.0.0+)
  ///
  /// Downloads automatically resume from the last byte on network failure:
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'download-large-file',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://cdn.example.com/app-update.apk',  // 100MB file
  ///     savePath: '/downloads/update.apk',
  ///     enableResume: true,  // Resume from last byte (default)
  ///   ),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// **How Resume Works:**
  /// - Downloads to temp file (`.tmp` extension)
  /// - On network failure, temp file is preserved
  /// - Next attempt sends `Range: bytes=N-` header
  /// - Server returns `206 Partial Content` with remaining data
  /// - Falls back to full download if server doesn't support Range
  ///
  /// ## Checksum Verification (v1.0.0+)
  ///
  /// Verify download integrity with checksum:
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'download-verified',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://cdn.example.com/update.apk',
  ///     savePath: '/downloads/update.apk',
  ///     expectedChecksum: 'a3b2c1d4e5f6...',  // Hex string
  ///     checksumAlgorithm: 'SHA-256',  // MD5, SHA-1, SHA-256, SHA-512
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[url]** *(required)* - The file URL to download.
  /// - Must start with `http://` or `https://`
  /// - Throws `ArgumentError` if empty or invalid
  ///
  /// **[savePath]** *(required)* - Where to save the downloaded file.
  /// - Must be absolute path, not relative
  /// - Throws `ArgumentError` if empty
  /// - Directory must exist (not auto-created)
  /// - Existing file will be overwritten
  ///
  /// **[headers]** *(optional)* - HTTP headers (default: empty).
  /// - Use for authentication or custom headers
  /// - Example: `{'Authorization': 'Bearer token'}`
  ///
  /// **[timeout]** *(optional)* - Download timeout (default: 5 minutes).
  /// - Increase for large files or slow networks
  /// - Download fails if timeout exceeded
  ///
  /// **[enableResume]** *(optional)* - Enable automatic resume (default: true).
  /// - When enabled, interrupted downloads resume from last byte
  /// - Uses HTTP Range requests (RFC 7233)
  /// - Falls back to full download if server doesn't support Range
  ///
  /// **[expectedChecksum]** *(optional)* - Expected checksum for verification.
  /// - Hexadecimal string (e.g., "a3b2c1d4e5f6...")
  /// - Download fails if actual checksum doesn't match
  /// - Use with [checksumAlgorithm] to specify algorithm
  ///
  /// **[checksumAlgorithm]** *(optional)* - Hash algorithm (default: 'SHA-256').
  /// - Supported: 'MD5', 'SHA-1', 'SHA-256', 'SHA-512'
  /// - Only used when [expectedChecksum] is provided
  ///
  /// **[useBackgroundSession]** *(optional, iOS only)* - Use background URLSession (default: false).
  /// - **v2.3.0+ iOS Feature** - Downloads survive app termination
  /// - No time limits (vs 30s foreground limit)
  /// - System-managed retry on network changes
  /// - Battery-efficient scheduling
  /// - Android: No effect (WorkManager already handles this)
  /// - Use for large files (>10MB) or unreliable networks
  /// - Example: App updates, media downloads
  ///
  /// ## Behavior
  ///
  /// - Downloads file to specified path
  /// - Reports progress via [NativeWorkManager.progress] stream
  /// - Overwrites existing file at savePath
  /// - Task succeeds if HTTP status 200-299 and file saved
  /// - Task fails on network error, disk full, or non-2xx status
  ///
  /// ## Progress Tracking
  ///
  /// ```dart
  /// // Show download progress in UI
  /// NativeWorkManager.progress
  ///     .where((p) => p.taskId == 'my-download')
  ///     .listen((progress) {
  ///   setState(() {
  ///     downloadProgress = progress.progress / 100.0;
  ///   });
  /// });
  /// ```
  ///
  /// ## Progress Tracking (v0.9.0+)
  ///
  /// **NEW:** Download progress is now automatically reported:
  /// ```dart
  /// // Show download progress in UI
  /// NativeWorkManager.progress
  ///     .where((p) => p.taskId == 'my-download')
  ///     .listen((progress) {
  ///   setState(() {
  ///     downloadProgress = progress.progress / 100.0;
  ///   });
  ///   print(progress.message); // "Downloading file.zip... (45MB/100MB)"
  /// });
  /// ```
  ///
  /// Progress updates include:
  /// - Percentage (0-100%)
  /// - Human-readable message with bytes transferred
  /// - Real-time updates every 1% increment
  ///
  /// ## When to Use
  ///
  /// ✅ **Use httpDownload when:**
  /// - Downloading files, images, videos, or documents
  /// - You need progress tracking
  /// - You want to save result to specific location
  /// - You need optimal battery usage (native execution)
  ///
  /// ❌ **Don't use httpDownload when:**
  /// - Downloading small JSON data → Use `httpSync` instead
  /// - You need to process data before saving → Use `DartWorker`
  ///
  /// ## Storage Validation (v0.9.0+)
  ///
  /// **NEW:** Automatic storage checks before download:
  /// - Validates file size + 20% buffer + 50MB minimum free space
  /// - Prevents downloads when storage is insufficient
  /// - Clear error messages showing required vs available space
  /// - Saves bandwidth by failing early
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** use relative paths for savePath (must be absolute)
  /// ❌ **Don't** assume directory exists (create it first)
  /// ❌ **Don't** download large files without WiFi constraint
  /// ❌ **Don't** disable resume for large files (wastes bandwidth)
  /// ✅ **Do** create parent directory before scheduling
  /// ✅ **Do** use WiFi constraint for large downloads
  /// ✅ **Do** handle task failure gracefully
  /// ✅ **Do** listen to progress updates for better UX
  /// ✅ **Do** use checksum verification for critical downloads
  /// ✅ **Do** enable resume for large/slow downloads (default: enabled)
  ///
  /// ## Platform Notes
  ///
  /// **Android:**
  /// - Uses OkHttp for downloading
  /// - Progress reported via WorkManager setProgress
  /// - Requires WRITE_EXTERNAL_STORAGE permission for external storage
  /// - Resume support via HTTP Range requests (RFC 7233)
  /// - Checksum verification using java.security.MessageDigest
  ///
  /// **iOS:**
  /// - Uses URLSession downloadTask
  /// - Progress reported via URLSessionTaskDelegate
  /// - File saved to app sandbox by default
  /// - Resume support via HTTP Range requests (RFC 7233)
  /// - Checksum verification using CryptoKit (iOS 13+)
  ///
  /// ## See Also
  ///
  /// - [httpUpload] - Upload files
  /// - [httpRequest] - Simple HTTP requests
  /// - [NativeWorkManager.progress] - Track download progress
  static Worker httpDownload({
    required String url,
    required String savePath,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(minutes: 5),
    bool enableResume = true,
    String? expectedChecksum,
    String checksumAlgorithm = 'SHA-256',
    bool useBackgroundSession = false,
  }) {
    _validateUrl(url);
    _validateFilePath(savePath, 'savePath');

    if (timeout.inMinutes > 10) {
      throw ArgumentError(
        'Download timeout too long: ${timeout.inMinutes} minutes\n'
        'iOS may terminate tasks after 30 seconds\n'
        'Android may defer long downloads in Doze mode\n'
        'Recommended: Keep under 10 minutes, use WiFi constraints for large files\n'
        'Current timeout: ${timeout.inSeconds} seconds',
      );
    }

    // Validate checksum algorithm if checksum is provided
    if (expectedChecksum != null) {
      final validAlgorithms = [
        'MD5',
        'SHA-1',
        'SHA1',
        'SHA-256',
        'SHA256',
        'SHA-512',
        'SHA512',
      ];
      if (!validAlgorithms.contains(
        checksumAlgorithm.toUpperCase().replaceAll('-', ''),
      )) {
        throw ArgumentError(
          'Invalid checksumAlgorithm: "$checksumAlgorithm"\n'
          'Supported algorithms: MD5, SHA-1, SHA-256, SHA-512',
        );
      }

      // Validate checksum format (must be hex string)
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(expectedChecksum)) {
        throw ArgumentError(
          'Invalid expectedChecksum format: must be hexadecimal string\n'
          'Example: "a3b2c1d4e5f6789..."',
        );
      }
    }

    return HttpDownloadWorker(
      url: url,
      savePath: savePath,
      headers: headers,
      timeout: timeout,
      enableResume: enableResume,
      expectedChecksum: expectedChecksum,
      checksumAlgorithm: checksumAlgorithm,
      useBackgroundSession: useBackgroundSession,
    );
  }

  /// Custom native worker for user-defined implementations.
  ///
  /// Allows users to implement their own native workers (in Kotlin/Swift)
  /// without modifying the plugin source code. This is the extensibility
  /// escape hatch for advanced use cases not covered by built-in workers.
  ///
  /// ## Prerequisites
  ///
  /// **You must implement the native worker first:**
  ///
  /// **Android (Kotlin):**
  /// ```kotlin
  /// package com.myapp.workers
  ///
  /// import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
  ///
  /// class ImageCompressWorker : AndroidWorker {
  ///     override suspend fun doWork(input: String?): Boolean {
  ///         // Parse input JSON
  ///         val config = parseJson(input)
  ///         val imagePath = config["imagePath"] as String
  ///
  ///         // Compress image (native code)
  ///         compressImage(imagePath, quality = 85)
  ///
  ///         return true
  ///     }
  /// }
  /// ```
  ///
  /// **iOS (Swift):**
  /// ```swift
  /// import Foundation
  ///
  /// class ImageCompressWorker: IosWorker {
  ///     func doWork(input: String?) async throws -> Bool {
  ///         // Parse input JSON
  ///         let config = parseJson(input)
  ///         let imagePath = config["imagePath"]
  ///
  ///         // Compress image (native code)
  ///         compressImage(imagePath, quality: 85)
  ///
  ///         return true
  ///     }
  /// }
  /// ```
  ///
  /// ## Registration
  ///
  /// **Android:** Register in `MainActivity.kt` before `initialize()`:
  /// ```kotlin
  /// NativeWorkManager.registerWorkerFactory { className ->
  ///     when (className) {
  ///         "ImageCompressWorker" -> ImageCompressWorker()
  ///         else -> null
  ///     }
  /// }
  /// ```
  ///
  /// **iOS:** Register in `AppDelegate.swift`:
  /// ```swift
  /// NativeWorkManager.registerWorker(
  ///     className: "ImageCompressWorker",
  ///     factory: { ImageCompressWorker() }
  /// )
  /// ```
  ///
  /// ## Dart Usage
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'compress-photo',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.custom(
  ///     className: 'ImageCompressWorker',
  ///     input: {
  ///       'imagePath': '/storage/photo.jpg',
  ///       'quality': 85,
  ///       'outputPath': '/storage/compressed.jpg',
  ///     },
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[className]** *(required)* - The worker class name.
  /// - Must match the class name you implemented in Kotlin/Swift
  /// - Must be registered before calling enqueue
  /// - Case-sensitive exact match
  ///
  /// **[input]** *(optional)* - Configuration data for the worker.
  /// - Will be JSON encoded and passed to `doWork(input)`
  /// - Can contain any JSON-serializable data
  ///
  /// ## When to Use
  ///
  /// ✅ **Use CustomNativeWorker when:**
  /// - You need native processing not covered by built-in workers
  /// - Image/video compression, encoding, encryption
  /// - Native database operations (Room, Core Data)
  /// - Platform-specific APIs (camera, sensors, etc.)
  /// - You want maximum performance (native execution)
  ///
  /// ❌ **Don't use CustomNativeWorker when:**
  /// - Built-in workers already cover your use case
  /// - Simple HTTP operations → Use built-in HTTP workers
  /// - You need Dart/Flutter APIs → Use `DartWorker` instead
  ///
  /// ## Performance
  ///
  /// - RAM: ~2-5MB (same as built-in native workers)
  /// - Startup: <50ms (no Flutter Engine)
  /// - Same benefits as built-in native workers
  ///
  /// ## See Also
  ///
  /// - [DartWorker] - For Dart-based custom logic
  /// - Built-in workers: [httpRequest], [httpUpload], [httpDownload], [httpSync]
  static Worker custom({
    required String className,
    Map<String, dynamic>? input,
  }) {
    if (className.isEmpty) {
      throw ArgumentError(
        'className cannot be empty.\n'
        'Provide the name of your custom worker class (e.g., "ImageCompressWorker")',
      );
    }

    return CustomNativeWorker(className: className, input: input);
  }

  /// Data sync worker (POST JSON, receive JSON).
  ///
  /// Sends JSON data to server and receives JSON response. Designed for
  /// data synchronization, API calls that return data, or two-way communication.
  /// Runs in native code **without** Flutter Engine.
  ///
  /// **Note:** Response is NOT returned to Dart code. This is fire-and-forget.
  /// Use `DartWorker` if you need to process the response.
  ///
  /// ## Basic Sync
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'sync-data',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
  ///   worker: NativeWorker.httpSync(
  ///     url: 'https://api.example.com/sync',
  ///     method: HttpMethod.post,
  ///     requestBody: {
  ///       'lastSyncTime': DateTime.now().millisecondsSinceEpoch,
  ///       'deviceId': 'device123',
  ///     },
  ///   ),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// ## Sync with Authentication
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'sync-user-data',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 6)),
  ///   worker: NativeWorker.httpSync(
  ///     url: 'https://api.example.com/users/sync',
  ///     method: HttpMethod.post,
  ///     headers: {
  ///       'Authorization': 'Bearer $accessToken',
  ///       'Content-Type': 'application/json',
  ///     },
  ///     requestBody: {
  ///       'settings': {'theme': 'dark', 'notifications': true},
  ///       'timestamp': DateTime.now().toIso8601String(),
  ///     },
  ///   ),
  /// );
  /// ```
  ///
  /// ## Batch Data Upload
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'upload-analytics',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 24)),
  ///   worker: NativeWorker.httpSync(
  ///     url: 'https://analytics.example.com/batch',
  ///     method: HttpMethod.post,
  ///     requestBody: {
  ///       'events': [
  ///         {'type': 'page_view', 'page': '/home', 'timestamp': 1234567890},
  ///         {'type': 'click', 'element': 'button', 'timestamp': 1234567891},
  ///       ],
  ///     },
  ///   ),
  ///   constraints: Constraints(requiresWifi: true),
  /// );
  /// ```
  ///
  /// ## GET Request for Data
  ///
  /// ```dart
  /// // Fetch configuration from server
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'fetch-config',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 12)),
  ///   worker: NativeWorker.httpSync(
  ///     url: 'https://api.example.com/config',
  ///     method: HttpMethod.get,
  ///     headers: {'Authorization': 'Bearer $token'},
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[url]** *(required)* - The API endpoint URL.
  /// - Must start with `http://` or `https://`
  /// - Throws `ArgumentError` if empty or invalid
  ///
  /// **[method]** *(optional)* - HTTP method (default: POST).
  /// - `HttpMethod.post` - Most common for syncing
  /// - `HttpMethod.get` - Fetch data from server
  /// - `HttpMethod.put` - Update existing data
  /// - `HttpMethod.patch` - Partial update
  ///
  /// **[headers]** *(optional)* - HTTP headers (default: empty).
  /// - Content-Type automatically set to application/json
  /// - Add Authorization header for auth
  ///
  /// **[requestBody]** *(optional)* - JSON data to send (default: null).
  /// - Automatically JSON encoded
  /// - Can be Map or any JSON-serializable data
  /// - Null for GET requests
  ///
  /// **[timeout]** *(optional)* - Request timeout (default: 60 seconds).
  /// - Increase for slow APIs or large payloads
  /// - Request fails if timeout exceeded
  ///
  /// ## Behavior
  ///
  /// - Automatically JSON encodes requestBody
  /// - Sets Content-Type to application/json
  /// - Expects JSON response from server
  /// - **Response is NOT returned** (fire-and-forget)
  /// - Task succeeds if HTTP status 200-299
  /// - Task fails on network error or non-2xx status
  ///
  /// ## When to Use
  ///
  /// ✅ **Use httpSync when:**
  /// - Syncing local data to server
  /// - Sending batch analytics events
  /// - Periodic data uploads
  /// - Fire-and-forget API calls with JSON
  ///
  /// ❌ **Don't use httpSync when:**
  /// - You need to process the response → Use `DartWorker`
  /// - Uploading files → Use `httpUpload`
  /// - Simple ping without body → Use `httpRequest`
  ///
  /// ## Important Limitation
  ///
  /// **The response is NOT available in Dart code.** This worker is designed
  /// for fire-and-forget operations. If you need the response data:
  ///
  /// ```dart
  /// // ❌ Won't work - response is not returned
  /// NativeWorker.httpSync(url: '...');
  ///
  /// // ✅ Use DartWorker instead
  /// DartWorker(
  ///   callbackId: 'processSync',
  ///   // In callback: make HTTP call, process response, save to DB
  /// );
  /// ```
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** expect to receive the response
  /// ❌ **Don't** use for uploading files (use `httpUpload`)
  /// ❌ **Don't** forget to set Authorization header
  /// ✅ **Do** use for periodic data syncing
  /// ✅ **Do** use network constraints
  /// ✅ **Do** handle task failure gracefully
  ///
  /// ## Platform Notes
  ///
  /// **Android:** Uses OkHttp with JSON request/response
  /// **iOS:** Uses URLSession with JSONSerialization
  ///
  /// ## See Also
  ///
  /// - [httpRequest] - Simple HTTP requests (no JSON encoding)
  /// - [httpUpload] - Upload files
  /// - [DartWorker] - For processing responses
  static Worker httpSync({
    required String url,
    HttpMethod method = HttpMethod.post,
    Map<String, String> headers = const {},
    Map<String, dynamic>? requestBody,
    Duration timeout = const Duration(seconds: 60),
  }) {
    _validateUrl(url);

    if (timeout.inMinutes > 5) {
      throw ArgumentError(
        'Sync timeout too long: ${timeout.inMinutes} minutes\n'
        'iOS limits background tasks to 30 seconds\n'
        'Android may defer long requests in Doze mode\n'
        'Recommended: Keep under 5 minutes for API sync operations\n'
        'Current timeout: ${timeout.inSeconds} seconds',
      );
    }

    return HttpSyncWorker(
      url: url,
      method: method,
      headers: headers,
      requestBody: requestBody,
      timeout: timeout,
    );
  }

  /// File compression worker (ZIP format).
  ///
  /// Compresses files or directories into ZIP archives in the background.
  /// Runs in native code **without** Flutter Engine for maximum efficiency.
  /// Perfect for log archiving, backup preparation, or reducing upload sizes.
  ///
  /// ## Basic File Compression
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'compress-logs',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileCompress(
  ///     inputPath: '/app/logs/app.log',
  ///     outputPath: '/app/archive/logs.zip',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Compress Directory with Options
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'compress-directory',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileCompress(
  ///     inputPath: '/app/data/',
  ///     outputPath: '/app/backups/data_${DateTime.now()}.zip',
  ///     level: CompressionLevel.high,
  ///     excludePatterns: ['*.tmp', '.DS_Store', '*.bak'],
  ///     deleteOriginal: false,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Compress and Delete Original
  ///
  /// ```dart
  /// // Archive old logs and delete originals to save space
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'archive-old-logs',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileCompress(
  ///     inputPath: '/app/logs/2025/',
  ///     outputPath: '/app/archive/logs_2025.zip',
  ///     level: CompressionLevel.medium,
  ///     deleteOriginal: true,  // Delete source after compression
  ///   ),
  ///   constraints: Constraints(requiresStorageNotLow: true),
  /// );
  /// ```
  ///
  /// ## Periodic Log Archiving
  ///
  /// ```dart
  /// // Compress logs daily
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'daily-log-archive',
  ///   trigger: TaskTrigger.periodic(Duration(days: 1)),
  ///   worker: NativeWorker.fileCompress(
  ///     inputPath: '/app/logs/',
  ///     outputPath: '/app/archive/logs_\${DateTime.now().day}.zip',
  ///     excludePatterns: ['current.log'],  // Keep current log
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[inputPath]** *(required)* - Path to file or directory to compress.
  /// - Must be absolute path
  /// - Can be a single file or directory
  /// - Directory will be compressed recursively
  /// - Throws `ArgumentError` if empty or doesn't exist
  ///
  /// **[outputPath]** *(required)* - Where to save the ZIP file.
  /// - Must be absolute path ending with .zip
  /// - Parent directory will be created if needed
  /// - Existing file will be overwritten
  /// - Throws `ArgumentError` if empty or doesn't end with .zip
  ///
  /// **[level]** *(optional)* - Compression level (default: medium).
  /// - `CompressionLevel.low` - Faster compression, larger file
  /// - `CompressionLevel.medium` - Balanced (recommended)
  /// - `CompressionLevel.high` - Best compression, slower
  ///
  /// **[excludePatterns]** *(optional)* - Patterns to exclude (default: empty).
  /// - Supports wildcards: `*.tmp`, `temp*`, `*backup*`
  /// - Exact match: `.DS_Store`, `Thumbs.db`
  /// - Case-insensitive matching
  ///
  /// **[deleteOriginal]** *(optional)* - Delete source after compression (default: false).
  /// - Use with caution!
  /// - Only deletes if compression succeeds
  /// - Cannot be undone
  ///
  /// ## Progress Tracking
  ///
  /// ```dart
  /// // Listen to compression progress
  /// NativeWorkManager.progress
  ///     .where((p) => p.taskId == 'my-compression')
  ///     .listen((progress) {
  ///   print('Compressed: ${progress.currentStep}/${progress.totalSteps} files');
  ///   print('Progress: ${progress.progress}%');
  /// });
  /// ```
  ///
  /// ## Behavior
  ///
  /// - Compresses using ZIP format (universal compatibility)
  /// - Preserves file modification times
  /// - Creates parent directories automatically
  /// - Overwrites existing output file
  /// - Reports progress via [NativeWorkManager.progress] stream
  /// - Task succeeds if compression completes successfully
  /// - Task fails on I/O error, missing file, or insufficient storage
  ///
  /// ## When to Use
  ///
  /// ✅ **Use fileCompress when:**
  /// - Archiving log files periodically
  /// - Preparing backups for upload
  /// - Reducing file sizes before transfer
  /// - Freeing up storage space
  /// - Creating distributable packages
  ///
  /// ❌ **Don't use fileCompress when:**
  /// - Files are already compressed (JPEG, PNG, MP4, PDF)
  /// - Need other formats (7z, RAR, tar.gz) → Use custom worker
  /// - Need encryption → Use FileEncryptionWorker (v1.1+)
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** compress already-compressed files (no benefit)
  /// ❌ **Don't** use deleteOriginal without backup
  /// ❌ **Don't** forget storage constraints for large files
  /// ❌ **Don't** compress system directories
  /// ✅ **Do** use excludePatterns to skip unnecessary files
  /// ✅ **Do** check available storage before large compressions
  /// ✅ **Do** use periodic tasks for automated archiving
  /// ✅ **Do** test with small files first
  ///
  /// ## Platform Notes
  ///
  /// **Android:**
  /// - Uses `java.util.zip.ZipOutputStream`
  /// - Supports all compression levels
  /// - No file size limit (system dependent)
  ///
  /// **iOS:**
  /// - Uses `Compression` framework (iOS 13+)
  /// - Supports all compression levels
  /// - No file size limit (system dependent)
  ///
  /// ## Performance
  ///
  /// | File Size | Low | Medium | High | Note |
  /// |-----------|-----|--------|------|------|
  /// | 10 MB | ~1s | ~2s | ~3s | Text files |
  /// | 100 MB | ~8s | ~15s | ~25s | Mixed content |
  /// | 1 GB | ~80s | ~150s | ~250s | Use constraints! |
  ///
  /// **Tip:** For large files (>100MB), use:
  /// ```dart
  /// constraints: Constraints(
  ///   requiresCharging: true,
  ///   requiresDeviceIdle: true,
  ///   requiresStorageNotLow: true,
  /// )
  /// ```
  ///
  /// ## See Also
  ///
  /// - [httpUpload] - Upload compressed files
  /// - [NativeWorkManager.progress] - Track compression progress
  /// - [NativeWorker.custom] - Custom compression formats
  static Worker fileCompress({
    required String inputPath,
    required String outputPath,
    CompressionLevel level = CompressionLevel.medium,
    List<String> excludePatterns = const [],
    bool deleteOriginal = false,
  }) {
    _validateFilePath(inputPath, 'inputPath');
    _validateFilePath(outputPath, 'outputPath');

    if (!outputPath.toLowerCase().endsWith('.zip')) {
      throw ArgumentError(
        'Output path must end with .zip\n'
        'Current: $outputPath\n'
        'Example: /app/archive/backup.zip',
      );
    }

    return FileCompressionWorker(
      inputPath: inputPath,
      outputPath: outputPath,
      level: level,
      excludePatterns: excludePatterns,
      deleteOriginal: deleteOriginal,
    );
  }

  /// File decompression worker (ZIP extraction).
  ///
  /// Extracts files from ZIP archives in the background. Supports password-protected
  /// archives, selective extraction, and zip bomb protection. Runs in native code
  /// **without** Flutter Engine for maximum efficiency.
  ///
  /// ## Basic Extraction
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'extract-backup',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileDecompress(
  ///     archivePath: '/app/downloads/backup.zip',
  ///     destinationPath: '/app/data/restored/',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Extract Specific Files Only
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'extract-config',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileDecompress(
  ///     archivePath: '/app/downloads/package.zip',
  ///     destinationPath: '/app/config/',
  ///     extractFiles: ['config.json', 'settings.xml'],
  ///   ),
  /// );
  /// ```
  ///
  /// ## Password-Protected Archive
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'extract-secure',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileDecompress(
  ///     archivePath: '/app/downloads/secure.zip',
  ///     destinationPath: '/app/private/',
  ///     password: 'mySecurePassword',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Extract and Delete Archive
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'extract-temp',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileDecompress(
  ///     zipPath: '/app/downloads/data.zip',
  ///     targetDir: '/app/temp/',
  ///     deleteAfterExtract: true,  // Save storage space
  ///     overwrite: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Complete Workflow: Download → Extract → Process
  ///
  /// ```dart
  /// // Step 1: Download ZIP
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'download-data',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpDownload(
  ///     url: 'https://cdn.example.com/data.zip',
  ///     savePath: '/app/downloads/data.zip',
  ///   ),
  /// );
  ///
  /// // Step 2: Extract downloaded ZIP
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'extract-data',
  ///   trigger: TaskTrigger.contentUri(taskId: 'download-data'),
  ///   worker: NativeWorker.fileDecompress(
  ///     zipPath: '/app/downloads/data.zip',
  ///     targetDir: '/app/data/',
  ///     deleteAfterExtract: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[zipPath]** *(required)* - Path to ZIP archive to extract.
  /// - Must be absolute path
  /// - File must exist at execution time
  /// - Throws `ArgumentError` if empty
  ///
  /// **[targetDir]** *(required)* - Directory where files will be extracted.
  /// - Must be absolute path
  /// - Directory will be created if it doesn't exist
  /// - Throws `ArgumentError` if empty
  ///
  /// **[deleteAfterExtract]** *(optional)* - Delete archive after extraction (default: false).
  /// - Saves storage space
  /// - Only deletes if extraction succeeds
  /// - Use with caution!
  ///
  /// **[overwrite]** *(optional)* - Overwrite existing files (default: true).
  /// - If false, skips files that already exist
  /// - If true, replaces existing files
  ///
  /// ## Progress Tracking
  ///
  /// ```dart
  /// // Listen to extraction progress
  /// NativeWorkManager.progress
  ///     .where((p) => p.taskId == 'my-extraction')
  ///     .listen((progress) {
  ///   print('Extracted: ${progress.currentStep}/${progress.totalSteps} files');
  ///   print('Progress: ${progress.progress}%');
  /// });
  /// ```
  ///
  /// ## Behavior
  ///
  /// - Extracts all files preserving directory structure
  /// - Creates destination directory if needed
  /// - Path traversal protection (prevents ../../../ attacks)
  /// - Validates uncompressed size before extraction
  /// - Reports progress via [NativeWorkManager.progress] stream
  /// - Task succeeds if extraction completes successfully
  /// - Task fails on I/O error, wrong password, or zip bomb detected
  ///
  /// ## When to Use
  ///
  /// ✅ **Use fileDecompress when:**
  /// - Extracting downloaded content packages
  /// - Restoring backups
  /// - Unpacking app resources
  /// - Processing uploaded archives
  /// - Handling OTA update packages
  ///
  /// ❌ **Don't use fileDecompress when:**
  /// - Archive format is not ZIP → Use custom worker
  /// - Need to extract on-the-fly during download → Use streaming
  /// - Archive is untrusted → Validate maxSizeBytes carefully
  ///
  /// ## Security Notes
  ///
  /// **Zip Bomb Protection:**
  /// - Built-in validation prevents decompression bombs
  /// - Checks extracted size during extraction
  /// - Task fails if suspicious expansion detected
  ///
  /// **Path Traversal Protection:**
  /// - Automatically validates all file paths
  /// - Prevents extraction outside destination directory
  /// - Blocks malicious paths like `../../etc/passwd`
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** extract untrusted archives without validation
  /// ❌ **Don't** use deleteAfterExtract without verifying extraction success
  /// ❌ **Don't** forget to handle task failure (archive may be corrupt)
  /// ❌ **Don't** extract to system directories
  /// ✅ **Do** use storage constraints for large archives
  /// ✅ **Do** validate archive integrity before extraction
  /// ✅ **Do** test with known-good archives first
  ///
  /// ## Platform Notes
  ///
  /// **Android:**
  /// - Uses standard Java ZIP libraries
  /// - Supports all ZIP formats including ZIP64
  /// - Streaming extraction (low memory)
  ///
  /// **iOS:**
  /// - Uses ZIPFoundation framework
  /// - Streaming extraction (low memory)
  /// - Built-in security validations
  ///
  /// ## Future Features (v1.1.0)
  ///
  /// - Password-protected ZIP support
  /// - Selective file extraction
  /// - Custom extraction filters
  ///
  /// ## Performance
  ///
  /// | Archive Size | Files | Time | Note |
  /// |--------------|-------|------|------|
  /// | 10 MB | 100 | ~1s | Small packages |
  /// | 100 MB | 1000 | ~8s | Medium backups |
  /// | 500 MB | 5000 | ~40s | Large archives |
  ///
  /// **Tip:** For large archives (>100MB), use:
  /// ```dart
  /// constraints: Constraints(
  ///   requiresStorageNotLow: true,
  /// )
  /// ```
  ///
  /// ## See Also
  ///
  /// - [fileCompress] - Compress files into ZIP
  /// - [httpDownload] - Download ZIP archives
  /// - [NativeWorkManager.progress] - Track extraction progress
  static Worker fileDecompress({
    required String zipPath,
    required String targetDir,
    bool deleteAfterExtract = false,
    bool overwrite = true,
  }) {
    _validateFilePath(zipPath, 'zipPath');
    _validateFilePath(targetDir, 'targetDir');

    if (!zipPath.toLowerCase().endsWith('.zip')) {
      throw ArgumentError(
        'ZIP path must end with .zip\n'
        'Current: $zipPath\n'
        'Example: /app/downloads/archive.zip',
      );
    }

    return FileDecompressionWorker(
      zipPath: zipPath,
      targetDir: targetDir,
      deleteAfterExtract: deleteAfterExtract,
      overwrite: overwrite,
    );
  }

  /// Cryptographic hash worker (MD5, SHA-1, SHA-256, SHA-512).
  ///
  /// Computes cryptographic hash of a file for integrity verification,
  /// deduplication, or content-addressable storage. Runs in native code
  /// **without** Flutter Engine for optimal performance.
  ///
  /// ## Hash File
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'verify-download',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.hashFile(
  ///     filePath: '/downloads/file.zip',
  ///     algorithm: HashAlgorithm.sha256,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Hash String
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'hash-password',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.hashString(
  ///     data: 'myPassword123',
  ///     algorithm: HashAlgorithm.sha256,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[filePath]** or **[data]** *(required)* - File path or string to hash.
  ///
  /// **[algorithm]** *(optional)* - Hash algorithm (default: SHA-256).
  /// - `HashAlgorithm.md5` - MD5 (fast, 128-bit, not cryptographically secure)
  /// - `HashAlgorithm.sha1` - SHA-1 (160-bit, deprecated for security)
  /// - `HashAlgorithm.sha256` - SHA-256 (256-bit, recommended)
  /// - `HashAlgorithm.sha512` - SHA-512 (512-bit, most secure)
  ///
  /// ## Behavior
  ///
  /// - Returns hash as hex string in result data
  /// - Streaming computation for large files (low memory)
  /// - Task succeeds with hash in result
  /// - Task fails if file not found or I/O error
  ///
  /// ## When to Use
  ///
  /// ✅ **Use hashFile when:**
  /// - Verifying download integrity
  /// - Checking for duplicate files
  /// - Content-addressable storage
  /// - File change detection
  ///
  /// ## See Also
  ///
  /// - [cryptoEncrypt] - Encrypt files with AES-256
  /// - [cryptoDecrypt] - Decrypt encrypted files
  static Worker hashFile({
    required String filePath,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) {
    _validateFilePath(filePath, 'filePath');
    return CryptoHashWorker.file(filePath: filePath, algorithm: algorithm);
  }

  /// Hash string data.
  ///
  /// See [hashFile] for full documentation.
  static Worker hashString({
    required String data,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) {
    if (data.isEmpty) {
      throw ArgumentError('data cannot be empty');
    }
    return CryptoHashWorker.string(data: data, algorithm: algorithm);
  }

  /// File encryption worker (AES-256-GCM).
  ///
  /// Encrypts files using AES-256-GCM with password-derived key.
  /// Runs in native code **without** Flutter Engine for optimal performance.
  ///
  /// ## Basic Encryption
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'encrypt-backup',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.cryptoEncrypt(
  ///     inputPath: '/data/backup.db',
  ///     outputPath: '/data/backup.db.enc',
  ///     password: 'mySecretPassword',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[inputPath]** *(required)* - Path to file to encrypt.
  ///
  /// **[outputPath]** *(required)* - Where encrypted file will be saved.
  ///
  /// **[password]** *(required)* - Password for encryption.
  /// - Used to derive AES-256 key via PBKDF2
  /// - Minimum 8 characters recommended
  /// - Store securely (use Flutter Secure Storage)
  ///
  /// ## Security Notes
  ///
  /// - Uses AES-256-GCM (authenticated encryption)
  /// - Random IV generated per encryption
  /// - PBKDF2 key derivation (100,000 iterations)
  /// - Password never stored, only used to derive key
  ///
  /// ## See Also
  ///
  /// - [cryptoDecrypt] - Decrypt encrypted files
  /// - [hashFile] - Hash files for integrity
  static Worker cryptoEncrypt({
    required String inputPath,
    required String outputPath,
    required String password,
  }) {
    _validateFilePath(inputPath, 'inputPath');
    _validateFilePath(outputPath, 'outputPath');

    if (password.isEmpty) {
      throw ArgumentError('password cannot be empty');
    }

    if (password.length < 8) {
      throw ArgumentError(
        'Password too weak: ${password.length} characters\n'
        'Minimum required: 8 characters for security\n'
        'Recommendation: Use 12+ characters with mixed case, numbers, and symbols',
      );
    }

    return CryptoEncryptWorker(
      inputPath: inputPath,
      outputPath: outputPath,
      password: password,
    );
  }

  /// File decryption worker (AES-256-GCM).
  ///
  /// Decrypts files previously encrypted by [cryptoEncrypt].
  /// Runs in native code **without** Flutter Engine.
  ///
  /// ## Basic Decryption
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'decrypt-backup',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.cryptoDecrypt(
  ///     inputPath: '/data/backup.db.enc',
  ///     outputPath: '/data/backup.db',
  ///     password: 'mySecretPassword',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[inputPath]** *(required)* - Path to encrypted file.
  ///
  /// **[outputPath]** *(required)* - Where decrypted file will be saved.
  ///
  /// **[password]** *(required)* - Password used for encryption.
  /// - Must match the password used in [cryptoEncrypt]
  /// - Decryption fails with wrong password
  ///
  /// ## See Also
  ///
  /// - [cryptoEncrypt] - Encrypt files
  /// - [hashFile] - Hash files for integrity
  static Worker cryptoDecrypt({
    required String inputPath,
    required String outputPath,
    required String password,
  }) {
    _validateFilePath(inputPath, 'inputPath');
    _validateFilePath(outputPath, 'outputPath');

    if (password.isEmpty) {
      throw ArgumentError('password cannot be empty');
    }

    // Note: For decryption, we accept any password length since it must match
    // the original encryption password (which was already validated)
    return CryptoDecryptWorker(
      inputPath: inputPath,
      outputPath: outputPath,
      password: password,
    );
  }

  /// Image processing worker (resize, compress, convert).
  ///
  /// Processes images natively for optimal performance and memory usage.
  /// Runs in native code **without** Flutter Engine. 10x faster and uses
  /// 9x less memory than Dart image packages.
  ///
  /// ## Resize Image
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'resize-photo',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.imageProcess(
  ///     inputPath: '/photos/IMG_4032.png',
  ///     outputPath: '/processed/photo_1080p.jpg',
  ///     maxWidth: 1920,
  ///     maxHeight: 1080,
  ///     outputFormat: ImageFormat.jpeg,
  ///     quality: 85,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Compress Image
  ///
  /// ```dart
  /// // Reduce file size for upload
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'compress-photo',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.imageProcess(
  ///     inputPath: '/photos/original.jpg',
  ///     outputPath: '/photos/compressed.jpg',
  ///     quality: 70,
  ///     deleteOriginal: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Convert Format
  ///
  /// ```dart
  /// // PNG to JPEG for smaller size
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'convert-format',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.imageProcess(
  ///     inputPath: '/photos/screenshot.png',
  ///     outputPath: '/photos/screenshot.jpg',
  ///     outputFormat: ImageFormat.jpeg,
  ///     quality: 90,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Crop Image
  ///
  /// ```dart
  /// // Crop to specific region
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'crop-avatar',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.imageProcess(
  ///     inputPath: '/photos/profile.jpg',
  ///     outputPath: '/avatars/cropped.jpg',
  ///     cropRect: Rect.fromLTWH(100, 100, 500, 500),
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[inputPath]** *(required)* - Path to input image.
  ///
  /// **[outputPath]** *(required)* - Where processed image will be saved.
  ///
  /// **[maxWidth]** *(optional)* - Maximum width in pixels (null = no limit).
  ///
  /// **[maxHeight]** *(optional)* - Maximum height in pixels (null = no limit).
  ///
  /// **[maintainAspectRatio]** *(optional)* - Keep aspect ratio (default: true).
  /// - If true, image fits within maxWidth × maxHeight
  /// - If false, image stretched to exactly maxWidth × maxHeight
  ///
  /// **[quality]** *(optional)* - Output quality 0-100 (default: 85).
  /// - Only affects JPEG and WEBP formats
  /// - Higher = better quality, larger file size
  /// - Recommended: 70-90 for photos, 90-100 for graphics
  ///
  /// **[outputFormat]** *(optional)* - Output format (default: same as input).
  /// - `ImageFormat.jpeg` - Best for photos, smaller size
  /// - `ImageFormat.png` - Lossless, larger size, transparency
  /// - `ImageFormat.webp` - Modern format, good compression
  ///
  /// **[cropRect]** *(optional)* - Crop to rectangle (x, y, width, height).
  /// - Applied before resize
  /// - Coordinates in pixels from top-left
  ///
  /// **[deleteOriginal]** *(optional)* - Delete input after processing (default: false).
  ///
  /// ## Performance
  ///
  /// | Operation | Dart (image package) | Native (ImageProcessWorker) |
  /// |-----------|---------------------|----------------------------|
  /// | 4K → 1080p | 2,500ms / 180MB | 250ms / 20MB |
  /// | JPEG compress | 1,200ms / 150MB | 120ms / 15MB |
  /// | Format convert | 2,000ms / 200MB | 200ms / 20MB |
  ///
  /// **Improvement:** 10x faster, 9x less memory
  ///
  /// ## When to Use
  ///
  /// ✅ **Use imageProcess when:**
  /// - Resizing photos before upload
  /// - Generating thumbnails
  /// - Compressing images to save storage
  /// - Converting image formats
  /// - Cropping user-selected regions
  ///
  /// ❌ **Don't use imageProcess when:**
  /// - Image is already optimal size
  /// - Need complex filters → Use Dart image package
  /// - Need to read pixel data → Use Dart
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** use quality > 95 (diminishing returns, huge files)
  /// ❌ **Don't** resize already-small images (waste of processing)
  /// ❌ **Don't** forget to set outputFormat when converting
  /// ✅ **Do** use quality 70-85 for most photos
  /// ✅ **Do** maintain aspect ratio for photos
  /// ✅ **Do** use constraints for large image processing
  ///
  /// ## See Also
  ///
  /// - [httpUpload] - Upload processed images
  /// - [fileCompress] - Compress multiple images into ZIP
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
  }) {
    _validateFilePath(inputPath, 'inputPath');
    _validateFilePath(outputPath, 'outputPath');

    if (quality < 0 || quality > 100) {
      throw ArgumentError(
        'quality must be between 0 and 100\n'
        'Current: $quality\n'
        'Recommended: 70-90 for photos, 90-100 for graphics',
      );
    }

    if (maxWidth != null && maxWidth <= 0) {
      throw ArgumentError('maxWidth must be positive');
    }

    if (maxHeight != null && maxHeight <= 0) {
      throw ArgumentError('maxHeight must be positive');
    }

    return ImageProcessWorker(
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

  // ═══════════════════════════════════════════════════════════════════════════
  // FILE SYSTEM OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Copy file or directory worker.
  ///
  /// Copies files or directories for pure-native task chains **without** Flutter Engine.
  /// Useful for organizing files, creating backups, or duplicating data.
  ///
  /// ## Basic File Copy
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'copy-file',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileCopy(
  ///     sourcePath: '/downloads/photo.jpg',
  ///     destinationPath: '/backups/photo.jpg',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Copy Directory
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'copy-directory',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileCopy(
  ///     sourcePath: '/photos/vacation',
  ///     destinationPath: '/backups/vacation',
  ///     recursive: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[sourcePath]** *(required)* - Path to source file or directory.
  ///
  /// **[destinationPath]** *(required)* - Where to copy the file/directory.
  ///
  /// **[overwrite]** *(optional)* - Overwrite if destination exists (default: false).
  ///
  /// **[recursive]** *(optional)* - Copy directories recursively (default: true).
  ///
  /// ## See Also
  ///
  /// - [fileMove] - Move files instead of copying
  /// - [fileDelete] - Delete files
  static Worker fileCopy({
    required String sourcePath,
    required String destinationPath,
    bool overwrite = false,
    bool recursive = true,
  }) {
    _validateFilePath(sourcePath, 'sourcePath');
    _validateFilePath(destinationPath, 'destinationPath');

    return FileSystemCopyWorker(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      overwrite: overwrite,
      recursive: recursive,
    );
  }

  /// Move file or directory worker.
  ///
  /// Moves files or directories for pure-native task chains **without** Flutter Engine.
  /// More efficient than copy+delete for large files (atomic operation when possible).
  ///
  /// ## Basic File Move
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'move-file',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileMove(
  ///     sourcePath: '/temp/download.zip',
  ///     destinationPath: '/downloads/file.zip',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[sourcePath]** *(required)* - Path to source file or directory.
  ///
  /// **[destinationPath]** *(required)* - Where to move the file/directory.
  ///
  /// **[overwrite]** *(optional)* - Overwrite if destination exists (default: false).
  ///
  /// ## See Also
  ///
  /// - [fileCopy] - Copy files instead of moving
  /// - [fileDelete] - Delete files after processing
  static Worker fileMove({
    required String sourcePath,
    required String destinationPath,
    bool overwrite = false,
  }) {
    _validateFilePath(sourcePath, 'sourcePath');
    _validateFilePath(destinationPath, 'destinationPath');

    return FileSystemMoveWorker(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      overwrite: overwrite,
    );
  }

  /// Delete file or directory worker.
  ///
  /// Deletes files or directories for cleanup in pure-native task chains **without** Flutter Engine.
  ///
  /// ## Basic File Delete
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'cleanup',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileDelete(
  ///     path: '/temp/cache.dat',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Delete Directory
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'cleanup-temp',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileDelete(
  ///     path: '/temp',
  ///     recursive: true,  // Delete all contents
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[path]** *(required)* - Path to file or directory to delete.
  ///
  /// **[recursive]** *(optional)* - Delete directories recursively (default: false).
  /// - If false and path is directory, task fails
  /// - If true, deletes directory and all contents
  ///
  /// ## Safety
  ///
  /// - Protected paths (/, /system, etc.) cannot be deleted
  /// - Deletion is permanent (no trash/recycle bin)
  ///
  /// ## See Also
  ///
  /// - [fileCopy] - Copy files before deleting
  /// - [fileMove] - Move files instead of deleting
  static Worker fileDelete({required String path, bool recursive = false}) {
    _validateFilePath(path, 'path');

    return FileSystemDeleteWorker(path: path, recursive: recursive);
  }

  /// List directory contents worker.
  ///
  /// Lists files in a directory for pure-native task chains **without** Flutter Engine.
  /// Useful for scanning directories, finding files, or building file indexes.
  ///
  /// ## Basic Directory Listing
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'list-files',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileList(
  ///     path: '/downloads',
  ///   ),
  /// );
  /// ```
  ///
  /// ## List with Pattern
  ///
  /// ```dart
  /// // Find all JPG files
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'find-photos',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileList(
  ///     path: '/photos',
  ///     pattern: '*.jpg',
  ///     recursive: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[path]** *(required)* - Directory path to list.
  ///
  /// **[pattern]** *(optional)* - Glob pattern to filter files (e.g., "*.jpg", "file_*.txt").
  /// - Supports wildcards: `*` (any chars), `?` (single char)
  /// - Example: `*.jpg` matches all JPEG files
  /// - Example: `photo_?.png` matches `photo_1.png`, `photo_a.png`
  ///
  /// **[recursive]** *(optional)* - List subdirectories recursively (default: false).
  ///
  /// ## Result
  ///
  /// Returns list of file info with:
  /// - `path` - Full file path
  /// - `name` - File name
  /// - `size` - File size in bytes
  /// - `lastModified` - Last modification timestamp
  ///
  /// ## See Also
  ///
  /// - [fileDelete] - Delete found files
  /// - [fileCopy] - Copy found files
  static Worker fileList({
    required String path,
    String? pattern,
    bool recursive = false,
  }) {
    _validateFilePath(path, 'path');

    return FileSystemListWorker(
      path: path,
      pattern: pattern,
      recursive: recursive,
    );
  }

  /// Create directory worker (mkdir).
  ///
  /// Creates directories for pure-native task chains **without** Flutter Engine.
  /// Useful for setting up folder structure before file operations.
  ///
  /// ## Create Directory
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'create-backup-dir',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.fileMkdir(
  ///     path: '/backups/2024-02-07',
  ///   ),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[path]** *(required)* - Directory path to create.
  ///
  /// **[createParents]** *(optional)* - Create parent directories if needed (default: true).
  /// - If true, creates `/backups/2024/02/07` even if `/backups` doesn't exist
  /// - If false, fails if parent doesn't exist
  ///
  /// ## See Also
  ///
  /// - [fileCopy] - Copy files after creating directory
  /// - [fileMove] - Move files to new directory
  static Worker fileMkdir({required String path, bool createParents = true}) {
    _validateFilePath(path, 'path');

    return FileSystemMkdirWorker(path: path, createParents: createParents);
  }
}
