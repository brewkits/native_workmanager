# Issue #84: ownership and execution limit

Reviewed against native_workmanager v1.8.3 and its pinned kmpworkmanager v3.5.0.

## Ownership

This is a Flutter plugin bug. `maxConcurrentTasks` is part of the plugin's
`initialize()` contract and is forwarded by Dart, but Android only logged it.
iOS also ignored the argument and constructed a fixed four-slot limiter.

The core's `KmpWorkManagerConfig` at v3.5.0 has no global concurrency option.
Its Android initialization installs `KmpWorkerFactory` in WorkManager; it does
not receive the Flutter parameter. `KmpWorker` and `KmpHeavyWorker` resolve the
actual worker through the supplied `AndroidWorkerFactory`. Therefore a plugin
factory decorator can enforce the plugin contract without changing the core's
API or imposing a new default on other KMP consumers.

The plugin also runs iOS workers itself (foreground, chains, graphs, Dart
callbacks, background fallback and commands). A core-only change would not cover
these paths. A core-wide concurrency feature could be proposed separately, but
is not required to fix #84. Core remains pinned to v3.5.0.

## Implementation contract

- Positive integer; default four. Dart and native bridges reject invalid values.
- One admission pool per process, shared by plugin instances and workers created
  through the plugin factory. Custom host factories bypassing the plugin factory
  are outside this guarantee.
- Android wraps actual worker execution, including custom workers. Factories
  restore persisted configuration before returning workers, including manual
  WorkManager initialization setups.
- iOS uses a shared limiter restored from UserDefaults. `executeWorkerSync`
  holds one permit per attempt; factory wrappers cover the other execution paths.
  The main execution path explicitly bypasses the wrapper to avoid double admission.
- Coroutine/Swift task cancellation removes pending admission. Execution holds
  its permit until the worker returns or throws. Retries reacquire permits.
- Reconfiguration retains active permits. Lowering the limit drains existing
  work before admitting more; it does not cancel work already executing.
- Limits worker invocations, not OS WorkInfo RUNNING states, HTTP connections
  within one worker, or OS-managed transfers that outlive worker execution.
  Waiting inside an OS worker still consumes its execution time budget.
- Public Dart initialization remains idempotent: configure on the first call.
  Native reconfiguration handles a subsequent Flutter engine/hot restart safely.

## Regression coverage

- Kotlin limiter tests: peak active workers for limits 1/2/4, cancellation,
  exception release and changing limits while tasks are active.
- Android bridge/factory test: actual initialize handler, persisted value and
  multiple factory instances sharing one limit.
- Swift limiter tests: limits 1/2/4, prompt cancellation while all slots are held,
  and reconfiguration without replacing the pool.
- Dart validation and existing initialization forwarding tests.
- Device integration test `issue_84:` records execution intervals in per-task files from example-only
  custom native probes and Dart workers. It avoids networking dependencies. Run once with
  `--dart-define=ISSUE84_LIMIT=1` and once with `=2`.

Device test command (from `example/`):

```sh
flutter test integration_test/device_integration_test.dart -d DEVICE_ID \
  --plain-name 'issue_84:' --dart-define=ISSUE84_LIMIT=1
```

## Verification (2026-11-06)

- `flutter analyze --no-pub`: no issues.
- `flutter test test/unit/ --no-pub`: 1,259 passed, one skipped.
- Android native regression tests: four passed (limiter plus initialize/factory bridge).
- Swift limiter XCTest suite: three passed, compiled from the actual limiter source
  in a temporary macOS Swift package with the checked-in test file.
- Device integration probe, eight mixed custom-native/Dart tasks per run:

| Platform | Configured limit | Observed peak | Completed |
| --- | ---: | ---: | ---: |
| Android API 34 emulator | 1 | 1 | 8 |
| Android API 34 emulator | 2 | 2 | 8 |
| iOS 18.6 simulator | 1 | 1 | 8 |
| iOS 18.6 simulator | 2 | 2 | 8 |

Local build adaptations: the installed Flutter SDK is 3.44.9, while the ignored
Android local.properties referenced a missing 3.47.5 SDK. Android tests used
`-Pandroid.builtInKotlin=false` (or the equivalent Gradle project environment
variable) for the installed SDK's integration_test dependency. Xcode tests used
a temporary `XCODE_XCCONFIG_FILE` setting `IPHONEOS_DEPLOYMENT_TARGET = 15.0` to
accommodate the installed Xcode SDK's supported target range. No library minimum
OS version, core dependency, or checked-in build configuration was changed.

The first HTTP-based device probe was replaced with interval files because its
iOS networking behavior was inconsistent. The final probe has no network
requirement.

### Follow-ups (2026-11-07)

- Android limiter is now strictly FIFO (queue of `CompletableDeferred`); a waiter
  granted a slot and cancelled in the same turn hands it back. New Kotlin tests:
  `issue_84_waiters_are_admitted_fifo` (fails on the previous revision-flow limiter),
  `issue_84_granted_then_cancelled_waiter_releases_slot`.
- Device test asserts `peak == limit` for limits >= 2 (an over-restrictive limiter no
  longer passes) and adds a chain with a parallel native+Dart step at limit 1 as a
  nested-permit deadlock guard. Android API 34 emulator: limit 1 peak 1, limit 2 peak 2,
  chain completes.
- Debug-only warning when a later `initialize()` passes a different
  `maxConcurrentTasks` (first call wins).
- **Android cold start** (`scripts/issue84-cold-start.sh`): limit 1 persisted, 8 Dart
  probes with a 45 s delay, process started headlessly (no Activity, no Dart
  `initialize`) and SIGKILLed so JobScheduler cold-starts a new process. Result: limit 1
  -> 8 files, peak 1; control limit 2 -> 8 files, peak 2. (`am force-stop` is not used:
  it sets the stopped state and cancels jobs.)
  Harness note: without a ~3 s pause after the last enqueue, `flutter test` force-stopping
  the app once left the 8th task absent from WorkManager although Dart had received
  `accepted`. Not investigated further; worth a look if "accepted but lost" is ever
  reported.
- **iOS cold start: not verified.** A killed-app BGTask launch cannot be driven
  reliably on the simulator; restoration is covered by review of the
  `ConcurrencyLimiter.shared` UserDefaults initialisation and the XCTest suite only.
