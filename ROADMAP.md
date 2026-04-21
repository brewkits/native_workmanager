# native_workmanager Roadmap

Our mission is to provide the most robust, efficient, and secure background execution engine for Flutter.

---

## ✅ Completed (v1.2.x)
- **Android Cold-Start Persistence:** `DartWorker` execution reliably survives app kills and restores automatically via `SharedPreferences`.
- **Advanced Remote Trigger (FCM/APNs):** Deep integration allowing backends to enqueue complete Task Chains, Graphs, and Offline Queues via silent push without waking the Flutter Engine.
- **HMAC Security:** Robust HMAC SHA-256 signature verification for remote triggers.
- **Task Dependency Graph (DAG):** Support for complex non-linear task dependencies.
- **Middleware / Decorator API:** Global interceptors for task execution (e.g., custom logging, analytics, dynamic headers).
- **Code Generation (`native_workmanager_gen`):** Generate type-safe enqueue wrappers and automatic worker registries via `@WorkerCallback` annotations.
- **Real-Time Observability:** DevTools extension real-time visualizer for tracking task events and engine status.
- **Automated Migration Tool:** CLI tool to safely migrate legacy `workmanager` projects to `native_workmanager` (`dart run native_workmanager:migrate`).
- **Selective Plugin Registration (v1.2.2):** Explicit opt-in flag `registerPlugins` and native callbacks (`setPluginRegistrantCallback`) to control background engine footprint.
- **iOS 18 / Flutter 3.38+ Compatibility (v1.2.2):** Safe window traversal and `UISceneDelegate` support.

---

## ✅ Completed (v1.1.0)
- **Zero-Flutter-Engine Workers:** 25+ native workers for HTTP, Crypto, File, Image, and more.
- **Task Chaining:** Sequential and parallel task execution with native SQLite persistence.
- **Isolate Caching:** 5-minute warm engine retention for Dart callbacks.
- **Enterprise Security:** Certificate pinning, SSRF protection, Zip-bomb protection.
- **Fluent API:** Builder-style task configuration.

---

## 🛠 Phase 2: Patterns & Reliability (v1.3.x - v1.5.x)
- [ ] **Offline Queue Pattern:** Built-in declarative pattern for queuing tasks while offline with automatic file/database-backed retry.
- [ ] **native_workmanager_firebase:** Dedicated companion package for seamless, highly optimized Firebase integration (FCM triggers, Analytics, Crashlytics).
- [ ] **Task Tagging & Batch Operations:** Cancel or query multiple tasks at once via tags.
- [ ] **Advanced iOS Background Optimization:** Further improvements to memory footprint and BGTaskScheduler integration.

[Phase 2 Architectural Proposals available in internal documentation]

---

## 🚀 Phase 3: Ecosystem & Scale (v2.0.x+)
- [ ] **Cloud Coordination:** Synchronize task status and dependency resolution across multiple devices.
- [ ] **Enterprise Rate Limiting:** Advanced bandwidth and concurrency control for multi-tenant apps.
- [ ] **Desktop Support:** Expanding the native worker engine to Windows, macOS, and Linux.

---

## KPIs Target
| Metric | 3 Months | 6 Months | 12 Months |
|--------|---------|---------|----------|
| pub.dev Likes | 100+ | 500+ | 2,000+ |
| GitHub Stars | 200+ | 1,000+ | 3,000+ |
| Weekly Downloads | 1k | 5k | 20k |
| Enterprise Users | 1 | 3+ | 10+ |
| pub.dev Score | 140 | 140 | 140 |
