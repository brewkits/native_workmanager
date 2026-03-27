import 'package:flutter/foundation.dart';
import '../worker.dart';
import 'request_signing.dart';

export 'request_signing.dart';

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
    this.requestSigning,
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

  /// HMAC-SHA256 request signing configuration.
  ///
  /// When set, each upload request is signed with the specified secret key
  /// and the signature is injected as a request header (default: `X-Signature`).
  final RequestSigning? requestSigning;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILDER-STYLE copyWith + convenience methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a copy with the given fields replaced.
  HttpUploadWorker copyWith({
    String? url,
    String? filePath,
    String? fileFieldName,
    String? fileName,
    String? mimeType,
    Map<String, String>? headers,
    Map<String, String>? additionalFields,
    Duration? timeout,
    bool? useBackgroundSession,
    RequestSigning? requestSigning,
  }) =>
      HttpUploadWorker(
        url: url ?? this.url,
        filePath: filePath ?? this.filePath,
        fileFieldName: fileFieldName ?? this.fileFieldName,
        fileName: fileName ?? this.fileName,
        mimeType: mimeType ?? this.mimeType,
        headers: headers ?? this.headers,
        additionalFields: additionalFields ?? this.additionalFields,
        timeout: timeout ?? this.timeout,
        useBackgroundSession: useBackgroundSession ?? this.useBackgroundSession,
        requestSigning: requestSigning ?? this.requestSigning,
      );

  /// Convenience: add or merge HTTP headers.
  ///
  /// ```dart
  /// worker.withHeaders({'Authorization': 'Bearer $token', 'X-App': '1'})
  /// ```
  HttpUploadWorker withHeaders(Map<String, String> extra) => copyWith(
        headers: {...headers, ...extra},
      );

  /// Convenience: add `Authorization` header.
  ///
  /// ```dart
  /// worker.withAuth(token: myToken)
  /// worker.withAuth(token: myApiKey, template: 'ApiKey {accessToken}')
  /// ```
  HttpUploadWorker withAuth({
    required String token,
    String template = 'Bearer {accessToken}',
  }) =>
      withHeaders({
        'Authorization': template.replaceAll('{accessToken}', token),
      });

  /// Convenience: sign requests with HMAC-SHA256.
  HttpUploadWorker withSigning(RequestSigning signing) =>
      copyWith(requestSigning: signing);

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
        if (requestSigning != null) 'requestSigning': requestSigning!.toMap(),
      };
}
