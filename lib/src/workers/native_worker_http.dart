part of '../worker.dart';

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
/// - [NativeWorker.httpSync] - POST JSON and receive JSON response
/// - [NativeWorker.httpUpload] - Upload files (multipart)
/// - [NativeWorker.httpDownload] - Download files
Worker _buildHttpRequest({
  required String url,
  HttpMethod method = HttpMethod.get,
  Map<String, String> headers = const {},
  String? body,
  Duration timeout = const Duration(seconds: 30),
}) {
  NativeWorker._validateUrl(url);

  // Validate timeout
  if (timeout.inMilliseconds <= 0) {
    throw ArgumentError(
      'Timeout must be positive: ${timeout.inMilliseconds}ms',
    );
  }
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
/// ## Progress Tracking (v1.0.0+)
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
/// ## Storage Validation (v1.0.0+)
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
/// - [NativeWorker.httpDownload] - Download files
/// - [NativeWorker.httpRequest] - Simple HTTP requests
/// - [NativeWorkManager.progress] - Track upload progress
Worker _buildHttpUpload({
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
  NativeWorker._validateUrl(url);
  NativeWorker._validateFilePath(filePath, 'filePath');

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

  // Validate field names are not empty
  for (final key in additionalFields.keys) {
    if (key.isEmpty) {
      throw ArgumentError(
        'Empty field name in additionalFields\n'
        'All field names must be non-empty strings',
      );
    }
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

/// Upload multiple files in a single multipart/form-data HTTP request.
///
/// Throws [ArgumentError] if [files] is empty or exceeds 50 files.
///
/// Example:
/// ```dart
/// NativeWorker.multiUpload(
///   url: 'https://api.example.com/batch',
///   files: [
///     const UploadFile(filePath: '/path/photo1.jpg', fieldName: 'photos'),
///     const UploadFile(filePath: '/path/photo2.jpg', fieldName: 'photos'),
///   ],
///   additionalFields: {'albumId': '42'},
/// )
/// ```
MultiUploadWorker _buildMultiUpload({
  required String url,
  required List<UploadFile> files,
  Map<String, String> headers = const {},
  Map<String, String> additionalFields = const {},
  Duration timeout = const Duration(minutes: 10),
  bool useBackgroundSession = false,
}) {
  if (files.isEmpty) {
    throw ArgumentError('files must not be empty');
  }
  if (files.length > 50) {
    throw ArgumentError('Maximum 50 files per upload request');
  }
  return MultiUploadWorker(
    url: url,
    files: files,
    headers: headers,
    additionalFields: additionalFields,
    timeout: timeout,
    useBackgroundSession: useBackgroundSession,
  );
}

/// Move a file from app-private storage to a shared / public location.
///
/// On Android uses `MediaStore` (API 29+) or
/// `Environment.getExternalStoragePublicDirectory` (API 28−).
/// On iOS saves to the `PHPhotoLibrary` (for `photos`/`video`) or the app's
/// `Documents` directory (Files app, for `downloads`/`music`).
///
/// Example — save downloaded photo to camera roll:
/// ```dart
/// NativeWorker.moveToSharedStorage(
///   sourcePath: cacheFile.path,
///   storageType: SharedStorageType.photos,
/// )
/// ```
MoveToSharedStorageWorker _buildMoveToSharedStorage({
  required String sourcePath,
  required SharedStorageType storageType,
  String? fileName,
  String? mimeType,
  String? subDir,
}) {
  return MoveToSharedStorageWorker(
    sourcePath: sourcePath,
    storageType: storageType,
    fileName: fileName,
    mimeType: mimeType,
    subDir: subDir,
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
/// ## Progress Tracking (v1.0.0+)
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
/// ## Storage Validation (v1.0.0+)
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
/// - [NativeWorker.httpUpload] - Upload files
/// - [NativeWorker.httpRequest] - Simple HTTP requests
/// - [NativeWorkManager.progress] - Track download progress
Worker _buildHttpDownload({
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
}) {
  NativeWorker._validateUrl(url);
  NativeWorker._validateFilePath(savePath, 'savePath');

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
}

/// Parallel chunked HTTP download worker.
///
/// Splits a single file into [numChunks] parallel byte-range requests and
/// downloads them concurrently, then merges into a single output file.
/// Delivers noticeably faster downloads for large files on servers that
/// support `Accept-Ranges: bytes`.
///
/// **Automatic fallback:** If the server does not support range requests
/// or does not return a `Content-Length`, the worker falls back to a
/// normal sequential download automatically.
///
/// ## Example
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'big-video',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.parallelHttpDownload(
///     url: 'https://cdn.example.com/movie.mp4',
///     savePath: '/data/user/0/com.example/files/movie.mp4',
///     numChunks: 4,
///   ),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// See also: [NativeWorker.httpDownload] for simpler single-connection downloads.
Worker _buildParallelHttpDownload({
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
}) {
  NativeWorker._validateUrl(url);
  NativeWorker._validateFilePath(savePath, 'savePath');

  if (numChunks < 1 || numChunks > 16) {
    throw ArgumentError('numChunks must be between 1 and 16, got $numChunks');
  }

  if (expectedChecksum != null) {
    final validAlgorithms = [
      'MD5',
      'SHA-1',
      'SHA1',
      'SHA-256',
      'SHA256',
      'SHA-512',
      'SHA512'
    ];
    if (!validAlgorithms
        .contains(checksumAlgorithm.toUpperCase().replaceAll('-', ''))) {
      throw ArgumentError(
        'Invalid checksumAlgorithm: "$checksumAlgorithm"\n'
        'Supported algorithms: MD5, SHA-1, SHA-256, SHA-512',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(expectedChecksum)) {
      throw ArgumentError(
        'Invalid expectedChecksum format: must be hexadecimal string',
      );
    }
  }

  return ParallelHttpDownloadWorker(
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
/// - [NativeWorker.httpRequest] - Simple HTTP requests (no JSON encoding)
/// - [NativeWorker.httpUpload] - Upload files
/// - [DartWorker] - For processing responses
Worker _buildHttpSync({
  required String url,
  HttpMethod method = HttpMethod.post,
  Map<String, String> headers = const {},
  Map<String, dynamic>? requestBody,
  Duration timeout = const Duration(seconds: 60),
}) {
  NativeWorker._validateUrl(url);

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
