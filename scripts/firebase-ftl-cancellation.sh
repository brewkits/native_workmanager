#!/usr/bin/env bash
# ============================================================
# Firebase Test Lab — issue #66 / #69 cancellation regression check
# ============================================================
#
# Builds the example app with integration_test/issue_66_69_ftl_test.dart as
# its entrypoint and runs it as an Android instrumentation test on a real
# device matrix via Firebase Test Lab. Deliberately separate from
# firebase-benchmark.sh: that script drives firebase_benchmark_test.dart
# (perf numbers, long-running); this one drives a short, cheap correctness
# check (~10s per device) so it's realistic to run ad hoc, not just weekly.
#
# Prerequisites:
#   - gcloud CLI authenticated to a project with the Cloud Testing API
#     (testing.googleapis.com) and billing enabled
#   - flutter in PATH
#   - example/android/app/build.gradle.kts has testInstrumentationRunner +
#     androidx.test:runner/rules configured, and
#     example/android/app/src/androidTest/.../MainActivityTest.kt exists
#     (both already committed — this script does not set them up)
#
# Usage:
#   FIREBASE_PROJECT_ID=<your-project> ./scripts/firebase-ftl-cancellation.sh
#
# Environment variables:
#   FIREBASE_PROJECT_ID   — required: your Firebase/GCP project ID
#   DEVICES               — optional: space-separated "model=X,version=Y"
#                            pairs. Default: a small 3-device spot check
#                            (one stock virtual baseline + two OEM
#                            battery-layer physical devices, matching the
#                            reasoning in benchmark/firebase-device-matrix.json)
#   TIMEOUT               — optional: per-device instrumentation timeout
#                            (default: 300s — generous for a ~10s test; the
#                            slack covers device allocation/boot overhead)
#
# Output: prints the Firebase Test Lab console URL and polls until the
# matrix finishes, then prints a pass/fail summary per device.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$REPO_ROOT/example"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; exit 1; }

command -v gcloud >/dev/null 2>&1 || error "gcloud CLI not found. Install from https://cloud.google.com/sdk"
command -v flutter >/dev/null 2>&1 || error "Flutter not found"
[[ -z "${FIREBASE_PROJECT_ID:-}" ]] && error "FIREBASE_PROJECT_ID is not set"

TIMEOUT="${TIMEOUT:-300s}"
DEVICES="${DEVICES:-model=MediumPhone.arm,version=34,locale=en,orientation=portrait model=SC-51E,version=36,locale=en,orientation=portrait model=OP573DL1,version=34,locale=en,orientation=portrait}"

ok "Prerequisites OK — project: $FIREBASE_PROJECT_ID"

info "Building app APK (integration_test/issue_66_69_ftl_test.dart as entrypoint)..."
pushd "$EXAMPLE_DIR" > /dev/null
flutter pub get
flutter build apk --debug --target=integration_test/issue_66_69_ftl_test.dart 2>&1 | tail -5

info "Building androidTest instrumentation APK..."
pushd android > /dev/null
./gradlew app:assembleAndroidTest --stacktrace 2>&1 | tail -10
popd > /dev/null

APP_APK="build/app/outputs/flutter-apk/app-debug.apk"
TEST_APK="build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
[[ -f "$APP_APK" ]] || error "App APK not found at $APP_APK"
[[ -f "$TEST_APK" ]] || error "Test APK not found at $TEST_APK"
ok "Both APKs built"

# Turn "$DEVICES" into repeated --device flags.
device_args=()
for d in $DEVICES; do
  device_args+=(--device "$d")
done

info "Submitting to Firebase Test Lab (project: $FIREBASE_PROJECT_ID)..."
run_output=$(gcloud firebase test android run \
    --type instrumentation \
    --app "$APP_APK" \
    --test "$TEST_APK" \
    --timeout "$TIMEOUT" \
    --project "$FIREBASE_PROJECT_ID" \
    --async \
    "${device_args[@]}" 2>&1)
echo "$run_output"

matrix_id=$(echo "$run_output" | grep -oE 'matrix-[a-z0-9]+' | head -1)
[[ -z "$matrix_id" ]] && error "Could not parse matrix ID from gcloud output"
ok "Submitted: $matrix_id"

popd > /dev/null

# The gcloud CLI version this was written against has no `matrices describe`
# subcommand under `firebase test android` (only locales/models/versions/run)
# — polling goes straight to the Testing API's REST endpoint instead.
info "Polling for completion via the Testing API (this can take a few minutes for device allocation)..."
while true; do
    token=$(gcloud auth print-access-token)
    resp=$(curl -s -H "Authorization: Bearer $token" \
        "https://testing.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/testMatrices/${matrix_id}")
    state=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('state','UNKNOWN'))" <<< "$resp")
    case "$state" in
        FINISHED|ERROR|INVALID|UNSUPPORTED_ENVIRONMENT|INCOMPATIBLE_ENVIRONMENT)
            break
            ;;
    esac
    sleep 20
done

echo ""
python3 -c "
import sys, json
d = json.load(sys.stdin)
for e in d.get('testExecutions', []):
    dev = e.get('environment', {}).get('androidDevice', {})
    print(f\"{dev.get('androidModelId')} / API{dev.get('androidVersionId')}: \"
          f\"state={e.get('state')} result={e.get('testResult', 'N/A')}\")
" <<< "$resp"

if [[ "$state" == "FINISHED" ]]; then
    ok "Matrix finished — check outcomes above (a device row can still be FAILED even when the matrix itself FINISHED)"
else
    warn "Matrix ended in state: $state — see console for details"
fi
