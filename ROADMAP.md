# native_workmanager Roadmap

Our mission is to provide the most robust, efficient, and secure background execution engine for Flutter.

## 🔜 Planned (v1.7.0)

- **Test against the declared minimum Flutter, not just the current one.** v1.6.0 moved
  `.flutter-version` from 3.27.4 to 3.41.9 so CI validates what the library is actually shipped
  against — but the published floor is still `flutter: '>=3.27.0'`, and nothing verifies it any
  more. A two-entry CI matrix (floor + current) is the honest fix; until then the floor is a
  claim, not a tested guarantee.
- **Audit the benchmark harness before publishing any figure from it.** The first recorded run
  (`benchmark/results/2026-09-06-ios-simulator/`) has the Dart-worker path reporting *faster*
  than the native path, and `chain_3_steps_ms` returning the timeout sentinel. Both need
  explaining — the two latency benchmarks do not appear to measure the same span. There is also
  no RAM instrument at all, which is why the memory claim had nothing behind it.
- **Push the iOS graph-node stagger into the bridge.** `TaskGraph` currently adds a 1-second delay
  to each node on iOS to work around BGTaskScheduler dropping back-to-back submissions
  (`_iosNodeSubmissionStagger`). It is a platform detail sitting in Dart domain logic; it belongs
  in the iOS scheduling layer, which needs a per-submission hook in KMP first.

---

## ✅ Completed (v1.6.x)
- **v1.6.0 removed every unmeasured performance claim from the docs.** The comparison tables
  carried a `~2 MB` RAM figure, a `< 50 ms` startup figure and a `100% Guaranteed` survival
  claim — for this package *and* for four competitors — none produced by a run anyone could
  reproduce. Running this project's own harness reports 698 ms and 794 ms against that
  `< 50 ms`, which is the whole argument. Numbers removed rather than restated; tables now carry
  dated capability rows only. First run recorded under `benchmark/results/`, labelled as a
  simulator run and explicitly not a performance claim. See §5.2 of `doc/BEST_PRACTICES.md`.
- **v1.6.0 battery-restriction diagnostics (Android):** the most common real-world reason a
  periodic task runs late is the OS, or the OEM, deferring it, and there was no way to see
  that from Dart. `batteryRestriction()` reports the stock-Android
  exemption state, `Build.MANUFACTURER`, and whether the settings screen actually resolves;
  `openBatteryOptimizationSettings()` is the no-permission route;
  `requestDisableBatteryOptimization()` is the direct dialog, which returns `missingPermission`
  unless the **host** app declares the Play-restricted permission itself (the plugin never
  will — `ManifestGuardTest` guards it). No per-OEM settings deep links: those activities are
  undocumented and rename between firmware builds, so `manufacturer` is passed up raw for the
  app to act on. Verified on Pixel 6 Pro (Android 17) and iPhone 16 Pro simulator; the
  permission-present/absent branches are covered by Robolectric, which a single device cannot
  produce.
- **v1.6.0 kmpworkmanager 3.4.1 engine bump:** no Dart API change *from the bump itself* — its
  value is entirely in the core. Android exact alarms actually execute their worker for the first time (the default
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

## 🧩 Phase 2: Ecosystem, Templates & Integrations

- [x] **SwiftUI `@main` App Support** — shipped in v1.5.0. `dart run native_workmanager:setup` detects a SwiftUI `@main` App and reports whether `@UIApplicationDelegateAdaptor(AppDelegate.self)` is wired.
- [ ] **Native Offline Queue Engine:** Built-in declarative pattern for queuing tasks while
  offline with automatic file/database-backed retry. Kept because it is engine work — it
  belongs below the Dart API, where this project's advantage actually lives.

---

## 🧊 Deliberately deferred

Not "someday" items — decisions, with the reason recorded so they do not quietly creep back
in. All of them were previously listed as planned work.

- **Cross-integration adapters** (`NativeDioAdapter`, FirebaseStorage, Hive/Isar sync).
  A Dio adapter is a couple of hundred lines of glue: it is the most copyable thing this
  project could build, and each adapter is a permanent maintenance obligation tracking
  somebody else's API. Adapters belong in separate packages — ideally other people's.
- **"Plug & Play" templates repository** (photo backup, offline chat queue, video download).
  Same objection, plus templates rot faster than APIs do. The example app already
  demonstrates the patterns; a template that silently goes stale is worse than none.
- **Desktop support** (Windows, macOS, Linux). Roughly triples the platform surface for a
  single maintainer, and the whole premise of this package — OS-level deferred execution
  that survives process death — barely exists on desktop, where a plain background isolate
  is usually the right answer.
- **Cloud coordination** (cross-device task status and dependency resolution). Needs server
  infrastructure and an operational commitment this project has explicitly decided not to
  take on.
- **Enterprise rate limiting** (multi-tenant bandwidth/concurrency control). No demand
  signal: not one issue or discussion has asked for it.

If someone opens an issue asking for one of these with a concrete use case, that is new
evidence and the decision can be revisited. Absent that, breadth is the wrong bet here.

---

## 📏 How this project measures itself

An earlier version of this file tracked pub.dev likes, GitHub stars, weekly downloads and
"Enterprise Users". Those targets were written before the July 2026 audit, which concluded
that this is a **portfolio and personal-brand project, explicitly not a commercial one**.
Steering by adoption metrics under that decision pushes every prioritisation the wrong way:
it rewards breadth (adapters, templates, desktop) when what a portfolio is judged on is
depth and rigour. So the targets are gone.

What is worth holding this project to instead:

| | Standard |
| :--- | :--- |
| **Claims** | Every quantitative claim in the docs is backed by a run in `benchmark/results/` with device, OS build and date attached — or it is not published. Nothing is asserted about another package that has not been measured here. |
| **Evidence** | A published measurement history across a real device matrix, growing over time. This is the one asset a competitor cannot fork along with the MIT source. |
| **Correctness** | Every bug fix that crosses a platform bridge carries a device test that fails if the bridge stops forwarding — see the Issue #30 and Issue #26 rules in `CLAUDE.md`. |
| **Honesty about limits** | Known-broken and unmeasured things are written down (see §5.2 of `doc/BEST_PRACTICES.md`), not omitted. |
| **pub.dev score** | 160/160 — kept, because it measures documentation and API hygiene rather than popularity. |

The one number still worth watching is **bus factor**, currently 1. The July 2026 audit
raised it and the governance section in `CONTRIBUTING.md` was written in response, but the
action item it names — granting a second person repository access — is still open. It caps
everything else on this list.
