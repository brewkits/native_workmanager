# native_workmanager Example App

Interactive demo app for the [`native_workmanager`](https://pub.dev/packages/native_workmanager)
plugin. The full API reference, install instructions, and copy-paste snippets live in the
[main README](../README.md) — this file covers running the demo and what each screen shows.

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

**Requirements:** Flutter 3.0+, Android 8.0+ (API 26+) or iOS 14.0+, a real device or
emulator/simulator.

### Entry points

- `lib/main.dart` — the main demo app (grid of feature screens, see below)
- `lib/main_basic.dart` — minimal quick-start example
- `lib/main_enhanced.dart` — extended feature walkthrough

### Platform setup

- **Android:** no additional setup — the plugin auto-initializes via `androidx.startup`.
- **iOS:** background execution requires the BGTaskScheduler entitlements and Info.plist
  entries described in [`doc/IOS_SETUP_GUIDE.md`](../doc/IOS_SETUP_GUIDE.md). Run
  `dart run native_workmanager:setup_ios` from the example directory to configure them
  automatically.

## What's demonstrated

The demo grid in `lib/main.dart` links out to focused pages under `lib/pages/`:

| Page | Demonstrates |
|---|---|
| `comprehensive_demo_page.dart` | End-to-end tour of native workers, triggers, and constraints |
| `demo_scenarios_page.dart` | Real-world scenarios (sync, backup, batch processing) |
| `fgs_bypass_demo_page.dart` | Foreground Service bypass for high-priority Android tasks |
| `file_system_demo_page.dart` | File workers — copy, move, compress, decompress |
| `cold_start_demo_page.dart` | `DartWorker` persistence across app kill / cold start |
| `case_study_page.dart` | Chain workflows (sequential + parallel) |
| `progress_tracking_demo_page.dart` | Real-time progress streaming (native + Dart workers) |
| `production_patterns_page.dart` | Retry/backoff, constraints, and other production patterns |
| `production_impact_page.dart` / `_improved.dart` | RAM/startup comparison vs a Flutter-Engine-per-task approach |
| `performance_page.dart` / `manual_benchmark_page.dart` | On-device performance benchmarking |
| `ab_testing_page.dart` | Side-by-side comparison against the `workmanager` plugin |

Additional coverage lives in `lib/examples/` (`chain_data_flow_demo.dart`,
`chain_resilience_test.dart`, `progress_tracking_example.dart`) and in
[`integration_test/`](integration_test) — the device regression suite exercised on every
release:

```bash
flutter test integration_test/device_integration_test.dart
```

## Retry and backoff

A `DartWorker` callback returning `false` (or throwing) retries under
`Constraints.maxRetries` / `backoffPolicy` / `backoffDelayMs`, enforced natively on both
platforms:

```dart
await NativeWorkManager.enqueue(
  taskId: 'sync-with-retry',
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: const Constraints(
    requiresNetwork: true,
    maxRetries: 3,
    backoffPolicy: BackoffPolicy.exponential,
    backoffDelayMs: 10000,
  ),
);
```

See `production_patterns_page.dart` for a runnable version and the main README's
[Custom Dart Workers](../README.md#custom-dart-workers) section for the full retry contract.

## Troubleshooting

**Tasks not executing (Android):** check battery optimization / battery saver settings and
confirm the task's `Constraints` are satisfiable (network, charging, etc.) — `adb logcat | grep WorkManager`
shows scheduling decisions.

**Tasks not running in background (iOS):** confirm the Background Modes capability and
BGTaskScheduler identifiers are registered (`dart run native_workmanager:setup_ios` handles
this); background execution is unreliable on the simulator — test on a real device.

**Nothing in the event log:** confirm `NativeWorkManager.initialize()` ran before any
`enqueue()` call and that the app is subscribed to `NativeWorkManager.events`.

For anything not covered here, see the [main README](../README.md), the
[`doc/`](../doc) directory, or [open an issue](https://github.com/brewkits/native_workmanager/issues).
