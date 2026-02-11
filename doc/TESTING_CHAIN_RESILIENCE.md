# Testing iOS Chain Resilience

This guide explains how to test the iOS chain state persistence feature that allows chains to resume after app kill.

## Overview

On iOS, chains now persist their state after each step completion. If the app is force-killed mid-chain, the chain will automatically resume from the last completed step when the app restarts.

**Key Components:**
- `ChainStateManager.swift` - Manages chain state persistence in UserDefaults
- `NativeWorkmanagerPlugin.swift` - Saves state after each step, resumes pending chains on initialize
- `chain_resilience_test.dart` - Interactive test UI

## Test Procedure

### 1. Launch Demo App

```bash
cd example
flutter run -d "iPhone 15 Simulator"  # or any iOS device
```

### 2. Navigate to Chain Test Tab

- Open the demo app
- Scroll tabs to find "🔄 Chain Test"
- Read the on-screen instructions

### 3. Execute Test

**Step-by-step:**

1. **Tap "Start Chain"**
   - Creates 3-step file copy chain
   - Each step takes ~5 seconds
   - Monitor logs at bottom of screen

2. **Wait for Step 1 completion**
   - Log should show: "✅ Step 1 complete"
   - This is critical - Step 1 must complete!

3. **Force quit the app**
   - On iOS simulator: Cmd+Shift+H twice, swipe up on app
   - On device: Double-tap home button, swipe up on app
   - **Timing:** Kill app AFTER Step 1 but BEFORE Step 2 completes

4. **Reopen the app**
   - Tap the app icon to launch
   - Navigate back to "🔄 Chain Test" tab

5. **Verify resume**
   - Log should show: "⚠️ Chain was interrupted! Last: Step 1 done"
   - Log should show: "📱 iOS should auto-resume chain..."
   - **Expected:** Step 2 and Step 3 execute automatically

### 4. Expected Results

**✅ Success Indicators:**
- Chain resumes from Step 2 (skips Step 1)
- Step 2 and Step 3 complete automatically
- All 3 output files created: `chain_step1_done.txt`, `chain_step2_done.txt`, `chain_step3_done.txt`
- Marker file deleted after completion

**❌ Failure Indicators:**
- Chain restarts from Step 1 (re-executes completed work)
- No auto-resume message in logs
- Chain doesn't execute after reopening app

## Technical Details

### State Persistence

```swift
// ChainStateManager saves state to UserDefaults after each step
struct ChainState: Codable {
    let chainId: String
    let chainName: String?
    let totalSteps: Int
    var currentStep: Int  // 0-indexed
    var completed: Bool
    let createdAt: Date
    var lastUpdatedAt: Date
    let steps: [[TaskData]]
}
```

### Resume Logic

```swift
// NativeWorkmanagerPlugin.swift - handleInitialize()
Task {
    await resumePendingChains()  // Auto-resumes interrupted chains
}
```

### Cleanup Policy

- Completed chains: Removed immediately
- Failed chains: Removed immediately
- Abandoned chains: Auto-deleted after 7 days

## Android Comparison

**iOS:** Manual state management with ChainStateManager
- Chains execute directly in app process
- State saved to UserDefaults after each step
- Chains resume on app restart

**Android:** Built-in WorkManager persistence
- Chains managed by WorkManager DB
- Automatic state persistence
- Chains survive app kill by design

## Debugging Tips

### Enable Verbose Logging

Check Xcode console for detailed logs:

```
ChainStateManager: Saving state for chain 'resilience_test_...'
  Progress: 1/3 steps
ChainStateManager: Saved successfully
```

After app restart:

```
ChainStateManager: Loading resumable chains...
NativeWorkmanagerPlugin: Resuming chain 'resilience_test_...'
  Starting from step 2 (1-indexed)
```

### Check Marker Files

On test completion, verify files exist:

```bash
# On simulator
cd ~/Library/Developer/CoreSimulator/Devices/<device-id>/data/Containers/Data/Application/<app-id>/Documents

# Should see:
# - chain_step1_done.txt
# - chain_step2_done.txt
# - chain_step3_done.txt
# - chain_test_marker.txt (only if chain interrupted)
```

### Reset Test State

Tap "Clear Data" button to delete all test files and start fresh.

## Known Limitations

1. **iOS only** - Chain state persistence is iOS-specific implementation
2. **Not BGTask** - Current implementation executes chains in-process (not using BGTaskScheduler)
3. **Manual intervention** - Requires app restart to resume (not automatic background resume)
4. **7-day cleanup** - Old chains auto-deleted after 7 days

## Future Enhancements (v1.1+)

- [ ] BGTask integration for true background chain execution
- [ ] Automatic resume without app restart
- [ ] Chain progress notifications
- [ ] Chain state UI viewer/debugger

## Troubleshooting

### Chain doesn't resume

**Possible causes:**
1. Step 1 didn't complete before force quit
2. App killed before state saved to UserDefaults
3. UserDefaults not persisting (rare)

**Solution:** Ensure Step 1 fully completes (see "✅ Step 1 complete" log) before force quit

### Chain restarts from beginning

**Possible cause:** ChainStateManager not integrated or not saving state

**Solution:** Verify ChainStateManager is initialized and saveChainState() is called after each step

### Files not created

**Possible cause:** File paths incorrect or permissions issue

**Solution:** Check app has write access to Documents directory

## Success Criteria

Chain resilience is working correctly when:

✅ Step 1 completes and saves state
✅ App force quit doesn't lose progress
✅ App relaunch detects interrupted chain
✅ Chain resumes from Step 2 (not Step 1)
✅ Steps 2 and 3 complete successfully
✅ All output files created
✅ Marker file cleaned up on completion

---

**Version:** v1.0.0
**Last Updated:** 2026-02-11
**Contact:** datacenter111@gmail.com
