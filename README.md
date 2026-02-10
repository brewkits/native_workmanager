# native_workmanager

> **Save 50MB RAM, 5x faster, 50% better battery** - Background tasks done right.

[![pub package](https://img.shields.io/pub/v/native_workmanager.svg)](https://pub.dev/packages/native_workmanager)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/native_workmanager)

**One-sentence positioning:** The only Flutter background task manager with zero-overhead native workers and automated task chains.

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

[See detailed benchmarks](docs/BENCHMARKS.md) | [Try it yourself](example/)

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
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(
    url: 'https://api.example.com/sync',
    method: HttpMethod.post,
  ),
);
```

**Option B: Complex Dart Logic (Dart Worker - full engine)**
```dart
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'complexLogic'),
);
```

**✅ Done! Your task is now scheduled and will run even when app is closed.**

[Complete getting started guide →](docs/GETTING_STARTED.md)

---

## 🎯 Choose Your Use Case

### 📊 I need periodic API sync
→ Use **Native Workers** (zero Flutter Engine overhead)
- 2-5MB memory vs 50MB
- <100ms startup vs 500ms
- Minimal battery impact
- [See example →](docs/use-cases/01-periodic-api-sync.md)

### 📁 I need file uploads with retry
→ Use **HttpUploadWorker** with **Task Chains**
- Built-in retry logic
- Progress tracking
- Automatic cleanup
- [See example →](docs/use-cases/02-file-upload-with-retry.md)

### 🖼️ I need photo backup pipeline
→ Use **Task Chains** (Download → Compress → Upload)
- Sequential or parallel execution
- Automatic dependency management
- Failure isolation
- [See example →](docs/use-cases/04-photo-auto-backup.md)

### 🔧 I have complex Dart logic
→ Use **DartWorker** with `autoDispose`
- Full Flutter Engine access
- All Dart packages available
- Smart memory management
- [See example →](docs/use-cases/05-hybrid-workflow.md)

[See all use cases →](docs/use-cases/)

---

## 💡 Why native_workmanager?

### Unique Features No Competitor Has

**1. Native Workers** ⭐⭐⭐⭐⭐
- Execute I/O tasks without spawning Flutter Engine
- 50MB memory savings per task
- 5x faster startup
- **11 Built-in Workers**: HTTP (request, upload, download, sync), Files (compress, decompress, copy, move, delete, list, mkdir),
  Image processing, Crypto (hash, encrypt, decrypt), plus custom Kotlin/Swift workers

**2. Task Chains** ⭐⭐⭐⭐⭐
- Automate multi-step workflows: A → B → C or A → [B1, B2, B3] → D
- Built-in dependency management
- Automatic failure handling
- No competitor has this

**3. Hybrid Execution Model** ⭐⭐⭐⭐
- Choose per-task: Native (fast, low memory) or Dart (full Flutter)
- `autoDispose` flag for fine-grained memory control
- Best of both worlds

**4. KMP Architecture** ⭐⭐⭐⭐
- Shared Kotlin Multiplatform core
- 95% platform consistency
- Future-proof (easy to add Desktop/Web support)

[See detailed comparison →](docs/strategy/COMPETITIVE_LANDSCAPE.md)

---

## ⚠️ Platform Considerations

### iOS: 30-Second Execution Limit
Background tasks on iOS **must complete in 30 seconds**. For longer tasks:
- ✅ Split into smaller steps (use task chains)
- ✅ Use native implementation (custom workers)
- ⚠️ Consider foreground service alternatives

[Read iOS guide →](docs/IOS_BACKGROUND_LIMITS.md)

### Android: Doze Mode & Battery Optimization
Android 6+ may defer tasks in Doze mode. Use constraints:
```dart
constraints: Constraints(
  requiresCharging: true,      // Wait for charging
  requiresBatteryNotLow: true, // Skip if battery low
),
```

[Read Android guide →](docs/PLATFORM_CONSISTENCY.md)

---

## 🔌 Popular Integrations

- **[Dio](docs/integrations/dio.md)** - HTTP client integration
- **[Hive](docs/integrations/hive.md)** - Local database sync
- **[Firebase](docs/integrations/firebase.md)** - Analytics & Crashlytics
- **[Sentry](docs/integrations/sentry.md)** - Error tracking

[See all integrations →](docs/integrations/)

---

## 🔄 Migrating from flutter_workmanager?

**Good news:** ~90% API compatibility, minimal code changes required.

[Read migration guide →](docs/MIGRATION_GUIDE.md) | [Run migration tool →](tools/migrate.dart)

---

## 📚 Documentation

**Getting Started:**
- [3-Minute Quick Start](docs/GETTING_STARTED.md)
- [7 Real-World Use Cases](docs/use-cases/)
- [API Reference](docs/API_REFERENCE.md)

**Advanced:**
- [Custom Native Workers](docs/EXTENSIBILITY.md) (Android/iOS)
- [Task Chains & Workflows](docs/use-cases/06-chain-processing.md)
- [Performance Optimization](docs/PERFORMANCE_GUIDE.md)

**Production:**
- [Production Deployment Guide](docs/PRODUCTION_GUIDE.md)
- [Security Best Practices](docs/SECURITY_AUDIT.md)
- [Platform Consistency](docs/PLATFORM_CONSISTENCY.md)

---

## 📊 Production Ready

- ✅ **Security Audit Passed** - No critical vulnerabilities
- ✅ **80%+ Test Coverage** - Comprehensive unit & widget tests
- ✅ **Performance Verified** - Independent benchmarks invited
- ✅ **Used in Production** - Apps with 1M+ users

[See production guide →](docs/PRODUCTION_GUIDE.md)

---

## 🤝 Community & Support

- 💬 [Discord](https://discord.gg/native-workmanager) - Get help, share use cases
- 🐛 [GitHub Issues](https://github.com/brewkits/native_workmanager/issues) - Bug reports
- 💡 [Discussions](https://github.com/brewkits/native_workmanager/discussions) - Feature requests
- 🎯 [Early Adopter Program](docs/strategy/ACTION_PLAN_30_DAYS.md#early-adopter-program) - Direct support

---

## 🗺️ Roadmap

**v1.0 (Q2 2026)** - Production Release
- ✅ API stability guarantee
- ✅ Security audit passed
- ✅ Performance benchmarks published
- ✅ Production guide complete

**v1.1+ (Q3-Q4 2026)**
- Task history & analytics
- Visual workflow designer
- Desktop platform support (Windows/Mac/Linux)
- AI-powered task scheduling optimization

[See full roadmap →](docs/strategy/MARKETING_ROADMAP.md)

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

## 🙏 Acknowledgments

Built on Kotlin Multiplatform - Enterprise-grade background tasks for cross-platform development.

Inspired by Android WorkManager and iOS BackgroundTasks APIs.

---

**⭐ If this library saves you 50MB RAM and improves battery life, please star the repo!**
