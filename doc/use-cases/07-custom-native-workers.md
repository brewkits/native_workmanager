# Custom Native Workers

**Level:** Advanced | **Time:** 45 minutes

Learn how to extend Native WorkManager with your own high-performance native workers written in Kotlin (Android) and Swift (iOS).

---

## Why Custom Native Workers?

Native workers give you **maximum performance** (no Flutter Engine overhead) for platform-specific operations:

- **Image/Video Processing:** Compression, resizing, encoding
- **Encryption/Decryption:** Native crypto libraries
- **Database Operations:** Room (Android), Core Data (iOS)
- **ML/AI Inference:** TensorFlow Lite, Core ML
- **File Operations:** Zip/unzip, batch file processing

**Performance:** ~2-5MB RAM | <50ms startup (same as built-in workers)

---

## Quick Start (3 Steps)

### Step 1: Implement Native Worker

#### Android (Kotlin)

Create `ImageCompressWorker.kt` in `android/app/src/main/kotlin/com/yourapp/workers/`:

```kotlin
package com.yourapp.workers

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.io.FileOutputStream

class ImageCompressWorker : AndroidWorker {
    override suspend fun doWork(input: String?): Boolean {
        try {
            // Parse JSON input
            val json = Json.parseToJsonElement(input ?: "{}")
            val config = json.jsonObject

            val inputPath = config["inputPath"]?.jsonPrimitive?.content
                ?: return false
            val outputPath = config["outputPath"]?.jsonPrimitive?.content
                ?: return false
            val quality = config["quality"]?.jsonPrimitive?.content?.toIntOrNull()
                ?: 85

            // Load image
            val bitmap = BitmapFactory.decodeFile(inputPath)
                ?: return false

            // Compress and save
            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()

            FileOutputStream(outputFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
            }

            bitmap.recycle()
            return true

        } catch (e: Exception) {
            println("ImageCompressWorker error: ${e.message}")
            return false
        }
    }
}
```

#### iOS (Swift)

Create `ImageCompressWorker.swift` in `ios/Runner/Workers/`:

```swift
import Foundation
import UIKit

class ImageCompressWorker: IosWorker {
    func doWork(input: String?) async throws -> Bool {
        // Parse JSON input
        guard let inputString = input,
              let data = inputString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputPath = json["inputPath"] as? String,
              let outputPath = json["outputPath"] as? String else {
            return false
        }

        let quality = json["quality"] as? Double ?? 0.85

        // Load image
        guard let image = UIImage(contentsOfFile: inputPath) else {
            return false
        }

        // Compress
        guard let compressedData = image.jpegData(compressionQuality: quality) else {
            return false
        }

        // Save
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try compressedData.write(to: outputURL)

        return true
    }
}
```

### Step 2: Register Worker

#### Android

In `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerFactory
import dev.brewkits.native_workmanager.SimpleAndroidWorkerFactory
import com.yourapp.workers.ImageCompressWorker

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Register custom workers BEFORE Flutter engine starts
        SimpleAndroidWorkerFactory.setUserFactory(object : AndroidWorkerFactory {
            override fun createWorker(workerClassName: String): AndroidWorker? {
                return when (workerClassName) {
                    "ImageCompressWorker" -> ImageCompressWorker()
                    // Add more custom workers here
                    else -> null
                }
            }
        })
    }
}
```

#### iOS

In `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register custom workers BEFORE GeneratedPluginRegistrant
        IosWorkerFactory.registerWorker(className: "ImageCompressWorker") {
            return ImageCompressWorker()
        }
        // Add more workers here

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### Step 3: Use in Dart

```dart
import 'package:native_workmanager/native_workmanager.dart';

await NativeWorkManager.enqueue(
  taskId: 'compress-photo-${DateTime.now().millisecondsSinceEpoch}',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.custom(
    className: 'ImageCompressWorker',
    input: {
      'inputPath': '/storage/emulated/0/DCIM/photo.jpg',
      'outputPath': '/data/user/0/com.app/files/compressed.jpg',
      'quality': 85,
    },
  ),
  constraints: Constraints(deviceIdle: true),
);
```

---

## Advanced Examples

### Example 1: Batch Image Compression

```dart
Future<void> compressCameraRoll() async {
  final photos = await getCameraRollPhotos();

  for (var photo in photos) {
    await NativeWorkManager.enqueue(
      taskId: 'compress-${photo.id}',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.custom(
        className: 'ImageCompressWorker',
        input: {
          'inputPath': photo.path,
          'outputPath': photo.path.replaceAll('.jpg', '_compressed.jpg'),
          'quality': 75,
        },
      ),
      tag: 'batch-compress',
      constraints: Constraints(
        requiresCharging: true,
        requiresWifi: true,
      ),
    );
  }
}
```

### Example 2: Encryption Worker

**Android:**
```kotlin
class EncryptionWorker : AndroidWorker {
    override suspend fun doWork(input: String?): Boolean {
        val json = Json.parseToJsonElement(input ?: "{}").jsonObject
        val filePath = json["filePath"]?.jsonPrimitive?.content ?: return false
        val password = json["password"]?.jsonPrimitive?.content ?: return false

        // Use Android Keystore for encryption
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        // ... encrypt file with cipher

        return true
    }
}
```

**iOS:**
```swift
class EncryptionWorker: IosWorker {
    func doWork(input: String?) async throws -> Bool {
        guard let inputString = input,
              let data = inputString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let filePath = json["filePath"] as? String,
              let password = json["password"] as? String else {
            return false
        }

        // Use iOS CryptoKit for encryption
        // ... encrypt file

        return true
    }
}
```

### Example 3: Database Batch Insert (Android Room)

```kotlin
class BatchInsertWorker(private val database: AppDatabase) : AndroidWorker {
    override suspend fun doWork(input: String?): Boolean {
        val json = Json.parseToJsonElement(input ?: "{}").jsonObject
        val itemsArray = json["items"]?.jsonArray ?: return false

        // Parse items
        val items = itemsArray.map { element ->
            val obj = element.jsonObject
            Item(
                id = obj["id"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0,
                name = obj["name"]?.jsonPrimitive?.content ?: "",
                value = obj["value"]?.jsonPrimitive?.content ?: ""
            )
        }

        // Batch insert using Room
        database.itemDao().insertAll(items)
        return true
    }
}
```

---

## Testing Custom Workers

### 1. Unit Test (Kotlin)

```kotlin
class ImageCompressWorkerTest {
    @Test
    fun `test image compression`() = runBlocking {
        val worker = ImageCompressWorker()

        val input = """
            {
                "inputPath": "/sdcard/test.jpg",
                "outputPath": "/sdcard/compressed.jpg",
                "quality": 85
            }
        """

        val result = worker.doWork(input)
        assertTrue(result)
        assertTrue(File("/sdcard/compressed.jpg").exists())
    }
}
```

### 2. Integration Test (Dart)

```dart
void main() {
  testWidgets('Custom worker executes successfully', (tester) async {
    await NativeWorkManager.initialize();

    final completer = Completer<bool>();
    NativeWorkManager.events.listen((event) {
      if (event.taskId == 'test-compress') {
        completer.complete(event.success);
      }
    });

    await NativeWorkManager.enqueue(
      taskId: 'test-compress',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.custom(
        className: 'ImageCompressWorker',
        input: {'inputPath': '/test.jpg', 'outputPath': '/out.jpg'},
      ),
    );

    final success = await completer.future.timeout(Duration(seconds: 10));
    expect(success, true);
  });
}
```

---

## Best Practices

### 1. Input Validation

```kotlin
override suspend fun doWork(input: String?): Boolean {
    if (input == null || input.isEmpty()) {
        Log.e("Worker", "Input is null or empty")
        return false
    }

    try {
        val json = Json.parseToJsonElement(input).jsonObject
        // Validate required fields
        require(json.containsKey("inputPath")) { "inputPath is required" }
        // ... continue
    } catch (e: Exception) {
        Log.e("Worker", "Invalid input: ${e.message}")
        return false
    }
}
```

### 2. Error Handling

```swift
func doWork(input: String?) async throws -> Bool {
    do {
        // Your work here
        return true
    } catch let error as NSError {
        print("Worker error: \(error.localizedDescription)")
        // Don't throw - return false instead
        return false
    }
}
```

### 3. Resource Cleanup

```kotlin
override suspend fun doWork(input: String?): Boolean {
    var bitmap: Bitmap? = null
    var outputStream: FileOutputStream? = null

    try {
        bitmap = BitmapFactory.decodeFile(inputPath)
        outputStream = FileOutputStream(outputPath)
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, outputStream)
        return true
    } finally {
        bitmap?.recycle()
        outputStream?.close()
    }
}
```

### 4. Size Limits

- Keep input JSON < 10MB (same as built-in workers)
- For large data, pass file paths instead of data itself
- Use file-based communication for multi-MB payloads

---

## Common Pitfalls

❌ **Don't** forget to register worker before `initialize()`
❌ **Don't** throw exceptions from `doWork()` (return false instead)
❌ **Don't** block on main thread (workers already run in background)
❌ **Don't** use instance methods as factories (use static/top-level)
✅ **Do** validate input thoroughly
✅ **Do** clean up resources in finally blocks
✅ **Do** test both platforms independently
✅ **Do** handle missing dependencies gracefully

---

## Performance Comparison

| Worker Type | RAM | Startup | Capabilities |
|-------------|-----|---------|--------------|
| Custom Native | ~2-5MB | <50ms | Native APIs only |
| Built-in HTTP | ~3MB | <50ms | HTTP only |
| DartWorker | ~50MB | 500-1000ms | Full Dart/Flutter |

**Recommendation:** Use custom native workers for CPU-intensive or platform-specific tasks. Avoid for simple operations that DartWorker can handle.

---

## Example App

See [`example/lib/tabs/custom_workers_tab.dart`](../../example/lib/tabs/custom_workers_tab.dart) for a complete working example with image compression and encryption workers.

---

## Next Steps

- [Task Chains with Custom Workers](06-chain-processing.md) - Combine custom + built-in workers
- [Hybrid Workflows](05-hybrid-workflow.md) - Mix native and Dart workers
- [Architecture Guide](../ARCHITECTURE.md) - Understand the worker factory pattern

---

**📧 Questions?** [Open an issue](https://github.com/user/native_workmanager/issues)
