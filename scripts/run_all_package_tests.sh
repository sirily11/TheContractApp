#!/bin/bash

# Script to run all tests for all packages in the packages/ directory
# Usage: ./scripts/run_all_package_tests.sh

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$PROJECT_ROOT/packages"

echo -e "${GREEN}Running all tests (including E2E) for all packages...${NC}"
echo "Project root: $PROJECT_ROOT"
echo "Packages directory: $PACKAGES_DIR"
echo ""

# Check if packages directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    echo -e "${RED}Error: packages directory not found at $PACKAGES_DIR${NC}"
    exit 1
fi

# Track test results
FAILED_PACKAGES=()
SUCCESS_COUNT=0
TOTAL_COUNT=0

# Find all Package.swift files in packages directory
while IFS= read -r -d '' package_file; do
    package_dir="$(dirname "$package_file")"
    package_name="$(basename "$package_dir")"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Testing package: $package_name${NC}"
    echo -e "${GREEN}Package path: $package_dir${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Run all tests including E2E
    if swift test --package-path "$package_dir"; then
        echo -e "${GREEN}✓ Tests passed for $package_name${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}✗ Tests failed for $package_name${NC}"
        FAILED_PACKAGES+=("$package_name")
    fi

    echo ""
done < <(find "$PACKAGES_DIR" -maxdepth 2 -name "Package.swift" -print0)

# Print summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Total packages tested: $TOTAL_COUNT"
echo -e "${GREEN}Successful: $SUCCESS_COUNT${NC}"
echo -e "${RED}Failed: ${#FAILED_PACKAGES[@]}${NC}"

if [ ${#FAILED_PACKAGES[@]} -ne 0 ]; then
    echo ""
    echo -e "${RED}Failed packages:${NC}"
    for package in "${FAILED_PACKAGES[@]}"; do
        echo -e "${RED}  - $package${NC}"
    done
    exit 1
fi

echo -e "${GREEN}All tests passed! ✓${NC}"
exit 0
