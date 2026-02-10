#!/bin/bash

# Benchmark Runner for native_workmanager
# Runs all benchmarks and generates report

set -e

echo "======================================"
echo "native_workmanager Benchmark Tool"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found. Please install Flutter SDK.${NC}"
    exit 1
fi

if ! command -v adb &> /dev/null; then
    echo -e "${YELLOW}⚠️  ADB not found. Android benchmarks will be skipped.${NC}"
    HAS_ADB=false
else
    HAS_ADB=true
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

# Detect device
echo "Detecting device..."

DEVICE=""
if [ "$HAS_ADB" = true ]; then
    DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device$" | wc -l | tr -d ' ')
    if [ "$DEVICE_COUNT" -gt 0 ]; then
        DEVICE="android"
        DEVICE_INFO=$(adb shell getprop ro.product.model)
        echo -e "${GREEN}✅ Android device detected: $DEVICE_INFO${NC}"
    fi
fi

if [ -z "$DEVICE" ]; then
    # Check for iOS simulator
    if xcrun simctl list devices | grep -q "Booted"; then
        DEVICE="ios"
        DEVICE_INFO=$(xcrun simctl list devices | grep "Booted" | head -1 | awk -F'[()]' '{print $2}')
        echo -e "${GREEN}✅ iOS simulator detected: $DEVICE_INFO${NC}"
    fi
fi

if [ -z "$DEVICE" ]; then
    echo -e "${RED}❌ No device found. Please connect a device or start simulator.${NC}"
    exit 1
fi

echo ""

# Create results directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULT_FILE="results/${DEVICE_INFO// /_}_${TIMESTAMP}.json"
mkdir -p results

echo "Results will be saved to: $RESULT_FILE"
echo ""

# Initialize result JSON
cat > "$RESULT_FILE" <<EOF
{
  "device": {
    "model": "$DEVICE_INFO",
    "platform": "$DEVICE"
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "benchmarks": {}
}
EOF

echo "======================================"
echo "Running Benchmarks..."
echo "======================================"
echo ""

# Benchmark 1: Memory
echo "📊 Benchmark 1/3: Memory Footprint"
echo "-----------------------------------"
echo "This test compares memory usage of background workers."
echo ""

if [ -f "scripts/benchmark_memory.sh" ]; then
    echo "⚠️  Note: Memory benchmark requires separate test apps."
    echo "Skipping for now. See scripts/benchmark_memory.sh for manual instructions."
    echo ""
else
    echo "⚠️  Memory benchmark script not yet implemented."
    echo ""
fi

# Benchmark 2: I/O Performance
echo "⚡ Benchmark 2/3: Heavy I/O Performance"
echo "---------------------------------------"
echo "Downloading 100KB file to measure I/O performance..."
echo ""

if [ -f "scripts/benchmark_io.sh" ]; then
    bash scripts/benchmark_io.sh
    # TODO: Parse results and add to JSON
else
    echo "⚠️  I/O benchmark script not yet implemented."
    echo ""
fi

# Benchmark 3: Battery Impact
echo "🔋 Benchmark 3/3: Battery Impact"
echo "--------------------------------"
echo "Counting engine spawns..."
echo ""

if [ -f "scripts/benchmark_battery.sh" ]; then
    bash scripts/benchmark_battery.sh
    # TODO: Parse results and add to JSON
else
    echo "⚠️  Battery benchmark script not yet implemented."
    echo ""
fi

# Summary
echo ""
echo "======================================"
echo "Benchmark Complete!"
echo "======================================"
echo ""
echo "Results saved to: $RESULT_FILE"
echo ""
echo "Next steps:"
echo "1. Review results in $RESULT_FILE"
echo "2. If satisfied, copy to results/community/"
echo "3. Create PR to share with community"
echo ""
echo "Example PR command:"
echo "  cp $RESULT_FILE results/community/"
echo "  git add results/community/"
echo "  git commit -m 'Add benchmark results: $DEVICE_INFO'"
echo "  git push"
echo ""
echo "Thank you for contributing! 🙏"
echo ""
