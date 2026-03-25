import 'package:flutter/foundation.dart';

import '../worker.dart';

/// Represents a single file in a multi-file upload.
@immutable
class UploadFile {
  const UploadFile({
    required this.filePath,
    this.fieldName = 'file',
    this.fileName,
    this.mimeType,
  });

  /// Absolute path to the file on device.
  final String filePath;

  /// Multipart form field name (default: 'file').
  final String fieldName;

  /// Override the filename sent in the Content-Disposition header.
  /// Defaults to the basename of [filePath].
  final String? fileName;

  /// MIME type override. Auto-detected from extension if not provided.
  final String? mimeType;

  Map<String, dynamic> toMap() => {
        'filePath': filePath,
        'fileFieldName': fieldName,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
      };
}

/// Upload multiple files in a single multipart/form-data HTTP request.
///
/// Reuses the existing [HttpUploadWorker] native implementation which
/// already supports the `files` array format.
///
/// Example:
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'batch-upload',
///   trigger: const TaskTrigger.oneTime(),
///   worker: NativeWorker.multiUpload(
///     url: 'https://api.example.com/photos',
///     files: [
///       const UploadFile(filePath: '/cache/photo1.jpg', fieldName: 'photos'),
///       const UploadFile(filePath: '/cache/photo2.jpg', fieldName: 'photos'),
///       const UploadFile(filePath: '/cache/document.pdf', fieldName: 'docs',
///                        mimeType: 'application/pdf'),
///     ],
///     headers: {'Authorization': 'Bearer token'},
///     additionalFields: {'albumId': '42'},
///   ),
///   constraints: const Constraints(requiresNetwork: true),
/// );
/// ```
@immutable
final class MultiUploadWorker extends Worker {
  const MultiUploadWorker({
    required this.url,
    required this.files,
    this.headers = const {},
    this.additionalFields = const {},
    this.timeout = const Duration(minutes: 10),
    this.useBackgroundSession = false,
  });

  /// Upload endpoint URL.
  final String url;

  /// Files to upload. Must not be empty, maximum 50 files.
  final List<UploadFile> files;

  /// HTTP headers to include in the request.
  final Map<String, String> headers;

  /// Additional multipart form fields (non-file fields).
  final Map<String, String> additionalFields;

  /// Request timeout.
  final Duration timeout;

  /// Use a background URLSession on iOS (survives app termination).
  final bool useBackgroundSession;

  @override
  String get workerClassName => 'HttpUploadWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'httpUpload',
        'url': url,
        'files': files.map((f) => f.toMap()).toList(),
        'headers': headers,
        'additionalFields': additionalFields,
        'timeoutMs': timeout.inMilliseconds,
        'useBackgroundSession': useBackgroundSession,
      };
}
