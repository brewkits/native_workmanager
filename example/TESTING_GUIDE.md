# 🧪 Native WorkManager Demo App - Testing Guide

**Version:** 1.0.0
**Platforms:** iOS 13+ | Android 8.0+
**Last Updated:** 2026-01-24

---

## 📱 Overview

Demo app có **6 tabs**, mỗi tab demo một nhóm features:

1. **Basic** - Native Workers (HTTP, File, Database)
2. **Retry** - BackoffPolicy v1.0.0 (Exponential & Linear)
3. **ContentUri** - ContentUri Triggers v1.0.0 (Android only)
4. **Constraints** - Advanced Constraints (QoS, isHeavyTask)
5. **Chains** - Task Chains (Sequential & Parallel)
6. **Scheduled** - Scheduled Tasks (Periodic, Exact, Windowed)

---

## 🎯 Tab 1: Basic Tasks (Native Workers)

### Features Tested
- HTTP GET requests
- HTTP POST requests
- JSON synchronization
- Native worker execution (zero Flutter Engine)

### Test Steps

#### 1.1 HTTP GET Request
**Button:** "HTTP GET"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: HTTP GET task
✅ http-1: Success
  Response: 200 OK from httpbin.org/get
```

**What to Verify:**
- Task executes immediately (no delay)
- Event log shows ✅ success
- Response includes GET request data
- RAM usage: ~3-5MB (check Activity Monitor/Profiler)

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 1.2 HTTP POST Request
**Button:** "HTTP POST"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: HTTP POST task
✅ post-1: Success
  Posted JSON data with timestamp
```

**What to Verify:**
- POST body includes JSON data
- Timestamp is current time
- Server echoes back the posted data
- Content-Type header is application/json

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 1.3 JSON Sync
**Button:** "JSON Sync"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: JSON sync task
✅ sync-1: Success
  Synced JSON payload to server
```

**What to Verify:**
- JSON payload includes lastSync timestamp
- Data array contains items
- Network constraint is respected (only runs when connected)

**Test on:**
- ✅ iOS
- ✅ Android

---

### Performance Comparison

**Native Workers (Mode 1):**
- RAM: 3-5MB
- Startup: <50ms
- Battery: Minimal

**vs Flutter Workers (Mode 2):**
- RAM: 30-50MB
- Startup: 500-1000ms (first time), 100-200ms (cached)
- Battery: Moderate

---

## 🔄 Tab 2: Retry (BackoffPolicy v1.0.0)

### Features Tested
- Exponential backoff retry
- Linear backoff retry
- Custom delay configuration
- Automatic retry on failure

### Test Steps

#### 2.1 Exponential Backoff
**Button:** "Exponential Backoff"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Exponential Backoff (backoff-exp-1)
⏰ Retry delays: 10s → 20s → 40s → 80s
❌ backoff-exp-1: Failed (Status 500)
⏰ Retrying in 10 seconds...
❌ backoff-exp-1: Failed (Status 500)
⏰ Retrying in 20 seconds...
...
```

**What to Verify:**
- Initial delay: 10 seconds
- Each retry doubles the delay (10s → 20s → 40s → 80s)
- Task fails because URL returns 500 error (intentional)
- Maximum 5 retry attempts
- Total time: ~310 seconds (10+20+40+80+160)

**Test on:**
- ✅ iOS
- ✅ Android

**How to Test:**
1. Click "Exponential Backoff"
2. Watch event log
3. Note the time between retries
4. Verify delays double each time
5. Wait ~5 minutes to see all retries

---

#### 2.2 Linear Backoff
**Button:** "Linear Backoff"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Linear Backoff (backoff-linear-1)
⏰ Retry delays: 30s → 60s → 90s → 120s
❌ backoff-linear-1: Failed (Status 503)
⏰ Retrying in 30 seconds...
❌ backoff-linear-1: Failed (Status 503)
⏰ Retrying in 60 seconds...
...
```

**What to Verify:**
- Initial delay: 30 seconds
- Each retry adds 30s (30s → 60s → 90s → 120s)
- Linear progression (not exponential)
- Maximum 5 retry attempts
- Total time: ~300 seconds (30+60+90+120)

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 2.3 Custom Delay
**Button:** "Custom Delay (60s)"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Custom Delay (backoff-custom-1)
⏰ Initial delay: 60 seconds
❌ backoff-custom-1: Failed
⏰ Retrying in 60 seconds...
```

**What to Verify:**
- Uses custom backoffDelayMs (60000ms = 60s)
- Retry delays match configured value
- Can be any value from 10000ms (10s) to 3600000ms (1 hour)

**Test on:**
- ✅ iOS
- ✅ Android

---

### BackoffPolicy Use Cases

**Exponential (Recommended for):**
- Network requests (API calls, HTTP)
- External service integration
- Rate-limited APIs
- Transient failures

**Linear (Recommended for):**
- Database operations
- File I/O operations
- Internal processing tasks
- Predictable retry patterns

---

## 📸 Tab 3: ContentUri (Android Only)

### Features Tested
- Content provider observation
- Photo/media changes detection
- Contact changes detection
- Automatic task triggering

### Test Steps

#### 3.1 Photo Observer
**Button:** "Observe Photos"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Photo Observer
⏰ Watching: content://media/external/images/media
```

**How to Trigger:**
1. Click "Observe Photos"
2. **Take a photo** with Android camera app
3. Or **download an image** from browser
4. Return to demo app

**Expected After Photo:**
```
Event Log:
✅ photo-observer: Triggered
📸 New photo detected
📤 Backing up photo...
✅ Backup complete
```

**What to Verify:**
- Task triggers automatically when photo added
- Works when app is in background
- triggerForDescendants: true (detects subdirectories)

**Test on:**
- ❌ iOS (Not available - Android only)
- ✅ Android

---

#### 3.2 Contacts Observer
**Button:** "Observe Contacts"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Contacts Observer
⏰ Watching: content://com.android.contacts/contacts
```

**How to Trigger:**
1. Click "Observe Contacts"
2. **Add/edit/delete a contact** in Contacts app
3. Return to demo app

**Expected After Contact Change:**
```
Event Log:
✅ contacts-observer: Triggered
📇 Contact change detected
📤 Syncing contacts...
✅ Sync complete
```

**What to Verify:**
- Task triggers on contact add/edit/delete
- Works when app is in background
- Can sync contacts to server

**Test on:**
- ❌ iOS (Not available - Android only)
- ✅ Android

---

#### 3.3 Combined: ContentUri + Constraints
**Button:** "Photos + Network + Charging"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Photo backup with constraints
⏰ Will only run when:
  - New photo detected
  - Network connected
  - Device charging
```

**How to Test:**
1. Click button
2. **Unplug device** (disable charging)
3. Take a photo → Task will NOT trigger
4. **Plug in device** (enable charging)
5. Take another photo → Task WILL trigger

**What to Verify:**
- Constraints are enforced (network + charging)
- Task waits until all conditions met
- Useful for heavy operations (photo backup, sync)

**Test on:**
- ❌ iOS (Not available)
- ✅ Android

---

### ContentUri Use Cases

**Photo/Media Observation:**
- Auto backup photos to cloud
- Photo sync between devices
- Media library cataloging
- Automatic image processing

**Contacts Observation:**
- Contact sync to server
- Backup contacts
- Cross-device contact sync
- CRM integration

**Other Content Providers:**
- Calendar events
- Messages/SMS
- Call logs
- Downloads

---

## ⚙️ Tab 4: Constraints (Advanced)

### Features Tested
- Quality of Service (QoS) levels
- Heavy task classification
- Constraint combinations
- Intelligent scheduling

### Test Steps

#### 4.1 QoS: User Initiated (High Priority)
**Button:** "QoS: User Initiated"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: User Initiated Task (qos-user-1)
⚡ Priority: HIGH
✅ qos-user-1: Executed immediately
  Execution time: <100ms
```

**What to Verify:**
- Task runs IMMEDIATELY (no delay)
- High priority execution
- Useful for user-facing operations
- Should complete quickly (<5 seconds)

**When to Use:**
- User clicked "Sync Now" button
- Immediate API call needed
- Time-sensitive operations
- User is waiting for result

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 4.2 QoS: Background (Low Priority)
**Button:** "QoS: Background"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Background Task (qos-bg-1)
⏰ Priority: LOW - will run when idle
⏳ Deferred execution...
✅ qos-bg-1: Executed (after delay)
  Wait time: 30-120 seconds
```

**What to Verify:**
- Task is DEFERRED (not immediate)
- Runs when system is idle
- Low battery/CPU impact
- May wait several minutes

**When to Use:**
- Non-urgent sync
- Cache cleanup
- Log uploads
- Background maintenance

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 4.3 Heavy Task (Deferred to Charging + Idle)
**Button:** "Heavy Task"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Heavy Task (heavy-1)
⚙️ Constraints:
  - isHeavyTask: true
  - requiresCharging: true
  - requiresDeviceIdle: true
  - requiresBatteryNotLow: true
⏳ Waiting for optimal conditions...
```

**How to Test:**
1. Click "Heavy Task"
2. Task will NOT run immediately
3. **Plug in device** (charging)
4. **Lock screen** (device idle)
5. Wait a few minutes
6. Check logs

**Expected When Conditions Met:**
```
Event Log:
✅ heavy-1: Started
⚙️ Progress: 10%... 20%... 30%...
✅ heavy-1: Completed (10 seconds)
```

**What to Verify:**
- Task waits for charging + idle
- Does NOT drain battery during use
- System throttles execution
- Prevents device overheating

**When to Use:**
- Video encoding/processing
- Large file compression
- AI model inference
- Batch photo processing
- Database migrations

**Test on:**
- ✅ iOS
- ✅ Android

---

### QoS Levels Comparison

| QoS Level | Priority | Delay | Battery Impact | Use Case |
|-----------|----------|-------|----------------|----------|
| **userInitiated** | High | None | Moderate | User-facing operations |
| **utility** | Medium | Short | Low | User-visible but not urgent |
| **background** | Low | Long | Minimal | Invisible background tasks |

---

## ⛓️ Tab 5: Task Chains

### Features Tested
- Sequential execution (A → B → C)
- Parallel execution (A + B + C → D)
- Error propagation
- Chain termination

### Test Steps

#### 5.1 Sequential Chain
**Button:** "Sequential Chain"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Sequential Chain
⛓️ Download → Process → Upload
✅ chain-download: Started
✅ chain-download: Completed (200 OK)
⏳ Starting next task...
✅ chain-process: Started
✅ chain-process: Completed
⏳ Starting next task...
✅ chain-upload: Started
✅ chain-upload: Completed (200 OK)
🎉 Chain completed successfully!
```

**What to Verify:**
- Tasks run in ORDER (download → process → upload)
- Each task waits for previous to complete
- If any task fails, chain stops
- Total execution time = sum of all tasks

**Workflow:**
```
Step 1: Download file from httpbin.org
   ↓ (wait for completion)
Step 2: Process downloaded file
   ↓ (wait for completion)
Step 3: Upload result
```

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 5.2 Parallel Chain
**Button:** "Parallel Chain"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Parallel Chain
⛓️ Download → [Upload1 + Upload2] parallel
✅ parallel-download: Started
✅ parallel-download: Completed
⏳ Starting parallel tasks...
✅ parallel-upload-1: Started
✅ parallel-upload-2: Started
✅ parallel-upload-1: Completed
✅ parallel-upload-2: Completed
🎉 All parallel tasks completed!
```

**What to Verify:**
- Download runs first (sequential)
- Upload1 and Upload2 run SIMULTANEOUSLY (parallel)
- Both must complete before chain finishes
- Total time < sequential (because parallel)

**Workflow:**
```
Step 1: Download file
   ↓
   ├─→ Upload1 ──┐
   │             ├─→ Done
   └─→ Upload2 ──┘
   (both run at same time)
```

**Test on:**
- ✅ iOS
- ✅ Android

---

#### 5.3 Error Handling in Chains
**Button:** "Chain with Error"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Chain with Error
✅ step1: Success
❌ step2: Failed (500 error)
⚠️ Chain terminated (step 3 skipped)
```

**What to Verify:**
- Chain stops at first error
- Subsequent tasks are cancelled
- Error is propagated to caller
- Cleanup happens automatically

**Test on:**
- ✅ iOS
- ✅ Android

---

### Chain Use Cases

**Sequential Chains:**
- Download → Process → Upload workflow
- Fetch → Transform → Store pipeline
- Backup → Compress → Upload
- Any workflow where order matters

**Parallel Chains:**
- Fetch multiple APIs simultaneously
- Upload to multiple servers
- Parallel data processing
- Independent operations that can run together

---

## 📅 Tab 6: Scheduled Tasks

### Features Tested
- Periodic tasks (recurring)
- Exact time tasks (one-time at specific time)
- Windowed tasks (within time range)
- Background scheduling

### Test Steps

#### 6.1 Periodic Task
**Button:** "Periodic (15 min)"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Periodic Task
⏰ Interval: 15 minutes
✅ periodic-1: First execution
⏳ Next run: 3:45 PM
... (wait 15 minutes)
✅ periodic-1: Second execution
⏳ Next run: 4:00 PM
... (repeats forever until cancelled)
```

**What to Verify:**
- First execution: Immediate or short delay
- Subsequent executions: Every 15 minutes
- Runs indefinitely until cancelled
- Respects constraints (network, battery, etc.)

**Note:**
- **iOS:** Actual interval may vary (13-17 min) due to BGTaskScheduler optimization
- **Android:** More precise intervals with WorkManager

**When to Use:**
- Background sync every N hours
- Cache refresh
- Health data upload
- Regular maintenance tasks

**Test on:**
- ✅ iOS (may have longer intervals)
- ✅ Android (precise intervals)

---

#### 6.2 Exact Time Task
**Button:** "Exact (1 hour from now)"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Exact Time Task
⏰ Will run at: 4:30 PM (exactly)
⏳ Waiting...
... (wait ~60 minutes)
✅ exact-1: Executed at 4:30:00 PM
```

**What to Verify:**
- Runs at EXACT specified time
- High precision (±1 second)
- One-time execution (not recurring)
- Wakes device if sleeping (Android)

**Android 12+ Note:**
- Requires `SCHEDULE_EXACT_ALARM` permission
- User may need to grant in Settings

**When to Use:**
- Alarm/reminder apps
- Scheduled reports
- Time-based notifications
- Countdown timers

**Test on:**
- ✅ iOS (may have ±1 min variance)
- ✅ Android (precise with permission)

---

#### 6.3 Windowed Task
**Button:** "Windowed (1-2 hours)"

**Expected Behavior:**
```
Event Log:
📤 Scheduled: Windowed Task
⏰ Window: 1-2 hours from now
⏰ Will run between: 3:30 PM - 4:30 PM
⏳ Waiting for optimal time...
... (wait ~75 minutes)
✅ windowed-1: Executed at 3:45 PM
  (within the window)
```

**What to Verify:**
- Runs within specified window (1-2 hours)
- System picks optimal time (battery, network)
- One-time execution
- More battery-friendly than exact

**When to Use:**
- Flexible backups
- Non-urgent sync
- Battery-friendly uploads
- Deferred maintenance

**Test on:**
- ✅ iOS
- ✅ Android

---

### Scheduling Comparison

| Type | Precision | Battery Impact | When to Use |
|------|-----------|----------------|-------------|
| **Periodic** | ±5 min | Medium | Regular sync |
| **Exact** | ±1 sec | Higher | Alarms, timers |
| **Windowed** | Within range | Lower | Flexible tasks |

---

## 🎨 Event Log

### Log Format

```
[Time] [Status] [TaskID]: [Message]

14:30:15 ✅ http-1: Success
14:30:12 📤 Scheduled: HTTP GET task
14:30:10 🚀 Native WorkManager v1.0.0 initialized
```

### Status Icons

- 🚀 **Initialization**
- 📤 **Task Scheduled**
- ✅ **Success**
- ❌ **Failed**
- ⏰ **Scheduled/Waiting**
- ⏳ **In Progress**
- ⚙️ **Processing**
- 📸 **Media/Photo**
- 📇 **Contacts**
- ⛓️ **Chain**

### Clear Log

**Button:** "Clear" (top right)

Clears all log entries. Useful when testing to see fresh results.

---

## 📊 Performance Monitoring

### iOS

**Instruments:**
```bash
# Open Xcode Instruments
open -a Instruments

# Select: Time Profiler or Allocations
# Attach to: native_workmanager_example
# Monitor: CPU, Memory, Battery usage
```

**Activity Monitor:**
- Open Activity Monitor app
- Find "native_workmanager_example"
- Check: Memory, CPU, Energy Impact

### Android

**Android Profiler:**
```
1. Open Android Studio
2. View → Tool Windows → Profiler
3. Select: native_workmanager_example
4. Monitor: CPU, Memory, Network, Energy
```

**Memory Profiler:**
```
1. In Profiler, click Memory
2. Run native worker task
3. Observe: ~3-5MB RAM (native mode)
4. Run Dart worker task
5. Observe: ~30-50MB RAM (Dart mode)
```

**Battery Historian:**
```bash
# Capture battery stats
adb shell dumpsys batterystats --reset
# Run tests for 1 hour
adb bugreport > bugreport.zip
# Analyze with Battery Historian
```

---

## ✅ Testing Checklist

### Pre-Test

- [ ] iOS Simulator/Device running
- [ ] Android Emulator/Device running
- [ ] Network connected (for HTTP tests)
- [ ] Event log visible
- [ ] Enough time for async tests (1-2 hours)

### iOS Tests

- [ ] Tab 1: Basic - HTTP GET
- [ ] Tab 1: Basic - HTTP POST
- [ ] Tab 1: Basic - JSON Sync
- [ ] Tab 2: Retry - Exponential Backoff
- [ ] Tab 2: Retry - Linear Backoff
- [ ] Tab 3: ContentUri - **SKIP** (Android only)
- [ ] Tab 4: Constraints - QoS User Initiated
- [ ] Tab 4: Constraints - QoS Background
- [ ] Tab 4: Constraints - Heavy Task
- [ ] Tab 5: Chains - Sequential
- [ ] Tab 5: Chains - Parallel
- [ ] Tab 6: Scheduled - Periodic
- [ ] Tab 6: Scheduled - Exact
- [ ] Tab 6: Scheduled - Windowed

### Android Tests

- [ ] Tab 1: Basic - HTTP GET
- [ ] Tab 1: Basic - HTTP POST
- [ ] Tab 1: Basic - JSON Sync
- [ ] Tab 2: Retry - Exponential Backoff
- [ ] Tab 2: Retry - Linear Backoff
- [ ] Tab 3: ContentUri - Photos (take photo to trigger)
- [ ] Tab 3: ContentUri - Contacts (edit contact to trigger)
- [ ] Tab 4: Constraints - QoS User Initiated
- [ ] Tab 4: Constraints - QoS Background
- [ ] Tab 4: Constraints - Heavy Task
- [ ] Tab 5: Chains - Sequential
- [ ] Tab 5: Chains - Parallel
- [ ] Tab 6: Scheduled - Periodic
- [ ] Tab 6: Scheduled - Exact
- [ ] Tab 6: Scheduled - Windowed

### Performance Tests

- [ ] Memory: Native worker uses <5MB
- [ ] Memory: Dart worker uses 30-50MB
- [ ] Speed: Native worker starts <50ms
- [ ] Speed: Dart worker (cached) starts <200ms
- [ ] Battery: Native workers minimal impact
- [ ] Constraints: Respected (network, charging, etc.)

---

## 🐛 Troubleshooting

### Tasks Not Executing

**iOS:**
```
1. Check Info.plist has BGTaskSchedulerPermittedIdentifiers
2. Enable Background Modes in Xcode
3. Test on real device (simulator has limitations)
4. Check Console.app for BGTaskScheduler logs
```

**Android:**
```bash
# Check WorkManager status
adb logcat | grep WorkManager

# Check battery optimization
adb shell dumpsys battery

# Check task status
adb shell dumpsys jobscheduler
```

### Event Log Not Updating

1. Restart app
2. Check `NativeWorkManager.initialize()` was called
3. Verify event stream subscription
4. Check device logs (Logcat/Console)

### ContentUri Not Triggering (Android)

1. Grant storage permissions
2. Use correct URI format: `content://media/external/images/media`
3. Set `triggerForDescendants: true`
4. Take photo or download image (don't just view)

---

## 📱 Platform Differences

### iOS vs Android

| Feature | iOS | Android | Notes |
|---------|-----|---------|-------|
| **ContentUri** | ❌ | ✅ | Android-only |
| **Exact Alarms** | ~±1min | ±1sec | iOS less precise |
| **Periodic Tasks** | ~15min min | 15min min | iOS may defer |
| **Heavy Tasks** | ✅ | ✅ | Both defer to charging+idle |
| **Background Execution** | Limited | More flexible | iOS stricter |
| **QoS Levels** | ✅ | ✅ | Both support |

---

## 🎯 Quick Test (5 minutes)

**Fastest way to verify everything works:**

1. **Tab 1** → Click "HTTP GET" → See ✅ in log
2. **Tab 2** → Click "Exponential Backoff" → See retry schedule
3. **Tab 3** → Skip iOS, test Android (take photo)
4. **Tab 4** → Click "QoS: User Initiated" → Immediate execution
5. **Tab 5** → Click "Sequential Chain" → See 3 tasks in order
6. **Tab 6** → Click "Periodic (15 min)" → See first execution

**Expected time:** 2-3 minutes (excluding periodic task wait)

---

## 📚 Resources

- **Main README:** `/README.md`
- **API Reference:** `/QUICK_REFERENCE.md`
- **Comparison:** `/COMPREHENSIVE_COMPARISON.md`
- **Source Audit:** `/SOURCE_CODE_AUDIT_REPORT.md`

---

**Happy Testing! 🚀**
