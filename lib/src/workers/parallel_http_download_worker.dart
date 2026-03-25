import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Parallel chunked HTTP download worker configuration.
///
/// Splits a single file download into [numChunks] parallel byte-range
/// requests (HTTP/1.1 `Range` header, RFC 7233), downloads them
/// concurrently on the native side, then merges the parts into a single
/// output file — all without loading the file into memory.
///
/// **When to use over [HttpDownloadWorker]:**
/// - Files larger than ~50 MB where parallel chunks give real speed-up.
/// - Servers that support `Accept-Ranges: bytes` (most CDNs do).
/// - When you want faster downloads on high-bandwidth connections.
///
/// **Automatic fallback:** If the server does not advertise
/// `Accept-Ranges: bytes` or does not return a `Content-Length`, the
/// worker automatically falls back to a single sequential download
/// (identical to [HttpDownloadWorker]).
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
///     numChunks: 4,           // default
///     showNotification: true,
///   ),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// ## Progress events
///
/// Progress is reported as aggregate bytes across all chunks, so the
/// [TaskProgress.progress] field rises smoothly from 0 to 100 even
/// when chunks finish out of order.
///
/// ## Resume support
///
/// Each chunk is saved to `savePath.partN` temporarily.  If the task is
/// interrupted, a subsequent enqueue will pick up any completed parts and
/// only re-download missing or incomplete chunks.
@immutable
final class ParallelHttpDownloadWorker extends Worker {
  const ParallelHttpDownloadWorker({
    required this.url,
    required this.savePath,
    this.numChunks = 4,
    this.headers = const {},
    this.timeout = const Duration(minutes: 10),
    this.expectedChecksum,
    this.checksumAlgorithm = 'SHA-256',
    this.showNotification = false,
    this.notificationTitle,
    this.notificationBody,
    this.skipExisting = false,
  }) : assert(numChunks >= 1 && numChunks <= 16,
            'numChunks must be between 1 and 16');

  /// The URL to download from.
  final String url;

  /// Absolute path where the merged file will be saved.
  final String savePath;

  /// Number of parallel byte-range chunks (1–16, default 4).
  ///
  /// A value of 1 is equivalent to a sequential download but still goes
  /// through the parallel code path.  Values above 8 rarely improve
  /// throughput and increase connection overhead.
  final int numChunks;

  /// Optional HTTP headers sent with every chunk request.
  final Map<String, String> headers;

  /// Per-chunk request timeout (default: 10 minutes).
  ///
  /// Each chunk has its own independent timeout counter.
  final Duration timeout;

  /// Expected checksum for the merged file (optional).
  ///
  /// Verified after all chunks are merged. Download fails if checksums
  /// do not match.
  final String? expectedChecksum;

  /// Hashing algorithm for checksum verification (default: `'SHA-256'`).
  ///
  /// Supported: `'MD5'`, `'SHA-1'`, `'SHA-256'`, `'SHA-512'`.
  final String checksumAlgorithm;

  /// Show a system notification with aggregate download progress.
  final bool showNotification;

  /// Title for the progress notification.
  ///
  /// Defaults to the file name derived from [url].
  final String? notificationTitle;

  /// Body text for the progress notification.
  final String? notificationBody;

  /// Skip the download if [savePath] already exists on disk.
  ///
  /// Same semantics as [HttpDownloadWorker.skipExisting].
  /// Default: `false`
  final bool skipExisting;

  @override
  String get workerClassName => 'ParallelHttpDownloadWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'parallelHttpDownload',
        'url': url,
        'savePath': savePath,
        'numChunks': numChunks,
        'headers': headers,
        'timeoutMs': timeout.inMilliseconds,
        if (expectedChecksum != null) 'expectedChecksum': expectedChecksum,
        'checksumAlgorithm': checksumAlgorithm,
        'skipExisting': skipExisting,
        'showNotification': showNotification,
        if (notificationTitle != null) 'notificationTitle': notificationTitle,
        if (notificationBody != null) 'notificationBody': notificationBody,
      };
}
