# Multi-Select Implementation Plan

## Overview
Implement Finder-style multi-select for sidebar items with drag support.

## State Added
✓ `selectedCustomerIds: Set<UUID>` in EditorStore
✓ `selectedMCPServerIds: Set<UUID>` in EditorStore
✓ `selectedLocationIds: Set<UUID>` in EditorStore
✓ Already exists: `selectedCreationIds`, `selectedProductIds`

## Implementation Strategy

### 1. Selection Behavior
- **Click**: Select single item, deselect others
- **Cmd+Click**: Toggle item in selection (multi-select)
- **Shift+Click**: Range select from last to current
- **Drag selected items**: Drag all selected items as batch

### 2. Visual Feedback
- Selected items show blue background (Color.accentColor.opacity(0.15))
- Multi-selected items stay highlighted
- Drag preview shows count badge (e.g., "3 items")

### 3. Components to Update
- ProductTreeItem - use `store.selectedProductIds`
- CustomerTreeItem - use `store.selectedCustomerIds`
- SidebarMCPServersSection - use `store.selectedMCPServerIds`
- Location rows - use `store.selectedLocationIds`

### 4. Drag Encoding
Update `SidebarDragItem` to support arrays:
```swift
enum SidebarDragItem: Codable {
    case product(Product)
    case products([Product])
    case customer(Customer)
    case customers([Customer])
    case mcpServer(MCPServer)
    case mcpServers([MCPServer])
    case location(Location)
    case locations([Location])
}
```

### 5. Drop Handling
AgentBuilderView drop handlers check for batch vs single:
- If `products([...])`: Add all as context
- If `mcpServers([...])`: Add all as tools

## Files to Modify
1. EditorView.swift - ✓ Added selection state
2. ProductTreeItem.swift - Add selection handling
3. CustomerTreeItem.swift - Add selection handling
4. SidebarMCPServersSection.swift - Add selection handling
5. DraggableComponents.swift - Update SidebarDragItem enum
6. AgentBuilderView.swift - Update drop handlers for batches
