import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Parallel multi-file HTTP upload worker configuration.
///
/// Uploads each file in [files] as a **separate** concurrent multipart request
/// (one request per file) with a per-host concurrency limit.  This differs
/// from [HttpUploadWorker], which bundles all files into a single request.
///
/// **When to use over [HttpUploadWorker]:**
/// - You need to upload many files independently (each gets its own response).
/// - You want individual retry-per-file semantics (failed files retry without
///   re-sending already-succeeded files).
/// - The server accepts one file per request (most REST APIs).
///
/// **Per-host concurrency:**
/// [maxConcurrent] caps how many simultaneous uploads run against the same
/// host at once, preventing connection-pool exhaustion and rate-limiting.
///
/// ## Example
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'batch-photos',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.parallelHttpUpload(
///     url: 'https://api.example.com/photos',
///     files: [
///       UploadFile(filePath: '/data/user/0/.../img1.jpg'),
///       UploadFile(filePath: '/data/user/0/.../img2.jpg', fieldName: 'photo'),
///     ],
///     maxConcurrent: 3,
///     maxRetries: 2,
///   ),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// ## Progress events
///
/// One [TaskProgress] event is emitted per uploaded chunk across all files, so
/// [TaskProgress.progress] rises smoothly from 0 to 100. The message field
/// includes per-file counts (`"Uploaded 2/5 files"`).
///
/// ## Result data
///
/// The success result [data] map contains:
/// - `uploadedCount` — number of files successfully uploaded.
/// - `failedCount`   — number of files that ultimately failed.
/// - `totalBytes`    — aggregate bytes sent across all files.
/// - `fileResults`   — list of per-file result maps.
@immutable
final class ParallelHttpUploadWorker extends Worker {
  const ParallelHttpUploadWorker({
    required this.url,
    required this.files,
    this.headers = const {},
    this.fields = const {},
    this.maxConcurrent = 3,
    this.maxRetries = 1,
    this.timeout = const Duration(minutes: 5),
    this.showNotification = false,
    this.notificationTitle,
    this.notificationBody,
  })  : assert(files.length > 0, 'files must not be empty'),
        assert(maxConcurrent >= 1 && maxConcurrent <= 16,
            'maxConcurrent must be between 1 and 16'),
        assert(maxRetries >= 0 && maxRetries <= 5,
            'maxRetries must be between 0 and 5');

  /// The endpoint URL that receives each file upload.
  final String url;

  /// List of files to upload.
  final List<UploadFile> files;

  /// HTTP headers added to every upload request.
  ///
  /// Typical use: `{'Authorization': 'Bearer token'}`.
  final Map<String, String> headers;

  /// Additional form fields added to every multipart request alongside the
  /// file part (e.g. `{'albumId': '42'}`).
  final Map<String, String> fields;

  /// Maximum simultaneous uploads per host (1–16, default 3).
  ///
  /// Uploads beyond this limit are queued until a slot opens.
  final int maxConcurrent;

  /// How many times to retry a failed individual file upload (0–5, default 1).
  ///
  /// A retry is attempted only when the server returns a 5xx response or when
  /// a network error occurs. 4xx responses (e.g. 400, 401) are not retried.
  final int maxRetries;

  /// Per-file request timeout (default: 5 minutes).
  final Duration timeout;

  /// Show a system notification with aggregate upload progress.
  final bool showNotification;

  /// Title for the progress notification.
  ///
  /// Defaults to `"Uploading N files"` derived from [files].
  final String? notificationTitle;

  /// Body text for the progress notification.
  final String? notificationBody;

  @override
  String get workerClassName => 'ParallelHttpUploadWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'parallelHttpUpload',
        'url': url,
        'files': files.map((f) => {
              'filePath': f.filePath,
              'fieldName': f.fieldName,
              if (f.fileName != null) 'fileName': f.fileName,
              if (f.mimeType != null) 'mimeType': f.mimeType,
            }).toList(),
        'headers': headers,
        'fields': fields,
        'maxConcurrent': maxConcurrent,
        'maxRetries': maxRetries,
        'timeoutMs': timeout.inMilliseconds,
        'showNotification': showNotification,
        if (notificationTitle != null) 'notificationTitle': notificationTitle,
        if (notificationBody != null) 'notificationBody': notificationBody,
      };
}

// UploadFile is defined in multi_upload_worker.dart and re-exported via worker.dart.
