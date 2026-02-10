import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Image output formats.
enum ImageFormat {
  jpeg('jpeg'),
  png('png'),
  webp('webp');

  const ImageFormat(this.value);
  final String value;
}

/// Image processing worker configuration.
///
/// Resizes, compresses, and converts images natively for optimal performance.
@immutable
final class ImageProcessWorker extends Worker {
  const ImageProcessWorker({
    required this.inputPath,
    required this.outputPath,
    this.maxWidth,
    this.maxHeight,
    this.maintainAspectRatio = true,
    this.quality = 85,
    this.outputFormat,
    this.cropRect,
    this.deleteOriginal = false,
  });

  /// Path to input image file.
  final String inputPath;

  /// Path where processed image will be saved.
  final String outputPath;

  /// Maximum width in pixels (null = no width limit).
  final int? maxWidth;

  /// Maximum height in pixels (null = no height limit).
  final int? maxHeight;

  /// Whether to maintain aspect ratio when resizing.
  final bool maintainAspectRatio;

  /// Output quality (0-100, higher is better quality).
  /// Only applies to JPEG and WEBP formats.
  final int quality;

  /// Output format (null = same as input).
  final ImageFormat? outputFormat;

  /// Optional crop rectangle (x, y, width, height).
  final Rect? cropRect;

  /// Whether to delete original image after processing.
  final bool deleteOriginal;

  @override
  String get workerClassName => 'ImageProcessWorker';

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'workerType': 'imageProcess',
      'inputPath': inputPath,
      'outputPath': outputPath,
      'maintainAspectRatio': maintainAspectRatio,
      'quality': quality,
      'deleteOriginal': deleteOriginal,
    };

    if (maxWidth != null) map['maxWidth'] = maxWidth;
    if (maxHeight != null) map['maxHeight'] = maxHeight;
    if (outputFormat != null) map['outputFormat'] = outputFormat!.value;
    if (cropRect != null) {
      map['cropRect'] = {
        'x': cropRect!.left.toInt(),
        'y': cropRect!.top.toInt(),
        'width': cropRect!.width.toInt(),
        'height': cropRect!.height.toInt(),
      };
    }

    return map;
  }
}
