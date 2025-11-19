#!/bin/bash
set -e

echo "========================================="
echo "Post-clone: Updating app version"
echo "========================================="

# Get the latest git tag
GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Extract version from tag (remove 'v' prefix if present)
if [ -n "$GIT_TAG" ]; then
    VERSION="${GIT_TAG#v}"
    echo "Found git tag: $GIT_TAG"
    echo "Extracted version: $VERSION"
else
    # No tags found, use a default development version
    VERSION="0.0.1-dev"
    echo "No git tags found, using default version: $VERSION"
fi

# Call the update-version script
echo "Calling update-version script..."
bash "$CI_PRIMARY_REPOSITORY_PATH/scripts/update-version.sh" "$VERSION"

echo "========================================="
echo "Version update complete!"
echo "========================================="
