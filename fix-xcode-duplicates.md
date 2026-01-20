# Fix Xcode Duplicate Build Files

## The Problem

Xcode is warning about duplicate build files:
- `OrderService.swift`
- `OrderDetailPanel.swift`
- `SidebarOrdersSection.swift`
- `OrderTreeItem.swift`

These files are added to the "Compile Sources" build phase multiple times, which can happen when files are added to the project repeatedly.

## How to Fix in Xcode

### Option 1: Quick Fix (Recommended)

1. **Open SwagManager.xcodeproj in Xcode**
2. **Select the SwagManager target** (in the left sidebar, click the blue project icon at the top)
3. **Click "Build Phases" tab**
4. **Expand "Compile Sources"**
5. **Look for duplicate entries** (they'll have the same filename listed twice)
6. **Select the duplicate** and press the **minus (-)** button to remove it
7. **Repeat** for each duplicate file:
   - OrderService.swift
   - OrderDetailPanel.swift
   - SidebarOrdersSection.swift
   - OrderTreeItem.swift

### Option 2: Remove and Re-add Files

If the duplicates are hard to spot:

1. **In Xcode Project Navigator** (left sidebar)
2. **Find each duplicate file**
3. **Right-click → Delete → Remove Reference** (don't move to trash!)
4. **Drag the file back** from Finder into the project
5. **Make sure "Copy items if needed" is UNCHECKED**
6. **Make sure the SwagManager target is CHECKED**

### Option 3: Clean Xcode Project

Sometimes Xcode's cache causes issues:

1. **Product → Clean Build Folder** (Cmd+Shift+K)
2. **Close Xcode**
3. **Delete derived data:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. **Reopen Xcode and build**

## Verify the Fix

After removing duplicates:

1. **Build the project** (Cmd+B)
2. **Check for warnings** - the "Skipping duplicate" warnings should be gone
3. **Run the app** to make sure it still works

## Why This Happens

Xcode sometimes adds files to the build phase multiple times when:
- Files are added through different methods (drag-drop vs File → Add Files)
- Xcode project file is manually edited
- Git merges conflict in the .pbxproj file
- Using multiple Xcode instances

## Already Fixed

✅ **Compilation errors are already fixed:**
- Added `categoryEnum` computed property to ResendEmail
- Fixed type mismatches in EmailCategory extensions
- All Swift code should now compile cleanly

The **duplicate warnings won't prevent compilation**, but they should be cleaned up for best practices.
