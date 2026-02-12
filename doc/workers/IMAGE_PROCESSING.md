# ImageProcessWorker Documentation

## Overview

The `ImageProcessWorker` processes images (resize, compress, convert, crop) in the background **without** starting the Flutter Engine. This provides native Bitmap/UIImage performance with reduced memory usage and faster execution.

**Key Benefits:**
- **Native Performance:** Uses platform image libraries (Bitmap on Android, UIImage on iOS)
- **Low Memory:** No Flutter Engine overhead
- **Battery Efficient:** Runs natively without loading Flutter runtime
- **Background Execution:** Process images when app is closed
- **EXIF Handling:** Automatic orientation correction from camera photos

---

## Basic Usage

### Resize Image

```dart
await NativeWorkManager.enqueue(
  taskId: 'resize-photo',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/photos/IMG_4032.jpg',
    outputPath: '/processed/photo_1080p.jpg',
    maxWidth: 1920,
    maxHeight: 1080,
  ),
);
```

### Compress Image

```dart
await NativeWorkManager.enqueue(
  taskId: 'compress-photo',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/photos/high_res.jpg',
    outputPath: '/photos/compressed.jpg',
    quality: 75,  // 0-100, lower = smaller file
  ),
);
```

### Convert Format

```dart
await NativeWorkManager.enqueue(
  taskId: 'convert-format',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/photos/screenshot.png',
    outputPath: '/photos/screenshot.jpg',
    outputFormat: ImageFormat.jpeg,
    quality: 90,
  ),
);
```

---

## Parameters

### Required Parameters

#### `inputPath` (String)
Path to the input image file.

**Supported Formats:**
- **JPEG** (.jpg, .jpeg) - Photos, lossy compression
- **PNG** (.png) - Screenshots, lossless, transparency
- **WEBP** (.webp) - Modern format (Android only)
- **HEIC** (.heic) - iOS camera photos (iOS only)

**Example:**
```dart
inputPath: '/photos/IMG_4032.jpg'
```

#### `outputPath` (String)
Path where the processed image will be saved.

**Example:**
```dart
outputPath: '/processed/photo_resized.jpg'
```

**Behavior:**
- Parent directories are created automatically
- Existing files are overwritten
- Can be same as `inputPath` (overwrites original)

### Optional Parameters

#### `maxWidth` (int?)
Maximum width in pixels. Image is scaled down if larger.

**Default:** `null` (no width limit)

**Example:**
```dart
maxWidth: 1920  // Full HD width
```

**Behavior:**
- If image width ≤ maxWidth, no resize
- If image width > maxWidth, scales down maintaining aspect ratio

#### `maxHeight` (int?)
Maximum height in pixels. Image is scaled down if larger.

**Default:** `null` (no height limit)

**Example:**
```dart
maxHeight: 1080  // Full HD height
```

**Behavior:**
- If image height ≤ maxHeight, no resize
- If image height > maxHeight, scales down maintaining aspect ratio

#### `maintainAspectRatio` (bool)
Whether to maintain the original aspect ratio when resizing.

**Default:** `true`

**Example:**
```dart
maintainAspectRatio: false  // Stretch to exact dimensions
```

**Behavior:**
- If `true`: Image fits within maxWidth × maxHeight box
- If `false`: Image stretched to exactly maxWidth × maxHeight

#### `quality` (int)
Output quality for JPEG/WEBP formats (0-100).

**Default:** `85`

**Example:**
```dart
quality: 75  // Good balance of quality and size
```

**Recommended Values:**
- `60-70` - Small file size, acceptable quality
- `75-85` - Balanced (recommended for most photos)
- `90-95` - High quality, larger files
- `100` - Maximum quality (very large files)

**Note:** PNG format ignores quality (always lossless)

#### `outputFormat` (ImageFormat?)
Output image format.

**Default:** `null` (same as input)

**Options:**
- `ImageFormat.jpeg` - Lossy compression, smallest size
- `ImageFormat.png` - Lossless, larger size, supports transparency
- `ImageFormat.webp` - Modern format (Android only, iOS returns error)

**Example:**
```dart
outputFormat: ImageFormat.jpeg  // Convert PNG to JPEG
```

#### `cropRect` (Rect?)
Rectangle to crop the image (x, y, width, height).

**Default:** `null` (no cropping)

**Example:**
```dart
import 'dart:ui';

cropRect: Rect.fromLTWH(100, 100, 500, 500)  // x, y, width, height
```

**Behavior:**
- Crop is applied **before** resize
- Coordinates are in pixels from top-left (0, 0)
- Out-of-bounds crop is automatically clamped

#### `deleteOriginal` (bool)
Whether to delete the input file after successful processing.

**Default:** `false`

**Example:**
```dart
deleteOriginal: true  // Save disk space
```

**Safety:**
- Only deletes if processing succeeds
- If processing fails, original is preserved
- Won't delete if input == output path

---

## Result Data

The worker returns detailed processing results in `WorkerResult.data`:

```dart
{
  "inputPath": "/photos/IMG_4032.jpg",
  "outputPath": "/processed/photo_1080p.jpg",
  "originalWidth": 3840,
  "originalHeight": 2160,
  "processedWidth": 1920,
  "processedHeight": 1080,
  "originalSize": 5242880,    // bytes
  "processedSize": 524288,    // bytes
  "compressionRatio": "10.0", // percentage
  "format": "jpeg"
}
```

### Result Fields

| Field | Type | Description |
|-------|------|-------------|
| `inputPath` | String | Source image path |
| `outputPath` | String | Processed image path |
| `originalWidth` | int | Original width (pixels) |
| `originalHeight` | int | Original height (pixels) |
| `processedWidth` | int | Processed width (pixels) |
| `processedHeight` | int | Processed height (pixels) |
| `originalSize` | int | Original file size (bytes) |
| `processedSize` | int | Processed file size (bytes) |
| `compressionRatio` | String | Size ratio as percentage |
| `format` | String | Output format |

---

## Common Use Cases

### 1. Photo Upload Pipeline

Complete workflow: Pick → Resize → Compress → Upload

```dart
// Step 1: User picks photo (Dart code)
final picker = ImagePicker();
final image = await picker.pickImage(source: ImageSource.gallery);
final originalPath = image!.path;

// Step 2: Resize and compress (native, background)
await NativeWorkManager.enqueue(
  taskId: 'process-photo',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: originalPath,
    outputPath: '/processed/upload_ready.jpg',
    maxWidth: 1920,
    maxHeight: 1080,
    quality: 80,
    outputFormat: ImageFormat.jpeg,
  ),
);

// Step 3: Upload processed image (native, background)
await NativeWorkManager.enqueue(
  taskId: 'upload-photo',
  trigger: TaskTrigger.contentUri(taskId: 'process-photo'),
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/upload',
    files: [
      UploadFile(filePath: '/processed/upload_ready.jpg', fieldName: 'photo'),
    ],
  ),
  constraints: Constraints(requiresWifi: true),
);
```

### 2. Thumbnail Generation

Create small previews for gallery view:

```dart
await NativeWorkManager.enqueue(
  taskId: 'generate-thumbnails',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/photos/full_res.jpg',
    outputPath: '/thumbnails/thumb.jpg',
    maxWidth: 200,
    maxHeight: 200,
    quality: 70,
  ),
);
```

### 3. Avatar Cropping

Crop and resize user profile photos:

```dart
import 'dart:ui';

await NativeWorkManager.enqueue(
  taskId: 'crop-avatar',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/temp/profile_photo.jpg',
    outputPath: '/avatars/user_avatar.jpg',
    cropRect: Rect.fromLTWH(100, 50, 400, 400),  // Square crop
    maxWidth: 256,
    maxHeight: 256,
    quality: 90,
    deleteOriginal: true,
  ),
);
```

### 4. Batch Processing

Process multiple photos efficiently:

```dart
final photos = ['/photo1.jpg', '/photo2.jpg', '/photo3.jpg'];

for (int i = 0; i < photos.length; i++) {
  await NativeWorkManager.enqueue(
    taskId: 'process-photo-$i',
    trigger: TaskTrigger.oneTime(),
    worker: NativeWorker.imageProcess(
      inputPath: photos[i],
      outputPath: '/processed/photo_$i.jpg',
      maxWidth: 1920,
      maxHeight: 1080,
      quality: 80,
    ),
  );
}
```

---

## Advanced Features

### EXIF Orientation Handling (Android v1.0+)

The worker **automatically** detects and corrects EXIF orientation for photos taken with cameras. This prevents photos from appearing sideways or upside-down.

**Supported Orientations:**
- Normal (0°)
- Rotate 90° CW
- Rotate 180°
- Rotate 270° CW
- Flip Horizontal
- Flip Vertical
- Transpose
- Transverse

**Example:**
```dart
// Portrait photo from camera appears correctly oriented
await NativeWorkManager.enqueue(
  taskId: 'fix-orientation',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/DCIM/IMG_4032.jpg',  // May have EXIF orientation
    outputPath: '/processed/corrected.jpg',
  ),
);
// ✅ Output image is correctly oriented, EXIF removed
```

### Progress Reporting (Android v1.0+)

The worker reports progress at 5 stages:

| Stage | Progress | Description |
|-------|----------|-------------|
| 1 | 20% | Image loaded into memory |
| 2 | 40% | Crop applied (if requested) |
| 3 | 60% | Resize applied (if requested) |
| 4 | 80% | Compressing to output format |
| 5 | 100% | Image saved to disk |

**Listen to Progress:**
```dart
NativeWorkManager.progress.listen((progress) {
  if (progress.taskId == 'process-photo') {
    print('Progress: ${progress.progress}%');
    print('Stage: ${progress.message}');
  }
});
```

---

## Performance

### Native Performance Benefits

ImageProcessWorker uses platform-native image libraries (Android Bitmap, iOS UIImage/CoreImage) without loading the Flutter Engine, providing:
- Reduced memory usage (no Flutter runtime overhead)
- Faster execution (native code, no Dart VM)
- Better battery efficiency (no engine initialization)

### Performance Tips

✅ **Do:**
- Process images before upload (save bandwidth)
- Use quality 70-85 for most photos
- Resize to screen dimensions (not higher)
- Use JPEG for photos, PNG for graphics
- Delete originals after processing (`deleteOriginal: true`)

❌ **Don't:**
- Use quality > 95 (diminishing returns, huge files)
- Resize already-optimal images
- Process images larger than needed
- Convert PNG to JPEG if transparency is needed

---

## Platform Differences

### Android

**Implementation:** Uses `Bitmap` and `BitmapFactory`

**Features:**
- ✅ EXIF orientation handling (v1.0+)
- ✅ Progress reporting at 5 stages
- ✅ Formats: JPEG, PNG, WEBP
- ✅ Hardware acceleration

**Dependencies:**
- `androidx.exifinterface:exifinterface:1.3.7` (v1.0+)

### iOS

**Implementation:** Uses `UIImage` and `CoreGraphics`

**Features:**
- ✅ Formats: JPEG, PNG, HEIC
- ✅ Hardware acceleration
- ❌ WEBP not supported (returns error with helpful message)
- ⏳ EXIF orientation (available in v1.0)
- ⏳ Progress reporting (available in v1.0)

**iOS-Specific Behavior:**
- HEIC format supported (iOS native camera format)
- WEBP format returns clear error suggesting JPEG/PNG alternatives

---

## Error Handling

### Common Errors

#### "Input file not found"
**Cause:** Image doesn't exist at specified path

**Solution:**
```dart
final file = File(inputPath);
if (!file.existsSync()) {
  print('Image not found: $inputPath');
  return;
}
```

#### "Failed to decode image"
**Cause:** File is not a valid image or corrupted

**Solution:**
```dart
// Validate file before processing
if (!isValidImageFile(inputPath)) {
  print('Invalid image format');
  return;
}
```

#### "WEBP format not fully supported on iOS"
**Cause:** Trying to output WEBP on iOS

**Solution:**
```dart
// Use JPEG or PNG on iOS
outputFormat: Platform.isIOS ? ImageFormat.jpeg : ImageFormat.webp
```

#### "Quality must be between 0 and 100"
**Cause:** Invalid quality value

**Solution:**
```dart
quality: 85.clamp(0, 100)  // Ensure valid range
```

---

## Troubleshooting

### Issue: Image Appears Rotated

**Symptoms:** Portrait photo displays sideways

**Cause:** EXIF orientation not handled

**Solution (Android v1.0+):**
```dart
// Automatic EXIF handling - no action needed!
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: cameraPhoto,
    outputPath: outputPath,
  ),
);
```

**Solution (iOS - manual):**
```dart
// For iOS < v1.0.1, handle in Dart:
import 'package:image/image.dart' as img;

final image = img.decodeImage(File(inputPath).readAsBytesSync());
final oriented = img.bakeOrientation(image!);
File(tempPath).writeAsBytesSync(img.encodeJpg(oriented));
```

### Issue: Processing Takes Too Long

**Symptoms:** Takes >10 seconds for small images

**Causes:**
1. Very large input image (8K+)
2. Complex processing (crop + resize + convert)
3. Background throttling

**Solutions:**
```dart
// 1. Pre-check image size
final file = File(inputPath);
final size = await file.length();
if (size > 20 * 1024 * 1024) {  // > 20MB
  print('Image too large, consider downsizing first');
}

// 2. Use constraints for immediate processing
constraints: Constraints(
  requiresDeviceIdle: false,  // Don't wait for idle
)
```

### Issue: Out of Memory

**Symptoms:** App crashes during processing

**Causes:** Processing very large images (12K+)

**Solutions:**
```dart
// Process in steps: first resize, then compress
// Step 1: Rough resize
await NativeWorkManager.enqueue(
  taskId: 'rough-resize',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: hugeImage,
    outputPath: '/temp/medium.jpg',
    maxWidth: 4000,
    maxHeight: 4000,
    quality: 90,
  ),
);

// Step 2: Fine-tune
await NativeWorkManager.enqueue(
  taskId: 'final-process',
  trigger: TaskTrigger.contentUri(taskId: 'rough-resize'),
  worker: NativeWorker.imageProcess(
    inputPath: '/temp/medium.jpg',
    outputPath: final Output,
    maxWidth: 1920,
    maxHeight: 1080,
    quality: 80,
  ),
);
```

---

## Migration from Dart Packages

### From `image` package

**Before (Dart):**
```dart
import 'package:image/image.dart' as img;

void processImage() {
  // ❌ Loads entire image in memory (180MB for 4K)
  final image = img.decodeImage(File(inputPath).readAsBytesSync())!;

  // ❌ Blocking operation (freezes UI)
  final resized = img.copyResize(image, width: 1920, height: 1080);

  // ❌ More blocking I/O
  final jpeg = img.encodeJpg(resized, quality: 85);
  File(outputPath).writeAsBytesSync(jpeg);
}
```

**After (Native Worker):**
```dart
// ✅ Native processing, no Flutter Engine overhead
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: inputPath,
    outputPath: outputPath,
    maxWidth: 1920,
    maxHeight: 1080,
    quality: 85,
  ),
);
```

**Benefits:**
- Native performance (no Flutter Engine overhead)
- Reduced memory usage
- Non-blocking (doesn't freeze UI)
- Works in background
- Automatic EXIF handling (Android)
- Progress reporting

---

## See Also

- **[HttpUploadWorker](./HTTP_UPLOAD.md)** - Upload processed images
- **[FileCompressionWorker](./FILE_COMPRESSION.md)** - Compress images into ZIP
- **[Task Chains Guide](../use-cases/06-chain-processing.md)** - Build image processing pipelines

---

## Changelog

### v1.0.0 (2026-02-07)
- ✅ Android: EXIF orientation handling for all 8 orientations
- ✅ Android: Progress reporting at 5 stages
- ✅ Android: Added `androidx.exifinterface` dependency
- ✅ iOS: Clear error for WEBP format (suggests alternatives)
- ✅ Formats: JPEG, PNG, WEBP (Android), HEIC (iOS)
- ✅ Operations: Resize, compress, convert, crop

### Planned for v1.0.1
- iOS: EXIF orientation handling
- iOS: Progress reporting
- Batch processing API (multiple images in one task)
- Advanced filters (grayscale, blur, etc.)
