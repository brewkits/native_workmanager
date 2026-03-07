# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.8] - 2026-03-07

### Fixed

- **iOS: DartWorker always returned failure in debug/test mode** (`NativeWorkmanagerPlugin.swift`)
  - **Root cause:** `FlutterCallbackCache.lookupCallbackInformation()` returns `nil` in debug/JIT builds (Flutter integration tests, Xcode debug runs). `FlutterEngineManager` used this cache to start a secondary engine, so it could never initialise — every `DartCallbackWorker` invocation silently failed.
  - **Fix:** Added `executeDartWorkerViaMethodChannel()` in `NativeWorkmanagerPlugin`. When `DartCallbackWorker` is detected, the plugin invokes `executeDartCallback` directly on the existing main Flutter method channel (Native → Dart) instead of launching a secondary engine. This reuses the already-running Dart isolate and works in any build mode. Falls back to `FlutterEngineManager` when `methodChannel` is `nil` (killed-app background execution in release builds).
  - **Impact:** iOS DartWorker tests went from 32/37 → **37/37** passing. `isHeavyTask` test (which uses DartWorker) also now passes.

- **iOS: HttpDownloadWorker regression — false disk-space failure on small files** (`SecurityValidator.swift`)
  - **Root cause:** The v1.0.7 disk-space check added a fixed `50 * 1024 * 1024` (50 MB) minimum to `hasEnoughDiskSpace()`. A 292-byte download from `jsonplaceholder.typicode.com/posts/1` required ~50 MB free, causing false failures on storage-constrained devices.
  - **Fix:** Removed the 50 MB constant. Formula now matches Android: `requiredWithMargin = bytes × 1.2`.

- **Security: Path traversal hardening across all Android workers** (`SecurityValidator.kt`)
  - Replaced `contains("..")` string checks (bypassable via URL encoding and symlink traversal) with `File.canonicalPath` against a blocked-prefix allowlist throughout all Android workers: `HttpDownloadWorker`, `HttpUploadWorker`, `FileDecompressionWorker`, `FileSystemWorker` (copy/move/mkdir), `ImageProcessWorker`, `FileCompressionWorker`, and `CryptoWorker`.

- **iOS: Chain cancel — task handle not stored before execution** (`NativeWorkmanagerPlugin.swift`)
  - `handleEnqueueChain` now creates the `Task` handle and stores it in `activeTasks[chainCancelId]` before the chain starts, so `cancel(chainName)` finds and cancels it correctly (C1 fix).

- **iOS: Chain execution was blocking** — `handleEnqueueChain` held `FlutterResult` open until the chain completed (M1 fix). Now returns `"ACCEPTED"` immediately; completion delivered via `emitTaskEvent` on the EventChannel.

- **iOS: Data race on `taskStartTimes`** (`NativeWorkmanagerPlugin.swift`)
  - Read and remove operations in `showDebugNotification` now use `stateQueue.sync` / `stateQueue.async(flags:.barrier)` to prevent concurrent access (H3 fix).

- **Android: Hot restart skipped Koin module reload** (`NativeWorkmanagerPlugin.kt`)
  - `isKoinInitialized` was never reset in `onDetachedFromEngine()`, so hot restart silently reused a stale Koin context (H2 fix).

- **Dart: `TaskEvent.fromMap` and `TaskProgress.fromMap` null-safety** (`events.dart`)
  - Replaced unsafe `as String` / `as int` casts with null-safe fallbacks: `(map['x'] as String?) ?? ''`, `(map['x'] as num?)?.toInt() ?? 0` (M5 fix).

- **Dart: `TaskEvent.operator==` ignored `message` field** (`events.dart`)
  - Two events with identical `taskId`/`success`/`timestamp` but different `message` were wrongly considered equal. Added `message == other.message` to `==` and `hashCode` (L6 fix).

- **Dart: DartWorker callback received wrong input format** (`method_channel.dart`, `native_work_manager.dart`)
  - `_executeDartCallback` in `method_channel.dart` was wrapping the raw JSON string as `{'raw': inputJson}` instead of parsing it. Callbacks received `{'raw': '{"key":"value"}'}` instead of `{'key': 'value'}`. Fixed by JSON-decoding the input before passing to the callback executor. The paired `{'raw': ...}` unwrap in `native_work_manager.dart` was also removed since it is no longer needed.

- **Android: `HttpDownloadWorker` force-unwrap NPE** (`HttpDownloadWorker.kt`)
  - `response.body!!` on line 218 could throw `NullPointerException` if OkHttp returned a null body. Added an explicit null check; returns `WorkerResult.Failure("No response body")` instead of crashing.

### Improved

- **Integration tests:** 37/37 passing on both Android (Pixel 6 Pro, Android 16) and iOS (iPhone 6s Plus, iOS 15.8.6). All DartWorker tests now pass on iOS.
- **Regression tests:** `test/unit/audit_bug_fixes_test.dart` — 33 new unit tests covering M5, L6, H1, C1 and round-trip serialisation.
- **Version alignment:** `pubspec.yaml`, `native_workmanager.podspec`, and `android/build.gradle` all corrected to `1.0.8` (were accidentally set to `2.3.6` / `1.0.0`).
- **README accuracy:** All code examples verified against actual Dart API. Fixed: `method: 'POST'` → `HttpMethod.post`, `files:[...]` → `filePath:` + `additionalFields:`, `cryptoEncrypt(filePath:)` → `inputPath:/outputPath:`, `TaskTrigger.oneTime(delay:)` → positional syntax, `NativeWorker.fileSystem()` → `NativeWorker.fileMove()`, `.enqueue(chainName:)` → `.named().enqueue()`, progress fields, triggers list.

---

## [1.0.7] - 2026-03-04

### Fixed

- **iOS: Custom workers silently failed — input data never reached `doWork()`** (`NativeWorkmanagerPlugin.swift`, `BGTaskSchedulerManager.swift`)
  - **Root cause:** `CustomNativeWorker.toMap()` encodes user input under the `"input"` key as a pre-serialised JSON string. `executeWorkerSync()` (the real iOS execution path for all foreground tasks) was passing the full `workerConfig` to `doWork()`, so workers received outer wrapper fields (`workerType`, `className`, `input`) instead of their own parameters (`inputPath`, `quality`, …). All custom-worker invocations silently returned failure since the initial implementation.
  - **Fix:** Extract `workerConfig["input"] as? String` when present and pass that directly to `doWork()`; fall back to full config for built-in workers (which have no `"input"` key). Applied consistently to both the foreground path (`executeWorkerSync`) and the background path (`BGTaskSchedulerManager.executeWorker`).

### Improved

- **`doc/use-cases/07-custom-native-workers.md`** — Corrected return types throughout (`Boolean`/`Bool` → `WorkerResult`), updated Android registration hook to `configureFlutterEngine`, updated iOS AppDelegate to `@main` + `import native_workmanager`, fixed broken file reference, aligned all code examples with the actual public API.
- **`README.md`** — Added "Custom Kotlin/Swift workers (no fork)" row to feature comparison table; added full custom-worker showcase section with Kotlin, Swift, and Dart examples.
- **Demo app** — Custom Workers tab now exercises real `NativeWorker.custom()` calls against `ImageCompressWorker` instead of placeholder `DartWorker` stubs.
- **Integration tests** — Added Group 10 "Custom Native Workers" (3 tests: success path, graceful failure on missing input, unknown-class error event). Total passing tests: 32.
- **`SimpleAndroidWorkerFactory`** — Unknown worker class now logs a clear `Log.e` message pointing to `setUserFactory()` instead of silently returning `null`.

---

## [1.0.6] - 2026-02-28

### Fixed

- **Android: Thread safety — `taskTags`, `taskStatuses`, `taskStartTimes` replaced with `ConcurrentHashMap`** (`NativeWorkmanagerPlugin.kt`)
  - **Root cause:** All three maps used `mutableMapOf()` (`LinkedHashMap` under the hood), which is not thread-safe. Multiple coroutines launched from the plugin's `CoroutineScope` could read and write concurrently, causing silent data corruption or `ConcurrentModificationException` under load
  - **Fix:** Replaced with `java.util.concurrent.ConcurrentHashMap` which provides lock-free reads and segment-level locking for writes

- **iOS: Memory safety — `onTaskComplete` closure captures `instance` weakly** (`NativeWorkmanagerPlugin.swift`)
  - **Root cause:** `BGTaskSchedulerManager.shared.onTaskComplete` held a strong reference to the plugin instance via an implicit capture; the adjacent `progressDelegate` closure already used `[weak instance]` correctly but this one did not
  - **Fix:** Added `[weak instance]` capture and optional-chained the call site (`instance?.emitTaskEvent(...)`)

### Changed

- **pub.dev: Added `topics`** — `background`, `workmanager`, `networking`, `files`, `cryptography` for better discoverability
- **SDK constraint tightened** — `sdk: '>=3.6.0 <4.0.0'` and `flutter: '>=3.27.0'` (was `>=3.10.0` / `>=3.3.0`; stricter constraint matches actual minimum required APIs and fixes pub.dev static analysis)
- **`analysis_options.yaml` — added lint rules**: `cancel_subscriptions`, `close_sinks`, `avoid_returning_null_for_future`, `avoid_void_async`, `unawaited_futures`, `always_declare_return_types`, `avoid_relative_lib_imports`; added `missing_required_param: error` and `missing_return: error` analyzer settings

---

## [1.0.5] - 2026-02-22

### Added

- **Swift Package Manager (SPM) support for iOS** — the plugin now works with both SPM and CocoaPods
  - Added `ios/native_workmanager/Package.swift` with `binaryTarget` for the bundled KMPWorkManager XCFramework and `ZIPFoundation` dependency
  - Moved Swift sources from `ios/Classes/` to `ios/native_workmanager/Sources/native_workmanager/` (Flutter SPM layout)
  - Updated `ios/native_workmanager.podspec` to reference new source paths (CocoaPods build unchanged)
  - Resolves the partial pub.dev platform score for Swift Package Manager support

### Fixed (Critical — Android periodic tasks)

- **Android: Trigger type was hardcoded to `OneTime` — periodic/exact/windowed triggers were silently ignored** (`NativeWorkmanagerPlugin.kt`)
  - **Root cause:** `handleEnqueue` always passed `TaskTrigger.OneTime(initialDelayMs = 0)` to the kmpworkmanager scheduler, regardless of what the Dart side sent
  - **Impact:** Every task was treated as a one-shot task. Periodic tasks only ran once; exact and windowed triggers were completely ineffective
  - **Fix:** Added full trigger parsing from `call.argument<Map<String, Any?>>("trigger")`, switching on the `"type"` key and creating the correct `TaskTrigger` subtype (`Periodic`, `Exact`, `Windowed`, `ContentUri`, battery, idle, storage)
  - **Reported by:** Abdullah Al-Hasnat (confirmed in production)

- **Android: `ExistingTaskPolicy` was hardcoded to `KEEP` — users could not replace existing tasks** (`NativeWorkmanagerPlugin.kt`)
  - **Root cause:** `handleEnqueue` always passed `ExistingPolicy.KEEP`, ignoring the `existingPolicy` argument sent from Dart
  - **Impact:** `ExistingTaskPolicy.replace` was silently treated as `KEEP`; calling `enqueue()` a second time with the same task ID had no effect even when `replace` was specified
  - **Fix:** Parse `existingPolicy` from `call.argument<String>("existingPolicy")` and map `"replace"` → `ExistingPolicy.REPLACE`, anything else → `ExistingPolicy.KEEP`

- **Android: Constraints were hardcoded to defaults — network, charging, backoff, system constraints were never applied** (`NativeWorkmanagerPlugin.kt`)
  - **Root cause:** `handleEnqueue` and `toTaskRequest` always used `Constraints()` (all defaults), ignoring the map sent by Dart
  - **Impact:** `requiresNetwork`, `requiresCharging`, `backoffPolicy`, `backoffDelayMs`, `isHeavyTask`, `systemConstraints` were silently ignored
  - **Fix:** Added `parseConstraints(map: Map<String, Any?>?)` helper that reads every field from Dart's `Constraints.toMap()` output

- **Android: Periodic tasks stopped emitting events after the first execution** (`NativeWorkmanagerPlugin.kt`)
  - **Root cause:** `observeWorkCompletion` used `Flow.first {}` which suspends until the FIRST terminal state (SUCCEEDED/FAILED/CANCELLED) and then unsubscribes. Periodic tasks never reach a terminal state between cycles, so subsequent executions produced no events
  - **Fix:** Periodic tasks now use `takeWhile { state != CANCELLED }.collect {}` to observe every execution cycle; one-time tasks keep the original `first {}` behaviour
  - **Related:** `isPeriodic` flag propagated from trigger parsing to `observeWorkCompletion`

- **iOS: `flexMs` key lookup used wrong name `flexIntervalMs`** (`KMPSchedulerBridge.swift`)
  - **Root cause:** `parseTrigger` looked for `map["flexIntervalMs"]` but Dart's `PeriodicTrigger.toMap()` sends the key as `"flexMs"`
  - **Impact:** `flexInterval` was always `nil` on iOS regardless of what Dart passed; WorkManager flex window was completely ignored
  - **Fix:** Changed key from `"flexIntervalMs"` to `"flexMs"` to match Dart

- **iOS: Constraints parsing ignored `qos` and `exactAlarmIOSBehavior` from Dart** (`KMPSchedulerBridge.swift`)
  - **Root cause:** `parseConstraints` only read `requiresNetwork`, `requiresCharging`, and `isHeavyTask`; `qos` and `exactAlarmIOSBehavior` were hardcoded to `.background` and `.showNotification`
  - **Fix:** Added full parsing for `qos` and `exactAlarmIOSBehavior` from the constraint map

- **iOS: Chain resume drops all worker config values** (`NativeWorkmanagerPlugin.swift`)
  - **Root cause:** `resumeChain` used `.mapValues { $0.value as? [String:Any] ?? [:] }.compactMapValues { $0.isEmpty ? nil : $0 }` which cast every `AnyCodable` to a nested dict; non-dict values (strings, ints, URLs) became empty dicts and were filtered out
  - **Impact:** After an app kill/crash, resumed chains ran workers with an empty config
  - **Fix:** Replaced faulty pipeline with `task.workerConfig.mapValues { $0.value }`

- **iOS: Initial task state set to `"running"` instead of `"pending"`** (`NativeWorkmanagerPlugin.swift`)
  - **Root cause:** `handleEnqueue` set `taskStates[taskId] = "running"` when scheduling; the task hasn't started executing yet
  - **Fix:** Changed to `"pending"` — state transitions to `"running"` when the worker actually starts

- **iOS: Custom worker registration always silently skipped** (`example/ios/Runner/AppDelegate.swift`)
  - **Root cause:** `#if canImport(ImageCompressWorker)` is always `false` — `canImport()` checks module names, not class names
  - **Fix:** Removed `#if canImport` guard; registration now unconditional

- **iOS: `IosWorker` protocol and `IosWorkerFactory` were `internal`** (`ios/Classes/workers/IosWorker.swift`)
  - **Root cause:** Both lacked `public` modifier, making them inaccessible outside the `native_workmanager` module; host apps could not conform to `IosWorker` or call `IosWorkerFactory.registerWorker`
  - **Fix:** Added `public` to both declarations

- **iOS example: `WorkerError` undefined; `WorkerResult.success(data:)` wrong type** (`example/ios/Runner/ImageCompressWorker.swift`)
  - **Fix:** Defined local `ImageCompressError` enum; changed `success(data: "string")` → `success(message: "...", data: [String: Any])`

- **iOS example: Type conflict between `Runner.IosWorker` and `native_workmanager.IosWorker`** (`example/ios/Runner/IosWorker.swift`, `WorkerResult.swift`)
  - **Fix:** Replaced duplicate declarations with `typealias` pointing to the plugin module's types

- **Android: Stale version strings in comments and logs** (`NativeWorkmanagerPlugin.kt`, `KMPBridge.swift`)
  - **Fix:** Updated "v2.3.1" / "v2.3.0" references to v2.3.3

- **Dart docs: `ExistingTaskPolicy` default incorrectly documented as `keep`**
  - **Fix:** Corrected to `replace` (the actual default in `NativeWorkManager.enqueue`)

- **Example app: Stale version strings** — updated to v1.0.5

- **Android: `CancellationException` silently swallowed in Flow-collection coroutines** (`NativeWorkmanagerPlugin.kt`)
  - **Root cause:** Three `catch (e: Exception)` blocks in `listenForProgress`, `listenForEvents`, and `observeWorkCompletion` caught `kotlinx.coroutines.CancellationException` (a subtype of `Exception`), preventing structured concurrency from propagating coroutine cancellation
  - **Impact:** Coroutines leaked when the Flutter plugin was detached (e.g., hot reload, app restart); could cause event-sink callbacks after disposal
  - **Fix:** Added `catch (e: kotlinx.coroutines.CancellationException) { throw e }` before the generic `catch (e: Exception)` block in all three locations

- **Android: HttpDownloadWorker deletes temp file on network error, breaking resume** (`HttpDownloadWorker.kt`)
  - **Root cause:** The `catch (e: Exception)` block unconditionally called `tempFile.delete()`, destroying the partial download that resume logic depends on
  - **Impact:** Resume downloads (`enableResume = true`) always restarted from byte 0 on any network error, wasting bandwidth
  - **Fix:** Removed the unconditional temp-file deletion; the file is now preserved so the next retry can use the `Range: bytes=N-` header to resume

- **iOS: `CryptoWorker` loads arbitrarily large files into RAM before size check** (`CryptoWorker.swift`)
  - **Root cause:** `Data(contentsOf: inputURL)` was called before `SecurityValidator.validateFileSize()`, so large files caused an OOM crash rather than a clean error
  - **Fix:** Moved `validateFileSize()` guard to run before reading the file; added random salt generation (`SecRandomCopyBytes`) replacing the hardcoded string salt, improving encryption security

- **Android: `ImageProcessWorker` uses `min()` without explicit import** (`ImageProcessWorker.kt`)
  - **Root cause:** `min(widthRatio, heightRatio)` without an explicit `import kotlin.math.min` could resolve to `java.lang.Math.min` in some Kotlin compiler configurations, producing a compile warning or error
  - **Fix:** Changed to `maxOf(1, min(widthRatio, heightRatio))` using Kotlin's built-in `maxOf`; the `max(1, …)` also prevents `sampleSize = 0` when one image dimension already fits within the requested bounds

### Added
- **Device integration test suite** (`example/integration_test/device_integration_test.dart`)
  - Covers all trigger types, ExistingPolicy (REPLACE/KEEP), all 11 workers, chains, tags, cancellation, events and progress streams
  - **GROUP 9 — DartWorker constraint & delay enforcement** — reproduces and verifies the fix for issue #1: `requiresNetwork` and `initialDelay` are now correctly applied to the WorkManager `WorkRequest` for all task types
  - Run with: `flutter test integration_test/device_integration_test.dart --timeout=none`

---

## [1.0.4] - 2026-02-18

### Fixed
- **Android: Worker crash "IllegalStateException: Not implemented"** (Complete fix)
  - **Root cause:** WorkManager 2.10.0+ calls `getForegroundInfoAsync()` in execution path for expedited tasks. Upstream `kmpworkmanager` did not override `getForegroundInfo()`, causing crash
  - **Solution:** Upgraded to `kmpworkmanager:2.3.3` which adds proper `getForegroundInfo()` override
  - **Impact:** All Android users can now safely use WorkManager 2.10.0+
  - **Files changed:** `android/build.gradle`
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
  - **Reported by:** Community user feedback

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
**KMP Parity:** 100%  (kmpworkmanager v2.3.3)
**Platforms:** Android  | iOS 
