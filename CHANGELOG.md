# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.4] - 2026-02-18

### Fixed
- **Android: Worker crash "IllegalStateException: Not implemented"** (Complete fix)
  - **Root cause:** WorkManager 2.10.0+ calls `getForegroundInfoAsync()` in execution path for expedited tasks. Upstream `kmpworkmanager` did not override `getForegroundInfo()`, causing crash
  - **Solution:** Upgraded to `kmpworkmanager:2.3.3` which adds proper `getForegroundInfo()` override
  - **Impact:** All Android users can now safely use WorkManager 2.10.0+
  - **Files changed:** `android/build.gradle`
  - **Reported by:** Abdullah Al-Hasnat
- **Example app: Flutter rendering error** in Chain Resilience Test screen
  - Fixed `RenderFlex` unbounded height constraint error caused by `Expanded` widget inside `SingleChildScrollView`
  - Changed to `SizedBox` with fixed height for logs section
- **Example app: Integration test API errors**
  - Updated bug fix integration tests to use correct `native_workmanager` API
  - Fixed `TaskTrigger.periodic()` usage and event stream handling
- **Example app: Incorrect library naming in benchmarks**
  - Corrected competitor library references from `flutter_wm` to `workmanager`
  - Updated production impact comparison pages and manual benchmark page

### Changed
- **Dependencies:**
  - Upgraded `kmpworkmanager` from 2.3.1 to 2.3.3 (fixes WorkManager 2.10.0+ compatibility)
  - Upgraded `work-runtime-ktx` from 2.9.1 to 2.10.1 (safe with kmpworkmanager 2.3.3+)

### Added
- **Bug fix verification demo** - Interactive UI demonstrating WorkManager 2.10.0+ compatibility
  - Shows original bug details and fix information
  - Runs expedited tasks (original crash scenario) and displays real-time results
  - Tests concurrent expedited tasks and task chains
  - Accessible via "🐛 Bug Fix" tab in example app
- **Integration tests** - Comprehensive test coverage for WorkManager 2.10.0+ bug fix
  - Tests expedited tasks, concurrent tasks, periodic tasks, and chains
  - Verifies notification i18n support
- **Documentation** - Complete bug fix verification guide (`BUG_FIX_VERIFICATION.md`)
  - Root cause analysis and fix details
  - Build and runtime verification steps
  - Migration guide for users

### Upstream Fix (kmpworkmanager 2.3.3)
- Added `getForegroundInfo()` override in `KmpWorker` with notification localization support
- Fixed chain heavy-task routing bug (tasks with `isHeavyTask=true` now correctly use `KmpHeavyWorker`)
- Notification strings now support i18n via Android string resources

---

## [1.0.3] - 2026-02-16

### Fixed
- **Android: Critical initialization bug** - "KmpWorkManager not initialized!" error
  - **Root cause:** Plugin was not calling `KmpWorkManager.initialize()` from kmpworkmanager library
  - **Impact:** All Android users attempting to use the plugin would get runtime errors when tasks execute
  - **Solution:** Added `KmpWorkManager.initialize()` call in `initializeKoin()` before setting up Koin modules
  - **Files changed:** `NativeWorkmanagerPlugin.kt`
  - **Reported by:** Abdullah Al-Hasnat (GitHub issue - user feedback)

### Added
- **Documentation: Android Setup Guide** (`doc/ANDROID_SETUP.md`)
  - Comprehensive Android configuration requirements
  - Minimum SDK 26+ requirement clearly documented
  - Troubleshooting section for initialization errors
  - Build verification steps
  - ProGuard/R8 configuration
  - Production checklist

### Changed
- **Documentation:** Updated README, GETTING_STARTED, and FAQ with Android setup requirements
  - Platform requirements mentioned upfront in Quick Start
  - Android minSdk 26+ requirement added to prerequisites
  - Troubleshooting section enhanced with Android-specific issues
  - Links to new Android setup guide

### Notes
- **CRITICAL FIX** - All Android users should upgrade immediately
- Previous versions (1.0.0, 1.0.1) are non-functional on Android
- iOS not affected by this bug
- Package description updates from 1.0.2 (2026-02-13) merged into this release

---

## [1.0.1] - 2026-02-12

### Fixed
- **Package Description:** Shortened from 215 to 154 characters to meet pub.dev requirements (60-180 chars)
- **Impact:** Improves pub.dev score from 150/160 to 160/160 points
- **Details:** Removed redundant text while preserving key value propositions

### Notes
- No code changes - metadata fix only
- Fixes issue identified in pub.dev analysis
- Achieves perfect pub.dev compliance score

---

## [1.0.0] - 2026-02-12

Production release with 11 built-in native workers for background task management.

### Critical Safety Fixes

#### iOS Force Unwrap Elimination
- **Fixed:** Removed all unsafe force unwraps (`!`) from iOS worker JSON parsing
- **Impact:** Prevents potential crashes from invalid UTF-8 encoding
- **Files:** 8 iOS workers (Crypto, DartCallback, FileCompression, FileDecompression, HttpDownload, HttpSync, HttpUpload, ImageProcess)
- **Pattern:** Replaced `input.data(using: .utf8)!` with safe `guard let` statements
- **Result:** Zero crash risk from encoding issues

#### Test Infrastructure Improvements
- **Fixed:** chain_data_flow_test.dart initialization issues
- **Added:** Proper platform channel mocking for unit tests
- **Result:** 808 tests passing

### Features

#### 1. **HttpDownloadWorker: Resume Support** 

Downloads can now resume from the last byte on network failure, saving bandwidth and time.

**Implementation:**
- HTTP Range Requests (RFC 7233) with 206 Partial Content handling
- Automatic retry from last downloaded byte
- Fallback to full download if server doesn't support Range
- `enableResume: true` by default (backward compatible)

**Example:**
```dart
NativeWorker.httpDownload(
  url: 'https://cdn.example.com/app-update.apk',  // 100MB file
  savePath: '/downloads/update.apk',
  enableResume: true,  // Resume from last byte on failure
)
```

**Benefits:**
-  Saves bandwidth on mobile networks
-  Faster completion for large files
-  Better UX (no restart from 0%)
-  Critical for unreliable connections

#### 2. **HttpUploadWorker: Multi-File Support** 

Upload multiple files in a single request, unblocking social media and e-commerce apps.

**Implementation:**
- `files: List<FileConfig>` array for multiple files
- Same `fileFieldName` = array on server side
- Different `fileFieldName` = separate form fields
- Backward compatible with single file API

**Example:**
```dart
NativeWorker.httpUpload(
  url: 'https://api.example.com/gallery',
  files: [
    FileUploadConfig(filePath: '/photos/img1.jpg', fileFieldName: 'photos'),
    FileUploadConfig(filePath: '/photos/img2.jpg', fileFieldName: 'photos'),
    FileUploadConfig(filePath: '/photos/thumb.jpg', fileFieldName: 'thumbnail'),
  ],
)
```

**Benefits:**
-  Upload multiple photos in one request
-  Mix different form fields (photos + thumbnail)
-  Reduces server round-trips
-  Unblocks social media, e-commerce use cases

#### 3. **FileDecompressionWorker: NEW Worker** 

Complete ZIP extraction worker with security protections, completing the compression/decompression pair.

**Implementation:**
- Streaming extraction (low memory usage ~5-10MB)
- Zip slip protection (canonical path validation)
- Zip bomb protection (size validation during extraction)
- `deleteAfterExtract` option to save storage
- `overwrite` control for existing files
- Basic ZIP support

**Example:**
```dart
// Download → Extract → Delete workflow
await NativeWorkManager.enqueue(
  taskId: 'extract-assets',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileDecompress(
    zipPath: '/cache/assets.zip',
    targetDir: '/data/assets/',
    deleteAfterExtract: true,
    overwrite: true,
  ),
);
```

**Benefits:**
-  Completes compression/decompression pair
-  Enables Download → Extract workflows
-  Security built-in (zip slip, zip bomb)
-  Memory efficient (~5-10MB RAM)
-  Password support coming in v1.1.0

#### 4. **ImageProcessWorker: NEW Worker** 

Native image processing (resize, compress, convert) with native performance.

**Implementation:**
- Native Bitmap (Android) / UIImage (iOS) APIs
- Hardware-accelerated rendering
- Memory-efficient: No Flutter Engine overhead
- Native performance
- Formats: JPEG, PNG, WEBP

**Example:**
```dart
// Resize 4K photo to 1080p for upload
await NativeWorkManager.enqueue(
  taskId: 'resize-photo',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/photos/IMG_4032.png',
    outputPath: '/processed/photo_1080p.jpg',
    maxWidth: 1920,
    maxHeight: 1080,
    quality: 85,
    outputFormat: ImageFormat.jpeg,
    deleteOriginal: false,
  ),
);
```

**Benefits:**
-  Native performance (no Flutter Engine)
-  Lower memory usage
-  Resize, compress, convert formats
-  Crop support
-  For photo upload pipelines

#### 5. **CryptoWorker: NEW Worker** 

File hashing and AES-256-GCM encryption/decryption for data security.

**Implementation:**
- Hash algorithms: MD5, SHA-1, SHA-256, SHA-512
- AES-256-GCM encryption (authenticated)
- Password-based key derivation (PBKDF2)
- Streaming operations for large files

**Example:**
```dart
// Hash file for integrity verification
await NativeWorkManager.enqueue(
  taskId: 'verify-download',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.hashFile(
    filePath: '/downloads/file.zip',
    algorithm: HashAlgorithm.sha256,
  ),
);

// Encrypt sensitive file
await NativeWorkManager.enqueue(
  taskId: 'encrypt-backup',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.cryptoEncrypt(
    inputPath: '/data/backup.db',
    outputPath: '/data/backup.db.enc',
    password: 'mySecretPassword',
  ),
);
```

**Benefits:**
-  File integrity verification
-  Secure backups with encryption
-  Deduplication via hashing

#### 6. **FileSystemWorker: NEW Worker** 

Native file system operations (copy, move, delete, list, mkdir) enabling pure-native task chains without Flutter Engine overhead.

**Implementation:**
- 5 operations: copy, move, delete, list, mkdir
- Security validations (path traversal, protected paths, sandbox enforcement)
- Atomic operations when possible (move on same filesystem)
- Pattern matching with wildcards (*.jpg, file_?.txt)
- Progress reporting for large operations

**Example:**
```dart
// Pure-native workflow: Download → Move → Extract → Process
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(url: url, savePath: '/temp/file.zip'),
  ),
).then(
  TaskRequest(
    id: 'move',
    worker: NativeWorker.fileMove(
      sourcePath: '/temp/file.zip',
      destinationPath: '/downloads/file.zip',
    ),
  ),
).then(
  TaskRequest(
    id: 'extract',
    worker: NativeWorker.fileDecompress(
      zipPath: '/downloads/file.zip',
      targetDir: '/extracted/',
    ),
  ),
).enqueue();

// List files with pattern
await NativeWorkManager.enqueue(
  taskId: 'find-photos',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileList(
    path: '/photos',
    pattern: '*.jpg',
    recursive: true,
  ),
);
```

**Benefits:**
-  Enables pure-native task chains (no Dart callbacks)
-  Lower memory usage (no Flutter Engine)
-  All 5 operations: copy, move, delete, list, mkdir
-  Security built-in (path traversal, sandbox)
-  Pattern matching for file filtering
-  Atomic move when possible (faster than copy+delete)

---

### ✨ Enhanced Features

#### HttpDownloadWorker: Checksum Verification 

Verify file integrity after download to detect corruption or tampering.

**Implementation:**
- Algorithms: MD5, SHA-1, SHA-256, SHA-512
- Automatic file deletion if checksum mismatch
- Task retry on verification failure

**Example:**
```dart
NativeWorker.httpDownload(
  url: 'https://cdn.example.com/firmware.bin',
  savePath: '/downloads/firmware.bin',
  expectedChecksum: 'a3b2c1d4e5f6...',
  checksumAlgorithm: 'SHA-256',
)
```

**Benefits:**
-  Detect corrupted downloads
-  Prevent security vulnerabilities
-  Critical for firmware, installers, sensitive files

#### HttpUploadWorker: Raw Bytes Upload 

Upload data from memory without creating temp files.

**Implementation:**
- `body: String` for text data (JSON, XML)
- `bodyBytes: String` for Base64-encoded binary data
- `contentType: String` for MIME type

**Example:**
```dart
// Upload JSON without temp file
NativeWorker.httpUpload(
  url: 'https://api.example.com/data',
  body: '{"userId": "123", "action": "sync"}',
  contentType: 'application/json',
)
```

**Benefits:**
-  No temp file for in-memory data
-  Faster for small payloads
-  Cleaner API for JSON/XML

#### HttpRequestWorker: Response Validation 

Detect API errors in HTTP 200 responses using regex patterns.

**Implementation:**
- `successPattern: String` - Regex response must match
- `failurePattern: String` - Regex that indicates error
- Fails task even with HTTP 200 if validation fails

**Example:**
```dart
NativeWorker.httpRequest(
  url: 'https://api.example.com/login',
  method: HttpMethod.post,
  successPattern: r'"status"\s*:\s*"success"',
  failurePattern: r'"status"\s*:\s*"error"',
)
```

**Benefits:**
-  Prevent false positives (200 with error body)
-  Critical for poorly-designed APIs
-  Flexible regex validation

#### ImageProcessWorker Enhancements (Android)

**1. EXIF Orientation Handling**
- Auto-detects and corrects EXIF orientation from camera photos
- Handles all 8 EXIF orientations (rotate, flip, transpose)
- Photos always display correctly (no more sideways images!)
- Dependency added: `androidx.exifinterface:exifinterface:1.3.7`

**2. Progress Reporting (5 Stages)**
- 20% - Image loaded into memory
- 40% - Crop applied (if requested)
- 60% - Resize applied (if requested)
- 80% - Compressing to output format
- 100% - Image saved to disk

**3. WEBP Error Handling (iOS)**
- Clear error message instead of silent fallback to JPEG
- Suggests alternatives (JPEG for smaller, PNG for lossless)
- Prevents user confusion

**Example:**
```dart
// Portrait photo from camera - automatically corrected!
await NativeWorkManager.enqueue(
  taskId: 'process-photo',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.imageProcess(
    inputPath: '/DCIM/IMG_4032.jpg',  // May have EXIF orientation
    outputPath: '/processed/corrected.jpg',
    maxWidth: 1920,
    maxHeight: 1080,
  ),
);
//  Output is correctly oriented, EXIF removed
```

**Benefits:**
-  Photos always display correctly
-  Real-time progress for large images (4K, 8K)
-  Clear errors instead of surprises
-  Better UX for photo upload workflows

#### HttpUploadWorker Enhancements

**Form Field Limit Validation**
- Added 50 field limit to prevent memory issues
- Clear error message with helpful suggestion
- Guides users to use JSON body for large data

**Example Error:**
```
Too many form fields: 75
Maximum allowed: 50 fields
Consider sending large data as JSON in request body instead
```

**Benefits:**
-  Prevents memory exhaustion
-  Clear guidance for proper usage
-  Protects against misuse

---

### 📚 **Documentation**

#### User Guides
- `docs/GETTING_STARTED.md` - 3-minute quick start guide
- `docs/MIGRATION_GUIDE.md` - Step-by-step migration from workmanager
- `docs/README.md` - Documentation index
- `docs/FAQ.md` - Frequently asked questions

#### Worker-Specific Documentation
- `docs/workers/FILE_DECOMPRESSION.md` - Complete guide
- `docs/workers/IMAGE_PROCESSING.md` - Complete guide
- `docs/workers/CRYPTO_OPERATIONS.md` - Complete guide
- `docs/workers/FILE_SYSTEM.md` - Complete guide

**Each guide includes:**
- Overview and key benefits
- Usage examples and parameters
- Common use cases
- Error handling and troubleshooting
- Platform differences

#### Platform Guides
- `docs/PLATFORM_CONSISTENCY.md` - Cross-platform behavior guide
- `docs/IOS_BACKGROUND_LIMITS.md` - iOS 30-second limit guide

#### Example App Demonstrations
- `example/lib/pages/demo_scenarios_page.dart` - Interactive demos
  - FileDecompressionWorker demo
  - ImageProcessWorker demo
  - CryptoWorker demo
  - FileSystemWorker demo
  - Complete Native Chain (7-step workflow)
  - Enhanced Real-World Scenarios
- `example/lib/pages/file_system_demo_page.dart` - Dedicated FileSystem demo
  - Interactive test environment
  - 8 demo operations
  - Real-time activity log

---

###  **Security Improvements**

All workers now include:
-  Path traversal validation (prevent `..` attacks)
-  File size limits (prevent DoS)
-  URL scheme validation (prevent `file://`, `ftp://`)
-  Input sanitization for logging
-  Atomic operations (cleanup on error)

**Specific Security Features:**
- **FileDecompressionWorker:** Zip slip + zip bomb protection
- **CryptoWorker:** PBKDF2 key derivation (100K iterations)
- **HttpDownloadWorker:** Checksum verification
- **All Workers:** Security validator utilities

---

### ⚡ **Performance**

All workers maintain high performance with low resource usage:

| Worker | Memory Usage | Startup Time | Battery Impact |
|--------|-------------|--------------|----------------|
| HttpDownloadWorker | Low | Fast | Minimal |
| HttpUploadWorker | Low | Fast | Minimal |
| FileDecompressionWorker | Low | Fast | Minimal |
| CryptoWorker | Low | Fast | Minimal |

**Key:** Streaming I/O keeps memory low regardless of file size.

---

### 🌐 **Platform Consistency**

All features implemented on **both Android and iOS** with 98-100% API consistency.

Minor difference: CryptoWorker uses AES-CBC (Android) vs AES-GCM (iOS), both AES-256.

---

### 🔄 **Backward Compatibility**

 **100% backward compatible** - All features are opt-in:
- `enableResume` defaults to `true` (can disable)
- `files` array is optional (single file API still works)
- Validation patterns are optional
- New workers don't affect existing code

---

### 🙏 **Acknowledgments**

Built on [kmpworkmanager v2.3.0](https://github.com/pablichjenkov/kmpworkmanager) for Kotlin Multiplatform.

---

## Links

- [GitHub Repository](https://github.com/brewkits/native_workmanager)
- [Issue Tracker](https://github.com/brewkits/native_workmanager/issues)
- [Documentation](https://github.com/brewkits/native_workmanager#readme)
- [KMP WorkManager](https://github.com/pablichjenkov/kmpworkmanager)
- [Migration Guide](doc/MIGRATION_GUIDE.md)

---

**Latest Version:** 1.0.1
**Status:**  Production Ready - Stable release for all production apps
**KMP Parity:** 100%  (kmpworkmanager v2.3.1)
**Platforms:** Android  | iOS 
