# Firebase Integration Guide

Integration guide for using native_workmanager with **Firebase** - Analytics, Crashlytics, Remote Config, and more.

---

## Overview

Firebase provides essential services for mobile apps:
- **Analytics** - Event tracking and user behavior
- **Crashlytics** - Crash reporting and diagnostics
- **Remote Config** - Dynamic configuration
- **Cloud Messaging** - Push notifications
- **Firestore** - Cloud database sync

This guide shows how to integrate Firebase with native_workmanager for background operations.

---

## Installation

```yaml
dependencies:
  native_workmanager: ^1.0.0
  firebase_core: ^2.24.0
  firebase_analytics: ^10.7.0
  firebase_crashlytics: ^3.4.0
  firebase_remote_config: ^4.3.0
  cloud_firestore: ^4.13.0
```

```bash
flutter pub get
```

**Platform Setup:**
- Follow [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup)
- Add google-services.json (Android) and GoogleService-Info.plist (iOS)
- Configure Firebase in your project

---

## Pattern 1: Analytics Event Batching

Send analytics events in background to reduce battery usage.

### Implementation

```dart
import 'package:native_workmanager/native_workmanager.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NativeWorkManager.initialize();

  // Register callback
  NativeWorkManager.registerCallback('analyticsSync', analyticsSyncCallback);

  runApp(MyApp());
}

@pragma('vm:entry-point')
Future<void> analyticsSyncCallback(String? input) async {
  // Initialize Firebase in background isolate
  await Firebase.initializeApp();

  final analytics = FirebaseAnalytics.instance;

  // Retrieve queued events from local storage
  final events = await getQueuedAnalyticsEvents();

  for (final event in events) {
    await analytics.logEvent(
      name: event.name,
      parameters: event.parameters,
    );
  }

  // Clear queue after successful sync
  await clearAnalyticsQueue();

  print('Synced ${events.length} analytics events');
}

// Schedule periodic sync
Future<void> scheduleAnalyticsSync() async {
  await NativeWorkManager.enqueue(
    taskId: 'analytics-sync',
    trigger: TaskTrigger.periodic(Duration(hours: 6)),
    worker: DartWorker(
      callbackId: 'analyticsSync',
      autoDispose: true,  // Dispose after completion
    ),
    constraints: Constraints(requiresNetwork: true),
  );
}
```

### Event Queueing System

```dart
// Store events locally when offline or batching
class AnalyticsQueue {
  static final List<AnalyticsEvent> _queue = [];

  static Future<void> queueEvent(String name, Map<String, dynamic> params) async {
    _queue.add(AnalyticsEvent(
      name: name,
      parameters: params,
      timestamp: DateTime.now(),
    ));

    // Save to persistent storage (SharedPreferences, Hive, etc.)
    await _saveQueue();

    // Trigger immediate sync if queue is large
    if (_queue.length >= 50) {
      await triggerAnalyticsSync();
    }
  }

  static Future<List<AnalyticsEvent>> getQueuedAnalyticsEvents() async {
    // Load from persistent storage
    return await _loadQueue();
  }

  static Future<void> clearAnalyticsQueue() async {
    _queue.clear();
    await _clearStorage();
  }

  static Future<void> _saveQueue() async {
    // Implementation: Save to SharedPreferences/Hive
  }

  static Future<List<AnalyticsEvent>> _loadQueue() async {
    // Implementation: Load from SharedPreferences/Hive
    return [];
  }

  static Future<void> _clearStorage() async {
    // Implementation: Clear storage
  }
}

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
    required this.timestamp,
  });
}

Future<void> triggerAnalyticsSync() async {
  await NativeWorkManager.enqueue(
    taskId: 'analytics-sync-immediate',
    trigger: TaskTrigger.oneTime(),
    worker: DartWorker(callbackId: 'analyticsSync'),
    constraints: Constraints(requiresNetwork: true),
  );
}
```

---

## Pattern 2: Crashlytics Integration

Capture crashes and errors in background tasks.

### Implementation

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

@pragma('vm:entry-point')
Future<void> safeSyncCallback(String? input) async {
  await Firebase.initializeApp();

  final crashlytics = FirebaseCrashlytics.instance;

  // Set custom keys for debugging
  crashlytics.setCustomKey('task_id', 'background-sync');
  crashlytics.setCustomKey('task_input', input ?? 'none');
  crashlytics.setCustomKey('timestamp', DateTime.now().toIso8601String());

  try {
    // Your background task logic
    await performBackgroundSync();

    // Log successful completion
    crashlytics.log('Background sync completed successfully');
  } catch (error, stackTrace) {
    // Log error to Crashlytics
    crashlytics.recordError(
      error,
      stackTrace,
      reason: 'Background sync failed',
      fatal: false,
    );

    // Re-throw to trigger retry
    rethrow;
  }
}

Future<void> performBackgroundSync() async {
  // Your sync logic here
}
```

### Error Breadcrumbs

```dart
@pragma('vm:entry-point')
Future<void> syncWithBreadcrumbs(String? input) async {
  await Firebase.initializeApp();

  final crashlytics = FirebaseCrashlytics.instance;

  crashlytics.log('Started background sync');

  try {
    crashlytics.log('Fetching data from API...');
    final data = await fetchData();

    crashlytics.log('Processing ${data.length} items...');
    await processData(data);

    crashlytics.log('Saving to database...');
    await saveData(data);

    crashlytics.log('Sync completed successfully');
  } catch (error, stackTrace) {
    crashlytics.log('ERROR: Sync failed at step');
    await crashlytics.recordError(error, stackTrace);
    rethrow;
  }
}
```

---

## Pattern 3: Remote Config Sync

Fetch Remote Config values in background.

### Implementation

```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';

@pragma('vm:entry-point')
Future<void> remoteConfigSyncCallback(String? input) async {
  await Firebase.initializeApp();

  final remoteConfig = FirebaseRemoteConfig.instance;

  // Configure settings
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: Duration(minutes: 1),
    minimumFetchInterval: Duration(hours: 1),
  ));

  try {
    // Fetch and activate
    await remoteConfig.fetchAndActivate();

    // Get values
    final syncInterval = remoteConfig.getInt('sync_interval_minutes');
    final enabledFeatures = remoteConfig.getString('enabled_features');

    print('Remote Config synced:');
    print('  Sync interval: $syncInterval minutes');
    print('  Enabled features: $enabledFeatures');

    // Update local configuration
    await updateAppConfig(syncInterval, enabledFeatures);
  } catch (e) {
    print('Remote Config sync failed: $e');
    rethrow;
  }
}

// Schedule periodic config sync
Future<void> scheduleRemoteConfigSync() async {
  await NativeWorkManager.enqueue(
    taskId: 'remote-config-sync',
    trigger: TaskTrigger.periodic(Duration(hours: 6)),
    worker: DartWorker(
      callbackId: 'remoteConfigSync',
      autoDispose: true,
    ),
    constraints: Constraints(requiresNetwork: true),
  );
}

Future<void> updateAppConfig(int interval, String features) async {
  // Save to local storage for app to use
}
```

---

## Pattern 4: Firestore Background Sync

Sync Firestore data in background.

### Implementation

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> firestoreSyncCallback(String? input) async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  try {
    // Fetch data that changed since last sync
    final lastSyncTime = await getLastSyncTime();

    final snapshot = await firestore
        .collection('user_data')
        .where('updated_at', isGreaterThan: lastSyncTime)
        .get();

    print('Found ${snapshot.docs.length} documents to sync');

    // Process documents
    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Save to local database (Hive, SQLite, etc.)
      await saveToLocalDatabase(doc.id, data);
    }

    // Update last sync time
    await saveLastSyncTime(DateTime.now());

    print('Firestore sync completed');
  } catch (e) {
    print('Firestore sync failed: $e');
    rethrow;
  }
}

Future<DateTime> getLastSyncTime() async {
  // Load from local storage
  return DateTime.now().subtract(Duration(hours: 1));
}

Future<void> saveLastSyncTime(DateTime time) async {
  // Save to local storage
}

Future<void> saveToLocalDatabase(String id, Map<String, dynamic> data) async {
  // Implementation: Save to Hive/SQLite
}
```

### Bi-directional Sync

```dart
@pragma('vm:entry-point')
Future<void> bidirectionalSyncCallback(String? input) async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  // 1. Upload local changes to Firestore
  final localChanges = await getLocalChanges();

  for (final change in localChanges) {
    await firestore.collection('user_data').doc(change.id).set(
      change.data,
      SetOptions(merge: true),
    );
  }

  print('Uploaded ${localChanges.length} local changes');

  // 2. Download remote changes from Firestore
  final lastSyncTime = await getLastSyncTime();

  final remoteChanges = await firestore
      .collection('user_data')
      .where('updated_at', isGreaterThan: lastSyncTime)
      .get();

  for (final doc in remoteChanges.docs) {
    await saveToLocalDatabase(doc.id, doc.data());
  }

  print('Downloaded ${remoteChanges.docs.length} remote changes');

  await saveLastSyncTime(DateTime.now());
}

Future<List<LocalChange>> getLocalChanges() async {
  // Load pending changes from local database
  return [];
}

class LocalChange {
  final String id;
  final Map<String, dynamic> data;

  LocalChange({required this.id, required this.data});
}
```

---

## Pattern 5: FCM Token Refresh

Refresh Firebase Cloud Messaging tokens in background.

### Implementation

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> fcmTokenRefreshCallback(String? input) async {
  await Firebase.initializeApp();

  final messaging = FirebaseMessaging.instance;

  try {
    // Get current token
    final token = await messaging.getToken();

    if (token != null) {
      print('FCM Token: $token');

      // Send token to your backend
      await sendTokenToBackend(token);

      // Save locally
      await saveTokenLocally(token);
    }
  } catch (e) {
    print('FCM token refresh failed: $e');
    rethrow;
  }
}

Future<void> sendTokenToBackend(String token) async {
  // Send to your API
  await NativeWorker.httpRequest(
    url: 'https://api.example.com/fcm-token',
    method: HttpMethod.post,
    body: '{"token": "$token"}',
  );
}

Future<void> saveTokenLocally(String token) async {
  // Save to SharedPreferences
}
```

---

## Best Practices

### 1. Always Initialize Firebase in Background

```dart
@pragma('vm:entry-point')
Future<void> firebaseCallback(String? input) async {
  // CRITICAL: Initialize Firebase in background isolate
  await Firebase.initializeApp();

  // Now use Firebase services
  final analytics = FirebaseAnalytics.instance;
  // ...
}
```

### 2. Handle Offline Scenarios

```dart
@pragma('vm:entry-point')
Future<void> offlineAwareCallback(String? input) async {
  await Firebase.initializeApp();

  try {
    await firestore.collection('data').get();
  } on FirebaseException catch (e) {
    if (e.code == 'unavailable') {
      // Network unavailable, retry later
      print('Offline, will retry');
      return;
    }
    rethrow;
  }
}
```

### 3. Use Batching for Performance

```dart
// Batch analytics events (send every 6 hours)
await NativeWorkManager.enqueue(
  taskId: 'analytics-batch',
  trigger: TaskTrigger.periodic(Duration(hours: 6)),
  worker: DartWorker(callbackId: 'analyticsSync'),
);

// Batch Firestore writes
final batch = firestore.batch();
for (final change in changes) {
  batch.set(firestore.collection('data').doc(change.id), change.data);
}
await batch.commit();
```

### 4. Dispose Resources

```dart
await NativeWorkManager.enqueue(
  taskId: 'firebase-sync',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(
    callbackId: 'firebaseSync',
    autoDispose: true,  // Dispose Flutter Engine after completion
  ),
);
```

---

## Performance Considerations

### Memory Usage

| Pattern | Memory | Notes |
|---------|--------|-------|
| **Analytics batching** | 50-70MB | Dart worker required |
| **Crashlytics logging** | 50-65MB | Lightweight |
| **Remote Config sync** | 50-80MB | One-time fetch |
| **Firestore sync (small)** | 60-90MB | <100 documents |
| **Firestore sync (large)** | 100-150MB | 1000+ documents |

**Optimization:** Use `autoDispose: true` to free memory after completion.

### Battery Impact

- **Analytics batching:** Minimal (periodic, short-lived)
- **Firestore sync:** Moderate (network + processing)
- **Remote Config:** Low (infrequent, small payload)

**Best Practice:** Use constraints to sync only when charging or on WiFi.

```dart
constraints: Constraints(
  requiresNetwork: true,
  requiresCharging: true,  // Large Firestore syncs
),
```

---

## Troubleshooting

### Issue: "Firebase not initialized"

**Solution:** Always call `Firebase.initializeApp()` in background callback:

```dart
@pragma('vm:entry-point')
Future<void> callback(String? input) async {
  await Firebase.initializeApp();  // Required!
  // ...
}
```

### Issue: Crashlytics not reporting background errors

**Solution:** Explicitly record errors:

```dart
try {
  await sync();
} catch (error, stackTrace) {
  await FirebaseCrashlytics.instance.recordError(error, stackTrace);
  rethrow;
}
```

### Issue: Firestore permission denied

**Solution:** Check Firestore security rules allow background access:

```javascript
// Firestore rules
service cloud.firestore {
  match /databases/{database}/documents {
    match /user_data/{userId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Ensure user is authenticated before background sync.

---

## Example: Complete Sync Service

```dart
import 'package:native_workmanager/native_workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseSyncService {
  static Future<void> initialize() async {
    await NativeWorkManager.initialize();

    // Register callbacks
    NativeWorkManager.registerCallback('analyticsSync', _analyticsSync);
    NativeWorkManager.registerCallback('firestoreSync', _firestoreSync);
    NativeWorkManager.registerCallback('configSync', _configSync);

    // Schedule tasks
    await _scheduleTasks();
  }

  static Future<void> _scheduleTasks() async {
    // Analytics sync every 6 hours
    await NativeWorkManager.enqueue(
      taskId: 'analytics-sync',
      trigger: TaskTrigger.periodic(Duration(hours: 6)),
      worker: DartWorker(
        callbackId: 'analyticsSync',
        autoDispose: true,
      ),
      constraints: Constraints(requiresNetwork: true),
    );

    // Firestore sync every 1 hour
    await NativeWorkManager.enqueue(
      taskId: 'firestore-sync',
      trigger: TaskTrigger.periodic(Duration(hours: 1)),
      worker: DartWorker(
        callbackId: 'firestoreSync',
        autoDispose: true,
      ),
      constraints: Constraints(requiresNetwork: true),
    );

    // Remote Config sync daily
    await NativeWorkManager.enqueue(
      taskId: 'config-sync',
      trigger: TaskTrigger.periodic(Duration(hours: 24)),
      worker: DartWorker(
        callbackId: 'configSync',
        autoDispose: true,
      ),
      constraints: Constraints(requiresNetwork: true),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> _analyticsSync(String? input) async {
    await Firebase.initializeApp();
    final crashlytics = FirebaseCrashlytics.instance;

    try {
      final events = await AnalyticsQueue.getQueuedAnalyticsEvents();
      final analytics = FirebaseAnalytics.instance;

      for (final event in events) {
        await analytics.logEvent(
          name: event.name,
          parameters: event.parameters,
        );
      }

      await AnalyticsQueue.clearAnalyticsQueue();
      crashlytics.log('Synced ${events.length} analytics events');
    } catch (error, stackTrace) {
      await crashlytics.recordError(error, stackTrace);
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firestoreSync(String? input) async {
    await Firebase.initializeApp();
    final crashlytics = FirebaseCrashlytics.instance;

    try {
      final firestore = FirebaseFirestore.instance;
      final lastSync = await getLastSyncTime();

      final snapshot = await firestore
          .collection('user_data')
          .where('updated_at', isGreaterThan: lastSync)
          .get();

      for (final doc in snapshot.docs) {
        await saveToLocalDatabase(doc.id, doc.data());
      }

      await saveLastSyncTime(DateTime.now());
      crashlytics.log('Synced ${snapshot.docs.length} documents');
    } catch (error, stackTrace) {
      await crashlytics.recordError(error, stackTrace);
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _configSync(String? input) async {
    await Firebase.initializeApp();
    final crashlytics = FirebaseCrashlytics.instance;

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();

      crashlytics.log('Remote Config synced');
    } catch (error, stackTrace) {
      await crashlytics.recordError(error, stackTrace);
      rethrow;
    }
  }
}
```

---

## Additional Resources

- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
- [native_workmanager Dart Workers](../EXTENSIBILITY.md)
- [Performance Guide](../PERFORMANCE_GUIDE.md)

---

**Last Updated:** 2026-02-07
