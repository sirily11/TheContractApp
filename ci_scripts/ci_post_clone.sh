#!/bin/bash
set -e

echo "========================================="
echo "Post-clone: Updating app version"
echo "========================================="

# Change to repository root
cd "$CI_PRIMARY_REPOSITORY_PATH"
echo "Working directory: $(pwd)"

# Get version from CI_TAG (set by Xcode Cloud when building from a tag)
if [ -n "$CI_TAG" ]; then
    # CI_TAG is set, use it
    VERSION="${CI_TAG#v}"
    echo "Building from tag: $CI_TAG"
    echo "Extracted version: $VERSION"
else
    # No tag, use build number or default development version
    if [ -n "$CI_BUILD_NUMBER" ]; then
        VERSION="0.0.$CI_BUILD_NUMBER-dev"
        echo "No tag found, using build number: $VERSION"
    else
        VERSION="0.0.1-dev"
        echo "No tag found, using default version: $VERSION"
    fi
fi

# Call the update-version script (from repository root)
echo "Calling update-version script..."
bash scripts/update-version.sh "$VERSION"

echo "========================================="
echo "Version update complete!"
echo "========================================="
