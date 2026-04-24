# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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

### 🙏 **Acknowledgments**

Built on [kmpworkmanager v2.4.1](https://github.com/pablichjenkov/kmpworkmanager) for Kotlin Multiplatform.

---

## Links

- [GitHub Repository](https://github.com/brewkits/native_workmanager)
- [Issue Tracker](https://github.com/brewkits/native_workmanager/issues)
- [Documentation](https://github.com/brewkits/native_workmanager#readme)
- [KMP WorkManager](https://github.com/pablichjenkov/kmpworkmanager)
- [Migration Guide](doc/MIGRATION_GUIDE.md)

---

**Latest Version:** 1.2.3
**Status:**  Production Ready - Stable release for all production apps
**KMP Parity:** 100%  (kmpworkmanager v2.4.1)
**Platforms:** Android  | iOS 
