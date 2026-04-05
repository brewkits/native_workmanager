/// Testing utilities for native_workmanager.
///
/// Import this library **only** in test files and DI setup code — not in
/// production widget/logic files.
///
/// ```dart
/// // pubspec.yaml — no special config needed; this is part of the main package.
///
/// // In your service:
/// import 'package:native_workmanager/native_workmanager.dart';
/// import 'package:native_workmanager/testing.dart';
///
/// class SyncService {
///   SyncService(this._wm);
///   final IWorkManager _wm;
/// }
///
/// // Production main.dart:
/// final service = SyncService(NativeWorkManagerClient());
///
/// // Test file:
/// final fake = FakeWorkManager();
/// final service = SyncService(fake);
/// ```
library;

export 'src/testing/i_work_manager.dart';
export 'src/testing/fake_work_manager.dart';
export 'src/testing/native_work_manager_client.dart';
