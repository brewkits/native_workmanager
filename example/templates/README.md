# Code Templates

Copy-paste ready code templates for common native_workmanager use cases.

## 📁 Templates Available

### 1. `basic_http_sync.dart` - Basic HTTP Sync ⭐ Start Here

**Use Case:** Periodic API synchronization

**Features:**
- Periodic HTTP GET/POST requests
- Response validation with regex
- Event listening for completion tracking
- Constraint-based execution (network, battery)

**Perfect For:**
- Syncing app data with server
- Checking for new messages/notifications
- Updating content cache
- Session refresh

**Complexity:** ⚫ Beginner

---

### 2. `file_upload_retry.dart` - File Upload with Retry

**Use Case:** Uploading files with automatic retry on failure

**Features:**
- Single file upload
- Multi-file upload (multiple files in one request)
- Raw JSON/bytes upload (no temp file)
- Progress tracking
- Exponential backoff retry

**Perfect For:**
- Photo/video backup
- Document upload
- Gallery uploads (multiple photos)
- Log file upload

**Complexity:** ⚫⚫ Intermediate

---

### 3. `chain_workflow.dart` - Task Chain Workflows

**Use Case:** Complex multi-step background workflows

**Features:**
- Sequential chains (A → B → C)
- Parallel chains (A → [B1, B2, B3] → D)
- Error handling with automatic retry
- Real-world workflow examples

**Included Workflows:**
1. Download → Extract → Upload
2. Download → Compress → Upload
3. Parallel image processing
4. Crypto workflow (Download → Verify → Decrypt)
5. Conditional workflow with validation

**Perfect For:**
- Resource pack downloads
- Media processing pipelines
- Backup workflows
- Complex data transformations

**Complexity:** ⚫⚫⚫ Advanced

---

### 4. `periodic_sync.dart` - Periodic Background Sync

**Use Case:** Multiple periodic synchronization tasks

**Features:**
- Multiple sync endpoints with different intervals
- Constraint-based execution
- Sync status tracking
- Manual sync triggers

**Included Syncs:**
- User data sync (every 1 hour)
- Messages sync (every 15 minutes)
- Media backup (daily on WiFi + charging)
- Analytics sync (every 6 hours)

**Perfect For:**
- Multi-endpoint sync systems
- Different sync frequencies per data type
- Conditional sync (WiFi, charging, battery)

**Complexity:** ⚫⚫ Intermediate

---

### 5. `crypto_operations.dart` - Cryptography Operations

**Use Case:** File hashing, encryption, and decryption

**Features:**
- File hashing (MD5, SHA-1, SHA-256, SHA-512)
- String hashing
- File encryption (AES-256)
- File decryption
- Secure workflows

**Perfect For:**
- File integrity verification
- Secure file storage
- Password hashing
- Deduplication (hash-based)
- Download verification

**Complexity:** ⚫⚫⚫ Advanced

---

## 🚀 How to Use

### Quick Start (3 steps)

1. **Copy template to your project**
   ```bash
   cp example/templates/basic_http_sync.dart lib/
   ```

2. **Replace placeholder values**
   - Search for `YOUR_API_URL` and replace with your endpoint
   - Search for `YOUR_AUTH_TOKEN` and replace with your token
   - Search for `/path/to/file` and replace with actual paths

3. **Run and test**
   ```bash
   flutter run
   ```

### Customization Tips

#### Update API Endpoints
```dart
// Before:
url: 'https://api.example.com/sync',

// After:
url: 'https://yourapi.com/v1/sync',
```

#### Add Authentication
```dart
headers: {
  'Authorization': 'Bearer ${await getAuthToken()}',
  'Content-Type': 'application/json',
}
```

#### Adjust Intervals
```dart
// Before: Every 1 hour
trigger: TaskTrigger.periodic(Duration(hours: 1)),

// After: Every 30 minutes
trigger: TaskTrigger.periodic(Duration(minutes: 30)),
```

#### Add Constraints
```dart
constraints: Constraints(
  requiresNetwork: true,       // Only when network available
  requiresWifi: true,          // Only on WiFi
  requiresCharging: true,      // Only when charging
  requiresBatteryNotLow: true, // Skip if battery low
)
```

---

## 📖 Learning Path

### For Beginners
1. Start with `basic_http_sync.dart`
2. Learn event listening and status tracking
3. Experiment with different intervals and constraints

### For Intermediate Users
1. Try `file_upload_retry.dart`
2. Learn progress tracking and retry logic
3. Move to `periodic_sync.dart` for multiple syncs

### For Advanced Users
1. Study `chain_workflow.dart`
2. Build complex multi-step workflows
3. Combine with `crypto_operations.dart` for secure workflows

---

## 💡 Common Patterns

### Pattern 1: API Sync with Validation
```dart
NativeWorker.httpRequest(
  url: 'https://api.example.com/sync',
  method: HttpMethod.post,
  successPattern: r'"status"\s*:\s*"success"',  // Must match this
  failurePattern: r'"error"',                   // Fail if matches this
)
```

### Pattern 2: Conditional Execution
```dart
constraints: Constraints(
  requiresWifi: true,          // Large uploads
  requiresCharging: true,      // Battery-intensive tasks
  requiresBatteryNotLow: true, // Skip if low battery
)
```

### Pattern 3: Retry with Backoff
```dart
backoffPolicy: BackoffPolicy(
  delay: Duration(seconds: 10),
  maxDelay: Duration(minutes: 5),
  backoffType: BackoffType.exponential,  // 10s, 20s, 40s, 80s...
),
maxAttempts: 5,
```

### Pattern 4: Progress Tracking
```dart
NativeWorkManager.events.listen((event) {
  if (event.state == TaskState.running) {
    print('Progress: ${(event.progress ?? 0) * 100}%');
  }
});
```

---

## 🔧 Troubleshooting

### Issue: Template doesn't run

**Solution:** Check that you've:
1. Replaced all placeholder values
2. Added authentication if required
3. Verified file paths exist
4. Initialized NativeWorkManager in main()

### Issue: Task never starts

**Solution:** Check constraints:
```dart
// Remove constraints for testing
constraints: Constraints(),  // No constraints
```

### Issue: Task fails immediately

**Solution:** Enable detailed logging:
```dart
NativeWorkManager.events.listen((event) {
  print('Task ${event.taskId}: ${event.state}');
  if (event.state == TaskState.failed) {
    print('Error: ${event.error}');
  }
});
```

### Issue: Progress not updating

**Solution:** Make sure you're listening to events before enqueueing:
```dart
// Setup listener BEFORE enqueue
NativeWorkManager.events.listen(...);
await NativeWorkManager.enqueue(...);
```

---

## 📚 Additional Resources

- [Getting Started Guide](../../docs/GETTING_STARTED.md)
- [Use Case Examples](../../docs/use-cases/)
- [API Reference](../../docs/API_REFERENCE.md)
- [Production Guide](../../docs/PRODUCTION_GUIDE.md)

---

## 🤝 Contributing

Have a useful template? Submit a PR!

**Template Requirements:**
- Complete, runnable code
- Clear inline comments
- Placeholder values marked with 👈
- Usage instructions in header
- Real-world use case

---

## 📝 Template Checklist

When creating a new template, include:

- [ ] Header comment with description
- [ ] Usage instructions
- [ ] Copy-paste ready code
- [ ] Placeholder values clearly marked
- [ ] Event listener setup
- [ ] Error handling
- [ ] Real-world example
- [ ] Common variations in comments
- [ ] Complexity rating

---

**Last Updated:** 2026-02-07
**Templates:** 5 files
**Total Lines:** 1,500+ lines of example code
