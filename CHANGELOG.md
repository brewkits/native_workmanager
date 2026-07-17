# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.4.3] - 2026-07-17

### Fixed

- **iOS SwiftPM: manifest rejected by stricter SwiftPM toolchains.**
  `Package.swift` declared a test target with `path: "../Tests"`, which escapes
  the package root. Newer SwiftPM (Xcode 26.x) tolerates the escape, but stricter
  toolchains reject the **entire manifest** at load time with *"target
  'NativeWorkManagerTests' in package 'native_workmanager' is outside the package
  root"* — which breaks dependency resolution for every SPM-enabled consumer app
  on those toolchains, the same failure mode as #49/#52. The test target is
  removed from the consumer-facing manifest (nothing ever executed it — no
  workflow or script invokes `swift test` — so no coverage is lost; the Swift
  test sources remain in the repo). Root cause confirmed by a controlled
  experiment: the CI job that reproduced the failure on the stricter toolchain
  goes green with the target removed.

  This closes the last known gap in the SwiftPM install path. All four layers
  are now verified automatically on every PR: remote binary target resolution,
  hyphenated product-name resolution, a full `flutter build` of a consuming app
  with SwiftPM enabled, and compile under SPM's strict module isolation.

---

## [1.4.2] - 2026-07-17

### Fixed

- **iOS SwiftPM resolution failed one layer above the 1.4.1 fix — Issue #52.**
  Flutter's generated `FlutterGeneratedPluginSwiftPackage` references every
  plugin by the **hyphenated** library product name
  (`plugin.name.replaceAll('_', '-')` in `flutter_tools` — SwiftPM uses the
  product name as `CFBundleIdentifier` when linking dynamically, and bundle
  identifiers cannot contain underscores). `Package.swift` exported the product
  as `native_workmanager`, so SPM-enabled apps failed dependency resolution with
  *"product 'native-workmanager' … not found in package 'native_workmanager'"*.
  The library product is now `native-workmanager`; the package and target names
  keep their underscores. Thanks @zaqwery for the precise diagnosis — again.

- **iOS: two workers did not compile under SwiftPM.** `CryptoWorker` and
  `FileSystemWorker` use `UIApplication` (background-task API) without an
  explicit `import UIKit`; CocoaPods builds compiled anyway via transitive
  module re-export, SwiftPM builds do not. Surfaced by the new end-to-end
  verification below; explicit imports added.

### Changed

- **Release verification now includes a real SwiftPM app build.** Both #49 and
  #52 escaped because the plugin package was only ever built in isolation or
  consumed via CocoaPods. The SPM check now builds a scratch Flutter app with
  `--enable-swift-package-manager` depending on the plugin, which exercises
  Flutter's generated manifest (hyphenated product reference, platform minimums,
  full plugin compile under SPM).

---

## [1.4.1] - 2026-07-16

### Fixed

- **iOS Swift Package Manager builds failed for pub.dev consumers — Issue #49.**
  `Package.swift` declared `KMPWorkManager` as a **local** `.binaryTarget`
  (`path: "../Frameworks/KMPWorkManager.xcframework"`), but that xcframework is
  stripped from the published package by `.pubignore` and only re-created by the
  CocoaPods `prepare_command` at install time. SwiftPM has no equivalent install
  hook, so with Flutter's SwiftPM integration enabled the local binary target
  resolved to nothing and `xcodebuild` aborted with *"local binary target
  'KMPWorkManager' … does not contain a binary artifact"* — and because Flutter
  routes a plugin through SwiftPM whenever a `Package.swift` exists (excluding it
  from CocoaPods), there was no fallback. Replaced the local target with a
  **remote, checksummed** `.binaryTarget` pointing at the same GitHub-release zip
  the podspec already downloads, so SwiftPM fetches the identical versioned
  artifact CocoaPods does. Verified end-to-end: SwiftPM downloads the asset,
  validates the checksum, and builds. Thanks @zaqwery for the precise root-cause
  report.

- **`CancellationException` swallowed by generic exception handling in 11 Android
  workers.** A worker cancelled mid-run (user calls `cancel()`/`cancelAll()`, or
  WorkManager stops the worker because constraints are no longer met) could have
  its `CancellationException` caught by the worker's own `catch (e: Exception)`
  and converted into a normal `WorkerResult.Failure` — in `HttpDownloadWorker`'s
  case with `shouldRetry: true`, meaning a task the user explicitly cancelled
  could reschedule itself. `ForegroundNativeWorker` was the most exposed case: it
  bypasses `BaseKmpWorker`, so nothing else catches cancellation correctly for
  the FGS-bypass path. Fixed by adding `catch (e: CancellationException) { throw
  e }` before the generic catch in every worker where the wrapped scope contains
  a real suspension point (network I/O awaited via child coroutines, `delay()`,
  `setForeground()`). Affected: `DbCleanupWorker`, `FileCompressionWorker`,
  `FileDecompressionWorker`, `FileSystemWorker`, `ForegroundNativeWorker` (two
  sites), `HttpDownloadWorker`, `HttpRequestWorker`, `HttpSyncWorker`,
  `HttpUploadWorker`, `ImageProcessWorker`, `ParallelHttpDownloadWorker` (two
  sites). Five workers audited and confirmed already safe without changes
  (`CryptoWorker`, `MoveToSharedStorageWorker`, `ParallelHttpUploadWorker`,
  `PdfWorker` rely on `BaseKmpWorker`'s outer `CancellationException` handling
  since they have no local catch around their dispatch; `WebSocketWorker`
  already used `try`/`finally` instead of `try`/`catch` around its
  cancellation-sensitive section).

- **Intermittent "Failed host lookup" on Android 15/16.** Bumped
  `androidx.work:work-runtime-ktx` 2.10.1 → 2.11.2, which fixes an upstream
  AndroidX WorkManager bug where a background `WorkRequest` could start
  running before the device's network/connectivity state was fully attached,
  causing spurious `SocketException: Failed host lookup` failures on HTTP
  calls made from background tasks. Found by auditing `flutter_workmanager`'s
  issue tracker (still pinned to 2.10.2 at the time of writing, with an open
  unresolved report) — see [issuetracker.google.com/issues/445324855](https://issuetracker.google.com/issues/445324855).
  `kmpworkmanager` pulls in `work-runtime-ktx` 2.9.1 transitively; the direct
  `api` declaration here wins Gradle's highest-version resolution (verified:
  `./gradlew :native_workmanager:dependencies` resolves `2.9.1 -> 2.11.2`).

---

## [1.4.0] - 2026-07-16

### Changed

- **Bumped `kmpworkmanager` core to 3.1.0** (was 3.0.1). 3.1.0 enforces
  `Constraints.maxRetries` inside `BaseKmpWorker`: it reads the `maxRetries`
  key off the WorkRequest input data and caps `Failure(shouldRetry=true)` /
  `Retry` at `N + 1` total runs (WorkManager itself has no max-retry API — a
  raw `Result.retry()` reschedules forever). The bundled iOS
  `KMPWorkManager.xcframework` was rebuilt from 3.1.0.

### Fixed

- **DartWorker `return false` never retried — permanent `Result.failure()`.**
  Android `DartCallbackWorker` and iOS Dart callback paths mapped a `false`
  callback result to `WorkerResult.Failure` / `.failure` without
  `shouldRetry: true`. Because `Failure.shouldRetry` defaults to `false`,
  WorkManager received `Result.failure()` (`reschedule = false`) and
  `Constraints.maxRetries` / `backoffDelayMs` were ignored despite docs
  promising retry-on-false. Native engine/setup exceptions still use
  `shouldRetry = false` so broken engine configuration does not loop forever.

- **Android `Constraints.maxRetries` was silently ignored.** Even once a task
  asked to retry, WorkManager's `Result.retry()` is unbounded, so a callback
  that kept returning `false` looped forever. `maxRetries` is now forwarded
  from the Dart constraints map onto the KMP `Constraints` (so
  `NativeTaskScheduler`-scheduled triggers cap via core) and stamped onto the
  WorkRequest input data for every direct-enqueue path (one-time, chain,
  graph) so `BaseKmpWorker` can enforce the `N + 1` ceiling. Periodic work is
  intentionally excluded — its `runAttemptCount` only resets on success, so a
  per-run cap would permanently disable retries after the first cap hit.
  `ForegroundNativeWorker` (which maps results itself, bypassing
  `BaseKmpWorker`) enforces the same cap inline. iOS `RetryConfig` now reads
  `maxRetries` via `NSNumber` (MethodChannel integers were silently dropped to
  `0` = no retry) and defaults to `3` to match the Dart contract.

---

## [1.3.3] - 2026-07-14

### Fixed

- **DartWorker progress events dropped (UI stuck at 0%) — Issue #38.**
  Native emitted the progress map without a `timestamp`, so the Dart
  session-filter (`timestamp < _sessionStartTime`, defaulting the missing value
  to `0`) silently discarded every progress event. Android
  `ProgressUpdate.toMap()`/`toJson()` and iOS `ProgressReporter`/`emitProgress`
  now stamp `timestamp`; the Dart filter treats a missing/`0` timestamp as
  "current" for backward compatibility with older native builds. Covered by
  `issue_38_*` in `device_integration_test.dart`.

  Fixing this on iOS surfaced two further iOS-only gaps (caught by the device
  test) that PR #40 alone did not close: (a) `__taskId` was never injected into
  a foreground DartWorker's input, so the callback had no id to report progress
  with — `executeDartWorkerViaMethodChannel` now merges it in, mirroring
  Android's `DartCallbackWorker`; (b) the `dev.brewkits/dart_worker_channel`
  `reportProgress` handler existed only on the `FlutterEngineManager` background
  engine, so foreground callbacks threw `MissingPluginException` — the main
  engine now registers the same handler, routed through `ProgressReporter`.

- **DartWorker TaskStore status stuck on `pending` after success — Issue #39.**
  Only the `TaskEventBus` path persisted terminal status to SQLite, and
  `DartCallbackWorker` never emits on that bus, so completed DartWorkers stayed
  `pending` forever in `allTasks()`. The WorkInfo fallback in
  `observeWorkCompletion` now calls `taskStore.updateStatus(...)` for
  running/completed/failed/cancelled, plus a `syncTaskStoreWithWorkManager()`
  reconciliation on restart to repair rows left stale by process death. Covered
  by `issue_39_*` in `device_integration_test.dart`.

### Security

- **Constant-time HMAC signature comparison in RemoteTrigger.** The remote-trigger
  HMAC verification compared signatures with plain string equality (Android
  `String.equals`, iOS `==`), which short-circuits on the first differing byte and
  can leak — via response timing — how many leading bytes matched (a signature
  verification timing side-channel). Both platforms now compare the raw HMAC bytes
  in constant time (Android `MessageDigest.isEqual`, iOS CryptoKit
  `HMAC.isValidAuthenticationCode`). Behavior-preserving: canonicalization and HMAC
  computation are unchanged, so valid signatures still verify and invalid ones are
  still rejected.

---

## [1.3.2] - 2026-07-07

### Fixed

- **iOS: startup crash on Flutter 3.38+ (UIScene template) — Issue #36.**
  Apps created with the Flutter 3.38+ iOS template register plugins in
  `AppDelegate.didInitializeImplicitFlutterEngine`, which runs *after*
  `application(_:didFinishLaunchingWithOptions:)` returns. Calling
  `BGTaskScheduler.register` at that point violates Apple's
  "all launch handlers must be registered before application finishes launching"
  rule and threw `NSInternalInconsistencyException` at startup
  (reported on iPhone 15 / iOS 18.6.2; affects any device on the new template).
  - BGTask launch handlers are now registered in an ObjC `+load` hook
    (`NWMBGTaskRegistrar`) that runs at binary load time — always inside the
    launch window, on both the old and the new template. Plugin registration
    only attaches the Swift handlers afterwards.
  - All `BGTaskScheduler.register` calls now go through ObjC `@try/@catch`
    (Swift cannot catch `NSException`): late or duplicate registration degrades
    to a `BGTASK_REGISTRATION_FAILED` system error instead of a crash.
  - Fixed a latent duplicate-registration crash: `registerHandlers()` had no
    idempotency guard, so `GeneratedPluginRegistrant` re-running on the headless
    background engine (`FlutterEngineManager`) re-registered the identifiers and
    threw the same `NSInternalInconsistencyException`.
  - BGTasks that fire before the Swift side attaches (cold-start background
    launch) are buffered and delivered once handlers attach.

### Changed

- **kmpworkmanager core upgraded 2.5.1 → 3.0.1** (Android Maven dependency +
  bundled iOS XCFramework rebuilt from source).
  - v3.0.1 fixes a critical crash on Android 8–11 (API 26–30): expedited tasks
    failed with `IllegalStateException: Not implemented` due to a missing
    `getForegroundInfo()` override (regressed in core v2.3.8).
  - v3.0.0 extracted Ktor HTTP workers into the optional `kmpworkmanager-http`
    artifact — not needed by this plugin (it ships its own native workers);
    no API changes affect the plugin bridge.

### Added

- iOS: `NativeWorkmanagerPlugin.registerBGTaskHandlers()` — optional explicit
  registration from `didFinishLaunchingWithOptions` (idempotent, exception-safe).
  Only needed if a build setup strips ObjC `+load` sections.
- Example app migrated to the Flutter 3.38+ UIScene template
  (`FlutterImplicitEngineDelegate` + `SceneDelegate`) so the device test suite
  runs on the lifecycle that triggered the crash; new `issue_36` device
  regression test asserts handlers are registered in `+load`, exactly once.

---

## [1.3.1] - 2026-06-07

### Fixed
- **Android (critical regression, since v1.2.4)**: All file-based native workers
  (`HttpDownload`, `HttpUpload`, `ParallelHttpDownload/Upload`, `FileCompression`,
  `FileDecompression`, `ImageProcess`, `Crypto` hash/encrypt/decrypt, `Pdf`,
  `WebSocket`, `FileSystem`, `MoveToSharedStorage`) failed on real devices with
  "Invalid or unsafe file path". v1.2.4 added a blanket `"/data"` entry to
  `SecurityValidator`'s blocked-prefix list, which rejected the app's own private
  sandbox (`/data/data/<pkg>`, `/data/user/<n>/<pkg>` — exactly what `path_provider`
  returns). The validator now blocks only the genuinely OS-owned sub-directories of
  `/data` (`/data/local`, `/data/system`, `/data/misc`, `/data/app`, …) while
  allowing the app sandbox. Path-traversal protection (canonical-path resolution)
  and blocking of `/proc`, `/sys`, `/etc`, `/system`, `/vendor`, `/dev`, `/root`
  are unchanged. Added `SecurityValidatorFilePathTest` (Kotlin) plus device
  coverage in the "All Workers" integration group.
- **iOS**: Fixed an issue where the `KMPWorkManager.xcframework` was extracted into a double-nested path (`Frameworks/Frameworks/KMPWorkManager.xcframework`) during `pod install`, causing iOS builds to fail with "Unable to find module dependency: 'KMPWorkManager'". The `prepare_command` in `native_workmanager.podspec` is now layout-agnostic (Resolves #33).

## [1.3.0] - 2026-06-04

### Added
- **Android Auto-Init** (`NativeWorkManagerInitializer`): Plugin now ships an `androidx.startup`
  `Initializer` declared in its own `AndroidManifest.xml`. It runs automatically before
  `Application.onCreate()`, restoring the `callbackHandle` from SharedPreferences and
  initializing `KmpWorkManager` with `SimpleAndroidWorkerFactory`.
  - **Breaking zero-config change:** `DartWorker` killed-app support now requires **no custom
    `Application` class and no manual `AndroidManifest.xml` edits** for the common case.
  - **Opt-out** for apps with custom WorkManager configuration: add
    `<meta-data android:name="native_workmanager.auto_init" android:value="false" />` to
    `<application>` in your `AndroidManifest.xml`, then follow `doc/ANDROID_SETUP.md`.
  - `isSchedulerInitialized` flag prevents double-initialization when `onAttachedToEngine`
    runs after the Initializer.

- **Unified setup CLI** (`dart run native_workmanager:setup`): Evolves `setup_ios` into a
  universal command covering both platforms.
  - `--android`: validates the app manifest has no conflicts with auto-init.
  - `--ios`: patches `Info.plist` with `UIBackgroundModes` and
    `BGTaskSchedulerPermittedIdentifiers` (same as the legacy `setup_ios` command).
  - `--check`: read-only validation mode — no files are written.
  - `--help`: full usage reference.
  - `setup_ios` executable retained for backward compatibility.

- **iOS `WorkerResult.retry()`**: Added `retry(reason:delayMs:attemptCap:)` factory on
  the Swift `WorkerResult` struct, providing parity with `WorkerResult.Retry` introduced
  in kmpworkmanager v2.5.0.

### Changed
- **Core**: Upgraded KMP WorkManager core dependency from v2.4.3 to v2.5.1.
  - Android: added `WorkerResult.Retry` branch in `ForegroundNativeWorker` to satisfy
    sealed-class exhaustiveness (maps to `Result.retry()`).
  - iOS `KMPWorkManager.xcframework` rebuilt from v2.5.1 source.

- **iOS retry semantics** (`executeWorkerSync`): the retry loop now respects
  `WorkerResult.shouldRetry`. A worker returning `failure(shouldRetry: false)` stops
  retrying immediately instead of exhausting all `maxRetries` attempts.

- **iOS `maxRetries` honored** on the direct-task execution path: `RetryConfig.from(constraintsMap:)`
  is now called and passed to `executeWorkerSync`. Previously `Constraints.maxRetries` was
  silently ignored on iOS (dead code).

- **iOS direct-task `qos`** now read from `constraintsMap["qos"]` instead of being
  hardcoded to `"background"`.

### Fixed
- **Android `DartCallbackWorker`**: `CancellationException` is now rethrown before the
  outer `catch (Exception)` block. `executeDartCallback` is a suspending function; without
  this fix, WorkManager task cancellation was silently converted to a `Failure` result.

- **iOS WebSocket**: `NativeWorker.webSocket()` now throws `UnsupportedError` at call-site
  when run on iOS. Previously the task was enqueued and silently failed with
  "Unknown worker class" because `IosWorkerFactory` has no `WebSocketWorker` case.

- **Android `handleResume`**: constraint JSON parse failure now logs a `NativeLogger.w`
  warning instead of silently falling back to empty constraints (which could cause resumed
  downloads to ignore `requiresNetwork` / `requiresCharging`).

- **Dart `resolveDispatcherTimeout`**: values ≤ 0 (zero, negative, NaN, ±Infinity) now
  fall back to the 25 s default. A `Duration(milliseconds: -n).timeout()` fires immediately,
  which would kill every DartWorker. Added four regression tests.

- **Android `HttpDownloadWorker` — data corruption** (directory mode): concurrent downloads
  to the same directory now each use their own temp file (`__pending_<taskId>__.tmp`)
  instead of sharing the hardcoded `__pending__.tmp`. Two workers writing to the same
  temp path produced a mixed-byte file; the first to finish would rename corrupted data.

- **Android `HttpDownloadWorker` — TOCTOU rename** (`onDuplicate: "rename"`): replaced
  `findNextAvailableFile() + Files.move(REPLACE_EXISTING)` with an atomic probe loop using
  `ATOMIC_MOVE` only (no `REPLACE_EXISTING`). A `FileAlreadyExistsException` now signals
  the next candidate rather than silently overwriting a file from a concurrent download.

- **Android constraint conflict warning**: enqueueing with `allowWhileIdle: true` and
  `isHeavyTask: true` simultaneously now logs a `NativeLogger.w` at enqueue time. The
  long-running worker already bypasses Doze mode, making `allowWhileIdle` redundant and
  potentially causing WorkManager rejection on some Android versions.

## [1.2.8] - 2026-06-04

### Changed
- **Core**: Upgraded KMP WorkManager core dependency from v2.4.3 to v2.5.1.
  - Android: added `WorkerResult.Retry` branch in `ForegroundNativeWorker` to satisfy sealed-class exhaustiveness (maps to `Result.retry()`).
  - iOS: added `WorkerResult.retry(reason:delayMs:attemptCap:)` factory method for parity with the new KMP sealed variant; existing `failure(shouldRetry: true)` callers unchanged.
  - iOS `KMPWorkManager.xcframework` rebuilt from v2.5.1 source.

## [1.2.7] - 2026-05-11

### Fixed
- **Core**: Enforced `DartWorker.timeoutMs` end-to-end (Issue #30).
  - Android and iOS bridges now correctly forward `timeoutMs` to the Dart callback dispatcher.
  - Added `resolveDispatcherTimeout` helper in Dart to securely parse the timeout, protecting against `NaN`, `Infinity`, and invalid types.
  - Enforced `timeoutMs` in both the background dispatcher and the foreground `MethodChannel` (`_executeDartCallback`).
  - Added comprehensive unit, integration, performance, and security test coverage.

## [1.2.6] - 2026-05-08

### Added
- **Android**: **Industrial-grade Foreground Service (FGS) Support**. Added `ForegroundNotificationConfig` to `Constraints`, allowing tasks to run as prioritized Foreground Services to bypass Android 12+ background restrictions.
- **Android**: Full compliance with Android 14 (API 34) Foreground Service Types. Automatically maps task types (dataSync, location, media, etc.) to system-level flags.
- **Android**: Proactive task promotion using `setForeground()` to ensure immediate execution even when the app is in the background.
- **Android**: FGS state persistence: configuration is automatically restored after device reboots or task resumes.
- **Core**: Added comprehensive unit tests and a new Demo page in the example app for FGS bypass.

### Fixed
- **Android**: Fixed regression where background tasks would not fire when the device screen was locked (Doze mode) even after the app was killed. Resolved by correctly mapping `allowWhileIdle` to WorkManager's expedited mode ([#28](https://github.com/brewkits/native_workmanager/issues/28)).
- **iOS**: Fixed Swift Concurrency deadlocks by migrating SQLite queues (DispatchQueue) from concurrent to serial.
- **iOS**: Improved scheduling reliability by adjusting internal `TaskTrigger` execution delays on iOS to ensure `BGTaskScheduler` correctly enqueues tasks.
- **Test**: Added platform-aware timeouts for iOS integration tests and automatically excluded timeout-prone integration tests (`TaskGraph` and `OfflineQueue`) when running on the iOS Simulator.

## [1.2.5] - 2026-05-06

### Fixed
- **Core**: Removed over-restrictive assertion in `TaskTrigger.periodic` that prevented using `initialDelay` and `runImmediately: false` together ([#26](https://github.com/brewkits/native_workmanager/issues/26)).
- **iOS**: Fixed bug where `runImmediately` flag was incorrectly recomputed from `initialDelay` instead of using the user-provided value.

## [1.2.4] - 2026-04-29

### Fixed
- **Android**: Added automatic ProGuard rules to prevent task classes from being stripped in Release builds ([#24](https://github.com/brewkits/native_workmanager/issues/24)).
- **Android**: Clarified that `Application` class setup is required for all tasks to survive app kill.
- **iOS**: Synchronized background task identifiers between `setup_ios.dart` and Swift code.
- **iOS**: `getTaskStatus()` now correctly returns `TaskStatus.completed` for finished tasks. Previously, the iOS plugin wrote `"success"` to SQLite but Dart's `TaskStatus` enum has no `success` case, so every call returned `null`.
- **Android**: Removed duplicate `taskStore.updateStatus()` call on task completion. The redundant second write used `JSONObject(map).toString()` which could corrupt nested result maps, overwriting the correctly-encoded first write.
- **iOS**: `FlutterEngineManager` now disposes the engine after a Dart callback timeout. Previously the engine remained `isInitialized = true` with a hung `MethodChannel`, causing all subsequent `DartCallbackWorker` tasks to silently fail (timeout again).

### Changed
- **Engine**: Upgraded core `kmpworkmanager` to v2.4.3 (re-publish of v2.4.2 to fix Maven Central artifact issue; no code changes).

## [1.2.3] - 2026-04-24

### Added
- **Feature: Support `initialDelay` and `runImmediately` for periodic tasks** ([#21](https://github.com/brewkits/native_workmanager/issues/21))
  - Allows delaying the first execution of a periodic task.
  - Added `runImmediately` flag to skip the first execution.
  - On Android, uses native `PeriodicWorkRequest.setInitialDelay()`.
  - On iOS, maps `initialDelay` to `earliestBeginDate` for optimized scheduling.
  - Added parameters to `TaskTrigger.periodic()`.
- **Security: Advanced Input Validation**
  - All native workers now perform strict validation to block **Null Byte Injection**, **Path Traversal** (`..`, `%2e%2e`), and **Shell Injection** characters in URLs and file paths.
- **Enterprise-Grade Testing**:
  - Implemented comprehensive `scripts/run_all_tests.sh` covering Unit, Integration, Security, Performance, and Stress tests.
  - Added specific performance benchmarks for task scheduling overhead.
  - Added malicious payload protection tests.
- **Improved CI/CD**: Integrated automated Security, Performance, and Stress testing into the GitHub Actions pipeline.

### Fixed
- **Android: Upgraded to `kmpworkmanager 2.4.1`**
  - Switched to native `setInitialDelay` instead of manual bypass logic.
  - Fixed edge-case crashes on Android 15.
- **iOS: Improved Periodic Task Lifecycle**
  - Fixed regression where periodic tasks were not tracked in `activeTasks`, preventing cancellation.
- **Android: Fixed broken `expedited` flag logic** in direct enqueue path.

---

## [1.2.2] - 2026-04-22

### Added
- **`registerPlugins` parameter** in `NativeWorkManager.initialize()`: opt-in flag to register all Flutter plugins in the background engine, required when using plugins like `flutter_local_notifications` inside `DartWorker` callbacks. Defaults to `false` to preserve the Zero-Engine I/O principle and avoid side-effects (e.g. Bluetooth disconnects). Also added `NativeWorkmanagerPlugin.setPluginRegistrantCallback` on Android and iOS to allow selective plugin registration when `registerPlugins` is false. ([#18](https://github.com/brewkits/native_workmanager/issues/18))

### Fixed
- **iOS: `openFile` always fails on Flutter 3.38+ / scene-based apps** — `UIApplication.shared.keyWindow` returns `nil` in `UIWindowScene` lifecycle. Replaced with a new `activeRootViewController` extension that traverses `connectedScenes` to find the active key window. ([#16](https://github.com/brewkits/native_workmanager/issues/16))
- **Android: `StackOverflowError` when middleware is registered** — Kotlin companion extension `applyMiddleware` was shadowing the internal package-level function of the same name, causing infinite recursion. Renamed the internal function to `applyMiddlewareInternal` to eliminate the ambiguity. ([#17](https://github.com/brewkits/native_workmanager/issues/17))
- **`native_workmanager_gen` incompatible with Flutter 3.41.x** — `analyzer >=11.0.0` requires `meta ^1.18.0` which conflicts with the Flutter SDK's `meta 1.17.0` pin. Widened constraint to `>=10.0.0 <13.0.0`; `analyzer 10.x` supports all APIs used by the generator and requires only `meta ^1.15.0`. ([#15](https://github.com/brewkits/native_workmanager/issues/15))

---

## [1.2.1] - 2026-04-19

### Added
- **Security Hardening**: All HTTP workers now support **HTTPS Enforcement** and **Private IP Blocking (SSRF Protection)** via `NativeWorkManager.initialize(enforceHttps: true, blockPrivateIPs: true)`.
- **Path Traversal Protection**: Enhanced file path validation to block null-byte injection and encoded dot-segments (`%2e%2e`) across all native workers.
- **`WorkManagerLogger` interface**: A type-safe delegate for forwarding background task events to third-party SDKs like Firebase or Sentry without dynamic reflection.
- **New Test Suite**: Added 100+ new test cases covering input sanitization, security policy enforcement, performance benchmarks for large directory operations, and multi-stage task chains.

### Fixed
- **Android: Dart Isolate Timeouts**: Implemented hard timeout handling for background Dart execution. If an isolate hangs, the engine is now force-disposed to prevent 50MB+ RAM leaks.
- **Android: Task Store Performance**: Added batch deletion for task history cleanup to prevent long SQLite write-locks on high-traffic apps.
- **Migration Tool**: Moved the `migrate.dart` script to the `bin/` directory and added it to the `executables` section in `pubspec.yaml` to resolve the `Could not find bin/migrate.dart` error when running `dart run native_workmanager:migrate` (#14). Also changed `developer.log` to `print` so the CLI output displays correctly.
- **Test Infrastructure**: Fixed a bug in `TaskEventTracker` where it incorrectly resolved on \"task started\" events instead of terminal completion events, leading to flakey stress tests.

---

## [1.2.0] - 2026-04-17

### Added
- **Android cold-start `DartWorker` persistence**: `DartWorker` tasks now execute reliably after app kill. The `callbackHandle` is persisted to `SharedPreferences` (Android) and `UserDefaults` (iOS) during `initialize()` and automatically restored when WorkManager restarts the process. Requires host app to implement `Configuration.Provider` — see `doc/ANDROID_SETUP.md`.
- **Advanced Remote Trigger**: Support for direct commands in push payloads (`native_wm` key). Execute tasks, chains (`enqueue_chain`), graphs, and offline queues without waking Flutter. Both Android and iOS support executing task chains completely in the background.
- **HMAC Security**: Robust HMAC SHA-256 signature verification for remote triggers (supporting nested objects) to prevent unauthorized task execution.
- **Real-time Observability**: DevTools extension now supports real-time event streaming via `developer.postEvent`.
- **Global Middleware API**: Global interceptors for task configuration (Headers, RemoteConfig, Logging).
- **Code Generation Enhancements**: `native_workmanager_gen` now generates type-safe enqueue wrappers and automatic worker registries from `@WorkerCallback` annotations.
- **Task Graphs (DAG)**: Support for complex non-linear task dependencies on Android.
