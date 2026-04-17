# Advanced Remote Trigger Guide (Phase 2)

This guide explains how to use the new Advanced Remote Trigger features to control background tasks from your backend.

## 1. Direct Payload Commands

Instead of pre-registering rules on the device, your backend can send a complete task schema directly in the push payload (FCM or APNs).

### Key: `native_wm`
The payload must contain a `native_wm` key. Its value can be a JSON object or a JSON string.

### Actions

#### `enqueue_task`
Enqueue a single native worker.

```json
{
  "native_wm": {
    "action": "enqueue_task",
    "data": {
      "taskId": "remote_sync_123",
      "workerClassName": "HttpSyncWorker",
      "workerConfig": {
        "url": "https://api.example.com/sync",
        "method": "POST"
      }
    }
  }
}
```

#### `offline_queue_enqueue`
Add a task to the persistent offline queue.

```json
{
  "native_wm": {
    "action": "offline_queue_enqueue",
    "data": {
      "queueId": "important_updates",
      "entry": {
        "taskId": "task_456",
        "workerClassName": "HttpDownloadWorker",
        "workerConfig": { "url": "https://cdn.com/file" },
        "retryPolicy": { "requiresNetwork": true }
      }
    }
  }
}
```

---

## 2. HMAC Security (Recommended)

To protect your users from malicious pushes, enable HMAC signature verification.

### Step 1: Register Secret on Device
```dart
await NativeWorkManager.registerRemoteTrigger(
  source: RemoteTriggerSource.fcm,
  rule: RemoteTriggerRule(
    payloadKey: 'type',
    workerMappings: { ... },
    secretKey: 'your_shared_secret_key' // Keep this secure
  ),
);
```

### Step 2: Backend Signs the Payload
Your backend must compute an HMAC SHA-256 signature and include it in the payload as `x-native-wm-signature`.

**Signing Logic (Pseudocode):**
1. Canonicalize payload:
   - Remove `x-native-wm-signature`.
   - Sort keys alphabetically.
   - Join entries with `|` (e.g., `key1=val1|key2=val2`).
2. Compute `hmac_sha256(canonical_string, secret_key)`.
3. Hex encode the result.

**Example Signed Payload:**
```json
{
  "type": "sync",
  "data_id": "999",
  "x-native-wm-signature": "a1b2c3d4e5f6..." 
}
```

---

## 3. Implementation Details

- **Android**: Handled in `NativeWorkmanagerPlugin.onRemoteMessage`.
- **iOS**: Handled in `NativeWorkmanagerPlugin.onRemoteNotification`.
- **Latency**: Tasks are enqueued with 0 delay but respect OS background limits.
