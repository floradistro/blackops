# SwagManager Build Validation & Cleanup

## Quick Start

### Before Building
```bash
./validate-project.sh  # Check for issues
./clean-build.sh       # Clean all build artifacts
```

### Building
```bash
# Command line
xcodebuild -project SwagManager.xcodeproj -scheme SwagManager build

# Or use Xcode (recommended)
open SwagManager.xcodeproj
# Then: Cmd+Shift+K (Clean Build Folder)
# Then: Cmd+B (Build)
```

## Scripts

### `validate-project.sh`
Validates the project before building:
- ✓ Checks project file integrity
- ✓ Verifies build file entries
- ✓ Detects stale derived data
- ✓ Checks file permissions
- ✓ Finds junk files
- ✓ Validates Swift files in target

**Run before every build to catch issues early!**

### `clean-build.sh`
Thoroughly cleans all build artifacts:
- Removes all Xcode derived data
- Cleans module cache
- Fixes file permissions (644 for .swift files)
- Removes junk files (.DS_Store, .orig, .swp)

**Run when experiencing strange build issues.**

## Common Issues & Fixes

### "Cannot find type 'Order' in scope"
**Cause**: Corrupted Xcode project file or missing PBXBuildFile entries

**Fix**:
```bash
./clean-build.sh
xcodebuild -project SwagManager.xcodeproj -scheme SwagManager clean build
```

### "Main actor-isolated property cannot be referenced"
**Cause**: Swift 6 concurrency mode requires explicit `nonisolated` or `@MainActor`

**Fix**: Add `nonisolated init` or mark class with `@MainActor`

### Stale Derived Data
**Cause**: Xcode caches outdated build artifacts

**Fix**:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SwagManager-*
# Or use Xcode: Product → Clean Build Folder (Cmd+Shift+K)
```

### File Permission Issues
**Cause**: Files created with restrictive permissions (600 instead of 644)

**Fix**:
```bash
find SwagManager -name "*.swift" -exec chmod 644 {} \;
```

## Prevention

### 1. Always Use Clean Builds
After major changes, always clean:
```bash
./clean-build.sh
```

### 2. Run Validation Before Commits
```bash
./validate-project.sh && git commit -m "message"
```

### 3. Never Commit Build Artifacts
The `.gitignore` file excludes:
- `DerivedData/`
- `Build/`
- `.build/`
- `*.swiftmodule`
- `*.corrupted`

### 4. Use Xcode for Complex Operations
For builds with many dependencies or complex module graphs, Xcode's UI handles compilation order better than command-line `xcodebuild`.

## What We Fixed

### Swift 6 Compliance
- Made all public types fully public with protocol requirements
- Added `nonisolated init` for MainActor classes
- Fixed access modifiers (private(set) → public where needed)

### Project File Corruption
- Repaired missing PBXBuildFile entries for:
  - Order.swift and related types
  - OrderDetailPanel.swift
  - CartPanel.swift
  - CheckoutSheet.swift

### File Organization
- Fixed 109 files with restrictive permissions
- Cleaned up corrupted backup files
- Removed stale build artifacts

## Maintenance

Run these regularly:

```bash
# Weekly cleanup
./clean-build.sh

# Before major builds
./validate-project.sh
./clean-build.sh

# After pulling changes
./clean-build.sh
xcodebuild -project SwagManager.xcodeproj -scheme SwagManager build
```

## Emergency Recovery

If the build is completely broken:

```bash
# 1. Clean everything
./clean-build.sh
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 2. Fix permissions
find SwagManager -name "*.swift" -exec chmod 644 {} \;

# 3. Verify project
./validate-project.sh

# 4. Open in Xcode and build there
open SwagManager.xcodeproj
# In Xcode: Product → Clean Build Folder (Cmd+Shift+K)
# Then: Product → Build (Cmd+B)
```

## Success Indicators

✅ `./validate-project.sh` passes with 0 errors
✅ `xcodebuild ...build` shows `** BUILD SUCCEEDED **`
✅ No "Cannot find type" errors
✅ No "Main actor-isolated" errors
✅ No file permission warnings

---

**Last Updated**: Fixed all Swift 6 compilation errors and project file corruption (Jan 2026)
