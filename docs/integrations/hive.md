# Hive Integration Guide

Integration guide for using native_workmanager with **Hive** - the lightweight and fast NoSQL database for Flutter.

---

## Overview

Hive is a fast, pure Dart key-value database that provides:
- Zero-config local storage
- Type adapters for custom objects
- Encryption support
- Fast read/write operations
- No native dependencies

This guide shows how to use Hive with native_workmanager for background data synchronization.

---

## Installation

```yaml
dependencies:
  native_workmanager: ^1.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.8
```

```bash
flutter pub get
```

---

## Use Cases

### ✅ Common Use Cases

1. **Background data sync** - Sync Hive database with remote API
2. **Offline-first apps** - Queue operations for background sync
3. **Data export** - Export Hive data to files periodically
4. **Data cleanup** - Remove old records in background
5. **Backup** - Backup Hive database to cloud storage

---

## Pattern 1: Background Sync (API → Hive)

Download data from API and store in Hive.

### Setup Hive

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('app_data');

  // Initialize native_workmanager
  await NativeWorkManager.initialize();
  NativeWorkManager.registerCallback('syncToHive', syncToHiveCallback);

  runApp(MyApp());
}

@pragma('vm:entry-point')
Future<void> syncToHiveCallback(String? input) async {
  // Re-initialize Hive in background isolate
  await Hive.initFlutter();
  final box = await Hive.openBox('app_data');

  try {
    // Fetch data from API (use native worker for better performance)
    // For this example, we'll use a simple HTTP request
    final response = await http.get(Uri.parse('https://api.example.com/data'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Store in Hive
      await box.put('last_sync', DateTime.now().toIso8601String());
      await box.put('user_data', data);

      print('✅ Data synced to Hive');
    }
  } catch (e) {
    print('❌ Sync failed: $e');
    rethrow;
  } finally {
    await box.close();
  }
}
```

### Schedule Periodic Sync

```dart
await NativeWorkManager.enqueue(
  taskId: 'hive-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: DartWorker(
    callbackId: 'syncToHive',
    autoDispose: true,
  ),
  constraints: Constraints(
    requiresNetwork: true,
  ),
);
```

---

## Pattern 2: Upload Hive Data to API

Sync local Hive data to remote server.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> uploadFromHiveCallback(String? input) async {
  await Hive.initFlutter();
  final box = await Hive.openBox('pending_uploads');

  try {
    // Get pending uploads
    final pendingItems = box.values.toList();

    if (pendingItems.isEmpty) {
      print('No pending uploads');
      return;
    }

    // Upload to API
    final response = await http.post(
      Uri.parse('https://api.example.com/upload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'items': pendingItems,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      // Clear pending items after successful upload
      await box.clear();
      print('✅ Uploaded ${pendingItems.length} items');
    } else {
      print('❌ Upload failed: ${response.statusCode}');
    }
  } finally {
    await box.close();
  }
}
```

### Schedule Upload

```dart
await NativeWorkManager.enqueue(
  taskId: 'hive-upload',
  trigger: TaskTrigger.periodic(Duration(minutes: 30)),
  worker: DartWorker(callbackId: 'uploadFromHive'),
  constraints: Constraints(
    requiresNetwork: true,
    requiresBatteryNotLow: true,
  ),
);
```

---

## Pattern 3: Offline Queue with Hive

Queue operations when offline, sync when online.

### Setup Queue

```dart
class OfflineQueue {
  static const String boxName = 'offline_queue';

  static Future<void> addToQueue(Map<String, dynamic> operation) async {
    final box = await Hive.openBox(boxName);
    await box.add({
      'operation': operation,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': Uuid().v4(),
    });
    await box.close();

    // Trigger background sync
    await _scheduleSync();
  }

  static Future<void> _scheduleSync() async {
    await NativeWorkManager.enqueue(
      taskId: 'queue-sync-${DateTime.now().millisecondsSinceEpoch}',
      trigger: TaskTrigger.oneTime(),
      worker: DartWorker(callbackId: 'processQueue'),
      constraints: Constraints(requiresNetwork: true),
    );
  }
}

@pragma('vm:entry-point')
Future<void> processQueueCallback(String? input) async {
  await Hive.initFlutter();
  final box = await Hive.openBox(OfflineQueue.boxName);

  try {
    final items = box.values.toList();

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        // Process operation
        await _processOperation(item['operation']);

        // Remove from queue
        await box.deleteAt(i);
        print('✅ Processed operation: ${item['id']}');
      } catch (e) {
        print('❌ Failed to process: ${item['id']} - $e');
        // Keep in queue for retry
      }
    }
  } finally {
    await box.close();
  }
}

Future<void> _processOperation(Map<String, dynamic> operation) async {
  final response = await http.post(
    Uri.parse(operation['url']),
    body: jsonEncode(operation['data']),
  );

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }
}
```

### Usage

```dart
// User performs action (online or offline)
await OfflineQueue.addToQueue({
  'url': 'https://api.example.com/action',
  'data': {'action': 'like', 'postId': 123},
});

// Automatically syncs when network available
```

---

## Pattern 4: Data Cleanup

Remove old Hive records periodically.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> cleanupHiveCallback(String? input) async {
  await Hive.initFlutter();
  final box = await Hive.openBox('cache');

  try {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = Duration(days: 7).inMilliseconds;

    int removed = 0;

    // Remove items older than 7 days
    final keysToDelete = <dynamic>[];
    for (var key in box.keys) {
      final item = box.get(key);
      if (item is Map && item['timestamp'] != null) {
        final age = now - (item['timestamp'] as int);
        if (age > maxAge) {
          keysToDelete.add(key);
        }
      }
    }

    for (var key in keysToDelete) {
      await box.delete(key);
      removed++;
    }

    print('✅ Cleaned up $removed old items');

    // Compact database
    await box.compact();
  } finally {
    await box.close();
  }
}
```

### Schedule Cleanup

```dart
await NativeWorkManager.enqueue(
  taskId: 'hive-cleanup',
  trigger: TaskTrigger.periodic(Duration(days: 1)),
  worker: DartWorker(callbackId: 'cleanupHive'),
);
```

---

## Pattern 5: Backup Hive to Cloud

Export Hive database and upload to cloud storage.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> backupHiveCallback(String? input) async {
  await Hive.initFlutter();
  final box = await Hive.openBox('app_data');

  try {
    // Export all data
    final allData = box.toMap();
    final jsonData = jsonEncode(allData);

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final backupFile = File('${tempDir.path}/hive_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await backupFile.writeAsString(jsonData);

    print('✅ Backup created: ${backupFile.path} (${backupFile.lengthSync()} bytes)');

    // Note: Use native_workmanager's httpUpload to upload the file
    // This would be a separate task in a chain
  } finally {
    await box.close();
  }
}
```

### Schedule with Chain

```dart
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'create-backup',
    worker: DartWorker(callbackId: 'backupHive'),
  ),
)
.then(TaskRequest(
  id: 'upload-backup',
  worker: NativeWorker.httpUpload(
    url: 'https://backup.example.com/upload',
    filePath: '/tmp/hive_backup.json',  // From previous task
  ),
))
.enqueue();
```

---

## Pattern 6: Type Adapters in Background

Using Hive type adapters in background workers.

### Define Model

```dart
import 'package:hive/hive.dart';

part 'user.g.dart';  // Generated file

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String email;

  @HiveField(3)
  DateTime lastSync;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.lastSync,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    lastSync: DateTime.parse(json['lastSync']),
  );
}
```

### Generate Adapter

```bash
flutter packages pub run build_runner build
```

### Use in Background Worker

```dart
@pragma('vm:entry-point')
Future<void> syncUsersCallback(String? input) async {
  await Hive.initFlutter();

  // Register adapter
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserAdapter());
  }

  final box = await Hive.openBox<User>('users');

  try {
    // Fetch users from API
    final response = await http.get(Uri.parse('https://api.example.com/users'));
    final data = jsonDecode(response.body) as List;

    // Store in Hive
    for (var userData in data) {
      final user = User.fromJson(userData);
      await box.put(user.id, user);
    }

    print('✅ Synced ${data.length} users');
  } finally {
    await box.close();
  }
}
```

---

## Best Practices

### 1. Always Initialize Hive in Background Worker

```dart
@pragma('vm:entry-point')
Future<void> myCallback(String? input) async {
  // ✅ Re-initialize in background isolate
  await Hive.initFlutter();

  final box = await Hive.openBox('data');
  // ... work with box
  await box.close();
}
```

### 2. Close Boxes After Use

```dart
@pragma('vm:entry-point')
Future<void> myCallback(String? input) async {
  final box = await Hive.openBox('data');

  try {
    // Work with box
  } finally {
    await box.close();  // ✅ Always close
  }
}
```

### 3. Use Transactions for Multiple Writes

```dart
await box.putAll({
  'key1': 'value1',
  'key2': 'value2',
  'key3': 'value3',
});  // Single transaction, faster than multiple puts
```

### 4. Register Adapters Only Once

```dart
if (!Hive.isAdapterRegistered(typeId)) {
  Hive.registerAdapter(MyAdapter());
}
```

### 5. Handle Corruption

```dart
@pragma('vm:entry-point')
Future<void> syncCallback(String? input) async {
  try {
    await Hive.initFlutter();
    final box = await Hive.openBox('data');
    // ... work
    await box.close();
  } on HiveError catch (e) {
    print('Hive error: $e');
    // Delete corrupted box and recreate
    await Hive.deleteBoxFromDisk('data');
    final box = await Hive.openBox('data');
    // ... initialize with defaults
    await box.close();
  }
}
```

---

## Performance Tips

### 1. Use Lazy Boxes for Large Data

```dart
final box = await Hive.openLazyBox('large_data');

// Only loads value when accessed
final value = await box.get('key');
```

### 2. Compact Periodically

```dart
if (box.length > 1000) {
  await box.compact();  // Reclaim space
}
```

### 3. Use Batch Operations

```dart
// ❌ Slow
for (var item in items) {
  await box.put(item.id, item);
}

// ✅ Fast
await box.putAll(Map.fromEntries(
  items.map((item) => MapEntry(item.id, item)),
));
```

---

## Example: Complete Sync Service

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HiveSyncService {
  static const String dataBoxName = 'app_data';
  static const String queueBoxName = 'sync_queue';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(dataBoxName);
    await Hive.openBox(queueBoxName);

    await NativeWorkManager.initialize();
    NativeWorkManager.registerCallback('syncDown', _syncDownCallback);
    NativeWorkManager.registerCallback('syncUp', _syncUpCallback);
    NativeWorkManager.registerCallback('cleanup', _cleanupCallback);

    // Schedule periodic sync down (API → Hive)
    await NativeWorkManager.enqueue(
      taskId: 'sync-down',
      trigger: TaskTrigger.periodic(Duration(hours: 1)),
      worker: DartWorker(callbackId: 'syncDown', autoDispose: true),
      constraints: Constraints(requiresNetwork: true),
    );

    // Schedule periodic sync up (Hive → API)
    await NativeWorkManager.enqueue(
      taskId: 'sync-up',
      trigger: TaskTrigger.periodic(Duration(minutes: 30)),
      worker: DartWorker(callbackId: 'syncUp', autoDispose: true),
      constraints: Constraints(requiresNetwork: true),
    );

    // Schedule daily cleanup
    await NativeWorkManager.enqueue(
      taskId: 'cleanup',
      trigger: TaskTrigger.periodic(Duration(days: 1)),
      worker: DartWorker(callbackId: 'cleanup', autoDispose: true),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> _syncDownCallback(String? input) async {
    await Hive.initFlutter();
    final box = await Hive.openBox(dataBoxName);

    try {
      final lastSync = box.get('last_sync_timestamp', defaultValue: 0);
      final response = await http.get(
        Uri.parse('https://api.example.com/sync?since=$lastSync'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await box.putAll(data['items']);
        await box.put('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
        print('✅ Synced ${data['items'].length} items from server');
      }
    } finally {
      await box.close();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _syncUpCallback(String? input) async {
    await Hive.initFlutter();
    final box = await Hive.openBox(queueBoxName);

    try {
      final pendingItems = box.values.toList();
      if (pendingItems.isEmpty) return;

      final response = await http.post(
        Uri.parse('https://api.example.com/sync'),
        body: jsonEncode({'items': pendingItems}),
      );

      if (response.statusCode == 200) {
        await box.clear();
        print('✅ Synced ${pendingItems.length} items to server');
      }
    } finally {
      await box.close();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _cleanupCallback(String? input) async {
    await Hive.initFlutter();
    final box = await Hive.openBox(dataBoxName);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAge = Duration(days: 30).inMilliseconds;

      final keysToDelete = box.keys.where((key) {
        final item = box.get(key);
        if (item is Map && item['timestamp'] != null) {
          return (now - item['timestamp']) > maxAge;
        }
        return false;
      }).toList();

      for (var key in keysToDelete) {
        await box.delete(key);
      }

      await box.compact();
      print('✅ Cleaned up ${keysToDelete.length} old items');
    } finally {
      await box.close();
    }
  }

  static Future<void> queueItem(Map<String, dynamic> item) async {
    final box = await Hive.openBox(queueBoxName);
    await box.add({...item, 'queued_at': DateTime.now().millisecondsSinceEpoch});
    await box.close();
  }
}
```

---

## Troubleshooting

### Issue: Box not found in background

**Solution:** Re-initialize Hive and open box in callback:
```dart
@pragma('vm:entry-point')
Future<void> callback(String? input) async {
  await Hive.initFlutter();  // Always initialize
  final box = await Hive.openBox('data');
  // ...
}
```

### Issue: Adapter not registered

**Solution:** Register adapter in callback:
```dart
if (!Hive.isAdapterRegistered(0)) {
  Hive.registerAdapter(MyAdapter());
}
```

### Issue: Corrupted box

**Solution:** Delete and recreate:
```dart
await Hive.deleteBoxFromDisk('corrupted_box');
final box = await Hive.openBox('corrupted_box');
```

---

## Additional Resources

- [Hive Documentation](https://docs.hivedb.dev/)
- [native_workmanager Dart Workers](../EXTENSIBILITY.md)
- [Offline-First Architecture](../use-cases/)

---

**Last Updated:** 2026-02-07
