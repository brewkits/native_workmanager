# Phase 2 Implementation: Power & Flexibility

This document records the architectural upgrades implemented in Phase 2 (v2.0.x).

---

## 1. Advanced Remote Trigger (FCM/APNs)

Backend servers can now trigger complex background workflows without waking the Flutter Engine.

### Direct Payload Commands
Payloads containing the `native_wm` key are processed as direct commands.
Supported actions:
- `enqueue_task`: Enqueue a single native worker.
- `enqueue_chain`: Enqueue a sequential/parallel chain of tasks.
- `offline_queue_enqueue`: Add a task to the native persistent offline queue.
- `enqueue_graph` (Android): Enqueue a complex Directed Acyclic Graph (DAG) of tasks.

### HMAC Security Enforcement
To prevent battery-drain attacks and unauthorized task execution, Remote Trigger now supports HMAC SHA-256 signature verification.
- **Registration**: Register a `secretKey` during initialization.
- **Secure Storage**: Sensitive keys are stored in hardware-backed secure storage (**Android EncryptedSharedPreferences** and **iOS Keychain**) to prevent extraction from rooted/jailbroken devices.
- **Verification**: The native side verifies the `x-native-wm-signature` in the payload.
- **Canonicalization**: Payload keys (excluding signature) are sorted alphabetically and joined with `|` before signing.

---

## 2. Real-Time Observability (DevTools Extension)

### Event Streaming
The host application now streams lifecycle and progress events to the DevTools extension via `developer.postEvent`.
- **Immediate Feedback**: Progress bars and status changes update instantaneously.
- **Bi-directional**: Support for manual "Sync Now" from the DevTools UI.

---

## 3. Middleware API

Global interceptors for background tasks.
- **HeaderMiddleware**: Automatically inject Auth tokens or custom headers into HTTP requests.
- **LoggingMiddleware**: Fire-and-forget execution logs to a custom backend after task completion.
- **RemoteConfigMiddleware**: Inject configuration values from remote sources at execution time.

---

## 4. Task Dependency Graph (DAG) - Android

Support for complex non-linear task chains using Android's `WorkContinuation`.
- **Cycle Detection**: Prevents infinite recursion in malformed graphs.
- **Parallel Execution**: Parallel nodes in the graph run concurrently within OS constraints.
- **Persistence**: Graph state is stored in SQLite and survives app restarts.
