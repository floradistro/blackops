#!/bin/bash
# SwagManager Clean Build Script
# Thoroughly cleans all build artifacts before building

echo "🧹 Cleaning SwagManager Build Artifacts"
echo "========================================"

# 1. Clean Xcode derived data
echo "1️⃣  Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/SwagManager-*
echo "✓ Cleaned Xcode derived data"

# 2. Clean local derived data
echo "2️⃣  Cleaning local build folders..."
rm -rf ./DerivedData
rm -rf ./.build
rm -rf ./Build
echo "✓ Cleaned local build folders"

# 3. Clean Xcode build folder
echo "3️⃣  Cleaning Xcode build..."
xcodebuild -project SwagManager.xcodeproj -scheme SwagManager clean > /dev/null 2>&1 || true
echo "✓ Cleaned Xcode build"

# 4. Clean module cache
echo "4️⃣  Cleaning module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*
echo "✓ Cleaned module cache"

# 5. Remove .DS_Store files
echo "5️⃣  Removing junk files..."
find . -name ".DS_Store" -delete 2>/dev/null || true
find . -name "*.orig" -delete 2>/dev/null || true
find . -name "*.swp" -delete 2>/dev/null || true
echo "✓ Removed junk files"

# 6. Fix file permissions
echo "6️⃣  Fixing file permissions..."
find SwagManager -name "*.swift" -exec chmod 644 {} \; 2>/dev/null || true
echo "✓ Fixed file permissions"

echo ""
echo "✅ Clean complete! Ready for fresh build."
echo ""
echo "Run: xcodebuild -project SwagManager.xcodeproj -scheme SwagManager build"
