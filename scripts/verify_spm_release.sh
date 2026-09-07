#!/usr/bin/env bash
# ============================================================================
# SwiftPM release verification
# ============================================================================
#
# Everything about the SwiftPM consumer path that can be checked from a clean
# checkout. Run it locally before tagging, and in CI on every PR.
#
#   ./scripts/verify_spm_release.sh
#
# Checks, in order:
#   1. Package.swift parses.
#   2. The library product is the HYPHENATED name. Flutter references plugins as
#      plugin.name.replaceAll('_','-'), and SPM uses the product name as
#      CFBundleIdentifier, which cannot contain underscores.        (issue #52)
#   3. KMPWorkManager is a REMOTE binaryTarget with a checksum. A local `path:`
#      target resolves to nothing on a pub.dev install, because .pubignore
#      strips ios/Frameworks/ and SPM has no installation hook.     (issue #49)
#   4. No testTarget is declared — a path-escaping one makes strict SwiftPM
#      toolchains reject the whole manifest for every consumer.     (v1.4.3)
#   5. The xcframework that will be published has both slices.
#   6. If the release asset is already live, its sha256 matches the checksum in
#      Package.swift. A mismatch breaks every SwiftPM consumer — that is exactly
#      what shipped in v1.4.5 and needed an immediate follow-up.
#
# Check 6 is a no-op before the release exists, which is the normal state on a
# release PR: the asset is attached when the release is cut. Set
# REQUIRE_PUBLISHED_ASSET=1 (CI does this on main and on tags) to turn a missing
# asset into a hard failure.
# ============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/ios/native_workmanager/Package.swift"
XCF="$REPO_ROOT/ios/Frameworks/KMPWorkManager.xcframework"

ok()   { printf '  \033[0;32mOK\033[0m    %s\n' "$1"; }
fail() { printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; exit 1; }
skip() { printf '  \033[1;33mSKIP\033[0m  %s\n' "$1"; }

echo "== SwiftPM release verification =="

# ── 1-4: manifest shape ────────────────────────────────────────────────────
DUMP="$(cd "$REPO_ROOT/ios/native_workmanager" && swift package dump-package)"
ok "Package.swift parses"

PYCHECK="$(mktemp -t spmcheck)"
trap 'rm -f "$PYCHECK"' EXIT
cat > "$PYCHECK" <<'PYEOF'
import json, sys
pkg = json.load(sys.stdin)

products = [p["name"] for p in pkg.get("products", [])]
if "native-workmanager" not in products:
    sys.exit(f"  FAIL  issue #52: product must be 'native-workmanager', got {products}")
print(f"  OK    product is hyphenated: {products}")

binaries = [t for t in pkg.get("targets", []) if t.get("type") == "binary"]
if not binaries:
    sys.exit("  FAIL  issue #49: KMPWorkManager must be declared as a binaryTarget")
b = binaries[0]
if not b.get("url"):
    sys.exit("  FAIL  issue #49: binaryTarget must be REMOTE (url:), not a local path:")
if not b.get("checksum"):
    sys.exit("  FAIL  binaryTarget must carry a checksum")
print(f"  OK    remote binaryTarget: {b['url']}")

tests = [t for t in pkg.get("targets", []) if t.get("type") == "test"]
if tests:
    sys.exit(f"  FAIL  v1.4.3: consumer manifests must declare no testTarget, got {[t['name'] for t in tests]}")
print("  OK    no testTarget declared")
PYEOF
printf '%s' "$DUMP" | python3 "$PYCHECK"

# ── 5: the framework that will ship ────────────────────────────────────────
[ -d "$XCF/ios-arm64" ] || fail "xcframework is missing the ios-arm64 device slice"
[ -d "$XCF/ios-arm64_x86_64-simulator" ] || fail "xcframework is missing the simulator slice"
ok "xcframework has both slices"

# ── 6: published asset ─────────────────────────────────────────────────────
URL="$(grep -o 'https://[^"]*KMPWorkManager.xcframework.zip' "$MANIFEST" | head -1)"
EXPECTED="$(grep -o 'checksum: "[a-f0-9]*"' "$MANIFEST" | grep -o '[a-f0-9]\{64\}' | head -1)"
[ -n "$URL" ] || fail "could not read the binaryTarget URL out of Package.swift"
[ -n "$EXPECTED" ] || fail "could not read the checksum out of Package.swift"

CODE="$(curl -sIL -o /dev/null -w '%{http_code}' "$URL" || echo 000)"
if [ "$CODE" != "200" ]; then
  if [ "${REQUIRE_PUBLISHED_ASSET:-0}" = "1" ]; then
    fail "asset is not downloadable (HTTP $CODE) at $URL — SwiftPM consumers cannot resolve this release"
  fi
  skip "asset not published yet (HTTP $CODE). Normal on a release PR."
  echo "        When cutting the release, attach a zip with sha256:"
  echo "        $EXPECTED"
  echo ""
  echo "All checks that can run before publication passed."
  exit 0
fi

TMP="$(mktemp -t kmpwm)"
trap 'rm -f "$TMP" "$PYCHECK"' EXIT
curl -sL -o "$TMP" "$URL"
ACTUAL="$(shasum -a 256 "$TMP" | cut -d' ' -f1)"
[ "$EXPECTED" = "$ACTUAL" ] || fail "checksum mismatch
        Package.swift: $EXPECTED
        published:     $ACTUAL"
ok "published asset matches the declared checksum"

echo ""
echo "All checks passed."
