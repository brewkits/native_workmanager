# native_workmanager Roadmap

Our mission is to provide the most robust, efficient, and secure background execution engine for Flutter.

---

## ✅ Completed (v1.1.0)
- **Zero-Flutter-Engine Workers:** 25+ native workers for HTTP, Crypto, File, Image, and more.
- **Remote Trigger:** Support for FCM (Android) and APNs (iOS) data messages to trigger native workers without waking Flutter.
- **Task Chaining:** Sequential and parallel task execution with native persistence.
- **Isolate Caching:** 5-minute warm engine retention for Dart callbacks.
- **Enterprise Security:** Certificate pinning, HMAC signing, SSRF protection, Zip-bomb protection.
- **Fluent API:** Builder-style task configuration.
- **DevTools Extension:** Real-time task and engine monitoring.

---

## 🛠 Phase 2: Power & Flexibility (v2.0.x)
- [ ] **Advanced Remote Trigger (FCM/APNs):** Deep integration allowing backends to enqueue complete Task Graphs and Offline Queues via silent push without waking the Flutter Engine.
- [ ] **Observability (DevTools Extension):** Real-time visualizer for Task Graphs (DAG) and Offline Queue inspection directly within Flutter DevTools.
- [ ] **Task Dependency Graph (DAG):** Support for complex non-linear task dependencies.
- [ ] **Offline Queue Pattern:** Built-in pattern for queuing tasks while offline with automatic file/database-backed retry.
- [ ] **Middleware / Decorator API:** Intercept task execution for custom logging, analytics, or global headers.

[Phase 2 Architectural Proposals available in internal documentation]

---

## 🚀 Phase 3: Ecosystem & Scale (v2.5.x+)
- [ ] **Code Generation:** `native_workmanager_gen` to generate type-safe worker wrappers.
- [ ] **native_workmanager_firebase:** Dedicated companion package for seamless Firebase integration.
- [ ] **Cloud Coordination:** Synchronize task status across multiple devices.
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
