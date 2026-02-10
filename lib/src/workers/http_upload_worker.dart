import 'package:flutter/foundation.dart';
import '../worker.dart';

/// HTTP upload worker configuration.
///
/// Supports multipart/form-data file uploads with optional background
/// URLSession on iOS for uploads that survive app termination.
@immutable
final class HttpUploadWorker extends Worker {
  const HttpUploadWorker({
    required this.url,
    required this.filePath,
    this.fileFieldName = 'file',
    this.fileName,
    this.mimeType,
    this.headers = const {},
    this.additionalFields = const {},
    this.timeout = const Duration(minutes: 5),
    this.useBackgroundSession = false,
  });

  /// The URL to upload to.
  final String url;

  /// Path to the file to upload (absolute path).
  final String filePath;

  /// Form field name for the file (default: "file").
  final String fileFieldName;

  /// Optional custom file name (defaults to actual file name).
  final String? fileName;

  /// Optional MIME type (auto-detected if not provided).
  final String? mimeType;

  /// Optional HTTP headers to include in the request.
  final Map<String, String> headers;

  /// Optional additional form fields to include in the multipart request.
  final Map<String, String> additionalFields;

  /// Request timeout (default: 5 minutes).
  final Duration timeout;

  /// Use background URLSession for uploads (iOS only).
  ///
  /// **v2.3.0+ iOS Feature:**
  /// When enabled, uploads use `URLSessionConfiguration.background` which:
  /// - **Survives app termination** - Uploads continue even if app is killed
  /// - **No time limits** - Can upload for hours (vs 30s foreground limit)
  /// - **System-managed** - OS handles network changes and retries
  /// - **Battery efficient** - OS schedules transfers optimally
  ///
  /// **Android:**
  /// This parameter has no effect on Android. WorkManager already handles
  /// background uploads robustly without special configuration.
  ///
  /// **When to use:**
  /// - ✅ Large files (>10MB) that may take minutes to upload
  /// - ✅ Uploads that must complete even if user force-quits app
  /// - ✅ Uploads on unreliable networks (automatic retry)
  /// - ❌ Small files (<1MB) - foreground session is faster
  /// - ❌ Immediate uploads that finish in seconds
  ///
  /// Example:
  /// ```dart
  /// // Large video upload (survives app termination)
  /// worker: NativeWorker.httpUpload(
  ///   url: 'https://cdn.example.com/videos',
  ///   filePath: '/videos/large-video.mp4',
  ///   useBackgroundSession: true,  // 🚀 Survives termination
  /// ),
  /// ```
  ///
  /// Default: `false` (backward compatible with existing code)
  final bool useBackgroundSession;

  @override
  String get workerClassName => 'HttpUploadWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'httpUpload',
        'url': url,
        'filePath': filePath,
        'fileFieldName': fileFieldName,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        'headers': headers,
        'additionalFields': additionalFields,
        'timeoutMs': timeout.inMilliseconds,
        'useBackgroundSession': useBackgroundSession,
      };
}
