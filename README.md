# native_workmanager

> **Native background task manager for Flutter with zero Flutter Engine overhead.**

[![pub package](https://img.shields.io/pub/v/native_workmanager.svg?color=blueviolet)](https://pub.dev/packages/native_workmanager)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/native_workmanager)

Flutter background task manager with native workers and task chains.

---

## ✨ Key Features

- **Zero Flutter Engine Overhead:** Native workers execute I/O tasks without loading the Flutter Engine
- **Task Chains:** Automate multi-step workflows (Download → Process → Upload) with built-in dependency management
- **11 Built-in Workers:** HTTP, File operations, Compression, Crypto, Image processing
- **Hybrid Architecture:** Choose native workers for I/O or Dart workers for complex logic
- **Production Ready:** 808 passing tests, comprehensive documentation, iOS 12.0+ and Android API 21+ support

---

## 🚀 Quick Start

**Step 1: Platform Requirements**

- **Android:** API 26+ (Android 8.0+) - [Android Setup Guide →](doc/ANDROID_SETUP.md)
- **iOS:** iOS 12.0+ - [iOS Setup Guide →](doc/IOS_BACKGROUND_LIMITS.md)

**Step 2: Install**
```bash
flutter pub add native_workmanager
```

**Step 3: Initialize**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

**Step 4: Schedule a Task**

**Option A: Simple HTTP Sync (Native Worker)**
```dart
// Starts hourly API sync without Flutter Engine overhead
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(  // ← Native worker
    url: 'https://api.example.com/sync',
    method: HttpMethod.post,
  ),
);
// ✓ Task runs every hour, even when app is closed
// ✓ No Flutter Engine overhead
```

**Option B: Complex Dart Logic (Dart Worker)**
```dart
// For tasks requiring custom Dart code or packages
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'complexLogic'),  // ← Dart worker
);
// ✓ Access to all Dart packages
// ✓ Full Flutter/Dart ecosystem support
```

Tasks are registered with the OS and survive app restarts, phone reboots, and force-quits.

[Complete getting started guide →](doc/GETTING_STARTED.md)

---

## 🔄 Migrating from workmanager?

**Good news:** ~90% API compatibility, most code stays the same!

### Quick Migration Checklist

- [ ] Replace `Workmanager.registerPeriodicTask` with `NativeWorkManager.enqueue`
- [ ] Update task trigger syntax (same logic, different API)
- [ ] Replace callback with `DartWorker(callbackId)` or use native workers
- [ ] Test on both iOS and Android (should work immediately!)

### Common Migration Pattern

**Before (workmanager):**
```dart
Workmanager.registerPeriodicTask(
  'myTask',
  'api_sync',
  frequency: Duration(hours: 1),
);
```

**After (native_workmanager):**
```dart
// Upgrade to native worker
NativeWorkManager.enqueue(
  taskId: 'myTask',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(  // ← Native HTTP worker
    url: 'https://api.example.com/sync',
  ),
);
```

**Result:** Same functionality, zero Flutter Engine overhead for I/O tasks.

[Full migration guide →](doc/MIGRATION_GUIDE.md) | [Migration tool →](tool/migrate.dart)

---

## 🎯 Choose Your Use Case

### 📊 I need periodic API sync
→ Use **Native Workers** (zero Flutter Engine overhead)
- No Flutter Engine overhead
- Minimal battery impact
- [See example →](doc/use-cases/01-periodic-api-sync.md)

### 📁 I need file uploads with retry
→ Use **HttpUploadWorker** with **Task Chains**
- Built-in retry logic
- Progress tracking
- Automatic cleanup
- [See example →](doc/use-cases/02-file-upload-with-retry.md)

### 🖼️ I need photo backup pipeline
→ Use **Task Chains** (Download → Compress → Upload)
- Sequential or parallel execution
- Automatic dependency management
- Failure isolation
- [See example →](doc/use-cases/04-photo-auto-backup.md)

### 🔧 I have complex Dart logic
→ Use **DartWorker** with `autoDispose`
- Full Flutter Engine access
- All Dart packages available
- Smart memory management
- [See example →](doc/use-cases/05-hybrid-workflow.md)

[See all 8 use cases →](doc/use-cases/)

---

## 💡 Why native_workmanager?

### Unique Features

**1. Native Workers**
- Execute I/O tasks without spawning Flutter Engine
- **11 Built-in Workers**: HTTP (request, upload, download, sync), Files (compress, decompress, copy, move, delete), Image processing, Crypto (hash, encrypt, decrypt)
- Extensible with custom Kotlin/Swift workers

**2. Task Chains**
- Automate multi-step workflows: A → B → C or A → [B1, B2, B3] → D
- Built-in dependency management
- Automatic retry and failure handling
- Data passing between steps

**3. Hybrid Execution Model**
- Choose per-task: Native workers (I/O) or Dart workers (complex logic)
- `autoDispose` flag for fine-grained engine lifecycle control
- Best of both worlds

**4. Cross-Platform Consistency**
- Unified API across Android and iOS
- Platform feature parity
- Built on kmpworkmanager for reliability

[See FAQ →](doc/FAQ.md)

---

## 🖥️ Platform Support

| Platform | Status | Min Version | Key Limitation |
|----------|:------:|:-----------:|----------------|
| **Android** | ✅ Supported | API 21 (5.0+) | Doze mode may defer tasks |
| **iOS** | ✅ Supported | iOS 12.0+ | **30-second execution limit** |

### iOS: 30-Second Execution Limit ⚠️

Background tasks on iOS **must complete in 30 seconds**. For longer tasks:

**Solutions:**
- ✅ **Use task chains** - Split work into 30-second chunks
- ✅ **Use native workers** - Faster than Dart workers (no engine overhead)
- ✅ **Use Background URLSession** - For large file transfers (no time limit)
- ⚠️ Consider foreground services for truly long tasks

**Example:**
```dart
// ❌ Won't work: Takes 90 seconds
await downloadLargeFile();  // 60sec
await processFile();        // 30sec

// ✅ Works: Split into chain (each <30sec)
await NativeWorkManager.beginWith(
  TaskRequest(id: 'download', worker: HttpDownloadWorker(...)),  // 20sec
).then(
  TaskRequest(id: 'process', worker: ImageProcessWorker(...)),   // 15sec
).enqueue();
```

[Read iOS background task guide →](doc/IOS_BACKGROUND_LIMITS.md)

### Android: Doze Mode & Battery Optimization

Android 6+ may defer tasks in Doze mode. Use constraints to ensure execution:

```dart
await NativeWorkManager.enqueue(
  taskId: 'important-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(
    requiresNetwork: true,         // Wait for network
    requiresCharging: true,        // Wait for charging (optional)
    requiresBatteryNotLow: true,   // Skip if battery low
  ),
);
```

[Read Android optimization guide →](doc/PLATFORM_CONSISTENCY.md)

---

## 📚 Complete Documentation

### 🚀 Start Here
- **[Quick Start (3 min)](doc/GETTING_STARTED.md)** - Get running fast
- **[API Reference](doc/API_REFERENCE.md)** - Complete API docs
- **[FAQ](doc/FAQ.md)** - Common questions answered

### 📖 Learn by Example
- **[Real-World Use Cases](doc/use-cases/)** (8 examples)
  - [Periodic API Sync](doc/use-cases/01-periodic-api-sync.md)
  - [File Upload with Retry](doc/use-cases/02-file-upload-with-retry.md)
  - [Background Cleanup](doc/use-cases/03-background-cleanup.md)
  - [Photo Auto-Backup](doc/use-cases/04-photo-auto-backup.md)
  - [Hybrid Dart/Native Workflows](doc/use-cases/05-hybrid-workflow.md)
  - [Task Chain Processing](doc/use-cases/06-chain-processing.md)
  - And more...

### 🔧 Build It Right
- **[Security Policy](doc/SECURITY.md)** - Report vulnerabilities, best practices
- **[Production Deployment](doc/PRODUCTION_GUIDE.md)** - Launch with confidence
- **[Platform Consistency](doc/PLATFORM_CONSISTENCY.md)** - iOS vs Android differences

### 🎓 Go Deep
- **[Custom Native Workers](doc/EXTENSIBILITY.md)** - Write Kotlin/Swift workers
- **[Task Chains & Workflows](doc/use-cases/06-chain-processing.md)** - Complex automations
- **[iOS Background Limits](doc/IOS_BACKGROUND_LIMITS.md)** - 30-second workarounds

---

## ❓ FAQ

**Q: Will my task run if the app is force-closed?**
A: Yes! Tasks are registered with the OS (Android WorkManager / iOS BGTaskScheduler), not your Flutter app.

**Q: How much memory does a task actually use?**
A: Native workers execute without Flutter Engine overhead. Dart workers require the full Flutter runtime. Actual memory usage depends on worker type and task complexity.

**Q: Can I chain 100 tasks together?**
A: Yes, but on iOS each task in the chain must complete within 30 seconds. Use native workers for speed.

**Q: What happens if a task in a chain fails?**
A: The chain stops. Subsequent tasks are cancelled. You can use retry policies to handle failures.

**Q: Is this compatible with workmanager?**
A: ~90% compatible. Most code works with minor syntax changes. See [migration guide](doc/MIGRATION_GUIDE.md).

**Q: Can I use this for location tracking?**
A: Background tasks are for periodic work, not continuous tracking. For location, use `geolocator` with background modes.

[See full FAQ →](doc/FAQ.md)

---

## 🔌 Popular Integrations

- **[Dio](doc/integrations/dio.md)** - HTTP client for complex requests
- **[Hive](doc/integrations/hive.md)** - Local database sync
- **[Firebase](doc/integrations/firebase.md)** - Analytics & Crashlytics
- **[Sentry](doc/integrations/sentry.md)** - Error tracking in background tasks

[See all integrations →](doc/integrations/)

---

## 📊 Production Ready

- **Security:** No critical vulnerabilities
- **Tests:** 808 unit tests passing
- **Coverage:** All 11 native workers tested
- **Platforms:** iOS 12.0+ and Android API 21+

---

## 🤝 Community & Support

- 💬 [GitHub Discussions](https://github.com/brewkits/native_workmanager/discussions) - Ask questions, share use cases
- 🐛 [Issue Tracker](https://github.com/brewkits/native_workmanager/issues) - Report bugs
- 📧 Email: support@brewkits.dev

### Found a Bug?

1. [Search existing issues](https://github.com/brewkits/native_workmanager/issues)
2. [Create new issue](https://github.com/brewkits/native_workmanager/issues/new) with:
   - Flutter version (`flutter --version`)
   - Platform (iOS/Android)
   - Minimal reproducible example

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to report bugs
- How to request features
- How to submit pull requests
- Coding standards

---

## 🙏 Acknowledgments

Built with ❤️ using platform-native APIs:
- **Android:** WorkManager - Google's official background task library
- **iOS:** BGTaskScheduler - Apple's background task framework
- **Shared Core:** [kmpworkmanager](https://github.com/pablichjenkov/kmpworkmanager) - Cross-platform worker orchestration

Inspired by Android WorkManager and iOS BackgroundTasks best practices.

---

## 📞 Support & Contact

**Need help?**
- 🌐 **Website:** [brewkits.dev](https://brewkits.dev)
- 🐛 **Issues:** [GitHub Issues](https://github.com/brewkits/native_workmanager/issues)
- 📧 **Email:** datacenter111@gmail.com

**Links:**
- 📦 [pub.dev Package](https://pub.dev/packages/native_workmanager)
- 📖 [Documentation](doc/)
- 💻 [GitHub Repository](https://github.com/brewkits/native_workmanager)

---

## 📄 License

Licensed under the MIT License - see [LICENSE](LICENSE) file for details.

**Author:** Nguyễn Tuấn Việt • [BrewKits](https://brewkits.dev)

---

**⭐ If this library helps your Flutter app, please star the repo!**
