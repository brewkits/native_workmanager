# Use Case: Photo Auto-Backup

**Difficulty:** Intermediate
**Platform:** Android (ContentUri triggers), iOS (manual trigger)
**Features:** ContentUri triggers, File upload, Batch operations

---

## Problem

Your app needs to automatically back up photos when they're added to the device gallery. The backup should:
- Detect new photos automatically (Android)
- Upload in background even when app is closed
- Only upload on WiFi to save data
- Handle batch uploads efficiently
- Support manual backup on iOS

Common scenarios:
- Photo backup apps
- Cloud storage apps
- Social media apps with auto-upload
- Gallery apps with sync features

---

## Solution

**Android:** Use `TaskTrigger.contentUri()` to detect new photos automatically.
**iOS:** Use manual triggers with periodic checks (ContentUri not supported).

---

## Complete Example (Android)

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize work manager
  await NativeWorkManager.initialize();

  // Request permissions
  await _requestPermissions();

  // Setup auto-backup (Android only)
  if (Platform.isAndroid) {
    await setupAutoBackup();
  }

  runApp(MyApp());
}

Future<void> _requestPermissions() async {
  // Android 13+: Request media permissions
  if (Platform.isAndroid) {
    await Permission.photos.request();
  } else {
    await Permission.photos.request();
  }
}

/// Setup automatic photo backup (Android only)
Future<void> setupAutoBackup() async {
  if (!Platform.isAndroid) {
    print('⚠️ ContentUri triggers only supported on Android');
    return;
  }

  final result = await NativeWorkManager.enqueue(
    taskId: 'photo-auto-backup',

    // Trigger when new photos are added to MediaStore
    trigger: TaskTrigger.contentUri(
      // Android MediaStore Images URI
      uri: 'content://media/external/images/media',

      // Also trigger on descendants (all subdirectories)
      triggerForDescendants: true,
    ),

    // Upload using native worker
    worker: DartWorker(
      callbackId: 'backupNewPhotos',
      input: {
        'backup_url': 'https://api.example.com/photos/upload',
      },
    ),

    // Only on WiFi, battery not low
    constraints: Constraints(
      networkType: NetworkType.unmetered,  // WiFi only
      batteryNotLow: true,
    ),

    // Keep existing task
    existingPolicy: ExistingTaskPolicy.keep,

    tag: 'photo-backup',
  );

  if (result == ScheduleResult.accepted) {
    print('✅ Auto-backup enabled');
  }
}

/// Dart worker callback to backup new photos
Future<bool> backupNewPhotos(Map<String, dynamic>? input) async {
  print('📸 Backing up new photos...');

  try {
    // Get new photos from gallery (simplified)
    // In real app, query MediaStore for photos added since last backup
    final newPhotos = await _getNewPhotos();

    if (newPhotos.isEmpty) {
      print('No new photos to backup');
      return true;
    }

    print('Found ${newPhotos.length} new photos');

    // Upload each photo
    for (final photo in newPhotos) {
      await _uploadPhoto(photo, input?['backup_url']);
    }

    print('✅ Backed up ${newPhotos.length} photos');
    return true;
  } catch (e) {
    print('❌ Backup failed: $e');
    return false;
  }
}

Future<List<File>> _getNewPhotos() async {
  // Simplified: In real app, query MediaStore
  // and track last backup timestamp
  return [];
}

Future<void> _uploadPhoto(File photo, String? url) async {
  // Upload photo using HTTP
  print('Uploading: ${photo.path}');
  // Implement actual upload logic
}

/// Manual backup (works on Android + iOS)
Future<void> triggerManualBackup() async {
  final result = await NativeWorkManager.enqueue(
    taskId: 'manual-backup-${DateTime.now().millisecondsSinceEpoch}',
    trigger: TaskTrigger.oneTime(),
    worker: DartWorker(
      callbackId: 'backupAllPhotos',
      input: {'backup_url': 'https://api.example.com/photos/upload'},
    ),
    constraints: Constraints(
      networkType: NetworkType.unmetered,  // WiFi only
    ),
    tag: 'photo-backup',
  );

  print(result == ScheduleResult.accepted
      ? '✅ Manual backup started'
      : '❌ Manual backup failed');
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Photo Auto-Backup')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, size: 80, color: Colors.blue),
              SizedBox(height: 32),
              Text(
                Platform.isAndroid
                    ? 'Auto-Backup Enabled ✅'
                    : 'Manual Backup Only',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              if (Platform.isAndroid)
                Text(
                  'New photos will be backed up automatically',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Text(
                  'Tap button to backup photos',
                  style: TextStyle(color: Colors.grey),
                ),
              SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: triggerManualBackup,
                icon: Icon(Icons.cloud_upload),
                label: Text('Backup Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## iOS Alternative: Periodic Check

Since iOS doesn't support ContentUri triggers, use periodic checks:

```dart
/// iOS: Periodic photo backup
Future<void> scheduleIOSPhotoBackup() async {
  if (!Platform.isIOS) return;

  final result = await NativeWorkManager.enqueue(
    taskId: 'ios-photo-backup',

    // Check for new photos every 6 hours
    trigger: TaskTrigger.periodic(Duration(hours: 6)),

    // Dart worker to check and upload
    worker: DartWorker(
      callbackId: 'checkAndBackupPhotos',
      input: {'backup_url': 'https://api.example.com/photos/upload'},
    ),

    constraints: Constraints(
      networkType: NetworkType.unmetered,
    ),

    tag: 'photo-backup',
  );

  print(result == ScheduleResult.accepted
      ? '✅ iOS photo backup scheduled'
      : '❌ Scheduling failed');
}
```

---

## Expected Behavior

### Android

**ContentUri triggers:**
- Monitors MediaStore for new images
- Triggers within seconds of new photo
- Waits for WiFi constraint if offline
- Batch processes multiple photos

**Battery optimization:**
- Deferred in Doze mode
- Runs during maintenance windows
- Low priority (won't wake device)

### iOS

**Manual triggers only:**
- ContentUri not supported
- Use periodic checks instead
- Or trigger on app foreground

---

## Platform Considerations

### Android Specific

**MediaStore URIs:**
```dart
// Images
'content://media/external/images/media'

// Videos
'content://media/external/video/media'

// All media
'content://media/external/file'
```

**Permissions:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

### iOS Specific

**Photo Library Access:**
```swift
// Info.plist
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to backup your photos</string>
```

**Photo changes observer:**
Use `photo_manager` package to detect changes:
```dart
import 'package:photo_manager/photo_manager.dart';

class PhotoObserver {
  void startObserving() {
    PhotoManager.addChangeCallback((value) {
      print('Photos changed, trigger backup');
      triggerManualBackup();
    });
  }
}
```

---

## Common Pitfalls

### 1. ❌ ContentUri on iOS

```dart
// ❌ Will fail on iOS
if (Platform.isIOS) {
  await NativeWorkManager.enqueue(
    taskId: 'backup',
    trigger: TaskTrigger.contentUri(uri: '...'),  // Not supported!
    worker: ...,
  );
}

// ✅ Platform-specific approach
if (Platform.isAndroid) {
  // Use ContentUri
  await setupAndroidAutoBackup();
} else {
  // Use periodic check or observer
  await setupIOSPhotoBackup();
}
```

### 2. ❌ No WiFi Constraint

```dart
// ❌ Will use mobile data
constraints: Constraints(
  networkType: NetworkType.connected,  // Any network!
)

// ✅ WiFi only
constraints: Constraints(
  networkType: NetworkType.unmetered,  // WiFi only
)
```

### 3. ❌ Missing Permissions

```dart
// ❌ No permission check
await setupAutoBackup();  // Will fail silently

// ✅ Check permissions first
final status = await Permission.photos.status;
if (status.isGranted) {
  await setupAutoBackup();
} else {
  await Permission.photos.request();
}
```

---

## Related

- **File upload:** [File Upload with Retry](02-file-upload-with-retry.md)
- **Hybrid approach:** [Hybrid Workflow](05-hybrid-workflow.md)

---

## Checklist

- [ ] Request photo permissions
- [ ] Android: Use ContentUri trigger for auto-detection
- [ ] iOS: Use periodic check or PHPhotoLibrary observer
- [ ] Add WiFi-only constraint
- [ ] Track last backup timestamp
- [ ] Handle duplicate uploads
- [ ] Test with real photos
- [ ] Verify background upload works

---

*Last updated: 2026-01-27*
