#!/usr/bin/env bash
# ============================================================
# Firebase Test Lab Benchmark Runner
# ============================================================
#
# Builds the example app and runs firebase_benchmark_test.dart
# on Firebase Test Lab devices defined in benchmark/firebase-device-matrix.json.
#
# Prerequisites:
#   - gcloud CLI authenticated (or GOOGLE_APPLICATION_CREDENTIALS set)
#   - Firebase project configured (FIREBASE_PROJECT_ID env var)
#   - flutter, dart, jq in PATH
#
# Usage:
#   ./scripts/firebase-benchmark.sh [android|ios|all]
#
# Environment variables:
#   FIREBASE_PROJECT_ID   — required: your Firebase project ID
#   GCS_RESULTS_BUCKET    — optional: GCS bucket for results (default: gs://<project>-test-results)
#   PLATFORM              — optional: android|ios|all (default: android)
#   SKIP_BUILD            — optional: true to skip app build (use existing artifacts)
#
# Output:
#   benchmark/results/firebase-<timestamp>/  — downloaded result files
#   benchmark/results/firebase-<timestamp>/summary.md — parsed summary
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$REPO_ROOT/example"
RESULTS_DIR="$REPO_ROOT/benchmark/results/firebase-$(date +%Y%m%d-%H%M%S)"
DEVICE_MATRIX="$REPO_ROOT/benchmark/firebase-device-matrix.json"

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; exit 1; }

# ── Validate prerequisites ───────────────────────────────────────────────────
info "Checking prerequisites..."
command -v gcloud >/dev/null 2>&1 || error "gcloud CLI not found. Install from https://cloud.google.com/sdk"
command -v flutter >/dev/null 2>&1 || error "Flutter not found"
command -v jq     >/dev/null 2>&1 || error "jq not found (brew install jq)"

[[ -z "${FIREBASE_PROJECT_ID:-}" ]] && error "FIREBASE_PROJECT_ID is not set"

PLATFORM="${PLATFORM:-android}"
GCS_BUCKET="${GCS_RESULTS_BUCKET:-gs://${FIREBASE_PROJECT_ID}-test-results}"
SKIP_BUILD="${SKIP_BUILD:-false}"

ok "Prerequisites OK — project: $FIREBASE_PROJECT_ID, platform: $PLATFORM"

mkdir -p "$RESULTS_DIR"

# ── Build ────────────────────────────────────────────────────────────────────
build_android() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        warn "Skipping Android build (SKIP_BUILD=true)"
        return
    fi
    info "Building Android debug APK + test APK..."
    pushd "$EXAMPLE_DIR" > /dev/null
    flutter pub get
    flutter build apk --debug --target-platform android-arm64 \
        --dart-define=BENCHMARK_MODE=true 2>&1 | tail -5
    pushd android > /dev/null
    ./gradlew assembleAndroidTest --stacktrace 2>&1 | tail -10
    popd > /dev/null
    popd > /dev/null
    ok "Android build complete"
}

build_ios() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        warn "Skipping iOS build (SKIP_BUILD=true)"
        return
    fi
    info "Building iOS for Firebase Test Lab..."
    pushd "$EXAMPLE_DIR" > /dev/null
    flutter pub get
    pushd ios > /dev/null
    pod install --repo-update
    popd > /dev/null
    xcodebuild build-for-testing \
        -workspace ios/Runner.xcworkspace \
        -scheme Runner \
        -sdk iphoneos \
        -derivedDataPath build/ios_ftl \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tail -10
    pushd build/ios_ftl/Build/Products > /dev/null
    zip -r "$RESULTS_DIR/ios_test.zip" ./*.xctestrun Debug-iphoneos 2>&1 | tail -3
    popd > /dev/null
    popd > /dev/null
    ok "iOS build complete"
}

# ── Firebase Test Lab run ────────────────────────────────────────────────────
run_android_ftl() {
    info "Running Android benchmarks on Firebase Test Lab..."

    local devices_args=()
    while IFS= read -r device; do
        local model version
        model=$(echo "$device" | jq -r '.model')
        version=$(echo "$device" | jq -r '.version')
        devices_args+=(--device "model=$model,version=$version,locale=en,orientation=portrait")
    done < <(jq -c '.android[]' "$DEVICE_MATRIX")

    local result_path="$GCS_BUCKET/benchmark-android-$(date +%s)"

    gcloud firebase test android run \
        --type instrumentation \
        --app "$EXAMPLE_DIR/build/app/outputs/apk/debug/app-debug.apk" \
        --test "$EXAMPLE_DIR/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk" \
        --results-bucket "${GCS_BUCKET#gs://}" \
        --results-dir "benchmark-android-$(date +%s)" \
        --timeout 300s \
        --project "$FIREBASE_PROJECT_ID" \
        "${devices_args[@]}" \
        2>&1 | tee "$RESULTS_DIR/android-ftl-run.log"

    ok "Android FTL run complete — logs saved"
}

run_ios_ftl() {
    info "Running iOS benchmarks on Firebase Test Lab..."

    local devices_args=()
    while IFS= read -r device; do
        local model version
        model=$(echo "$device" | jq -r '.model')
        version=$(echo "$device" | jq -r '.version')
        devices_args+=(--device "model=$model,version=$version,locale=en,orientation=portrait")
    done < <(jq -c '.ios[]' "$DEVICE_MATRIX")

    gcloud firebase test ios run \
        --test "$RESULTS_DIR/ios_test.zip" \
        --results-bucket "${GCS_BUCKET#gs://}" \
        --results-dir "benchmark-ios-$(date +%s)" \
        --timeout 300s \
        --project "$FIREBASE_PROJECT_ID" \
        "${devices_args[@]}" \
        2>&1 | tee "$RESULTS_DIR/ios-ftl-run.log"

    ok "iOS FTL run complete — logs saved"
}

# ── Download results ─────────────────────────────────────────────────────────
download_results() {
    info "Downloading results from GCS..."
    # Extract result paths from run logs
    grep -oE 'gs://[^ ]+' "$RESULTS_DIR"/*.log 2>/dev/null | sort -u | while read -r gcs_path; do
        gsutil -m cp -r "$gcs_path" "$RESULTS_DIR/" 2>/dev/null || true
    done
    ok "Results downloaded to $RESULTS_DIR"
}

# ── Parse ────────────────────────────────────────────────────────────────────
parse_results() {
    info "Parsing benchmark results..."
    python3 "$SCRIPT_DIR/parse-firebase-results.py" \
        --results-dir "$RESULTS_DIR" \
        --output "$RESULTS_DIR/summary.md" 2>&1
    ok "Summary written to $RESULTS_DIR/summary.md"
    echo ""
    cat "$RESULTS_DIR/summary.md"
}

# ── Main ─────────────────────────────────────────────────────────────────────
case "$PLATFORM" in
    android)
        build_android
        run_android_ftl
        ;;
    ios)
        build_ios
        run_ios_ftl
        ;;
    all)
        build_android
        build_ios
        run_android_ftl
        run_ios_ftl
        ;;
    *)
        error "Unknown platform: $PLATFORM. Use android|ios|all"
        ;;
esac

download_results
parse_results

ok "Benchmark complete — results in $RESULTS_DIR"
