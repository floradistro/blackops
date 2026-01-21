#!/bin/bash
# Smart cache clearing - keeps Swift packages intact

DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "SwagManager-*" -type d -maxdepth 1 | head -1)

if [ -z "$DERIVED_DATA" ]; then
    echo "⚠️  No DerivedData found for SwagManager"
    exit 0
fi

echo "📦 Found DerivedData: $DERIVED_DATA"

# Only clear build artifacts, not Swift packages
rm -rf "$DERIVED_DATA/Build"
rm -rf "$DERIVED_DATA/ModuleCache"
rm -rf "$DERIVED_DATA/Index"

echo "✅ Cleared Build, ModuleCache, and Index"
echo "✅ Kept SourcePackages (Swift packages intact)"
