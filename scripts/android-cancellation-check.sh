#!/usr/bin/env bash
# Android device check: cancelling WebSocketWorker / ParallelHttpUploadWorker really
# stops (WebSocket: server-side close frame; upload: progress stops, asserted in the test). Usage: scripts/android-cancellation-check.sh <adb-serial>
set -euo pipefail
SERIAL="${1:?adb serial required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp -t nwm_cancel_log.XXXXXX)"
python3 -I "$ROOT/scripts/cancellation_probe_server.py" "$LOG" & SRV=$!
trap 'kill $SRV 2>/dev/null || true; adb -s "$SERIAL" reverse --remove-all >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 20); do grep -q ready "$LOG" 2>/dev/null && break; sleep 0.25; done
adb -s "$SERIAL" reverse tcp:8765 tcp:8765 >/dev/null
adb -s "$SERIAL" reverse tcp:8766 tcp:8766 >/dev/null

cd "$ROOT/example"
env 'ORG_GRADLE_PROJECT_android.builtInKotlin=false' flutter test \
  integration_test/android_cancellation_test.dart -d "$SERIAL"

python3 -I - "$LOG" <<'PY'
import json, sys
ev = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
def first(name): return next((e for e in ev if e["ev"] == name), None)
ok = True
wo, wc = first("ws_open"), first("ws_close_frame")
if not wo: print("FAIL websocket: worker never connected"); ok = False
elif not wc: print("FAIL websocket: connection still open after cancel"); ok = False
else:
    d = wc["t"] - wo["t"]; good = d < 15   # worker timeout is 120 s
    print(f"websocket: closed {d:.1f}s after open (timeout 120s) -> {'ok' if good else 'FAIL'}"); ok &= good
# upload: asserted inside the Dart test (progress stops after cancel) - see the test comment.
sys.exit(0 if ok else 1)
PY
