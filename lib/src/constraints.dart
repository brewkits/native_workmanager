import 'package:flutter/foundation.dart';

/// Backoff policy for retry behavior when task fails.
///
/// **Android**: Determines retry behavior for failed WorkManager tasks.
/// **iOS**: Not applicable (manual retry required).
enum BackoffPolicy {
  /// Exponential backoff - Delay doubles after each retry.
  ///
  /// **Delay Pattern**: 30s, 60s, 120s, 240s, ...
  ///
  /// **Use Cases**: Network errors, server issues (gives server time to recover).
  exponential,

  /// Linear backoff - Constant delay between retries.
  ///
  /// **Delay Pattern**: 30s, 30s, 30s, 30s, ...
  ///
  /// **Use Cases**: Database locks, transient errors.
  linear,
}

/// Quality of Service (QoS) priority for task execution.
///
/// **iOS**: Maps to DispatchQoS for task execution priority.
/// **Android**: Ignored (WorkManager handles priority automatically).
enum QoS {
  /// Low priority - User is not waiting.
  ///
  /// **Use Cases**: Prefetching, maintenance, non-urgent sync.
  utility,

  /// Default priority - Deferrable work.
  ///
  /// **Use Cases**: Most background tasks, indexing, cleanup.
  background,

  /// Important work - User may be waiting.
  ///
  /// **Use Cases**: Explicit user action, data refresh from user request.
  userInitiated,

  /// Critical work - User actively waiting.
  ///
  /// **Use Cases**: UI updates, immediate user-facing operations.
  /// **Note**: Avoid for background tasks (defeats purpose of background work).
  userInteractive,
}

/// iOS-specific behavior for exact time alarms.
///
/// **Background**: iOS does not allow background code execution at exact times.
/// This enum provides transparency and control over how exact alarms are handled on iOS.
///
/// **Android**: Always executes worker code (this setting is ignored).
enum ExactAlarmIOSBehavior {
  /// Show a local notification at the exact time (DEFAULT - Safe).
  ///
  /// **Guarantees**:
  /// - ✅ Notification appears at exact time (±seconds)
  /// - ✅ Works in Low Power Mode
  /// - ✅ Survives app termination
  ///
  /// **Use Cases**: Reminders, alarms, time-sensitive notifications.
  showNotification,

  /// Attempt background code execution (Best Effort - NOT GUARANTEED).
  ///
  /// **Limitations**:
  /// - ❌ NOT suitable for time-critical operations
  /// - ❌ Timing accuracy: ±minutes to ±hours
  /// - ❌ May not run in Low Power Mode
  ///
  /// **Use Cases**: Non-critical background sync with timing hint.
  attemptBackgroundRun,

  /// Throw exception immediately (Fail Fast - Development Safety).
  ///
  /// **Benefits**:
  /// - ✅ Immediate feedback during development
  /// - ✅ Prevents deploying code with wrong expectations
  /// - ✅ Forces platform-aware design
  ///
  /// **Use Cases**: Development/testing, critical operations that require exact timing.
  throwError,
}

/// System-level constraints for task execution (Android only).
///
/// **New in KMP WorkManager 2.2.0+**: SystemConstraints provide a cleaner way to
/// specify system-level requirements. These replace the deprecated trigger-based
/// approach (TaskTrigger.batteryLow, etc.) and the individual boolean flags.
///
/// **Platform Support**: Android only. iOS ignores these constraints.
///
/// ## Basic Usage
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'maintenance-task',
///   trigger: TaskTrigger.oneTime(),
///   worker: DartWorker(callbackId: 'cleanup'),
///   constraints: Constraints(
///     systemConstraints: {
///       SystemConstraint.deviceIdle,  // Run when device is idle
///       SystemConstraint.allowLowStorage,  // OK to run on low storage
///     },
///   ),
/// );
/// ```
///
/// ## Constraint Types
///
/// **Storage Constraints:**
/// - `allowLowStorage` - Task can run even when storage is low
/// - Default behavior: Task waits for sufficient storage
///
/// **Battery Constraints:**
/// - `allowLowBattery` - Task can run even when battery is low
/// - `requireBatteryNotLow` - Task requires battery level to not be low
/// - Default behavior: No battery restriction
///
/// **System State:**
/// - `deviceIdle` - Task requires device to be idle (screen off, no user interaction)
/// - Use for maintenance tasks that should not impact user experience
///
/// ## Migration from Old API
///
/// **Before (deprecated triggers):**
/// ```dart
/// // OLD - deprecated in v2.2.0
/// trigger: TaskTrigger.storageLow,  // or batteryLow, deviceIdle
/// ```
///
/// **After (SystemConstraints):**
/// ```dart
/// // NEW - recommended approach
/// constraints: Constraints(
///   systemConstraints: {SystemConstraint.allowLowStorage},
/// )
/// ```
///
/// **Before (boolean flags):**
/// ```dart
/// // OLD - still works but less flexible
/// constraints: Constraints(
///   requiresStorageNotLow: true,
///   requiresBatteryNotLow: true,
///   requiresDeviceIdle: true,
/// )
/// ```
///
/// **After (SystemConstraints - more explicit):**
/// ```dart
/// // NEW - clearer intent
/// constraints: Constraints(
///   systemConstraints: {
///     SystemConstraint.deviceIdle,
///     SystemConstraint.requireBatteryNotLow,
///   },
/// )
/// ```
///
/// ## Common Patterns
///
/// **Maintenance Task (idle device, low priority):**
/// ```dart
/// Constraints(
///   systemConstraints: {
///     SystemConstraint.deviceIdle,
///     SystemConstraint.allowLowStorage,
///     SystemConstraint.allowLowBattery,
///   },
///   qos: QoS.utility,
/// )
/// ```
///
/// **Critical Task (needs resources):**
/// ```dart
/// Constraints(
///   systemConstraints: {
///     SystemConstraint.requireBatteryNotLow,
///   },
///   requiresNetwork: true,
///   requiresCharging: true,
/// )
/// ```
///
/// **Background Sync (opportunistic):**
/// ```dart
/// Constraints(
///   systemConstraints: {
///     SystemConstraint.allowLowBattery,  // Run even on low battery
///   },
///   requiresNetwork: true,
/// )
/// ```
///
/// ## Platform Behavior
///
/// **Android:**
/// - Maps to WorkManager's SystemConstraint API
/// - Enforced by Android WorkManager
/// - Affects task scheduling and execution
///
/// **iOS:**
/// - Ignored (not applicable to iOS background tasks)
/// - iOS has different constraint system
/// - Use iOS-specific constraints like `requiresCharging` instead
///
/// ## Best Practices
///
/// ✅ **Do** use SystemConstraints for explicit intent
/// ✅ **Do** combine with other constraints (network, charging)
/// ✅ **Do** use deviceIdle for maintenance tasks
/// ✅ **Do** use allowLowStorage/allowLowBattery for non-critical tasks
///
/// ❌ **Don't** mix old triggers with new SystemConstraints
/// ❌ **Don't** expect SystemConstraints to work on iOS
/// ❌ **Don't** use deviceIdle for user-initiated tasks
///
/// See also:
/// - [Constraints] - Container for all constraint types
/// - [TaskTrigger] - When tasks should execute
enum SystemConstraint {
  /// Allow task to run even when storage is low (Android only).
  ///
  /// Use this for tasks that:
  /// - Don't require much storage
  /// - Can handle low-storage conditions gracefully
  /// - Are not storage-intensive
  ///
  /// **Example**: Small API sync, log cleanup.
  allowLowStorage,

  /// Allow task to run even when battery is low (Android only).
  ///
  /// Use this for tasks that:
  /// - Are lightweight and quick
  /// - Don't drain battery significantly
  /// - Can tolerate battery constraints
  ///
  /// **Example**: Quick sync, small uploads.
  allowLowBattery,

  /// Require battery level to not be low (Android only).
  ///
  /// Task will wait until battery is above low threshold (~15%).
  ///
  /// Use this for tasks that:
  /// - Are battery-intensive
  /// - Should not drain a low battery further
  /// - Can wait for charging
  ///
  /// **Example**: Large file processing, heavy computation.
  requireBatteryNotLow,

  /// Require device to be idle (Android only).
  ///
  /// Device is considered idle when:
  /// - Screen is off
  /// - No user interaction
  /// - Device has been idle for a period
  ///
  /// Use this for tasks that:
  /// - Are low priority
  /// - Should not impact user experience
  /// - Can run overnight or during idle periods
  ///
  /// **Example**: Database optimization, cache cleanup, maintenance.
  deviceIdle,
}

/// iOS background task type selection (iOS 13.0+ only).
///
/// **New in KMP WorkManager 2.2.0+**: Control which iOS BGTask type is used
/// for background execution. Each type has different time limits and capabilities.
///
/// **Platform Support**: iOS only. Android ignores this setting.
///
/// ## Task Types
///
/// **BGAppRefreshTask (appRefresh):**
/// - Time limit: ~30 seconds total
/// - Task timeout: 20 seconds
/// - Chain timeout: 50 seconds
/// - Use case: Quick sync, small updates, lightweight operations
/// - Frequency: System-determined (multiple times per day)
///
/// **BGProcessingTask (processing):**
/// - Time limit: 5-10 minutes
/// - Task timeout: 120 seconds (2 minutes)
/// - Chain timeout: 300 seconds (5 minutes)
/// - Use case: Heavy processing, large downloads/uploads, data migration
/// - Frequency: Less frequent (overnight, device charging)
/// - Requires: `requiresCharging` or `requiresNetwork` in constraints
///
/// ## Auto-Selection Behavior
///
/// If `bgTaskType` is **not specified** (null), the system auto-selects based on:
/// - `isHeavyTask = true` → BGProcessingTask
/// - `isHeavyTask = false` → BGAppRefreshTask
///
/// ## Basic Usage
///
/// **Auto-Selection (Recommended):**
/// ```dart
/// // System chooses based on isHeavyTask
/// await NativeWorkManager.enqueue(
///   taskId: 'sync',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   constraints: Constraints(
///     isHeavyTask: false,  // → BGAppRefreshTask
///   ),
/// );
/// ```
///
/// **Manual Selection:**
/// ```dart
/// // Force BGAppRefreshTask for quick sync
/// await NativeWorkManager.enqueue(
///   taskId: 'quick-sync',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   constraints: Constraints(
///     bgTaskType: BGTaskType.appRefresh,  // Explicit
///     requiresNetwork: true,
///   ),
/// );
/// ```
///
/// ## When to Use Each Type
///
/// **Use appRefresh for:**
/// - Quick API sync (<30s)
/// - Small data uploads
/// - Fast health checks
/// - Lightweight maintenance
/// - Frequent operations
///
/// ```dart
/// Constraints(
///   bgTaskType: BGTaskType.appRefresh,
///   requiresNetwork: true,
/// )
/// ```
///
/// **Use processing for:**
/// - Large file uploads/downloads (minutes)
/// - Video/image processing
/// - Database migrations
/// - ML model inference
/// - Batch operations
///
/// ```dart
/// Constraints(
///   bgTaskType: BGTaskType.processing,
///   requiresNetwork: true,
///   requiresCharging: true,  // Recommended
///   isHeavyTask: true,
/// )
/// ```
///
/// ## Time-Slicing (KMP 2.2.1+)
///
/// For large queues, KMP WorkManager automatically:
/// - Uses 85% of available time for tasks
/// - Reserves 15% for cleanup
/// - Stops early when time is insufficient
/// - Schedules continuation for remaining tasks
///
/// ## Info.plist Configuration
///
/// Both task types must be declared in Info.plist:
///
/// ```xml
/// <key>BGTaskSchedulerPermittedIdentifiers</key>
/// <array>
///   <string>dev.brewkits.kmpworkmanager.refresh</string>
///   <string>dev.brewkits.kmpworkmanager.processing</string>
/// </array>
/// ```
///
/// ## Platform Behavior
///
/// **iOS:**
/// - Maps to BGTaskScheduler API
/// - Time limits strictly enforced by iOS
/// - Processing tasks run less frequently
/// - System decides actual execution timing
///
/// **Android:**
/// - Setting is ignored (not applicable)
/// - Android WorkManager uses different scheduling
/// - Use `isHeavyTask` for foreground service on Android
///
/// ## Common Pitfalls
///
/// ❌ **Don't** use processing for quick operations (wastes battery)
/// ❌ **Don't** use appRefresh for operations >30 seconds (will fail)
/// ❌ **Don't** forget Info.plist configuration (tasks won't run)
/// ❌ **Don't** rely on exact timing (iOS schedules opportunistically)
///
/// ✅ **Do** prefer auto-selection (leave null, set isHeavyTask)
/// ✅ **Do** handle task interruption gracefully
/// ✅ **Do** use processing for long operations
/// ✅ **Do** test with actual background conditions
///
/// ## Best Practices
///
/// 1. **Default to auto-selection**: Let `isHeavyTask` control type
/// 2. **Test timeouts**: Verify operations complete within limits
/// 3. **Handle interruption**: Save progress if task is stopped early
/// 4. **Monitor metrics**: Use TaskEventBus for execution time tracking
/// 5. **Optimize for appRefresh**: Most tasks should complete in 30s
///
/// ## See Also
///
/// - [Constraints.isHeavyTask] - Auto-selects BGProcessingTask
/// - [TaskTrigger] - When tasks execute
/// - KMP WorkManager: BGTaskType enum
enum BGTaskType {
  /// BGAppRefreshTask - Quick operations (~30 seconds).
  ///
  /// **Limits**:
  /// - Total time: ~30 seconds
  /// - Task timeout: 20 seconds
  /// - Chain timeout: 50 seconds
  ///
  /// **Use Cases**: Quick sync, small uploads, health checks.
  ///
  /// **Frequency**: Multiple times per day (system-determined).
  appRefresh,

  /// BGProcessingTask - Heavy operations (5-10 minutes).
  ///
  /// **Limits**:
  /// - Total time: 5-10 minutes
  /// - Task timeout: 120 seconds
  /// - Chain timeout: 300 seconds
  ///
  /// **Use Cases**: Large downloads, video processing, migrations.
  ///
  /// **Frequency**: Less frequent (overnight, charging).
  ///
  /// **Requirements**: Needs `requiresCharging` or `requiresNetwork`.
  processing,
}

/// Android 14+ foreground service type for heavy tasks.
///
/// **Available in native_workmanager 1.0.0+** (introduced in 0.8.0): Android 14 (API 34+)
/// requires explicit foreground service types for apps targeting SDK 34+.
///
/// **Platform Support**: Android 14+ only. iOS and Android <14 ignore this setting.
///
/// **Applies To**: Only relevant when `isHeavyTask = true`. Heavy tasks run as
/// foreground services with a persistent notification.
///
/// ## Service Types
///
/// Each type requires corresponding permissions in AndroidManifest.xml.
///
/// **dataSync (default):**
/// - Use case: Background data upload/download, API sync, database operations
/// - Permissions: None (safe default)
/// - Validation: Always passes on Chinese ROMs (FAIL OPEN strategy)
///
/// **location:**
/// - Use case: GPS tracking, location-based services
/// - Permissions: `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION`
/// - Manifest: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>`
///
/// **mediaPlayback:**
/// - Use case: Audio/video playback, media processing
/// - Permissions: None
/// - Manifest: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>`
///
/// **camera:**
/// - Use case: Camera operations, photo/video capture
/// - Permissions: `CAMERA`
/// - Manifest: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA"/>`
///
/// **microphone:**
/// - Use case: Audio recording, voice processing
/// - Permissions: `RECORD_AUDIO`
/// - Manifest: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>`
///
/// **health:**
/// - Use case: Health/fitness data collection
/// - Permissions: `BODY_SENSORS`, `HIGH_SAMPLING_RATE_SENSORS` (if applicable)
/// - Manifest: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH"/>`
///
/// ## Basic Usage
///
/// **Default (dataSync):**
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'large-upload',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpUpload(
///     url: 'https://cdn.example.com/upload',
///     filePath: '/path/to/file.zip',
///   ),
///   constraints: Constraints(
///     isHeavyTask: true,  // Uses dataSync by default
///     requiresNetwork: true,
///   ),
/// );
/// ```
///
/// **Location Tracking:**
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'gps-tracker',
///   trigger: TaskTrigger.periodic(Duration(minutes: 15)),
///   worker: DartWorker(callbackId: 'trackLocation'),
///   constraints: Constraints(
///     isHeavyTask: true,
///     foregroundServiceType: ForegroundServiceType.location,
///     requiresNetwork: true,
///   ),
/// );
/// ```
///
/// **Media Processing:**
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'video-encode',
///   trigger: TaskTrigger.oneTime(),
///   worker: DartWorker(callbackId: 'encodeVideo'),
///   constraints: Constraints(
///     isHeavyTask: true,
///     foregroundServiceType: ForegroundServiceType.mediaPlayback,
///     requiresCharging: true,
///   ),
/// );
/// ```
///
/// ## AndroidManifest.xml Configuration
///
/// Add permission for the service type you're using:
///
/// ```xml
/// <manifest>
///   <!-- For location tasks -->
///   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
///   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
///
///   <!-- For media tasks -->
///   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
///
///   <!-- For camera tasks -->
///   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA"/>
///   <uses-permission android:name="android.permission.CAMERA"/>
///
///   <!-- For microphone tasks -->
///   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
///   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
///
///   <!-- For health tasks -->
///   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH"/>
///   <uses-permission android:name="android.permission.BODY_SENSORS"/>
/// </manifest>
/// ```
///
/// ## Validation Strategy (KMP 2.1.2+)
///
/// KMP WorkManager uses **FAIL OPEN** validation:
/// - Validates permissions on Android 14+ (API 34+)
/// - Falls back to `dataSync` if validation fails
/// - Ensures compatibility with Chinese ROMs (Xiaomi, Oppo, etc.)
/// - Never crashes due to missing permissions
///
/// ## Platform Behavior
///
/// **Android 14+ (API 34+):**
/// - Foreground service type is required and validated
/// - Missing permissions → fallback to dataSync
/// - Notification shows during task execution
///
/// **Android <14:**
/// - Setting is ignored (not required)
/// - Heavy tasks still run as foreground services
/// - Any type works without validation
///
/// **iOS:**
/// - Setting is completely ignored
/// - iOS uses BGTaskScheduler (no foreground services)
/// - Use `bgTaskType` for iOS task type selection
///
/// ## When to Use Each Type
///
/// | Type | Use Case | Permissions Required |
/// |------|----------|----------------------|
/// | dataSync | Default, file upload/download | None |
/// | location | GPS tracking, location services | FINE or COARSE location |
/// | mediaPlayback | Audio/video playback | None |
/// | camera | Camera operations | CAMERA |
/// | microphone | Audio recording | RECORD_AUDIO |
/// | health | Health/fitness data | BODY_SENSORS |
///
/// ## Common Pitfalls
///
/// ❌ **Don't** forget manifest permissions (task will fall back to dataSync)
/// ❌ **Don't** use without `isHeavyTask = true` (no effect)
/// ❌ **Don't** expect exact type on Chinese ROMs (FAIL OPEN)
/// ❌ **Don't** use for tasks <30 seconds (foreground overhead)
///
/// ✅ **Do** add manifest permissions for your service type
/// ✅ **Do** use dataSync as safe default for uploads/downloads
/// ✅ **Do** combine with appropriate constraints
/// ✅ **Do** test on Android 14+ devices
///
/// ## Best Practices
///
/// 1. **Default to dataSync**: Safe for most heavy tasks
/// 2. **Add manifest entries**: Always declare required permissions
/// 3. **Test on Android 14+**: Verify behavior on modern devices
/// 4. **Handle fallback**: App works even with wrong type (falls back to dataSync)
/// 5. **Use specific types**: Only when actually accessing camera/location/etc.
///
/// ## See Also
///
/// - [Constraints.isHeavyTask] - Enables foreground service
/// - [BGTaskType] - iOS equivalent for task type selection
/// - KMP WorkManager: ForegroundServiceType and validation
enum ForegroundServiceType {
  /// Data synchronization (DEFAULT - Safe for all heavy tasks).
  ///
  /// **Use Case**: File uploads/downloads, API sync, database operations.
  ///
  /// **Permissions**: None required.
  ///
  /// **Validation**: Always passes (FAIL OPEN strategy).
  ///
  /// **Best for**: Most heavy tasks (default choice).
  dataSync,

  /// Location tracking and GPS services.
  ///
  /// **Use Case**: GPS tracking, location-based services, geofencing.
  ///
  /// **Permissions Required**:
  /// - `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION`
  /// - `FOREGROUND_SERVICE_LOCATION` (Android 14+)
  ///
  /// **Manifest**:
  /// ```xml
  /// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
  /// ```
  location,

  /// Audio/video playback and media processing.
  ///
  /// **Use Case**: Audio playback, video encoding, media streaming.
  ///
  /// **Permissions Required**:
  /// - `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (Android 14+)
  ///
  /// **Manifest**:
  /// ```xml
  /// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
  /// ```
  mediaPlayback,

  /// Camera operations and photo/video capture.
  ///
  /// **Use Case**: Camera capture, photo processing, AR applications.
  ///
  /// **Permissions Required**:
  /// - `CAMERA`
  /// - `FOREGROUND_SERVICE_CAMERA` (Android 14+)
  ///
  /// **Manifest**:
  /// ```xml
  /// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA"/>
  /// <uses-permission android:name="android.permission.CAMERA"/>
  /// ```
  camera,

  /// Microphone and audio recording.
  ///
  /// **Use Case**: Audio recording, voice recognition, speech processing.
  ///
  /// **Permissions Required**:
  /// - `RECORD_AUDIO`
  /// - `FOREGROUND_SERVICE_MICROPHONE` (Android 14+)
  ///
  /// **Manifest**:
  /// ```xml
  /// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
  /// <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  /// ```
  microphone,

  /// Health and fitness data collection.
  ///
  /// **Use Case**: Health tracking, fitness monitoring, sensor data.
  ///
  /// **Permissions Required**:
  /// - `BODY_SENSORS`
  /// - `HIGH_SAMPLING_RATE_SENSORS` (if applicable)
  /// - `FOREGROUND_SERVICE_HEALTH` (Android 14+)
  ///
  /// **Manifest**:
  /// ```xml
  /// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH"/>
  /// <uses-permission android:name="android.permission.BODY_SENSORS"/>
  /// ```
  health,
}

/// Constraints that must be met before a task can run.
///
/// Constraints optimize battery life and ensure tasks run under appropriate
/// conditions. The OS will defer task execution until all constraints are met.
///
/// ## Basic Examples
///
/// **Network Required:**
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'api-sync',
///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// **WiFi + Charging (Heavy Task):**
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'video-upload',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpUpload(
///     url: 'https://cdn.example.com/videos',
///     filePath: '/path/to/video.mp4',
///   ),
///   constraints: Constraints.heavyTask,
/// );
/// ```
///
/// **Custom Constraints:**
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'db-cleanup',
///   trigger: TaskTrigger.periodic(Duration(days: 1)),
///   worker: DartWorker(callbackId: 'cleanupDatabase'),
///   constraints: Constraints(
///     requiresDeviceIdle: true,
///     requiresBatteryNotLow: true,
///     requiresStorageNotLow: true,
///   ),
/// );
/// ```
///
/// ## Common Constraint Patterns
///
/// **Data Sync (Network Required):**
/// ```dart
/// Constraints(requiresNetwork: true)
/// ```
///
/// **Large Upload (WiFi + Battery Safe):**
/// ```dart
/// Constraints(
///   requiresUnmeteredNetwork: true,
///   requiresCharging: true,
///   isHeavyTask: true,
/// )
/// ```
///
/// **Maintenance Task (Device Idle):**
/// ```dart
/// Constraints(
///   requiresDeviceIdle: true,
///   requiresBatteryNotLow: true,
/// )
/// ```
///
/// **Critical Task (No Constraints):**
/// ```dart
/// Constraints.none // or Constraints()
/// ```
///
/// ## Static Helpers
///
/// - [networkRequired] - Simple network requirement
/// - [heavyTask] - WiFi + charging for large operations
/// - [none] - No constraints (runs ASAP)
///
/// ## When to Use Constraints
///
/// ✅ **Use constraints for:**
/// - Network-dependent operations (API calls, uploads)
/// - Battery-intensive tasks (video processing)
/// - Storage-intensive operations (downloads, caching)
/// - Maintenance work (cleanup, optimization)
///
/// ❌ **Don't use constraints for:**
/// - Time-critical operations
/// - User-initiated actions (use no constraints)
/// - Tasks that must run immediately
///
/// ## Battery Impact
///
/// More constraints = Better battery life:
/// - Tasks deferred until optimal conditions
/// - OS can batch work together
/// - Prevents running on cellular data
/// - Avoids draining battery
///
/// ## Platform Differences
///
/// **Android:**
/// - All constraints enforced by WorkManager
/// - Very reliable constraint checking
/// - Can combine multiple constraints
///
/// **iOS:**
/// - Constraints are advisory (not strictly enforced)
/// - Best effort by BGTaskScheduler
/// - Some constraints (requiresDeviceIdle) not available
///
/// ## See Also
///
/// - [BackoffPolicy] - Retry behavior on failure
/// - [QoS] - iOS task priority
/// - [ExactAlarmIOSBehavior] - iOS exact alarm handling
@immutable
class Constraints {
  const Constraints({
    this.requiresNetwork = false,
    this.requiresUnmeteredNetwork = false,
    this.requiresCharging = false,
    this.requiresDeviceIdle = false,
    this.requiresBatteryNotLow = false,
    this.requiresStorageNotLow = false,
    this.allowWhileIdle = false,
    this.isHeavyTask = false,
    this.qos = QoS.background,
    this.exactAlarmIOSBehavior = ExactAlarmIOSBehavior.showNotification,
    this.backoffPolicy = BackoffPolicy.exponential,
    this.backoffDelayMs = 30000,
    this.systemConstraints = const {},
    this.bgTaskType,
    this.foregroundServiceType,
  });

  /// Task requires any network connection.
  final bool requiresNetwork;

  /// Task requires unmetered (WiFi) network.
  final bool requiresUnmeteredNetwork;

  /// Task requires device to be charging.
  final bool requiresCharging;

  /// Task requires device to be idle. (Android only)
  final bool requiresDeviceIdle;

  /// Task requires battery level to not be low. (Android only)
  final bool requiresBatteryNotLow;

  /// Task requires storage to not be low. (Android only)
  final bool requiresStorageNotLow;

  /// Allow task to run during Doze mode. (Android only)
  final bool allowWhileIdle;

  /// Indicates this is a long-running or heavy task requiring special handling.
  ///
  /// **Android**: Uses ForegroundService with persistent notification.
  /// - Task can run indefinitely while service is foreground
  /// - Prevents system from killing the task
  /// - Shows persistent notification to user
  ///
  /// **iOS**: Uses BGProcessingTask (≤60s) instead of BGAppRefreshTask (≤30s).
  /// - Double the execution time limit
  /// - Better for CPU-intensive work
  ///
  /// **Use Cases**: File upload, video processing, data migration.
  final bool isHeavyTask;

  /// Quality of Service hint for task priority (iOS only).
  ///
  /// **iOS**: Maps to DispatchQoS for task execution priority.
  /// **Android**: Ignored (WorkManager handles priority automatically).
  ///
  /// Default: [QoS.background]
  final QoS qos;

  /// iOS-specific behavior for exact time alarms.
  ///
  /// Determines how [TaskTrigger.exact()] is handled on iOS,
  /// since iOS does not support background code execution at exact times.
  ///
  /// **Android**: This field is ignored (Android always executes worker code).
  ///
  /// Default: [ExactAlarmIOSBehavior.showNotification]
  final ExactAlarmIOSBehavior exactAlarmIOSBehavior;

  /// Backoff policy when task fails and needs retry (Android only).
  ///
  /// **Android**: Determines retry behavior for failed WorkManager tasks.
  /// - [BackoffPolicy.exponential]: Delay doubles after each retry (30s, 60s, 120s, ...)
  /// - [BackoffPolicy.linear]: Constant delay between retries
  ///
  /// **iOS**: Not applicable (manual retry required).
  ///
  /// Default: [BackoffPolicy.exponential]
  final BackoffPolicy backoffPolicy;

  /// Initial backoff delay in milliseconds when task fails (Android only).
  ///
  /// **Android**: Starting delay before first retry.
  /// - Minimum: 10,000ms (10 seconds)
  /// - Subsequent retries follow [backoffPolicy]
  ///
  /// **iOS**: Not applicable.
  ///
  /// **Example**:
  /// ```dart
  /// Constraints(
  ///   backoffPolicy: BackoffPolicy.exponential,
  ///   backoffDelayMs: 30000,  // Start with 30s, then 60s, 120s, ...
  /// )
  /// ```
  ///
  /// Default: 30,000ms (30 seconds)
  final int backoffDelayMs;

  /// System-level constraints for task execution (Android only).
  ///
  /// **New in KMP WorkManager 2.2.0+**: Provides cleaner way to specify
  /// system-level requirements than individual boolean flags.
  ///
  /// **Platform Support**: Android only. iOS ignores these constraints.
  ///
  /// **Available Constraints**:
  /// - [SystemConstraint.allowLowStorage] - Run even when storage is low
  /// - [SystemConstraint.allowLowBattery] - Run even when battery is low
  /// - [SystemConstraint.requireBatteryNotLow] - Wait for battery to recover
  /// - [SystemConstraint.deviceIdle] - Run only when device is idle
  ///
  /// **Example**:
  /// ```dart
  /// Constraints(
  ///   systemConstraints: {
  ///     SystemConstraint.deviceIdle,
  ///     SystemConstraint.allowLowStorage,
  ///   },
  /// )
  /// ```
  ///
  /// **Migration**: Prefer this over deprecated boolean flags
  /// (`requiresDeviceIdle`, `requiresBatteryNotLow`, `requiresStorageNotLow`).
  ///
  /// Default: Empty set (no system constraints)
  final Set<SystemConstraint> systemConstraints;

  /// iOS background task type selection (iOS 13.0+ only).
  ///
  /// **New in KMP WorkManager 2.2.0+**: Controls which iOS BGTask type is used
  /// for background execution (BGAppRefreshTask vs BGProcessingTask).
  ///
  /// **Platform Support**: iOS only. Android ignores this setting.
  ///
  /// **Auto-Selection**: If null (default), type is selected based on [isHeavyTask]:
  /// - `isHeavyTask = true` → BGProcessingTask (5-10 min limit)
  /// - `isHeavyTask = false` → BGAppRefreshTask (~30s limit)
  ///
  /// **Time Limits**:
  /// - appRefresh: ~30 seconds total (20s task, 50s chain)
  /// - processing: 5-10 minutes total (120s task, 300s chain)
  ///
  /// **Example** (auto-selection):
  /// ```dart
  /// Constraints(
  ///   isHeavyTask: true,  // Selects BGProcessingTask
  ///   requiresNetwork: true,
  /// )
  /// ```
  ///
  /// **Example** (manual selection):
  /// ```dart
  /// Constraints(
  ///   bgTaskType: BGTaskType.appRefresh,  // Force quick task
  ///   requiresNetwork: true,
  /// )
  /// ```
  ///
  /// **Best Practice**: Prefer auto-selection (leave null) unless you have
  /// specific timing requirements.
  ///
  /// Default: null (auto-select based on isHeavyTask)
  final BGTaskType? bgTaskType;

  /// Android 14+ foreground service type for heavy tasks.
  ///
  /// **New in KMP WorkManager 2.1.2+**: Controls the foreground service type
  /// for heavy tasks on Android 14 (API 34+).
  ///
  /// **Platform Support**: Android 14+ only. iOS and Android <14 ignore this.
  ///
  /// **Applies To**: Only effective when [isHeavyTask] is `true`. Heavy tasks
  /// run as foreground services with persistent notifications.
  ///
  /// **Available Types**:
  /// - [ForegroundServiceType.dataSync] (default) - File sync, uploads, downloads
  /// - [ForegroundServiceType.location] - GPS tracking, location services
  /// - [ForegroundServiceType.mediaPlayback] - Audio/video playback
  /// - [ForegroundServiceType.camera] - Camera operations
  /// - [ForegroundServiceType.microphone] - Audio recording
  /// - [ForegroundServiceType.health] - Health/fitness data
  ///
  /// **Permissions**: Each type requires manifest permissions (see [ForegroundServiceType]).
  ///
  /// **Validation**: KMP WorkManager uses FAIL OPEN strategy - falls back to
  /// dataSync if validation fails. Ensures compatibility with Chinese ROMs.
  ///
  /// **Example** (location tracking):
  /// ```dart
  /// Constraints(
  ///   isHeavyTask: true,
  ///   foregroundServiceType: ForegroundServiceType.location,
  ///   requiresNetwork: true,
  /// )
  /// ```
  ///
  /// **Example** (default data sync):
  /// ```dart
  /// Constraints(
  ///   isHeavyTask: true,  // Uses dataSync by default
  ///   requiresNetwork: true,
  /// )
  /// ```
  ///
  /// **Manifest Required**:
  /// ```xml
  /// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
  /// ```
  ///
  /// Default: null (uses dataSync)
  final ForegroundServiceType? foregroundServiceType;

  /// Preset for network-dependent tasks.
  ///
  /// Use this for any task that requires network connectivity (API calls,
  /// uploads, downloads, sync operations).
  ///
  /// **Equivalent to:** `Constraints(requiresNetwork: true)`
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'api-sync',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  static const Constraints networkRequired = Constraints(requiresNetwork: true);

  /// Preset for heavy tasks (should run on WiFi + Charging).
  ///
  /// Use this for battery-intensive or data-heavy operations like video uploads,
  /// large file downloads, or extensive data processing. Ensures task only runs
  /// when device is charging and on WiFi (not cellular).
  ///
  /// **Equivalent to:**
  /// ```dart
  /// Constraints(
  ///   requiresUnmeteredNetwork: true,
  ///   requiresCharging: true,
  /// )
  /// ```
  ///
  /// **Use cases:**
  /// - Video upload/download
  /// - Batch photo backup
  /// - Large database sync
  /// - App data backup
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'video-backup',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://cdn.example.com/videos',
  ///     filePath: '/path/to/large-video.mp4',
  ///   ),
  ///   constraints: Constraints.heavyTask,
  /// );
  /// ```
  static const Constraints heavyTask = Constraints(
    requiresUnmeteredNetwork: true,
    requiresCharging: true,
  );

  /// No constraints - task can run anytime.
  ///
  /// Use this for tasks that should run as soon as possible regardless of
  /// network, battery, or charging state. Be cautious as this can impact
  /// battery life and use cellular data.
  ///
  /// **Equivalent to:** `Constraints()`
  ///
  /// **When to use:**
  /// - Critical user-initiated actions
  /// - Time-sensitive operations
  /// - Emergency tasks
  /// - Local-only operations (no network needed)
  ///
  /// **When NOT to use:**
  /// - Network-dependent tasks → Use `networkRequired`
  /// - Large uploads/downloads → Use `heavyTask`
  /// - Background maintenance → Use custom constraints
  ///
  /// ```dart
  /// // Critical local operation - run immediately
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'emergency-save',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: DartWorker(callbackId: 'saveToLocalDb'),
  ///   constraints: Constraints.none,
  /// );
  /// ```
  static const Constraints none = Constraints();

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() => {
        'requiresNetwork': requiresNetwork,
        'requiresUnmeteredNetwork': requiresUnmeteredNetwork,
        'requiresCharging': requiresCharging,
        'requiresDeviceIdle': requiresDeviceIdle,
        'requiresBatteryNotLow': requiresBatteryNotLow,
        'requiresStorageNotLow': requiresStorageNotLow,
        'allowWhileIdle': allowWhileIdle,
        'isHeavyTask': isHeavyTask,
        'qos': qos.name,
        'exactAlarmIOSBehavior': exactAlarmIOSBehavior.name,
        'backoffPolicy': backoffPolicy.name,
        'backoffDelayMs': backoffDelayMs,
        'systemConstraints': systemConstraints.map((c) => c.name).toList(),
        'bgTaskType': bgTaskType?.name,
        'foregroundServiceType': foregroundServiceType?.name,
      };

  /// Create from map.
  factory Constraints.fromMap(Map<String, dynamic> map) => Constraints(
        requiresNetwork: map['requiresNetwork'] as bool? ?? false,
        requiresUnmeteredNetwork:
            map['requiresUnmeteredNetwork'] as bool? ?? false,
        requiresCharging: map['requiresCharging'] as bool? ?? false,
        requiresDeviceIdle: map['requiresDeviceIdle'] as bool? ?? false,
        requiresBatteryNotLow: map['requiresBatteryNotLow'] as bool? ?? false,
        requiresStorageNotLow: map['requiresStorageNotLow'] as bool? ?? false,
        allowWhileIdle: map['allowWhileIdle'] as bool? ?? false,
        isHeavyTask: map['isHeavyTask'] as bool? ?? false,
        qos: QoS.values.firstWhere(
          (e) => e.name == map['qos'],
          orElse: () => QoS.background,
        ),
        exactAlarmIOSBehavior: ExactAlarmIOSBehavior.values.firstWhere(
          (e) => e.name == map['exactAlarmIOSBehavior'],
          orElse: () => ExactAlarmIOSBehavior.showNotification,
        ),
        backoffPolicy: BackoffPolicy.values.firstWhere(
          (e) => e.name == map['backoffPolicy'],
          orElse: () => BackoffPolicy.exponential,
        ),
        backoffDelayMs: map['backoffDelayMs'] as int? ?? 30000,
        systemConstraints: (map['systemConstraints'] as List<dynamic>?)
                ?.map((name) => SystemConstraint.values
                    .firstWhere((e) => e.name == name))
                .toSet() ??
            {},
        bgTaskType: map['bgTaskType'] != null
            ? BGTaskType.values
                .firstWhere((e) => e.name == map['bgTaskType'])
            : null,
        foregroundServiceType: map['foregroundServiceType'] != null
            ? ForegroundServiceType.values
                .firstWhere((e) => e.name == map['foregroundServiceType'])
            : null,
      );

  /// Create a copy with updated values.
  Constraints copyWith({
    bool? requiresNetwork,
    bool? requiresUnmeteredNetwork,
    bool? requiresCharging,
    bool? requiresDeviceIdle,
    bool? requiresBatteryNotLow,
    bool? requiresStorageNotLow,
    bool? allowWhileIdle,
    bool? isHeavyTask,
    QoS? qos,
    ExactAlarmIOSBehavior? exactAlarmIOSBehavior,
    BackoffPolicy? backoffPolicy,
    int? backoffDelayMs,
    Set<SystemConstraint>? systemConstraints,
    BGTaskType? bgTaskType,
    ForegroundServiceType? foregroundServiceType,
  }) =>
      Constraints(
        requiresNetwork: requiresNetwork ?? this.requiresNetwork,
        requiresUnmeteredNetwork:
            requiresUnmeteredNetwork ?? this.requiresUnmeteredNetwork,
        requiresCharging: requiresCharging ?? this.requiresCharging,
        requiresDeviceIdle: requiresDeviceIdle ?? this.requiresDeviceIdle,
        requiresBatteryNotLow:
            requiresBatteryNotLow ?? this.requiresBatteryNotLow,
        requiresStorageNotLow:
            requiresStorageNotLow ?? this.requiresStorageNotLow,
        allowWhileIdle: allowWhileIdle ?? this.allowWhileIdle,
        isHeavyTask: isHeavyTask ?? this.isHeavyTask,
        qos: qos ?? this.qos,
        exactAlarmIOSBehavior:
            exactAlarmIOSBehavior ?? this.exactAlarmIOSBehavior,
        backoffPolicy: backoffPolicy ?? this.backoffPolicy,
        backoffDelayMs: backoffDelayMs ?? this.backoffDelayMs,
        systemConstraints: systemConstraints ?? this.systemConstraints,
        bgTaskType: bgTaskType ?? this.bgTaskType,
        foregroundServiceType:
            foregroundServiceType ?? this.foregroundServiceType,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Constraints &&
          requiresNetwork == other.requiresNetwork &&
          requiresUnmeteredNetwork == other.requiresUnmeteredNetwork &&
          requiresCharging == other.requiresCharging &&
          requiresDeviceIdle == other.requiresDeviceIdle &&
          requiresBatteryNotLow == other.requiresBatteryNotLow &&
          requiresStorageNotLow == other.requiresStorageNotLow &&
          allowWhileIdle == other.allowWhileIdle &&
          isHeavyTask == other.isHeavyTask &&
          qos == other.qos &&
          exactAlarmIOSBehavior == other.exactAlarmIOSBehavior &&
          backoffPolicy == other.backoffPolicy &&
          backoffDelayMs == other.backoffDelayMs;

  @override
  int get hashCode => Object.hash(
        requiresNetwork,
        requiresUnmeteredNetwork,
        requiresCharging,
        requiresDeviceIdle,
        requiresBatteryNotLow,
        requiresStorageNotLow,
        allowWhileIdle,
        isHeavyTask,
        qos,
        exactAlarmIOSBehavior,
        backoffPolicy,
        backoffDelayMs,
      );

  @override
  String toString() => 'Constraints('
      'network: $requiresNetwork, '
      'unmetered: $requiresUnmeteredNetwork, '
      'charging: $requiresCharging, '
      'idle: $requiresDeviceIdle, '
      'batteryOk: $requiresBatteryNotLow, '
      'storageOk: $requiresStorageNotLow, '
      'allowIdle: $allowWhileIdle, '
      'heavy: $isHeavyTask, '
      'qos: ${qos.name}, '
      'iosAlarm: ${exactAlarmIOSBehavior.name}, '
      'backoff: ${backoffPolicy.name}, '
      'backoffDelay: ${backoffDelayMs}ms)';
}
