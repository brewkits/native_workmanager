#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Native Workmanager Comprehensive Test Suite ===${NC}"

# 1. Unit Tests
echo -e "\n${BLUE}[1/6] Running Unit Tests...${NC}"
flutter test test/unit/
if [ $? -eq 0 ]; then echo -e "${GREEN}Unit Tests Passed${NC}"; else echo -e "${RED}Unit Tests Failed${NC}"; exit 1; fi

# 2. Integration Tests
echo -e "\n${BLUE}[2/6] Running Integration Tests...${NC}"
flutter test test/integration/
if [ $? -eq 0 ]; then echo -e "${GREEN}Integration Tests Passed${NC}"; else echo -e "${RED}Integration Tests Failed${NC}"; exit 1; fi

# 3. Security Tests
echo -e "\n${BLUE}[3/6] Running Security Tests...${NC}"
flutter test test/security/ --reporter expanded
if [ $? -eq 0 ]; then echo -e "${GREEN}Security Tests Passed${NC}"; else echo -e "${RED}Security Tests Failed${NC}"; exit 1; fi

# 4. Performance Tests
echo -e "\n${BLUE}[4/6] Running Performance Tests...${NC}"
flutter test test/performance/scheduling_performance_test.dart --reporter expanded
if [ $? -eq 0 ]; then echo -e "${GREEN}Performance Tests Passed${NC}"; else echo -e "${RED}Performance Tests Failed${NC}"; exit 1; fi

# 5. Device Integration Tests (Requires connected device/emulator)
echo -e "\n${BLUE}[5/6] Running Device Integration Tests...${NC}"
cd example
flutter test integration_test/initialization_test.dart
if [ $? -eq 0 ]; then echo -e "${GREEN}Device Integration Tests Passed${NC}"; else echo -e "${RED}Device Integration Tests Failed${NC}"; cd ..; exit 1; fi
cd ..

# 6. Stress Tests
echo -e "\n${BLUE}[6/6] Running Stress Tests...${NC}"
cd example
flutter test integration_test/stress_and_system_test.dart
if [ $? -eq 0 ]; then echo -e "${GREEN}Stress Tests Passed${NC}"; else echo -e "${RED}Stress Tests Failed${NC}"; cd ..; exit 1; fi
cd ..

echo -e "\n${GREEN}🎉 All test suites passed successfully!${NC}"
