import 'package:flutter/foundation.dart';
import '../worker.dart';

export 'request_signing.dart';

/// What to do if the destination file already exists.
enum DuplicatePolicy {
  /// Overwrite the existing file (default).
  overwrite,

  /// Rename the new file to avoid collision (e.g. `file_1.zip`).
  rename,

  /// Skip the download entirely and report success.
  skip,
}

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
    this.skipExisting = false,
    this.allowPause = false,
    this.cookies,
    this.authToken,
    this.authHeaderTemplate = 'Bearer {accessToken}',
    this.onDuplicate = DuplicatePolicy.overwrite,
    this.moveToPublicDownloads = false,
    this.saveToGallery = false,
    this.extractAfterDownload = false,
    this.extractPath,
    this.deleteArchiveAfterExtract = false,
    this.bandwidthLimitBytesPerSecond,
    this.requestSigning,
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

  /// Skip the download if the destination file already exists.
  ///
  /// When `true`, the worker checks whether [savePath] already exists on disk.
  /// If it does, the task reports success immediately without issuing any HTTP
  /// request.  This is useful for incremental download managers or caches
  /// where a previously completed download should not be repeated.
  ///
  /// When `false` (default), the download always proceeds and overwrites any
  /// existing file.
  ///
  /// Default: `false`
  final bool skipExisting;

  /// Allow the task to be paused via [NativeWorkManager.pause]. When false
  /// (default), the Pause button is hidden from the download notification.
  final bool allowPause;

  /// HTTP cookies to include in the download request. Keys are cookie names,
  /// values are cookie values.
  final Map<String, String>? cookies;

  /// Auth token for the download request. Injected into the header as
  /// [authHeaderTemplate] with `{accessToken}` replaced by this value.
  final String? authToken;

  /// Template for the `Authorization` header value.
  ///
  /// `{accessToken}` is replaced with [authToken] at request time.
  /// Default: `"Bearer {accessToken}"`
  final String authHeaderTemplate;

  /// What to do if the destination file already exists.
  final DuplicatePolicy onDuplicate;

  /// Move the completed download into the public Downloads folder.
  final bool moveToPublicDownloads;

  /// Save the completed download to the device gallery (images/videos).
  final bool saveToGallery;

  /// Automatically extract the downloaded archive after a successful download.
  final bool extractAfterDownload;

  /// Directory to extract the archive into. Defaults to the directory
  /// containing [savePath] when null.
  final String? extractPath;

  /// Delete the archive file after successful extraction.
  final bool deleteArchiveAfterExtract;

  /// Maximum download speed in bytes per second.
  ///
  /// When set, the download stream is throttled to this rate using a token-bucket
  /// algorithm. Useful for limiting bandwidth consumption on metered connections.
  ///
  /// **Android:** applied via OkHttp response-body wrapping (effective immediately).
  /// **iOS:** applied via streaming download on iOS 15+; ignored on iOS 14 (downloads
  /// proceed at full speed — no error is raised).
  ///
  /// Example: `500 * 1024` for 500 KB/s.
  ///
  /// Default: `null` (no limit).
  final int? bandwidthLimitBytesPerSecond;

  /// HMAC-SHA256 request signing configuration.
  ///
  /// When set, each download request is signed with the specified secret key
  /// and the signature is injected as a request header (default: `X-Signature`).
  /// An `X-Timestamp` header is also added when [RequestSigning.includeTimestamp] is true.
  ///
  /// Default: `null` (no signing).
  final RequestSigning? requestSigning;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILDER-STYLE copyWith — avoids parameter explosion at call sites
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a copy of this worker with the given fields replaced.
  ///
  /// Enables a fluent builder-style API without a separate builder class:
  ///
  /// ```dart
  /// final base = HttpDownloadWorker(url: '...', savePath: '...');
  ///
  /// final withNotification = base.copyWith(
  ///   showNotification: true,
  ///   notificationTitle: 'Downloading update…',
  ///   allowPause: true,
  /// );
  ///
  /// final withResume = withNotification.copyWith(
  ///   enableResume: true,
  ///   onDuplicate: DuplicatePolicy.rename,
  /// );
  /// ```
  HttpDownloadWorker copyWith({
    String? url,
    String? savePath,
    Map<String, String>? headers,
    Duration? timeout,
    bool? enableResume,
    String? expectedChecksum,
    String? checksumAlgorithm,
    bool? useBackgroundSession,
    bool? showNotification,
    String? notificationTitle,
    String? notificationBody,
    bool? skipExisting,
    bool? allowPause,
    Map<String, String>? cookies,
    String? authToken,
    String? authHeaderTemplate,
    DuplicatePolicy? onDuplicate,
    bool? moveToPublicDownloads,
    bool? saveToGallery,
    bool? extractAfterDownload,
    String? extractPath,
    bool? deleteArchiveAfterExtract,
    int? bandwidthLimitBytesPerSecond,
    RequestSigning? requestSigning,
  }) {
    return HttpDownloadWorker(
      url: url ?? this.url,
      savePath: savePath ?? this.savePath,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      enableResume: enableResume ?? this.enableResume,
      expectedChecksum: expectedChecksum ?? this.expectedChecksum,
      checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
      useBackgroundSession: useBackgroundSession ?? this.useBackgroundSession,
      showNotification: showNotification ?? this.showNotification,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      skipExisting: skipExisting ?? this.skipExisting,
      allowPause: allowPause ?? this.allowPause,
      cookies: cookies ?? this.cookies,
      authToken: authToken ?? this.authToken,
      authHeaderTemplate: authHeaderTemplate ?? this.authHeaderTemplate,
      onDuplicate: onDuplicate ?? this.onDuplicate,
      moveToPublicDownloads:
          moveToPublicDownloads ?? this.moveToPublicDownloads,
      saveToGallery: saveToGallery ?? this.saveToGallery,
      extractAfterDownload: extractAfterDownload ?? this.extractAfterDownload,
      extractPath: extractPath ?? this.extractPath,
      deleteArchiveAfterExtract:
          deleteArchiveAfterExtract ?? this.deleteArchiveAfterExtract,
      bandwidthLimitBytesPerSecond:
          bandwidthLimitBytesPerSecond ?? this.bandwidthLimitBytesPerSecond,
      requestSigning: requestSigning ?? this.requestSigning,
    );
  }

  /// Convenience: enable notification with sensible defaults.
  ///
  /// ```dart
  /// worker.withNotification(title: 'Downloading...', allowPause: true)
  /// ```
  HttpDownloadWorker withNotification({
    String? title,
    String? body,
    bool allowPause = false,
  }) =>
      copyWith(
        showNotification: true,
        notificationTitle: title,
        notificationBody: body,
        allowPause: allowPause,
      );

  /// Convenience: set authentication token.
  ///
  /// ```dart
  /// worker.withAuth(token: myToken)
  /// worker.withAuth(token: myApiKey, template: 'ApiKey {accessToken}')
  /// ```
  HttpDownloadWorker withAuth({
    required String token,
    String template = 'Bearer {accessToken}',
  }) =>
      copyWith(authToken: token, authHeaderTemplate: template);

  /// Convenience: enable resume + skip-existing policy.
  HttpDownloadWorker withResume({bool skipIfExists = false}) => copyWith(
        enableResume: true,
        skipExisting: skipIfExists,
      );

  /// Convenience: verify download integrity with a checksum.
  ///
  /// ```dart
  /// worker.withChecksum(expected: sha256Hex)  // defaults to SHA-256
  /// worker.withChecksum(expected: md5Hex, algorithm: 'MD5')
  /// ```
  HttpDownloadWorker withChecksum({
    required String expected,
    String algorithm = 'SHA-256',
  }) =>
      copyWith(expectedChecksum: expected, checksumAlgorithm: algorithm);

  /// Convenience: limit download speed.
  ///
  /// ```dart
  /// worker.withBandwidthLimit(500 * 1024)  // 500 KB/s
  /// ```
  HttpDownloadWorker withBandwidthLimit(int bytesPerSecond) =>
      copyWith(bandwidthLimitBytesPerSecond: bytesPerSecond);

  /// Convenience: sign requests with HMAC-SHA256.
  ///
  /// ```dart
  /// worker.withSigning(RequestSigning(secretKey: mySecret))
  /// ```
  HttpDownloadWorker withSigning(RequestSigning signing) =>
      copyWith(requestSigning: signing);

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
        'skipExisting': skipExisting,
        'showNotification': showNotification,
        if (notificationTitle != null) 'notificationTitle': notificationTitle,
        if (notificationBody != null) 'notificationBody': notificationBody,
        'allowPause': allowPause,
        if (cookies != null) 'cookies': cookies,
        if (authToken != null) 'authToken': authToken,
        'authHeaderTemplate': authHeaderTemplate,
        'onDuplicate': onDuplicate.name,
        'moveToPublicDownloads': moveToPublicDownloads,
        'saveToGallery': saveToGallery,
        'extractAfterDownload': extractAfterDownload,
        if (extractPath != null) 'extractPath': extractPath,
        'deleteArchiveAfterExtract': deleteArchiveAfterExtract,
        if (bandwidthLimitBytesPerSecond != null)
          'bandwidthLimitBytesPerSecond': bandwidthLimitBytesPerSecond,
        if (requestSigning != null) 'requestSigning': requestSigning!.toMap(),
      };
}
