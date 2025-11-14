#!/bin/bash

# Script to run all Xcode tests for SmartContractApp
# Usage: ./scripts/run_xcode_tests.sh

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}Running Xcode tests for SmartContractApp...${NC}"
echo "Project root: $PROJECT_ROOT"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if the Xcode project exists
if [ ! -f "SmartContractApp.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}Error: SmartContractApp.xcodeproj not found${NC}"
    exit 1
fi

# Run tests
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Running SmartContractApp tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if xcodebuild test \
    -scheme SmartContractApp \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet; then
    echo ""
    echo -e "${GREEN}✓ All Xcode tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Xcode tests failed${NC}"
    exit 1
fi
