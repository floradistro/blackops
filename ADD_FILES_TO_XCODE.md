# How to Add MCP Files to Xcode Project

## Quick Method: Drag & Drop in Xcode

1. **Open SwagManager.xcodeproj in Xcode**

2. **Add MCPServer.swift to Models group:**
   - In Project Navigator, right-click on `Models` folder
   - Select "Add Files to SwagManager..."
   - Navigate to: `SwagManager/Models/MCPServer.swift`
   - Make sure "Copy items if needed" is UNCHECKED
   - Make sure "SwagManager" target is CHECKED
   - Click "Add"

3. **Add EditorStore+MCPManagement.swift to Stores group:**
   - Right-click on `Stores` folder
   - Select "Add Files to SwagManager..."
   - Navigate to: `SwagManager/Stores/EditorStore+MCPManagement.swift`
   - Uncheck "Copy items if needed"
   - Check "SwagManager" target
   - Click "Add"

4. **Add SidebarMCPServersSection.swift to Sidebar group:**
   - Right-click on `Views/Editor/Sidebar` folder
   - Select "Add Files to SwagManager..."
   - Navigate to: `SwagManager/Views/Editor/Sidebar/SidebarMCPServersSection.swift`
   - Uncheck "Copy items if needed"
   - Check "SwagManager" target
   - Click "Add"

5. **Add MCPServerDetailPanel.swift to Editor group:**
   - Right-click on `Views/Editor` folder
   - Select "Add Files to SwagManager..."
   - Navigate to: `SwagManager/Views/Editor/MCPServerDetailPanel.swift`
   - Uncheck "Copy items if needed"
   - Check "SwagManager" target
   - Click "Add"

6. **Build the project** (⌘B)

## Alternative: Command Line (If you prefer)

Run this command from the blackops directory:

```bash
open SwagManager.xcodeproj
```

Then follow the drag & drop steps above.

## Files to Add

- ✅ `SwagManager/Models/MCPServer.swift`
- ✅ `SwagManager/Stores/EditorStore+MCPManagement.swift`
- ✅ `SwagManager/Views/Editor/Sidebar/SidebarMCPServersSection.swift`
- ✅ `SwagManager/Views/Editor/MCPServerDetailPanel.swift`

## Verify

After adding, you should see all 4 files in:
- Project Navigator (left sidebar in Xcode)
- Build Phases → Compile Sources section

Then build (⌘B) - it should compile without errors!
