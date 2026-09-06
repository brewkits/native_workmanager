# native_workmanager Roadmap

Our mission is to provide the most robust, efficient, and secure background execution engine for Flutter.

## 🔜 Planned (v1.7.0)

- **OEM battery-optimisation helpers (Android).** WorkManager persists tasks in the OS database,
  but Xiaomi (MIUI/HyperOS), Samsung ("App put to sleep") and similar OEM layers stretch a 15-minute
  periodic task out to 6–12 hours unless the app is whitelisted. There is no way to detect or
  request that today. Planned: `NativeWorkManager.isIgnoringBatteryOptimizations()` and
  `requestIgnoreBatteryOptimizations()` so apps that need punctual periodic work can prompt the
  user. Note `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is a Play-policy-restricted permission — the
  API must document the eligible use cases so apps do not risk a listing rejection.
- **Push the iOS graph-node stagger into the bridge.** `TaskGraph` currently adds a 1-second delay
  to each node on iOS to work around BGTaskScheduler dropping back-to-back submissions
  (`_iosNodeSubmissionStagger`). It is a platform detail sitting in Dart domain logic; it belongs
  in the iOS scheduling layer, which needs a per-submission hook in KMP first.

---

## ✅ Completed (v1.6.x)
- **v1.6.0 kmpworkmanager 3.4.1 engine bump:** no Dart API change; the value is entirely in the
  core. Android exact alarms actually execute their worker for the first time (the default
  `AlarmReceiver` used to log the alarm and stop), exact-alarm tasks survive a mid-run process
  kill, `KmpHeavyWorker` retries a transient foreground-service denial instead of dropping the
  task, and two overflow-file leaks are closed. iOS gets `ExistingPolicy.keep` working for
  dynamic task ids, no more chain-progress regression on a failed flush, constraint enforcement
  (`requiresUnmeteredNetwork` / charging / battery-not-low) and backoff timing for *standalone*
  tasks rather than chain steps only, and atomic metadata writes. One behaviour regression to
  watch for: expedited work is now gated on `TaskPriority`, so plugin `enqueue()` tasks (always
  `NORMAL`) are no longer blanket-expedited on Android.
  - Bridge fix forced by the bump: an inverted `TaskTrigger.windowed` window now throws at
    construction upstream, which on iOS is an uncatchable Kotlin exception crossing into Swift.
    `KMPSchedulerBridge` rejects it first — see `kmp_341:` in `device_integration_test.dart`.

### Not yet exposed in Dart (follow-up)
kmpworkmanager 3.4.0 shipped a WorkManager-parity API surface this plugin does not yet surface.
Each is a full Dart → Android → iOS parity change with its own device coverage:
- **Task tags + `cancelByTag(tag)` / `cancelByWorkerClass(name)`** — group cancellation by
  business context (`cancelByTag("user-123")`) across mixed worker types. Not supported for
  `TaskTrigger.Exact` on Android (AlarmManager is not tag-indexed).
- **Per-task `deadlineMs`** — a task not started by its deadline is skipped rather than run with
  stale data, and it finally gives `TaskTrigger.windowed`'s `latest` real teeth on iOS. Note the
  Dart bridge would also need `ScheduleResult.DEADLINE_ALREADY_PASSED`, which the Android plugin
  already forwards but `_parseScheduleResult` does not recognise (it logs and falls back to
  `accepted`); the branch is unreachable today only because no deadline is ever set.
- **Chain `InputMerger` (`mergeOutputFromPreviousStep`)** — a step opts in to receiving the
  previous step's result data merged into its own input, removing the need for the
  `{{taskId.outputKey}}` placeholder dance for whole-payload hand-off.
- **`ExistingPolicy.UPDATE`** — change a periodic task's constraints/input without resetting its
  interval timer.
- **`kmpworker-http` HMAC request signing + token refresh on 401** — overlaps the v1.4.0 backlog
  item on RemoteTrigger HMAC canonicalisation.

---

## ✅ Completed (v1.5.x)
- **v1.5.0 Live Activity progress filter, SwiftUI @main detection & kmpworkmanager 3.3.1:**
  - **`NativeWorkManager.iosLiveActivity`:** a `taskId`-scoped filter over the existing progress
    stream, so an iOS Live Activity can subscribe to just the task it renders. A Dart-side
    convenience helper — it does not call ActivityKit and does not wrap the KMP
    `IosLiveActivityBridge`; driving the `Activity<Attributes>` stays app-side.
  - **SwiftUI `@main` Detection:** `dart run native_workmanager:setup` validates SwiftUI `@main` lifecycle and `@UIApplicationDelegateAdaptor` configuration.
  - **Pub Score 160/160:** Fixed `@visibleForTesting` member exposure in testing library, restoring 160/160 pub points.
  - **kmpworkmanager core upgraded 3.2.0 → 3.3.1:** spans two upstream releases — 3.3.0 drops Koin
    (breaking for apps relying on it transitively) and fixes silently-dropped iOS execution
    history; 3.3.1 fixes iOS single-task persistence, a wall-clock duration bug, and an iOS
    filename path-traversal gap.

---

## ✅ Completed (v1.3.x)
- **v1.3.2 iOS UIScene Lifecycle Compatibility (Issue #36):**
  - Fixed a startup crash (`NSInternalInconsistencyException`) on apps using the Flutter 3.38+ UIScene template, where plugin registration runs after `didFinishLaunching` — too late for `BGTaskScheduler.register`.
  - BGTask launch handlers now register in an ObjC `+load` hook (`NWMBGTaskRegistrar`), always inside the launch window, on both the legacy and UIScene templates — no user setup required.
  - Closes out the registration-hook and reference-app work promised (but not delivered) in Issue #16.
  - `kmpworkmanager` core upgraded 2.5.1 → 3.0.1, fixing an expedited-task crash on Android 8–11 (API 26–30).
- **v1.3.0 "Zero-Config" Developer Experience** — both items below shipped:
  - **Android Auto-Init:** `androidx.startup` `Initializer` (`NativeWorkManagerInitializer`) runs before `Application.onCreate()` — no custom `Application` class or manifest edits needed for `DartWorker`.
  - **Unified CLI Setup Tool:** `dart run native_workmanager:setup` patches `AndroidManifest.xml` and `Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) automatically. The iOS `+load` registration piece originally scoped as a CLI injection ships instead as a built-in plugin mechanism (v1.3.2) — simpler and always-on, no CLI step required.

---
## ✅ Completed (v1.2.x)
- **v1.2.6 Industrial Reliability & FGS Bypass:**
  - **Foreground Service (FGS) Support (Android)**: Bypass Android 12+ background restrictions for heavy tasks with prioritized notifications.
  - **Locked Device Support (Android)**: Optimized task execution during Doze mode via Expedited Work mapping.
  - **Swift Concurrency Stability (iOS)**: Eliminated database deadlocks by migrating to serial dispatch queues.
  - **iOS Scheduling Reliability**: Tuned internal delays to ensure consistent `BGTaskScheduler` enqueuing.
  - **Platform-Aware Test Suite**: Comprehensive integration tests with automatic simulator detection and isolation.
- **v1.2.3 Critical Core Stability:** 
...
  - Bypassed Android's 10KB WorkManager payload limit via automated secure file spilling (`wm_spill_*.json`).
  - Fixed iOS URLSession background file loss with synchronous blocking moves.
  - Eliminated iOS `BGTaskScheduler` starvation and race conditions via `TaskCompletionGuard`.
  - Full I/O interruption support: `worker.stop()` now drops mid-flight network connections on cancel.
  - Added `initialDelay` and `runImmediately` support for Periodic Tasks.
  - Advanced Security: Strict validation against Null Byte Injection, Path Traversal (`..`), and Shell Injection.
- **Android Cold-Start Persistence:** `DartWorker` execution reliably survives app kills and restores automatically.
- **Advanced Remote Trigger (FCM/APNs):** Enqueue complete Task Chains and Offline Queues via silent push without waking the Flutter Engine.
- **HMAC Security:** Robust HMAC SHA-256 signature verification for remote triggers.
- **Real-Time Observability & Middleware:** DevTools extension real-time visualizer and global interceptors.
- **Code Generation (`native_workmanager_gen`):** Generate type-safe enqueue wrappers via `@WorkerCallback` annotations.
- **Selective Plugin Registration:** Explicit opt-in flag `registerPlugins` to control background engine memory footprint.

---

## 🧩 Phase 2: Ecosystem, Templates & Integrations (v1.4.x - v1.5.x) — Current Priority

To capture mindshare from legacy libraries, we must provide "Plug & Play" solutions.

- [ ] **Cross-Integrations (Adapters):**
  - `NativeDioAdapter`: Use Dio configurations but execute via the Zero-Engine `HttpDownloadWorker`.
  - `FirebaseStorage Native`: Upload directly via Native SDK without booting Flutter.
  - `Hive/Isar Sync`: Auto-sync local DB to server via native workers.
- [ ] **"Plug & Play" Templates Repository:**
  - Provide ready-to-use Dart templates for common use cases: *Auto Photo Backup to S3*, *Offline Chat Queue*, *Netflix-style Large Video Download*.
- [ ] **Native Offline Queue Engine:** Built-in declarative pattern for queuing tasks while offline with automatic file/database-backed retry.
- [x] **SwiftUI `@main` App Support** — shipped in v1.5.0. `dart run native_workmanager:setup` detects a SwiftUI `@main` App and reports whether `@UIApplicationDelegateAdaptor(AppDelegate.self)` is wired.

---

## 🚀 Phase 3: Scale & Desktop (v2.0.x+)
- [ ] **Cloud Coordination:** Synchronize task status and dependency resolution across multiple devices.
- [ ] **Enterprise Rate Limiting:** Advanced bandwidth and concurrency control for multi-tenant apps.
- [ ] **Desktop Support:** Expanding the native worker engine to Windows, macOS, and Linux.

---

## 📈 KPIs Target
| Metric | 3 Months | 6 Months | 12 Months |
|--------|---------|---------|----------|
| pub.dev Likes | 100+ | 500+ | 2,000+ |
| GitHub Stars | 200+ | 1,000+ | 3,000+ |
| Weekly Downloads | 1k | 5k | 20k |
| Enterprise Users | 1 | 3+ | 10+ |
| pub.dev Score | 160 | 160 | 160 |

*(Note: pub.dev score target increased to 160/160 following the v1.2.3 release).*