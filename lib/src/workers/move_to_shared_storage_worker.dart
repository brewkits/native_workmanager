import 'package:flutter/foundation.dart';

import '../worker.dart';

/// Target shared storage location for [MoveToSharedStorageWorker].
enum SharedStorageType {
  /// Public Downloads folder.
  ///
  /// Android API 29+: `MediaStore.Downloads`.
  /// Android API 28−: `Environment.DIRECTORY_DOWNLOADS`.
  /// iOS: app's `Documents` directory (accessible via Files app).
  downloads,

  /// Device photo library / camera roll.
  ///
  /// Android: `MediaStore.Images` (API 29+) or `DIRECTORY_PICTURES` (API 28−).
  /// iOS: `PHPhotoLibrary` — requires `NSPhotoLibraryAddUsageDescription` in Info.plist.
  photos,

  /// Public Music folder / audio library.
  ///
  /// Android: `MediaStore.Audio` (API 29+) or `DIRECTORY_MUSIC` (API 28−).
  /// iOS: Falls back to `Documents` directory (MPMediaLibrary write is not supported).
  music,

  /// Public Video folder / video library.
  ///
  /// Android: `MediaStore.Video` (API 29+) or `DIRECTORY_MOVIES` (API 28−).
  /// iOS: `PHPhotoLibrary` (supports both image and video files).
  video,
}

/// Move a file from app-private storage to a shared / public location.
///
/// On Android this uses `MediaStore` (API 29+) or the legacy
/// `Environment.getExternalStoragePublicDirectory` (API 28−).
///
/// On iOS the `downloads` and `music` types copy the file to the app's
/// `Documents` directory (accessible via the Files app). The `photos` and
/// `video` types save to `PHPhotoLibrary`.
///
/// Example:
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'save-photo',
///   trigger: const TaskTrigger.oneTime(),
///   worker: NativeWorker.moveToSharedStorage(
///     sourcePath: '/path/to/download/photo.jpg',
///     storageType: SharedStorageType.photos,
///   ),
///   constraints: const Constraints(),
/// );
/// ```
@immutable
final class MoveToSharedStorageWorker extends Worker {
  const MoveToSharedStorageWorker({
    required this.sourcePath,
    required this.storageType,
    this.fileName,
    this.mimeType,
    this.subDir,
  });

  /// Absolute path to the source file inside the app sandbox.
  final String sourcePath;

  /// Target shared storage bucket.
  final SharedStorageType storageType;

  /// Filename to use in the shared storage location.
  /// Defaults to the basename of [sourcePath].
  final String? fileName;

  /// MIME type hint for MediaStore insertion.
  /// Auto-detected from file extension when `null`.
  final String? mimeType;

  /// Optional subdirectory within the shared storage location.
  /// On Android (API 29+) this sets `MediaStore.MediaColumns.RELATIVE_PATH`.
  /// Example: `'MyApp/Camera'` → `Downloads/MyApp/Camera/`.
  final String? subDir;

  @override
  String get workerClassName => 'MoveToSharedStorageWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'moveToSharedStorage',
        'sourcePath': sourcePath,
        'storageType': storageType.name,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (subDir != null) 'subDir': subDir,
      };
}
