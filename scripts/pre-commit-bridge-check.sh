#!/bin/bash
# Pre-commit check for KMP bridge files.
# Install: cp scripts/pre-commit-bridge-check.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

BRIDGE_FILES=(
  "ios/native_workmanager/Sources/native_workmanager/KMPSchedulerBridge.swift"
  "android/src/main/kotlin/dev/brewkits/native_workmanager/NativeWorkmanagerPlugin+Enqueue.kt"
)

changed_bridges=()
for file in "${BRIDGE_FILES[@]}"; do
  if git diff --cached --name-only | grep -qF "$file"; then
    changed_bridges+=("$file")
  fi
done

if [ ${#changed_bridges[@]} -eq 0 ]; then
  exit 0
fi

echo -e "${RED}⚠️  KMP BRIDGE FILE(S) CHANGED:${NC}"
for f in "${changed_bridges[@]}"; do
  echo "   • $f"
done
echo ""
echo -e "${YELLOW}Mandatory checklist before committing:${NC}"
echo "  1. KotlinLong/KotlinInt: still using explicit KotlinLong(value:) constructor?"
echo "     (NOT 'as? KotlinLong' — that always returns nil silently)"
echo "  2. Every Dart map key parsed by the bridge is still named correctly?"
echo "  3. New/changed parameter has a test in test/unit/bridge_parameter_passthrough_test.dart?"
echo "  4. If this is a second 'cleanup' commit, treated with same scrutiny as the fix commit?"
echo ""
# Skip interactive prompt in CI or non-interactive shells
if [ ! -t 1 ] || [ "${CI:-}" = "true" ] || [ "${SKIP_BRIDGE_CHECK:-}" = "1" ]; then
  echo "(non-interactive — skipping prompt, proceeding)"
  exit 0
fi

echo -n "Type 'yes' to confirm checklist complete: "
read -r answer </dev/tty
if [ "$answer" != "yes" ]; then
  echo -e "${RED}Commit aborted.${NC}"
  exit 1
fi
