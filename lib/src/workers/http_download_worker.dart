import 'package:flutter/foundation.dart';
import '../worker.dart';

/// HTTP download worker configuration.
///
/// Supports automatic resume from last downloaded byte on network failure,
/// and optional checksum verification for download integrity.
@immutable
final class HttpDownloadWorker extends Worker {
  const HttpDownloadWorker({
    required this.url,
    required this.savePath,
    this.headers = const {},
    this.timeout = const Duration(minutes: 5),
    this.enableResume = true,
    this.expectedChecksum,
    this.checksumAlgorithm = 'SHA-256',
    this.useBackgroundSession = false,
    this.showNotification = false,
    this.notificationTitle,
    this.notificationBody,
  });

  /// The URL to download from.
  final String url;

  /// Where to save the downloaded file (absolute path).
  final String savePath;

  /// Optional HTTP headers to include in the request.
  final Map<String, String> headers;

  /// Request timeout (default: 5 minutes).
  final Duration timeout;

  /// Enable automatic resume from last downloaded byte on network failure.
  ///
  /// When enabled (default), if the download is interrupted, the next attempt
  /// will resume from the last successfully downloaded byte using HTTP Range
  /// requests. The server must support Range requests (returns 206 Partial Content).
  /// Falls back to full download if server doesn't support resume.
  ///
  /// Default: `true`
  final bool enableResume;

  /// Expected checksum for download verification (optional).
  ///
  /// If provided, the downloaded file will be verified against this checksum
  /// after download completes. The download fails if checksums don't match.
  ///
  /// Example: `"a3b2c1d4e5f6..."` (hexadecimal string)
  ///
  /// Use with [checksumAlgorithm] to specify the hashing algorithm.
  final String? expectedChecksum;

  /// Checksum algorithm for verification.
  ///
  /// Supported algorithms:
  /// - `'MD5'` - Fast but not cryptographically secure
  /// - `'SHA-1'` - 160-bit hash (deprecated for security)
  /// - `'SHA-256'` - 256-bit hash (recommended, default)
  /// - `'SHA-512'` - 512-bit hash (most secure)
  ///
  /// Default: `'SHA-256'`
  final String checksumAlgorithm;

  /// Show a system notification with download progress.
  ///
  /// When `true`, the native side shows a persistent notification while the
  /// download is in progress and a completion/failure notification when done.
  ///
  /// **Android:** Uses a low-priority notification channel with a Cancel button.
  /// Requires `POST_NOTIFICATIONS` permission on Android 13+ (API 33+).
  ///
  /// **iOS:** Uses `UNUserNotificationCenter`. Progress updates are best-effort
  /// (iOS suspends the app during background downloads). The completion
  /// notification is always shown.
  ///
  /// Default: `false`
  final bool showNotification;

  /// Title for the progress notification.
  ///
  /// Defaults to the file name derived from [url] on the native side.
  final String? notificationTitle;

  /// Body text for the progress notification.
  ///
  /// Defaults to the download URL on the native side.
  final String? notificationBody;

  /// Use background URLSession for downloads (iOS only).
  ///
  /// **v2.3.0+ iOS Feature:**
  /// When enabled, downloads use `URLSessionConfiguration.background` which:
  /// - **Survives app termination** - Downloads continue even if app is killed
  /// - **No time limits** - Can download for hours (vs 30s foreground limit)
  /// - **System-managed** - OS handles network changes and retries
  /// - **Battery efficient** - OS schedules transfers optimally
  ///
  /// **Android:**
  /// This parameter has no effect on Android. WorkManager already handles
  /// background downloads robustly without special configuration.
  ///
  /// **When to use:**
  /// - ✅ Large files (>10MB) that may take minutes to download
  /// - ✅ Downloads that must complete even if user force-quits app
  /// - ✅ Downloads on unreliable networks (automatic retry)
  /// - ❌ Small files (<1MB) - foreground session is faster
  /// - ❌ Immediate downloads that finish in seconds
  ///
  /// Example:
  /// ```dart
  /// // Large app update download (survives app termination)
  /// worker: NativeWorker.httpDownload(
  ///   url: 'https://cdn.example.com/app-v2.0.0.apk',
  ///   savePath: '/downloads/update.apk',
  ///   useBackgroundSession: true,  // 🚀 Survives termination
  /// ),
  /// ```
  ///
  /// Default: `false` (backward compatible with existing code)
  final bool useBackgroundSession;

  @override
  String get workerClassName => 'HttpDownloadWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'httpDownload',
        'url': url,
        'savePath': savePath,
        'headers': headers,
        'timeoutMs': timeout.inMilliseconds,
        'enableResume': enableResume,
        if (expectedChecksum != null) 'expectedChecksum': expectedChecksum,
        'checksumAlgorithm': checksumAlgorithm,
        'useBackgroundSession': useBackgroundSession,
        'showNotification': showNotification,
        if (notificationTitle != null) 'notificationTitle': notificationTitle,
        if (notificationBody != null) 'notificationBody': notificationBody,
      };
}
