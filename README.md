# native_workmanager

> **Save 50MB RAM, 5x faster, 50% better battery** - Background tasks done right.

[![pub package](https://img.shields.io/pub/v/native_workmanager.svg?color=blueviolet)](https://pub.dev/packages/native_workmanager)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/native_workmanager)
[![Tests](https://img.shields.io/badge/tests-744%20unit%20tests%20passing-brightgreen)](doc/releases/RELEASE_v1.0.0.md)
[![Platform Coverage](https://img.shields.io/badge/platform%20coverage-Android%20%7C%20iOS-blue)](doc/releases/RELEASE_v1.0.0.md)

**The only Flutter background task manager with zero-overhead native workers and automated task chains.**

---

## 🚨 Is Your Flutter App Suffering From These Issues?

- ❌ Background tasks eating 50MB+ RAM per execution
- ❌ Slow task startup (500ms+ delay)
- ❌ Battery drain complaints from users
- ❌ Can't chain tasks (Download → Process → Upload requires manual coordination)
- ❌ No way to run I/O operations without full Flutter Engine overhead

**If yes, native_workmanager solves all of this.**

---

## ⚡ Performance Comparison

| Metric | flutter_workmanager | native_workmanager | Improvement |
|--------|:------------------:|:------------------:|:-----------:|
| **Memory** | 85 MB | 35 MB | **-50 MB (58%)** |
| **Startup** | 500ms | <100ms | **5x faster** |
| **Battery** | High drain | Minimal | **~50% savings** |
| **Task Chains** | ❌ Manual | ✅ Built-in | **Unique** |

### Real-World Impact

- **Periodic API sync (hourly):** Save 1.2GB RAM over 24 hours
- **File upload queue:** 2-3s faster per upload start
- **Battery life:** ~1 extra hour per day on typical usage

[See detailed benchmarks](doc/BENCHMARKS.md) | [Try it yourself](example/)

---

## 🚀 Get Started in 3 Minutes

**Step 1: Install (30 seconds)**
```bash
flutter pub add native_workmanager
```

**Step 2: Initialize (1 minute)**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

**Step 3: Schedule Your First Task (1 minute)**

**Option A: Simple HTTP Sync (Native Worker - 0 overhead)**
```dart
// Starts hourly API sync using only ~2-5MB memory
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(  // ← Native = no Flutter engine overhead
    url: 'https://api.example.com/sync',
    method: HttpMethod.post,
  ),
);
// ✓ Task runs every hour, even when app is closed
// ✓ Uses 2-5MB RAM vs 50MB with Dart workers
// ✓ Startup: <100ms
```

**Option B: Complex Dart Logic (Dart Worker - full engine)**
```dart
// For tasks requiring custom Dart code or packages
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'complexLogic'),  // ← Full Flutter engine
);
// ✓ Access to all Dart packages
// ✓ Uses ~50MB RAM (still optimized vs alternatives)
```

**✅ Done! Your task is now scheduled and will run even when app is closed.**

### What Just Happened? 🤔

- Your task is now **registered with the OS** to run at scheduled intervals
- **Native Worker (Option A):** Executes without starting Flutter engine → 2-5MB memory, <100ms startup
- **Dart Worker (Option B):** Starts Flutter engine for full Dart access → ~50MB memory, but still faster than alternatives
- Tasks survive **app restarts, phone reboots, and force-quits**

[Complete getting started guide →](doc/GETTING_STARTED.md)

---

## 🔄 Migrating from flutter_workmanager?

**Good news:** ~90% API compatibility, most code stays the same!

### Quick Migration Checklist

- [ ] Replace `Workmanager.registerPeriodicTask` with `NativeWorkManager.enqueue`
- [ ] Update task trigger syntax (same logic, different API)
- [ ] Replace callback with `DartWorker(callbackId)` or use native workers
- [ ] Test on both iOS and Android (should work immediately!)

### Common Migration Pattern

**Before (flutter_workmanager):**
```dart
Workmanager.registerPeriodicTask(
  'myTask',
  'api_sync',
  frequency: Duration(hours: 1),
);
```

**After (native_workmanager):**
```dart
// Upgrade to native worker for better performance
NativeWorkManager.enqueue(
  taskId: 'myTask',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(  // ← Now uses native HTTP, saves 45MB RAM!
    url: 'https://api.example.com/sync',
  ),
);
```

**Result:** Same functionality, 58% less memory, 5x faster startup.

[Full migration guide →](doc/MIGRATION_GUIDE.md) | [Migration tool →](tool/migrate.dart)

---

## 🎯 Choose Your Use Case

### 📊 I need periodic API sync
→ Use **Native Workers** (zero Flutter Engine overhead)
- 2-5MB memory vs 50MB
- <100ms startup vs 500ms
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

### Feature Comparison

| Feature | native_workmanager | flutter_workmanager | workmanager |
|---------|:--:|:--:|:--:|
| Native Workers (zero overhead) | ✅ 11 types | ❌ | ❌ |
| Task Chains (A→B→C) | ✅ Built-in | ❌ Manual | ❌ Manual |
| Memory per task | 2-5 MB (native) | 50+ MB | 40+ MB |
| Startup time | <100ms | 500ms | 400ms+ |
| Hybrid execution | ✅ Per-task choice | ❌ | ⚠️ Limited |
| Custom native workers | ✅ Kotlin/Swift | ❌ | ❌ |
| iOS Background URLSession | ✅ Built-in | ❌ | ❌ |

### Unique Features No Competitor Has

**1. Native Workers** ⭐⭐⭐⭐⭐
- Execute I/O tasks without spawning Flutter Engine
- 50MB memory savings per task
- 5x faster startup
- **11 Built-in Workers**: HTTP (request, upload, download, sync), Files (compress, decompress, copy, move, delete, list, mkdir), Image processing, Crypto (hash, encrypt, decrypt), plus custom Kotlin/Swift workers

**2. Task Chains** ⭐⭐⭐⭐⭐
- Automate multi-step workflows: A → B → C or A → [B1, B2, B3] → D
- Built-in dependency management
- Automatic failure handling
- No competitor has this

**3. Hybrid Execution Model** ⭐⭐⭐⭐
- Choose per-task: Native (fast, low memory) or Dart (full Flutter)
- `autoDispose` flag for fine-grained memory control
- Best of both worlds

**4. Cross-Platform Consistency** ⭐⭐⭐⭐
- Unified API across Android and iOS
- 95% behavior consistency
- Future-proof architecture for Desktop/Web support

[See detailed comparison →](doc/FAQ.md#how-does-this-compare-to-other-solutions)

---

## 🖥️ Platform Support

| Platform | Status | Min Version | Key Limitation |
|----------|:------:|:-----------:|----------------|
| **Android** | ✅ Full Support | API 21 (5.0+) | Doze mode may defer tasks |
| **iOS** | ✅ Full Support | iOS 12.0+ | **30-second execution limit** |
| **Web** | 🔜 Planned | - | v1.2+ |
| **macOS** | 🔜 Planned | - | v1.3+ |
| **Windows** | 🔜 Planned | - | v1.3+ |
| **Linux** | 🔜 Planned | - | v1.3+ |

### iOS: 30-Second Execution Limit ⚠️

Background tasks on iOS **must complete in 30 seconds**. For longer tasks:

**Solutions:**
- ✅ **Use task chains** - Split work into 30-second chunks
- ✅ **Use native workers** - 5x faster than Dart workers
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
- **[Performance Guide](doc/PERFORMANCE_GUIDE.md)** - Optimize memory & battery
- **[Security Best Practices](doc/SECURITY_AUDIT.md)** - Encrypt data, handle tokens safely
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
A: Native workers: 2-5MB. Dart workers: ~50MB. Depends on worker type and task complexity.

**Q: Can I chain 100 tasks together?**
A: Yes, but on iOS each task in the chain must complete within 30 seconds. Use native workers for speed.

**Q: What happens if a task in a chain fails?**
A: The chain stops. Subsequent tasks are cancelled. You can use retry policies to handle failures.

**Q: Is this compatible with flutter_workmanager?**
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

- ✅ **Security Audit Passed** - No critical vulnerabilities
- ✅ **744+ Unit Tests Passing** - Comprehensive test suite covering all workers
- ✅ **100% Worker Coverage** - All 11 native workers tested
- ✅ **Performance Verified** - Benchmarks published, independent validation invited
- ✅ **Used in Production** - Apps with 1M+ active users

[See v1.0.0 release notes →](doc/releases/RELEASE_v1.0.0.md)

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

## 🗺️ Roadmap

**v1.0** ✅ - Production Release (February 2026)
- API stability guarantee
- Security audit passed
- Performance benchmarks published
- 744+ unit tests passing, all workers covered

**v1.1** (Q2 2026)
- Password-protected ZIP support
- Query params builder for HTTP workers
- Advanced file system features (batch operations)

**v1.2+** (Q3-Q4 2026)
- Task history & analytics
- Web platform support
- Desktop platform support (Windows/macOS/Linux)

[See full roadmap →](doc/strategy/MARKETING_ROADMAP.md)

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to report bugs
- How to request features
- How to submit pull requests
- Coding standards

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

**You can:**
- ✅ Use in commercial projects
- ✅ Modify the code
- ✅ Distribute freely

**You must:**
- ✅ Include license and copyright notice

---

## 🙏 Acknowledgments

Built with ❤️ using platform-native APIs:
- **Android:** WorkManager - Google's official background task library
- **iOS:** BGTaskScheduler - Apple's background task framework
- **Shared Core:** [kmpworkmanager](https://github.com/frankois944/kmpworkmanager) - Cross-platform worker orchestration

Inspired by Android WorkManager and iOS BackgroundTasks best practices.

---

**⭐ If this library saves you 50MB RAM and improves battery life, please star the repo!**

[GitHub Repository](https://github.com/brewkits/native_workmanager) | [pub.dev Package](https://pub.dev/packages/native_workmanager) | [Documentation](doc/)
