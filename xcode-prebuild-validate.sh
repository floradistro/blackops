#!/bin/bash
# SwagManager Xcode Pre-Build Validation
# Add this to Xcode Build Phases → Run Script (before Compile Sources)

set -e

echo "🔍 Pre-build validation..."

# 1. Check for stale DerivedData (older than 7 days)
STALE_COUNT=$(find ~/Library/Developer/Xcode/DerivedData/SwagManager-* -maxdepth 0 -mtime +7 2>/dev/null | wc -l)
if [ "$STALE_COUNT" -gt 0 ]; then
    echo "⚠️  Found $STALE_COUNT stale DerivedData folders (>7 days old)"
    echo "   Cleaning..."
    find ~/Library/Developer/Xcode/DerivedData/SwagManager-* -maxdepth 0 -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
fi

# 2. Validate project file
if ! plutil -lint "${PROJECT_FILE_PATH}/project.pbxproj" > /dev/null 2>&1; then
    echo "❌ ERROR: Project file is corrupted!"
    exit 1
fi

# 3. Check file permissions (only validate, don't fix during build)
RESTRICTED=$(find "${SRCROOT}/SwagManager" -name "*.swift" -perm -600 ! -perm -644 2>/dev/null | wc -l)
if [ "$RESTRICTED" -gt 0 ]; then
    echo "⚠️  Warning: Found $RESTRICTED Swift files with restrictive permissions"
    echo "   Run: chmod 644 SwagManager/**/*.swift"
fi

# 4. Kill any zombie processes from previous debug sessions
ps aux | grep "SwagManager.app/Contents/MacOS/SwagManager" | grep -v grep | grep -v "$PPID" | awk '{print $2}' | xargs -r kill -9 2>/dev/null || true

echo "✅ Pre-build validation passed"
