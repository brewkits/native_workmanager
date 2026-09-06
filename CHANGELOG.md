# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-09-06

### Changed

- **kmpworkmanager core upgraded 3.3.1 → 3.4.1** (spans two upstream releases). No Dart API
  change — this release is the engine bump plus the one bridge fix it forced. The parts that
  reach plugin users without any code change on their side:

  - **Android: `TaskTrigger.exact` actually runs its worker now.** The default `AlarmReceiver`
    registered by `KmpWorkManager.initialize()` — the one this plugin uses — logged the fired
    alarm and finished the broadcast without ever resolving or invoking the scheduled worker.
    Every exact-alarm task fired on time and did nothing. Fixed upstream in 3.4.0.
  - **Android: exact-alarm tasks survive a process kill mid-execution.** Alarm metadata was
    removed from `AlarmStore` *before* the work ran; a kill in that window lost the task with
    no trace and no reboot recovery. Removal now happens after a definitive outcome.
  - **Android: expedited work is now gated on task priority.** Previously every eligible task
    (no delay, not heavy, no charging/unmetered requirement) was requested as expedited work
    regardless of priority. Standalone `enqueue()` has no priority parameter, so plugin tasks
    are `NORMAL` and are **no longer blanket-expedited** — expect slightly later scheduling for
    them under WorkManager quota pressure. Chain steps marked `CRITICAL`/`HIGH` are unaffected.
  - **Android: `KmpHeavyWorker` retries instead of discarding on a transient foreground-service
    denial.** A `SecurityException`/`IllegalStateException` from OS background-start policy
    (battery saver, OEM restriction) returned a permanent failure and dropped the task.
  - **Android: file leaks closed** — the large-input overflow file for a task rescheduled under
    `ExistingPolicy.replace` is now deleted rather than orphaned until the 24 h janitor sweep,
    and chain-step overflow files are cleaned up when a chain is cancelled before the step runs.
  - **Android: `getExecutionHistory()` records the real failure reason.** `ExecutionRecord.errorMessage`
    was always persisted as `null`, so persisted history lost every diagnostic detail (live
    completion events were unaffected).
  - **iOS: `ExistingPolicy.keep` no longer behaves like `replace`.** For a task id not declared
    in `Info.plist` — the normal case, since ids are usually per-instance — the KEEP check
    queried `BGTaskScheduler` for an identifier that is never submitted under its own name, so
    it always missed. A repeat `enqueue(policy: keep)` therefore discarded the first call's
    metadata and could duplicate the task.
  - **iOS: chain progress can no longer regress.** A failed progress flush unconditionally
    re-buffered its pre-failure snapshot, which could clobber a newer in-memory value; a
    process kill after that made a resumed chain re-run an already-completed step.
  - **iOS: a dynamic task is no longer silently dropped** when a host app's `WorkerFactory`
    throws something other than `IllegalArgumentException` — the case that permanently stopped
    a periodic task's recurring schedule.
  - **iOS: standalone tasks now honour `requiresUnmeteredNetwork`, `requiresCharging` and the
    battery-not-low constraint**, and `Constraints.backoffPolicy`/`backoffDelayMs` affect retry
    timing when explicitly set. Previously only chain steps enforced any of these.
  - **iOS: metadata, chain definitions and chain progress are written atomically**
    (temp file + `replaceItemAtURL`) instead of via `NSString.writeToFile(atomically:)`, and a
    completed background download is moved without the previous delete-then-move window.

  Upstream 3.4.0 carries one breaking change — `AlarmReceiver.onReceive()` no longer removes
  `AlarmStore` metadata before dispatch — that affects only apps subclassing `AlarmReceiver`
  **directly**. This plugin subclasses neither it nor `BaseAlarmReceiver`, so no host-app
  migration is required.

### Fixed

- **An inverted `TaskTrigger.windowed(earliest:, latest:)` window (`latest < earliest`) is
  rejected with a normal Dart-visible error instead of taking the app down on iOS.**
  kmpworkmanager 3.4.1 added construction-time validation to `TaskTrigger.Windowed`; a Kotlin
  `IllegalArgumentException` thrown from a constructor exported to Swift cannot be caught and
  terminates the process. `KMPSchedulerBridge` now rejects the inverted window before
  constructing the trigger, which flows into the existing "Invalid trigger configuration" error
  path. Android already parsed the trigger inside a guarded block and surfaces `ENQUEUE_ERROR`.
  No Dart-side `assert` was added — the Dart API still accepts the combination and lets the
  platform answer. Covered by `kmp_341: inverted windowed trigger errors instead of crashing`
  in `device_integration_test.dart`, which fails (by killing the app) if the guard is removed.

### Notes

- `BackgroundTaskScheduler.enqueue()` gained defaulted `tags` and `deadlineMs` parameters
  upstream. Kotlin defaults keep Android source-compatible, but they are **not** exported to
  Swift, so the ObjC selector changed and `KMPSchedulerBridge.swift` now passes both explicitly
  at their Kotlin defaults (empty set / `nil`) — behaviour is identical to 3.3.1.
- The new upstream API surface — task tags with `cancelByTag`, per-task deadlines, the chain
  `InputMerger` (`mergeOutputFromPreviousStep`) and `ExistingPolicy.UPDATE` — is **not** exposed
  through the Dart API in this release. Wiring it is tracked separately.

## [1.5.0] - 2026-08-23

### Added

- **`NativeWorkManager.iosLiveActivity` — a `taskId`-scoped progress filter for iOS Live
  Activities.** `iosLiveActivity.onProgress(taskId: ...)` returns just one task's slice of the
  existing progress stream, so a Live Activity / Dynamic Island can subscribe to the task it
  renders without filtering by hand.

  Read the scope carefully: this is a **Dart-side convenience filter over the progress
  EventChannel** that `NativeWorkManager.progress` already exposes. It does **not** call
  ActivityKit, and it does **not** wrap the KMP `IosLiveActivityBridge` in the bundled
  `KMPWorkManager.xcframework`. Starting, updating and ending the `Activity<Attributes>` remains
  your app's job — the `ActivityAttributes` type lives in your target, not in this plugin. On
  non-iOS platforms `onProgress` returns an already-closed stream; use
  `NativeWorkManager.progress` for cross-platform progress.

  If progress never needs to reach Dart, observe the KMP bridge directly from Swift instead —
  `IosLiveActivityBridge.companion.shared.startObserving(taskId:onProgress:)` runs with no Flutter
  engine attached, which suits a killed-app background download better. Both routes are documented
  on `IosLiveActivityBridge`.
- **Public `GraphExecution` constructor.** `GraphExecution(graphId, result)` is now public API;
  `GraphExecution.internal(...)` is deprecated and forwards to it. This is what lets
  `FakeWorkManager` build a graph handle without tripping the analyzer (see *Fixed* below).
- **CLI SwiftUI `@main` detection.** `dart run native_workmanager:setup` (and
  `native_workmanager:setup_ios`) now inspect `ios/Runner` for a SwiftUI `@main` App and report
  whether `@UIApplicationDelegateAdaptor(AppDelegate.self)` is wired — without it the AppDelegate
  lifecycle never runs, so BGTask launch handlers registered in `+load` never attach.

### Fixed

- **Pub.dev static analysis back to 160/160.** `FakeWorkManager` called
  `GraphExecution.internal`, a `@visibleForTesting` member, from `lib/` — an
  `invalid_use_of_visible_for_testing_member` warning that cost analysis points. The constructor
  is public now and the annotation is gone.
- **Analyzer guardrail:** `invalid_use_of_visible_for_testing_member: error` added to
  `analysis_options.yaml` so the same class of violation fails CI instead of quietly costing pub
  points.
- **`setup`'s iOS checks no longer stop at the first Info.plist problem.** The SwiftUI `@main`
  check now runs even when `ios/Runner/Info.plist` is missing or malformed — a non-standard
  plist layout is exactly what a SwiftUI-lifecycle project is likely to have.
- **`OfflineQueue` could lose a queued task or crash when a task was cancelled mid-flight**
  (pre-existing). `_processHead()` captured the head slot, then awaited the task's completion event
  for up to an hour. `cancel()` is synchronous and mutates the pending list directly, so it could
  land inside that window — after which the failure path still wrote back **positionally**
  (`_pending[0] = …` / `removeAt(0)`). If the cancel emptied the queue the retry write threw
  `RangeError (index): Valid value range is empty: 0`; if another entry had become the head, that
  entry was silently overwritten by the cancelled task's retry slot and never ran. Both branches
  now resolve the slot by identity — matching the success path, which already did. A cancelled
  in-flight task is dropped rather than retried or dead-lettered. Covered by
  `test/unit/offline_queue_cancel_race_test.dart`, which reproduces both failures.
- **Flutter engine could leak on Android after a channel error** (pre-existing).
  `FlutterEngineManager.executeDartCallback` incremented `activeTaskCount` before the try whose
  `finally` decremented it, so anything thrown in between — `channel.invokeMethod` hitting a
  detached engine, for instance — leaked the counter permanently. `activeTaskCount.get() <= 0`
  then never held, so the engine was never auto-disposed (~50 MB retained for the process
  lifetime). The count is now released exactly once on every exit path, still before the
  timeout/dispose checks that read it.
- **iOS Dart-callback continuation leaked on timeout** (pre-existing). `invokeCallback` suspended
  on a bare `withCheckedThrowingContinuation` with no cancellation handling. When the enclosing
  task group's timeout won — the hung-isolate case, where the method-channel reply never
  arrives — the continuation was never resumed: Swift logged `SWIFT TASK CONTINUATION MISUSE:
  continuation was leaked` and the child task stayed suspended holding the channel. It now runs
  under `withTaskCancellationHandler` with a single-resume guard, so cancellation settles it.
- **DartWorker cancellation was swallowed on Android** (pre-existing, not a 1.5.0 regression).
  `FlutterEngineManager.executeDartCallback` wrapped `withTimeout { resultDeferred.await() }` in a
  generic `catch (e: Exception)`. `CancellationException` **is-a** `Exception`, so cancelling a
  DartWorker — or cancelling its parent Job — was reported as an ordinary `false` result instead
  of propagating, breaking structured concurrency. It is now rethrown ahead of the generic catch.
  The timeout path is unchanged: `TimeoutCancellationException` is caught at the `withTimeout`
  call site and converted to `timedOut`, so it never reaches the new guard.
- **`OfflineQueue` class doc contradicted the implementation** (pre-existing). The class-level
  docs said `enqueue` throws a `StateError` when the queue is full; it has always dropped the
  entry silently and returned normally (as `enqueue`'s own doc correctly stated). A caller
  following the class doc would have written a `try/catch (StateError)` that never fires. The
  class doc now matches the behaviour and points at `pendingCount`.
- **Swift snippet in `IosLiveActivityBridge` docs did not compile.** It showed
  `IosLiveActivityBridge.shared`, but Kotlin/Native exposes the singleton through the Companion
  object — the generated header declares only a `companion` class property on the bridge. The
  example now uses `IosLiveActivityBridge.companion.shared`.

### Changed

- **The iOS graph-node delay is no longer inline in DAG logic.** `TaskGraph._scheduleNode` hard-coded
  a 1-second `TaskTrigger` delay for iOS to work around BGTaskScheduler dropping back-to-back
  submissions. The workaround stays (removing it needs a per-submission hook in the KMP scheduler —
  tracked in ROADMAP), but it is now a named `_iosNodeSubmissionStagger` constant behind
  `_nodeTrigger()`, documented as a platform quirk rather than domain logic. Downstream scheduling
  also marks its fire-and-forget call explicitly with `unawaited()`.
- **The cancellation-rethrow invariant guard is now checked per function, not per file.**
  `test/unit/cancellation_rethrow_invariant_test.dart` used to regex the whole worker source for
  a single `catch (e: CancellationException) { throw e }`. `HttpUploadWorker.kt` has two suspend
  functions, and the one rethrow in `doWork()` made the file pass while `handleRawBodyUpload()`
  had no guard at all — the test built to catch this bug class could not see it. It now parses
  each `suspend fun` body by brace depth and requires either a rethrow or an explicit exemption
  carrying a written reason. `handleRawBodyUpload()` gained the matching rethrow (uniformity: its
  guarded region is blocking OkHttp with no suspension point, so there was no live bug — but the
  two upload paths must not diverge).
- **⚠️ Android `compileSdk` raised 35 → 36, and consuming apps now need `compileSdk 36` or
  higher.** This is forced by the kmpworkmanager bump, not a choice: 3.3.0 dropped `koin-android`
  and began declaring `androidx.core` directly, which resolves `androidx.core:core-ktx` to
  **1.17.0**, and that artifact's AAR metadata requires everything depending on it to compile
  against API 36+. Verified by a controlled A/B on this repo — with kmpworkmanager 3.2.0
  `:native_workmanager:testDebugUnitTest` exits 0 and no `core-ktx:1.17.0` appears on the
  classpath; with 3.3.1 it exits 1 with *"requires libraries and applications that depend on it to
  compile against version 36 or later"*. Apps already on Flutter's current default `compileSdk`
  are unaffected; apps pinned to 35 must raise it.
- **`extension/devtools`** version bumped 1.3.0 → 1.5.0 to match the monorepo (`publish_to: none`,
  so this affects nothing published).
- **kmpworkmanager core bumped 3.2.0 → 3.3.1** — this spans **two** upstream releases (3.3.0 and
  3.3.1). Both are pulled in by this bump:

  **From 3.3.0 — ⚠️ BREAKING for apps that used Koin transitively:** kmpworkmanager no longer
  depends on Koin, and `kmpWorkerModule()` / `kmpWorkerCoreModule()` are removed upstream. This
  plugin is unaffected — it has always called `KmpWorkManager.initialize()` directly and never
  referenced Koin — but if your app was relying on `koin-core` arriving transitively through this
  plugin's dependency tree, it no longer does; declare it yourself. Also from 3.3.0: iOS execution
  history and task events were being silently dropped (`EventStore` / `ExecutionHistoryStore` were
  lazy bindings nothing ever resolved, so `getExecutionHistory()` returned an empty list on iOS),
  and `shutdown()` left stale global registrations behind so a `shutdown()` → `initialize()` cycle
  pointed the event store at a dead registry.

  **From 3.3.1:** iOS single (non-chained) tasks never persisted their completion event or
  execution history — only chain executions showed up in `getExecutionHistory()` on iOS; iOS
  `SingleTaskExecutor` used a wall-clock diff for `ExecutionRecord.durationMs`, which an NTP sync
  mid-task could corrupt, now `TimeSource.Monotonic`; and the KSP processor now fails the build on
  two `@Worker` classes claiming the same name or alias instead of silently making one
  unreachable.

### Security

- **iOS path traversal in task-metadata filenames (via kmpworkmanager 3.3.1).** Caller-supplied
  task and chain ids were used unsanitized as filenames at 13 call sites in `IosFileStorage`; ids
  containing `/`, or equal to `.` / `..`, could escape the intended directory. They are now
  percent-encoded. The escaping is deliberately narrow — only `/`, a bare `.`/`..`, and a literal
  `%` — so ordinary ids (`"nightly-sync"`, `"com.example.sync"`, UUIDs) map to the same on-disk
  filename as before and tasks scheduled before the upgrade keep resolving.

---

## [1.4.5] - 2026-08-06

### Fixed

- **Task chain `{{taskId.outputKey}}` data-flow placeholders (#57):** the documented syntax for passing one chain step's output into a later step's config never actually worked on either platform.
  - **iOS:** step results were stored under flat, unprefixed keys, but substitution looked up the whole `"taskId.key"` string as one key — the two never matched, so placeholders always stayed literal text. A parallel step's tasks also overwrote each other's stored result (only the last task to finish survived). Separately, `AnyCodable`'s `Codable` conformance had no `Int32`/`Int64`/`Float`/`UInt64` cases, so any worker result containing one of those types (e.g. `ImageProcessWorker`'s `originalSize`/`processedSize`) silently failed to persist — the next step's substitution data came back empty with no error surfaced.
  - **Android:** had no substitution mechanism at all. Chains were built by enqueuing every step's `WorkRequest` upfront via WorkManager's native `.then()` chaining, which freezes each step's config before any earlier step has even run — there was no point in time a later step could see a real predecessor output. Fixed by moving to a dynamic per-step enqueue (`ChainHelper.buildAndEnqueueStep`) driven by `WorkInfo` completion, with output captured via a new `ChainResultCapturingWorker` decorator and resumed idempotently via `enqueueUniqueWork(..., KEEP)`.
  - Both platforms now namespace each task's result under `"<taskId>.<key>"`, merge (not overwrite) across parallel tasks, and resolve a whole-match placeholder (the entire config value is one `{{...}}`) to the original typed value rather than a stringified one, so substitution can target numeric/bool config fields, not just strings.
- **Android: Foreground-service permissions no longer bundled unconditionally.** `android/src/main/AndroidManifest.xml` used to declare `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` and a hardcoded `SystemForegroundService` type override, merging them into every consumer app's APK regardless of whether it used `isHeavyTask`/`ForegroundNativeWorker` — Google Play flags apps carrying foreground-service permissions they never exercise. These permissions are now consumer-app opt-in; see `doc/ANDROID_SETUP.md`'s "Android 14+ Foreground Services" section if you use `isHeavyTask: true`. Enforced going forward by a new `ManifestGuardTest`.

### Changed

- **kmpworkmanager core bumped 3.1.0 → 3.2.0**, bringing the Android FGS-permission fix above (same root cause, fixed independently in this plugin's own manifest too — kmpworkmanager's manifest and this plugin's manifest are separate merge sources) plus two iOS-only changes bundled in the same upstream release: `FileCompressionWorker` on iOS now produces a real PKZIP archive via `platform.zlib` (previously an uncompressed-copy stub gated behind `allowIosUncompressedFallback`), and a new `IosLiveActivityBridge` API for relaying worker progress to Live Activities/Dynamic Island (not yet wired into this plugin's public Dart API). Bundled `KMPWorkManager.xcframework` rebuilt from kmpworkmanager v3.2.0 source and re-verified through the full 4-layer SwiftPM check.

---

## [1.4.4] - 2026-07-26

### Fixed

- **DevTools Extension Loading Error (#55):** Fixed extension failure where DevTools failed with `could not read file as String: devtools_extensions/.../index.html`. Bundled compiled web assets into package root `extension/devtools/build/` and removed `extension/devtools/build/` from `.pubignore` so compiled DevTools extension assets are included in `pub.dev` releases.

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
