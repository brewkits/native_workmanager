# Benchmark Tool

Independent benchmarking tool to verify native_workmanager performance claims.

## Purpose

This tool allows **anyone** to run benchmarks and verify the performance differences between `native_workmanager` and `flutter_workmanager` on their own devices.

## Why This Matters

Performance claims are only credible when:
1. ✅ Methodology is transparent
2. ✅ Anyone can reproduce results
3. ✅ Community verifies independently

**This tool provides all three.**

## Quick Start

### Prerequisites

- Flutter SDK installed
- Android device/emulator OR iOS device/simulator
- ADB installed (for Android)
- Xcode installed (for iOS)

### Run All Benchmarks

```bash
cd benchmark
./run_all.sh
```

This will:
1. Run memory benchmark
2. Run I/O performance benchmark
3. Run battery impact test
4. Generate report in `results/`

### Run Individual Benchmarks

```bash
# Memory only
./scripts/benchmark_memory.sh

# I/O only
./scripts/benchmark_io.sh

# Battery only
./scripts/benchmark_battery.sh
```

## What Gets Measured

### 1. Memory Footprint

**Test:** Compare memory usage of background workers in separate processes

**Method:**
1. Kill all apps
2. Start native_workmanager worker process
3. Wait 10 seconds for stabilization
4. Measure PSS (Proportional Set Size) via `dumpsys meminfo`
5. Kill process
6. Repeat with flutter_workmanager worker
7. Compare results

**Expected difference:** ~50MB (flutter_wm spawns Flutter Engine)

### 2. Heavy I/O Performance

**Test:** Download 100KB file from httpbin.org

**Method:**
1. Clear cache
2. Start native_workmanager download task
3. Measure time to completion
4. Repeat with flutter_workmanager
5. Average over 5 runs

**Expected difference:** ~25-35% faster (native OkHttp vs Dart http)

### 3. Battery Impact

**Test:** Count engine initializations

**Method:**
1. Clear logcat
2. Run 10 tasks with flutter_workmanager
3. Count "Beginning load of flutter" messages
4. Repeat with native_workmanager
5. Compare

**Expected:** native_wm: 0 spawns, flutter_wm: 10 spawns

## Results Format

Results are saved as JSON in `results/`:

```json
{
  "device": {
    "model": "Pixel 6",
    "os": "Android 13",
    "manufacturer": "Google"
  },
  "timestamp": "2026-02-04T10:30:00Z",
  "benchmarks": {
    "memory": {
      "native_workmanager_mb": 34.5,
      "flutter_workmanager_mb": 84.2,
      "difference_mb": 49.7,
      "difference_percent": 59.0
    },
    "io_performance": {
      "native_workmanager_ms": 8420,
      "flutter_workmanager_ms": 11350,
      "difference_ms": 2930,
      "difference_percent": 34.8
    },
    "battery": {
      "native_workmanager_spawns": 0,
      "flutter_workmanager_spawns": 10,
      "difference": 10
    }
  },
  "methodology_version": "1.0"
}
```

## Submit Your Results

Help build community trust by submitting your benchmark results!

### Steps:

1. Run benchmarks: `./run_all.sh`
2. Find your result file in `results/[device]-[timestamp].json`
3. Copy to `results/community/`
4. Create PR with:
   - Title: "Benchmark results: [Your Device]"
   - Description: Any notes about your setup

### Example PR:

```
Title: Benchmark results: Samsung Galaxy S21

Results from my Galaxy S21:
- Memory: 36.2 MB vs 86.1 MB
- I/O: 7.8s vs 10.2s
- Battery: 0 vs 10 spawns

Ran on WiFi, no other apps running.
```

## Current Community Results

| Contributor | Device | Memory Diff | I/O Diff | Date | PR |
|-------------|--------|-------------|----------|------|-----|
| @maintainer | Pixel 6 | 50 MB | +35% | 2026-02-04 | #1 |
| *Your name here* | *Your device* | *Your result* | *Your result* | | |

**Goal:** Get 10+ independent verifications to build credibility.

## Methodology Details

### Why PSS (Proportional Set Size)?

PSS is the most accurate metric for measuring app memory because:
- Includes private memory
- Includes proportional share of shared memory
- Accounts for memory shared across processes

Alternative metrics (USS, RSS) are less accurate.

### Why 10-second stabilization?

Memory usage fluctuates during app startup. We wait 10 seconds for:
- GC to run
- Caches to initialize
- Memory to stabilize

This gives consistent, reproducible results.

### Why httpbin.org?

- ✅ Public, free API
- ✅ Reliable uptime
- ✅ Returns exact bytes requested
- ✅ Anyone can reproduce tests

### Why 5 runs average?

Network conditions vary. Averaging 5 runs eliminates outliers and gives statistical significance.

## Troubleshooting

### "adb not found"

Install Android SDK Platform Tools:
```bash
brew install android-platform-tools  # macOS
```

### "Permission denied"

```bash
chmod +x run_all.sh
chmod +x scripts/*.sh
```

### "Device not found"

Make sure device is connected and USB debugging enabled:
```bash
adb devices  # Should list your device
```

### Results seem wrong

Common issues:
- Other apps running (close all apps first)
- Low battery (charge device)
- Poor network (use strong WiFi)
- Background processes (restart device)

## Advanced Usage

### Test on Multiple Devices

```bash
# Save device name for each result
./run_all.sh --device "Pixel 6"
./run_all.sh --device "Samsung S21"
```

### Custom test iterations

```bash
# Run I/O test 10 times instead of 5
./scripts/benchmark_io.sh --iterations 10
```

### Export to CSV

```bash
# Convert all JSON results to CSV
python3 scripts/export_csv.py results/*.json > all_results.csv
```

## Contributing

Found a bug in the benchmark tool? Have suggestions?

1. Open an issue: https://github.com/brewkits/native_workmanager/issues
2. Tag with `benchmark` label
3. Describe the problem

## Benchmark Tool Roadmap

- [ ] v1.0: Basic memory + I/O benchmarks
- [ ] v1.1: Add startup time benchmark
- [ ] v1.2: Add battery drain measurement (requires longer test)
- [ ] v1.3: Automated CI/CD benchmarks
- [ ] v2.0: Web dashboard to view all community results

## FAQ

### Q: How long does it take to run all benchmarks?

**A:** ~5-10 minutes depending on network speed.

### Q: Can I run on simulator/emulator?

**A:** Yes, but results may differ from physical devices. We recommend physical devices for accurate results.

### Q: Will this drain my battery?

**A:** Minimal. The benchmarks run for ~5 minutes total.

### Q: What if my results differ from the README?

**A:** That's expected! Different devices, Android versions, and network conditions will give different results. What matters is the **relative difference** between native_wm and flutter_wm.

## License

Same as main project (MIT).

## Credits

Methodology inspired by:
- Android Performance Patterns
- iOS Performance Best Practices
- Flutter Performance Profiling Guide
