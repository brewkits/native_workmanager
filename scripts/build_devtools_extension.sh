#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building DevTools Extension for native_workmanager ===${NC}"

# 1. Navigate to extension/devtools and build Flutter Web
cd extension/devtools
flutter build web --release

# 2. Copy web build output to extension/devtools/build root (where devtools_shared expects index.html)
echo -e "${BLUE}Copying web build assets to extension/devtools/build/...${NC}"
cp -R build/web/* build/

# 3. Clean up stale/redundant directories if any exist
rm -rf extension/

# 4. Validate extension structure
echo -e "${BLUE}Validating DevTools Extension...${NC}"
dart run devtools_extensions validate --package=../..

cd ../..
echo -e "${GREEN}🎉 DevTools Extension built and validated successfully!${NC}"
