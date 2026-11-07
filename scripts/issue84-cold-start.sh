#!/usr/bin/env bash
# Issue #84: verify the persisted maxConcurrentTasks survives process death (Android).
#
# Why not `am force-stop`: it puts the app in the "stopped" state, so JobScheduler will
# not start it, and relaunching the Activity would re-run Dart initialize() — hiding
# whether persistence worked. We SIGKILL the process instead (app stays "not stopped"),
# then let WorkManager start it headlessly when the delayed jobs come due.
#
# Usage: scripts/issue84-cold-start.sh <adb-serial> [limit=1]
set -euo pipefail
SERIAL="${1:?adb serial required}"; LIMIT="${2:-1}"
PKG=dev.brewkits.native_workmanager_example
ADB="adb -s $SERIAL"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/example"
env 'ORG_GRADLE_PROJECT_android.builtInKotlin=false' flutter test \
  integration_test/issue_84_cold_start_test.dart -d "$SERIAL" \
  --dart-define=ISSUE84_LIMIT="$LIMIT" --no-uninstall

# `flutter test` force-stops the app when it finishes (stopped state, jobs cancelled).
# Start a headless process WITHOUT an Activity / Dart initialize(): an explicit
# broadcast to WorkManager's DiagnosticsReceiver clears the stopped state and makes
# WorkManager re-register the persisted jobs. From here on no Dart code has run in this
# process, so the only possible source of the limit is the persisted one.
$ADB shell am broadcast -n "$PKG/androidx.work.impl.diagnostics.DiagnosticsReceiver" \
  -a androidx.work.diagnostics.REQUEST_DIAGNOSTICS >/dev/null
sleep 6
PID=$($ADB shell pidof "$PKG" | tr -d '\r' || true)
echo "headless pid=${PID:-none}"
[ -n "$PID" ] || { echo "FAIL: headless process did not start"; exit 2; }
# Kill it too, so the delayed jobs must cold-start a brand-new process via JobScheduler.
$ADB shell run-as "$PKG" kill -9 "$PID"
sleep 2

echo "waiting for delayed jobs to fire in a cold process..."
for i in $(seq 1 30); do
  N=$($ADB shell "run-as $PKG sh -c 'ls code_cache/issue84_cold/ 2>/dev/null | wc -l'" | tr -d '\r')
  [ "$N" -ge 8 ] && break
  sleep 5
done
echo "completed probe files: $N"
$ADB shell "run-as $PKG sh -c 'for f in code_cache/issue84_cold/*.json; do cat \$f; echo; done'" \
  | tr -d '\r' | python3 -I -c '
import sys, json
ev = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    d = json.loads(line); ev += [(d["start"], 1), (d["end"], -1)]
ev.sort(key=lambda e: (e[0], e[1]))
run = peak = 0
for _, k in ev:
    run += k; peak = max(peak, run)
print(f"files={len(ev)//2} peak={peak}")
sys.exit(0 if len(ev) // 2 >= 8 and peak <= int(sys.argv[1]) else 1)
' "$LIMIT"
echo "RESULT: cold-start limit=$LIMIT honoured"
