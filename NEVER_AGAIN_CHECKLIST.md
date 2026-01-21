# 🛡️ NEVER AGAIN - Build Corruption Prevention Checklist

## ✅ Before Every Build

```bash
# 1. Validate project
./validate-project.sh

# 2. If any errors, clean first
./clean-build.sh

# 3. Build
xcodebuild -project SwagManager.xcodeproj -scheme SwagManager build
```

## ✅ Before Every Commit

```bash
# 1. Validate
./validate-project.sh

# 2. Check git status
git status

# 3. Never commit these:
# ❌ build/
# ❌ DerivedData/
# ❌ *.swiftmodule
# ❌ *.corrupted
# ❌ .DS_Store
```

## ✅ Weekly Maintenance

```bash
# Every Monday morning:
./clean-build.sh
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

## 🚨 Red Flags - Act Immediately

### "Cannot find type 'X' in scope"
```bash
./clean-build.sh
# Check project.pbxproj for corruption
./validate-project.sh
```

### "Main actor-isolated property..."
- Add `nonisolated init` or `@MainActor` to class

### Xcode won't build but xcodebuild does
```bash
# In Xcode:
# Product → Clean Build Folder (Cmd+Shift+K)
# Close Xcode
./clean-build.sh
# Reopen Xcode
```

### Build succeeds but types not found
- Corrupted project file - check PBXBuildFile entries
- Run: `./validate-project.sh`

## ✅ When Adding New Swift Files

1. **Add to Git**: `git add NewFile.swift`
2. **Check Xcode Target**: File Inspector → Target Membership → ✓ SwagManager
3. **Verify**: `./validate-project.sh`
4. **Test Build**: Build in Xcode

## ✅ Swift 6 Compliance Rules

### Making Types Public
```swift
// ❌ Wrong
struct MyType: Codable, Identifiable {
    let id: UUID
}

// ✅ Correct
public struct MyType: Codable, Identifiable {
    public let id: UUID

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MyType, rhs: MyType) -> Bool {
        lhs.id == rhs.id
    }
}
```

### MainActor Classes
```swift
// ❌ Wrong
@MainActor
class MyService {
    init(dep: Dependency = .shared) { // Error in Swift 6
    }
}

// ✅ Correct
@MainActor
class MyService {
    nonisolated init(dep: Dependency = .shared) {
    }
}
```

## ✅ File Permissions

All Swift files must be readable:
```bash
# Check
ls -la SwagManager/**/*.swift | grep "^-rw-------"

# Fix
chmod 644 SwagManager/**/*.swift
```

## ✅ Git Best Practices

### Before Committing
1. Run `./validate-project.sh`
2. Check `git status` for unwanted files
3. Never commit build artifacts
4. Write descriptive commit messages

### After Pulling
```bash
git pull
./clean-build.sh
./validate-project.sh
```

## 🆘 Emergency Recovery

### Nuclear Option (Only if everything is broken)
```bash
# 1. Backup current work
git stash
git branch backup-$(date +%Y%m%d-%H%M%S)

# 2. Clean everything
./clean-build.sh
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# 3. Restore files
git stash pop

# 4. Fix permissions
find SwagManager -name "*.swift" -exec chmod 644 {} \;

# 5. Validate and build
./validate-project.sh
open SwagManager.xcodeproj
# Xcode: Cmd+Shift+K then Cmd+B
```

## 📊 Health Indicators

### Healthy Project
```
✅ validate-project.sh passes
✅ 0 files with restrictive permissions
✅ 0 junk files
✅ 0 stale derived data
✅ BUILD SUCCEEDED
```

### Unhealthy Project
```
❌ validate-project.sh fails
❌ Cannot find types
❌ Corrupted project file
❌ Stale derived data
❌ BUILD FAILED
```

## 🎯 Key Lessons Learned

1. **Always use validation scripts before building**
2. **Clean builds after major changes**
3. **Never commit build artifacts**
4. **Swift 6 requires explicit public protocol implementations**
5. **Xcode project files can get corrupted - use validation**
6. **File permissions matter (644 for .swift files)**
7. **MainActor classes need nonisolated inits**
8. **When in doubt, clean everything and start fresh**

## 🔧 Tools

- `validate-project.sh` - Pre-build validation
- `clean-build.sh` - Thorough cleanup
- `BUILD_VALIDATION.md` - Full documentation

## 📞 Quick Reference

```bash
# Quick fix for most issues
./clean-build.sh && ./validate-project.sh

# Emergency clean
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Fix permissions
chmod 644 SwagManager/**/*.swift

# Validate git
git status | grep -E "build/|DerivedData|\.swiftmodule"
```

---

**Remember**: An ounce of prevention is worth a pound of debugging! 🛡️

**Last Updated**: Jan 2026 after fixing the great Swift 6 compilation crisis
