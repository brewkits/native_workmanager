/// Defines when a task should be executed.
sealed class TaskTrigger {
  const TaskTrigger();

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap();

  /// Execute once after an optional delay.
  ///
  /// The most common trigger type. Schedules a task to run once, either
  /// immediately or after a specified delay.
  ///
  /// ## Immediate Execution
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'immediate-task',
  ///   trigger: TaskTrigger.oneTime(),
  ///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/ping'),
  /// );
  /// ```
  ///
  /// ## Delayed Execution
  ///
  /// ```dart
  /// // Execute after 5 minutes
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'delayed-task',
  ///   trigger: TaskTrigger.oneTime(Duration(minutes: 5)),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  /// );
  ///
  /// // Execute after 1 hour
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'hourly-reminder',
  ///   trigger: TaskTrigger.oneTime(Duration(hours: 1)),
  ///   worker: DartWorker(callbackId: 'sendNotification'),
  /// );
  /// ```
  ///
  /// ## Platform Behavior
  ///
  /// **Android:**
  /// - Immediate tasks (no delay) execute as soon as constraints are met
  /// - Delayed tasks use WorkManager's initial delay
  /// - Timing is approximate (not exact)
  /// - OS may defer execution to optimize battery
  ///
  /// **iOS:**
  /// - Uses BGProcessingTask for background execution
  /// - Execution timing is opportunistic (OS decides)
  /// - May not run immediately even with zero delay
  /// - Requires app to be in background for reasonable time
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** expect exact timing (use `exact()` for that)
  /// ❌ **Don't** use for time-critical operations
  /// ✅ **Do** use for most one-time background tasks
  /// ✅ **Do** add appropriate constraints
  ///
  /// ## See Also
  ///
  /// - [periodic] - For recurring tasks
  /// - [exact] - For alarm-style exact timing
  /// - [windowed] - For execution within a time range
  const factory TaskTrigger.oneTime([Duration initialDelay]) = OneTimeTrigger;

  /// Execute periodically at a fixed interval.
  ///
  /// Schedules a task to run repeatedly at the specified interval. Perfect for
  /// data syncing, periodic updates, or scheduled cleanup operations.
  ///
  /// **Important:** Minimum interval is 15 minutes on Android (OS limitation).
  ///
  /// ## Basic Periodic Task
  ///
  /// ```dart
  /// // Sync every hour
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'hourly-sync',
  ///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  ///   constraints: Constraints.networkRequired,
  /// );
  /// ```
  ///
  /// ## Daily Cleanup
  ///
  /// ```dart
  /// // Clean up cache daily at opportune time
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'daily-cleanup',
  ///   trigger: TaskTrigger.periodic(Duration(days: 1)),
  ///   worker: DartWorker(callbackId: 'cleanupCache'),
  /// );
  /// ```
  ///
  /// ## With Flex Interval (Android)
  ///
  /// ```dart
  /// // Sync every 6 hours, with 30-minute flex window
  /// // Task can run between 5.5 and 6 hours after last execution
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'flexible-sync',
  ///   trigger: TaskTrigger.periodic(
  ///     Duration(hours: 6),
  ///     flexInterval: Duration(minutes: 30),
  ///   ),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  /// );
  /// ```
  ///
  /// ## Minimum Interval Example
  ///
  /// ```dart
  /// // Minimum allowed interval (15 minutes)
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'frequent-check',
  ///   trigger: TaskTrigger.periodic(Duration(minutes: 15)),
  ///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/status'),
  /// );
  /// ```
  ///
  /// ## Parameters
  ///
  /// **[interval]** - Time between executions.
  /// - Must be at least 15 minutes on Android
  /// - Throws `ArgumentError` if less than 15 minutes
  /// - iOS uses this as a hint (not guaranteed)
  ///
  /// **[flexInterval]** *(optional)* - Flex time window (Android only).
  /// - Allows Android to optimize execution time within this window
  /// - Example: 6-hour interval with 30-min flex = execute between 5.5-6 hours
  /// - Improves battery life by batching work
  /// - Ignored on iOS
  ///
  /// ## Platform Behavior
  ///
  /// **Android:**
  /// - Uses WorkManager PeriodicWorkRequest
  /// - Minimum interval: 15 minutes (OS limitation)
  /// - Flex interval helps Android optimize battery usage
  /// - May defer execution if device is in Doze mode
  /// - Timing is approximate, not exact
  ///
  /// **iOS:**
  /// - Uses BGAppRefreshTask
  /// - Interval is a suggestion, not guaranteed
  /// - OS decides actual execution timing
  /// - May run less frequently to save battery
  /// - Best effort scheduling (no guarantees)
  ///
  /// ## When to Use
  ///
  /// ✅ **Use periodic trigger for:**
  /// - Data synchronization every N hours
  /// - Periodic content updates
  /// - Scheduled cleanup operations
  /// - Background refresh of local data
  ///
  /// ❌ **Don't use periodic for:**
  /// - Intervals < 15 minutes (will throw error)
  /// - Time-sensitive operations (use `exact` instead)
  /// - User-initiated actions (use `oneTime` instead)
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** use intervals less than 15 minutes
  /// ❌ **Don't** expect exact timing (OS optimizes for battery)
  /// ❌ **Don't** rely on precise scheduling on iOS
  /// ❌ **Don't** schedule too many periodic tasks (battery drain)
  /// ✅ **Do** use flexInterval on Android for better battery life
  /// ✅ **Do** combine with network constraints for data sync
  /// ✅ **Do** handle cases where task doesn't run on time
  ///
  /// ## Battery Impact
  ///
  /// Periodic tasks can impact battery life:
  /// - Use longest acceptable interval
  /// - Add flex interval on Android
  /// - Use appropriate constraints (WiFi, charging)
  /// - Keep task execution time short
  ///
  /// ## See Also
  ///
  /// - [oneTime] - For one-time execution
  /// - [windowed] - For execution within a time window
  /// - [Constraints] - To optimize battery usage
  const factory TaskTrigger.periodic(
    Duration interval, {
    Duration? flexInterval,
  }) = PeriodicTrigger;

  /// Execute at an exact time (alarm-style).
  ///
  /// Schedules a task to run at a specific DateTime. Unlike oneTime, this
  /// attempts to execute at the EXACT specified time, like an alarm.
  ///
  /// **⚠️ Platform Limitations:** Exact timing has significant limitations,
  /// especially on iOS. Consider if you really need exact timing before using.
  ///
  /// ## Schedule for Specific Time
  ///
  /// ```dart
  /// // Schedule for tomorrow at 9 AM
  /// final tomorrow9am = DateTime.now()
  ///     .add(Duration(days: 1))
  ///     .copyWith(hour: 9, minute: 0, second: 0);
  ///
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'morning-reminder',
  ///   trigger: TaskTrigger.exact(tomorrow9am),
  ///   worker: DartWorker(callbackId: 'sendReminder'),
  /// );
  /// ```
  ///
  /// ## Schedule for 2 Hours from Now
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'delayed-notification',
  ///   trigger: TaskTrigger.exact(
  ///     DateTime.now().add(Duration(hours: 2)),
  ///   ),
  ///   worker: DartWorker(callbackId: 'showNotification'),
  /// );
  /// ```
  ///
  /// ## Platform Behavior & Limitations
  ///
  /// **Android (API 31+):**
  /// - Uses AlarmManager for exact timing
  /// - **Requires SCHEDULE_EXACT_ALARM permission** (auto-granted)
  /// - User can revoke permission in Settings
  /// - Task may fail if permission revoked
  /// - Battery optimization may still defer task
  /// - Most reliable of the two platforms
  ///
  /// **iOS:**
  /// - **Severely limited - NOT recommended**
  /// - Cannot guarantee code execution at exact time
  /// - Uses UNNotification as workaround
  /// - Requires user interaction to run code
  /// - Not suitable for background tasks
  /// - Consider using `oneTime` or `windowed` instead
  ///
  /// ## When to Use
  ///
  /// ✅ **Use exact trigger for (Android only):**
  /// - Alarm clock functionality
  /// - Scheduled reminders
  /// - Time-sensitive operations
  /// - Exact appointment notifications
  ///
  /// ❌ **Don't use exact trigger for:**
  /// - iOS apps (very limited)
  /// - Background data sync (use `periodic` instead)
  /// - Flexible timing tasks (use `oneTime` or `windowed`)
  /// - Battery-sensitive operations
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** rely on this for iOS (use notifications instead)
  /// ❌ **Don't** assume permission is always granted on Android
  /// ❌ **Don't** use for routine background tasks
  /// ❌ **Don't** forget to check if scheduledTime is in future
  /// ✅ **Do** check if time is in future before scheduling
  /// ✅ **Do** handle Android permission denial gracefully
  /// ✅ **Do** consider `oneTime` or `windowed` alternatives
  /// ✅ **Do** use local notifications for UI alerts
  ///
  /// ## Alternative Solutions
  ///
  /// For most use cases, consider these alternatives:
  ///
  /// ```dart
  /// // Instead of exact alarm, use windowed:
  /// TaskTrigger.windowed(
  ///   earliest: Duration(hours: 2),
  ///   latest: Duration(hours: 2, minutes: 15),
  /// )
  ///
  /// // Or use delayed oneTime:
  /// TaskTrigger.oneTime(Duration(hours: 2))
  ///
  /// // For UI notifications, use flutter_local_notifications:
  /// await flutterLocalNotificationsPlugin.zonedSchedule(
  ///   id,
  ///   title,
  ///   body,
  ///   scheduledDateTime,
  ///   notificationDetails,
  /// );
  /// ```
  ///
  /// ## Permission Handling (Android)
  ///
  /// ```dart
  /// // Check if exact alarm permission is available
  /// if (Platform.isAndroid && Build.VERSION.SDK_INT >= 31) {
  ///   final alarmManager = AlarmManager();
  ///   if (!await alarmManager.canScheduleExactAlarms()) {
  ///     // Show dialog explaining need for permission
  ///     // Direct user to settings
  ///   }
  /// }
  /// ```
  ///
  /// ## See Also
  ///
  /// - [oneTime] - For flexible one-time execution
  /// - [windowed] - For execution within a time window
  /// - [periodic] - For recurring tasks
  const factory TaskTrigger.exact(DateTime scheduledTime) = ExactTrigger;

  /// Execute within a time window.
  ///
  /// Schedules a task to run sometime between two time points. More flexible
  /// than exact timing, allowing the OS to optimize battery usage by choosing
  /// the best time within the window.
  ///
  /// ## Execute Between 1-2 Hours from Now
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'flexible-sync',
  ///   trigger: TaskTrigger.windowed(
  ///     earliest: Duration(hours: 1),
  ///     latest: Duration(hours: 2),
  ///   ),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  /// );
  /// ```
  ///
  /// ## Night-Time Processing
  ///
  /// ```dart
  /// // Execute sometime between 2-4 AM (low usage period)
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'night-processing',
  ///   trigger: TaskTrigger.windowed(
  ///     earliest: Duration(hours: 6), // 6 hours from now
  ///     latest: Duration(hours: 8),   // 8 hours from now
  ///   ),
  ///   worker: DartWorker(callbackId: 'processLargeDataset'),
  ///   constraints: Constraints(
  ///     requiresCharging: true,
  ///     requiresWifi: true,
  ///   ),
  /// );
  /// ```
  ///
  /// ## Platform Behavior
  ///
  /// **Android:**
  /// - Uses WorkManager's OneTimeWorkRequest with flex time
  /// - OS chooses optimal execution time within window
  /// - Batches with other work for battery efficiency
  ///
  /// **iOS:**
  /// - Uses BGProcessingTask
  /// - Window is advisory (OS may defer further)
  /// - Best effort scheduling
  ///
  /// ## When to Use
  ///
  /// ✅ **Use windowed trigger for:**
  /// - Flexible data synchronization
  /// - Background processing that isn't time-critical
  /// - Heavy tasks that should run during low-usage periods
  /// - Operations that can benefit from being batched with other work
  ///
  /// ❌ **Don't use windowed for:**
  /// - Time-critical operations
  /// - User-initiated actions (use `oneTime` instead)
  ///
  /// ## See Also
  ///
  /// - [oneTime] - For simple delayed execution
  /// - [exact] - For alarm-style exact timing
  const factory TaskTrigger.windowed({
    required Duration earliest,
    required Duration latest,
  }) = WindowedTrigger;

  /// Execute when a content URI changes (Android only).
  ///
  /// **Android Only:** Monitors Android ContentProvider for changes and triggers
  /// task execution when detected. Perfect for reacting to media changes, contact
  /// updates, or file system modifications.
  ///
  /// **iOS:** Not supported - will return error on enqueue.
  ///
  /// ## Monitor Media Store for New Photos
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'photo-backup',
  ///   trigger: TaskTrigger.contentUri(
  ///     uri: Uri.parse('content://media/external/images/media'),
  ///     triggerForDescendants: true,
  ///   ),
  ///   worker: DartWorker(callbackId: 'backupNewPhotos'),
  ///   constraints: Constraints(requiresWifi: true),
  /// );
  /// ```
  ///
  /// ## Monitor Contact Changes
  ///
  /// ```dart
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'contact-sync',
  ///   trigger: TaskTrigger.contentUri(
  ///     uri: Uri.parse('content://com.android.contacts/contacts'),
  ///     triggerForDescendants: false,
  ///   ),
  ///   worker: NativeWorker.httpSync(url: 'https://api.example.com/contacts/sync'),
  /// );
  /// ```
  ///
  /// ## Common Content URIs
  ///
  /// - **Images:** `content://media/external/images/media`
  /// - **Videos:** `content://media/external/video/media`
  /// - **Audio:** `content://media/external/audio/media`
  /// - **Downloads:** `content://downloads/public_downloads`
  /// - **Contacts:** `content://com.android.contacts/contacts`
  ///
  /// ## Parameters
  ///
  /// **[triggerForDescendants]** - Monitor child URIs too.
  /// - `true`: Triggers for changes in descendant URIs
  /// - `false`: Only triggers for exact URI match
  /// - Example: With `content://media/external` and `true`, changes to
  ///   `content://media/external/images/media/123` will also trigger
  ///
  /// ## Platform Notes
  ///
  /// **Android:** Uses WorkManager ContentUriTriggers
  /// **iOS:** ❌ Not supported - task will be rejected
  ///
  /// ## When to Use
  ///
  /// ✅ **Use contentUri for (Android only):**
  /// - Auto-backup new photos/videos
  /// - React to contact changes
  /// - Monitor downloads folder
  /// - Sync when media is added
  ///
  /// ## Common Pitfalls
  ///
  /// ❌ **Don't** use on iOS (will fail)
  /// ❌ **Don't** forget `triggerForDescendants` for broad monitoring
  /// ✅ **Do** add platform check before using
  /// ✅ **Do** combine with appropriate constraints
  ///
  /// ## See Also
  ///
  /// - [oneTime] - For one-time execution
  /// - [periodic] - For time-based recurring tasks
  const factory TaskTrigger.contentUri({
    required Uri uri,
    bool triggerForDescendants,
  }) = ContentUriTrigger;

  /// Execute when battery is NOT low (Android only).
  ///
  /// **Android Only:** Triggers when battery level is above the "low" threshold
  /// (typically above 15%). Useful for battery-friendly operations.
  ///
  /// **iOS:** Not supported - returns REJECTED_OS_POLICY.
  ///
  /// ```dart
  /// // Schedule backup that only runs when battery is okay
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'safe-backup',
  ///   trigger: TaskTrigger.batteryOkay(),
  ///   worker: NativeWorker.httpUpload(
  ///     url: 'https://api.example.com/backup',
  ///     filePath: '/data/backup.zip',
  ///   ),
  /// );
  /// ```
  ///
  /// **Note:** Consider using `Constraints(requiresBatteryNotLow: true)` with
  /// `oneTime` trigger instead for more control.
  const factory TaskTrigger.batteryOkay() = BatteryOkayTrigger;

  /// Execute when battery IS low (Android only).
  ///
  /// **Android Only:** Triggers when battery drops below 15%. Useful for warning
  /// users or reducing background activity.
  ///
  /// **iOS:** Not supported - returns REJECTED_OS_POLICY.
  ///
  /// ```dart
  /// // Notify user to charge device
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'low-battery-warning',
  ///   trigger: TaskTrigger.batteryLow(),
  ///   worker: DartWorker(callbackId: 'showLowBatteryNotification'),
  /// );
  /// ```
  const factory TaskTrigger.batteryLow() = BatteryLowTrigger;

  /// Execute when device is idle (Android only).
  ///
  /// **Android Only:** Triggers when device enters idle/Doze mode (screen off,
  /// stationary, not charging). Perfect for maintenance tasks.
  ///
  /// **iOS:** Not supported - returns REJECTED_OS_POLICY.
  ///
  /// ```dart
  /// // Database maintenance during idle time
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'db-maintenance',
  ///   trigger: TaskTrigger.deviceIdle(),
  ///   worker: DartWorker(callbackId: 'optimizeDatabase'),
  /// );
  /// ```
  ///
  /// **Use case:** Database vacuuming, cache cleanup, index optimization.
  const factory TaskTrigger.deviceIdle() = DeviceIdleTrigger;

  /// Execute when storage is low (Android only).
  ///
  /// **Android Only:** Triggers when device storage drops below threshold.
  /// Useful for cleanup operations.
  ///
  /// **iOS:** Not supported - returns REJECTED_OS_POLICY.
  ///
  /// ```dart
  /// // Auto-cleanup when storage is low
  /// await NativeWorkManager.enqueue(
  ///   taskId: 'emergency-cleanup',
  ///   trigger: TaskTrigger.storageLow(),
  ///   worker: DartWorker(callbackId: 'deleteOldCache'),
  /// );
  /// ```
  ///
  /// **Use case:** Delete old files, clear caches, compress data.
  const factory TaskTrigger.storageLow() = StorageLowTrigger;
}

/// Execute once after an optional delay.
class OneTimeTrigger extends TaskTrigger {
  const OneTimeTrigger([this.initialDelay = Duration.zero]);

  /// Delay before execution.
  final Duration initialDelay;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'oneTime',
        'initialDelayMs': initialDelay.inMilliseconds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OneTimeTrigger && initialDelay == other.initialDelay;

  @override
  int get hashCode => initialDelay.hashCode;

  @override
  String toString() => 'TaskTrigger.oneTime($initialDelay)';
}

/// Execute periodically at a fixed interval.
class PeriodicTrigger extends TaskTrigger {
  const PeriodicTrigger(this.interval, {this.flexInterval});

  /// Interval between executions.
  final Duration interval;

  /// Flex time window for execution.
  final Duration? flexInterval;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'periodic',
        'intervalMs': interval.inMilliseconds,
        'flexMs': flexInterval?.inMilliseconds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodicTrigger &&
          interval == other.interval &&
          flexInterval == other.flexInterval;

  @override
  int get hashCode => Object.hash(interval, flexInterval);

  @override
  String toString() => 'TaskTrigger.periodic($interval, flex: $flexInterval)';
}

/// Execute at an exact time.
class ExactTrigger extends TaskTrigger {
  const ExactTrigger(this.scheduledTime);

  /// The exact time to execute.
  final DateTime scheduledTime;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'exact',
        'scheduledTimeMs': scheduledTime.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExactTrigger && scheduledTime == other.scheduledTime;

  @override
  int get hashCode => scheduledTime.hashCode;

  @override
  String toString() => 'TaskTrigger.exact($scheduledTime)';
}

/// Execute within a time window.
class WindowedTrigger extends TaskTrigger {
  const WindowedTrigger({
    required this.earliest,
    required this.latest,
  });

  /// Earliest time to start.
  final Duration earliest;

  /// Latest time to complete.
  final Duration latest;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'windowed',
        'earliestMs': earliest.inMilliseconds,
        'latestMs': latest.inMilliseconds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowedTrigger &&
          earliest == other.earliest &&
          latest == other.latest;

  @override
  int get hashCode => Object.hash(earliest, latest);

  @override
  String toString() => 'TaskTrigger.windowed($earliest - $latest)';
}

/// Execute when a content URI changes (Android only).
class ContentUriTrigger extends TaskTrigger {
  const ContentUriTrigger({
    required this.uri,
    this.triggerForDescendants = false,
  });

  /// Content URI to observe.
  ///
  /// Common examples:
  /// - `Uri.parse('content://media/external/images/media')` - MediaStore images
  /// - `Uri.parse('content://media/external/video/media')` - MediaStore videos
  /// - `Uri.parse('content://com.android.contacts/contacts')` - Contacts
  final Uri uri;

  /// If true, triggers for changes in descendant URIs as well.
  ///
  /// Example: If uri is `content://media/external` and this is true,
  /// changes to `content://media/external/images/media/123` will also trigger.
  final bool triggerForDescendants;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'contentUri',
        'uriString': uri.toString(),
        'triggerForDescendants': triggerForDescendants,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentUriTrigger &&
          uri == other.uri &&
          triggerForDescendants == other.triggerForDescendants;

  @override
  int get hashCode => Object.hash(uri, triggerForDescendants);

  @override
  String toString() =>
      'TaskTrigger.contentUri($uri, descendants: $triggerForDescendants)';
}

/// Execute when battery is NOT low (Android only).
class BatteryOkayTrigger extends TaskTrigger {
  const BatteryOkayTrigger();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'batteryOkay',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BatteryOkayTrigger;

  @override
  int get hashCode => 'batteryOkay'.hashCode;

  @override
  String toString() => 'TaskTrigger.batteryOkay()';
}

/// Execute when battery IS low (Android only).
class BatteryLowTrigger extends TaskTrigger {
  const BatteryLowTrigger();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'batteryLow',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BatteryLowTrigger;

  @override
  int get hashCode => 'batteryLow'.hashCode;

  @override
  String toString() => 'TaskTrigger.batteryLow()';
}

/// Execute when device is idle (Android only).
class DeviceIdleTrigger extends TaskTrigger {
  const DeviceIdleTrigger();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'deviceIdle',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceIdleTrigger;

  @override
  int get hashCode => 'deviceIdle'.hashCode;

  @override
  String toString() => 'TaskTrigger.deviceIdle()';
}

/// Execute when storage is low (Android only).
class StorageLowTrigger extends TaskTrigger {
  const StorageLowTrigger();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'storageLow',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StorageLowTrigger;

  @override
  int get hashCode => 'storageLow'.hashCode;

  @override
  String toString() => 'TaskTrigger.storageLow()';
}
