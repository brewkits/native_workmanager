#!/bin/bash
set -e

echo "=== Verifying Podspec Extraction Logic ==="

# 1. Create mock framework environment
rm -rf /tmp/mock_fw /tmp/mock_fw_nested
mkdir -p /tmp/mock_fw/KMPWorkManager.xcframework/Headers
touch /tmp/mock_fw/KMPWorkManager.xcframework/Headers/Mock.h

# 2. Simulate flat zip creation
cd /tmp/mock_fw
zip -rq /tmp/flat_release.zip KMPWorkManager.xcframework

# 3. Simulate nested zip creation (wrapped in Frameworks/)
mkdir -p /tmp/mock_fw_nested/Frameworks
cp -r /tmp/mock_fw/KMPWorkManager.xcframework /tmp/mock_fw_nested/Frameworks/
cd /tmp/mock_fw_nested
zip -rq /tmp/nested_release.zip Frameworks/

echo "[✓] Successfully created 2 mock release zips (Flat and Nested)."
echo ""

# 4. Extraction test function matching podspec prepare_command
test_extraction() {
  local zip_path=$1
  local test_name=$2
  
  echo "--- Running test: $test_name ---"
  
  # Clean up test workspace
  rm -rf /tmp/test_workspace
  mkdir -p /tmp/test_workspace/Frameworks
  cd /tmp/test_workspace
  
  # ---- LOGIC COPIED FROM PODSPEC PREPARE_COMMAND ----
  rm -rf /tmp/kmpwm_extract
  unzip -oq "$zip_path" -d /tmp/kmpwm_extract
  # Release zip may be flat or wrapped in a Frameworks/ dir - handle both.
  SRC=$(find /tmp/kmpwm_extract -maxdepth 2 -type d -name 'KMPWorkManager.xcframework' | head -1)
  rm -rf Frameworks/KMPWorkManager.xcframework
  mv "$SRC" Frameworks/KMPWorkManager.xcframework
  rm -rf /tmp/kmpwm_extract
  # ---- END LOGIC FROM PODSPEC ----
  
  # Verify extraction structure
  if [ -d "Frameworks/KMPWorkManager.xcframework" ] && [ ! -d "Frameworks/Frameworks" ]; then
    echo "[✓] SUCCESS: Correct single-layer extraction at Frameworks/KMPWorkManager.xcframework"
  else
    echo "[x] FAILURE: Incorrect directory structure."
    ls -R Frameworks
    exit 1
  fi
  echo ""
}

# 5. Run test for both cases
test_extraction "/tmp/flat_release.zip" "FLAT ZIP FILE (Root-level XCFramework)"
test_extraction "/tmp/nested_release.zip" "NESTED ZIP FILE (Wrapped inside Frameworks/)"

echo "=== ALL PODSPEC EXTRACTION TESTS PASSED! ==="
