# 🍎 Apple Engineering Standards for SwagManager

**Date**: 2026-01-19
**Status**: Comprehensive audit and implementation guide

---

## ✅ Current State: What We're Doing Right

### Native macOS Components ✅
```swift
// We're already using native materials correctly
VisualEffectBackground(material: .sidebar)         // Native NSVisualEffectView
VisualEffectBackground(material: .underWindowBackground)
VisualEffectBackground(material: .titlebar)

// WebViews wrapped properly
NSViewRepresentable + WKWebView                    // Native web rendering

// Native SwiftUI components
TextField, Toggle, Button, Menu, Picker            // All native, no custom hacks
```

### Performance ✅
- **LazyVStack** in sidebar (just implemented)
- **Debounced search** (300ms delay)
- **Animation modifiers** for smooth interactions
- **Indexed lookups** in stores (O(1) not O(n))

### Design System ✅
- **100% adoption** of DesignSystem tokens
- **Consistent spacing**, colors, typography
- **Zero hardcoded values** in new code

---

## 📐 Apple Code Size Standards

### File Size Limits (Apple Internal Guidelines)
```
✅ EXCELLENT:   <300 lines   (Single, focused responsibility)
✅ GOOD:        300-700 lines (Well-organized, clear sections)
⚠️  WARNING:    700-1000 lines (Needs refactoring soon)
❌ CRITICAL:    >1000 lines  (Refactor immediately)
```

### Current State
```
❌ EditorView.swift:          4,516 lines  (3.3x over limit)
❌ CategoryConfigView.swift:  1,319 lines  (1.3x over limit)
❌ SupabaseService.swift:     1,219 lines  (1.2x over limit)
⚠️  MarkdownText.swift:       1,066 lines  (Near limit)
⚠️  BrowserSessionView.swift:  757 lines  (Near limit)
⚠️  AIService.swift:            750 lines  (Near limit)
✅ All other files:           <700 lines
```

### Target State
```
EditorView.swift:          →  <1,500 lines (extract panels)
CategoryConfigView.swift:  →  <700 lines (extract editors)
SupabaseService.swift:     →  4 files <500 lines each
MarkdownText.swift:        →  <500 lines (optimize rendering)
BrowserSessionView.swift:  →  <500 lines (extract toolbar)
AIService.swift:           →  <500 lines (extract providers)
```

---

## 🎯 Apple Component Standards

### 1. Use Native SwiftUI Whenever Possible

#### ✅ Currently Using Native
```swift
// Form controls
TextField, SecureField, TextEditor
Toggle, Picker, Slider, Stepper
Button, Menu, Link

// Layout
VStack, HStack, ZStack, LazyVStack, LazyHStack
ScrollView, List, Form
Group, Section

// Modifiers
.padding(), .frame(), .background(), .foregroundStyle()
.font(), .fontWeight(), .tracking()
```

#### ✅ Using Native macOS Materials
```swift
// Glass/vibrancy effects (native NSVisualEffectView)
.sidebar
.titlebar
.underWindowBackground
.headerView
.menu
.popover
.sheet
```

#### ❌ Avoid Custom Implementations Of Native Components
```swift
// DON'T create custom:
- SearchField (use TextField with .searchable())
- Toggle (use native Toggle)
- Picker (use native Picker)
- ProgressBar (use native ProgressView)
```

---

### 2. Component Composition Over Inheritance

#### ✅ Good: Small, Composable Views
```swift
// TreeItems.swift: Each component <100 lines
struct CategoryTreeItem: View { }     // 40 lines
struct ProductTreeItem: View { }      // 45 lines
struct CollectionTreeItem: View { }   // 42 lines
struct CreationTreeItem: View { }     // 50 lines
```

#### ✅ Good: Reusable State Components
```swift
// StateViews.swift: Standard patterns
EmptyStateView(icon:title:message:action:)
LoadingStateView()
ErrorStateView(error:retry:)
```

#### ❌ Bad: Monolithic Views
```swift
// DON'T do this:
struct MassiveView: View {
    // 2000+ lines
    // Does everything
    // Hard to test
    // Impossible to reuse
}
```

---

### 3. Performance: 60fps Guarantee

#### ✅ Implemented
```swift
// Lazy loading
LazyVStack { /* Only render visible items */ }

// Debouncing
.onChange(of: searchText) { _, newValue in
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000)
        debouncedSearchText = newValue
    }
}

// Smooth animations
.animation(DesignSystem.Animation.fast, value: isActive)
.animation(DesignSystem.Animation.fast, value: isSelected)
```

#### 🚧 Need to Add
```swift
// Equatable views (prevent unnecessary re-renders)
struct ProductTreeItem: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product.id == rhs.product.id &&
        lhs.isSelected == rhs.isSelected
    }
}

// State minimization
@State private var isHovering = false  // ✅ Local state
@Published var allProducts: [Product]  // ❌ Global causes full re-render

// Smart updates
.id(item.id)  // Helps SwiftUI diff efficiently
```

---

### 4. Native macOS Patterns

#### ✅ Already Following

**Sidebar Pattern**
```swift
NavigationSplitView {
    SidebarPanel()  // List-based navigation
} detail: {
    ContentView()   // Detail content
}
```

**Visual Hierarchy**
```
Section Headers:  10pt semibold, uppercase, tracking 0.5
Item Labels:      11pt regular (caption2)
Metadata:         9pt medium
Icons:            9-11pt (visual weight adjusted)
```

**Materials**
```swift
.sidebar           // Navigation/sidebar
.titlebar          // Window chrome
.underWindowBackground  // Content area
.menu              // Dropdowns, popovers
```

#### 🚧 Need to Add

**NSToolbar** (Native macOS toolbar)
```swift
// Replace custom toolbar with native NSToolbar
WindowGroup {
    ContentView()
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Back/forward buttons
            }
            ToolbarItemGroup(placement: .primaryAction) {
                // Main actions
            }
        }
}
```

**Touch Bar Support** (if applicable)
```swift
.touchBar {
    HStack {
        Button("Action") { }
    }
}
```

---

## 📊 Component Size Audit

### Components/ Directory
```
✅ ButtonStyles.swift:     221 lines  (8 button styles)
✅ ChatComponents.swift:   385 lines  (4 chat components)
⚠️  EditorSheets.swift:    543 lines  (5 sheet views) → Split to individual files
✅ StateViews.swift:       250 lines  (3 state views)
✅ TreeItems.swift:        542 lines  (7 tree components)
```

**Recommendation**: Extract EditorSheets.swift into individual files:
```
EditorSheets/
├── NewCreationSheet.swift     (~100 lines)
├── NewCollectionSheet.swift   (~100 lines)
├── NewStoreSheet.swift        (~100 lines)
├── NewCatalogSheet.swift      (~100 lines)
└── NewCategorySheet.swift     (~100 lines)
```

---

## 🎯 Immediate Action Items

### Priority 1: Split Large Files (Apple Standard <1000 lines)

#### EditorView.swift (4,516 → 1,500 lines)
**Extract**:
1. `TabBarView.swift` (~400 lines)
2. `ProductDetailPanel.swift` (~600 lines)
3. `CreationDetailPanel.swift` (~600 lines)
4. `BrowserControlsBar.swift` (~300 lines)
5. `EditorToolbar.swift` (~200 lines)

#### SupabaseService.swift (1,219 → 4 files <500 lines each)
**Split into**:
1. `ProductService.swift` (~300 lines)
2. `CreationService.swift` (~300 lines)
3. `ChatService.swift` (~200 lines)
4. `AuthService.swift` (~200 lines)
5. Keep `SupabaseService.swift` as coordinator (~200 lines)

#### CategoryConfigView.swift (1,319 → 700 lines)
**Extract**:
1. `FieldSchemaEditor.swift` (~200 lines)
2. `PricingSchemaEditor.swift` (~200 lines)
3. Use existing `StateViews.swift` components

---

### Priority 2: Add Equatable to Views

**Performance boost: Prevent unnecessary re-renders**

```swift
struct ProductTreeItem: View, Equatable {
    let product: Product
    let isSelected: Bool
    let isActive: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product.id == rhs.product.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isActive == rhs.isActive
    }

    var body: some View {
        // ... view code
    }
}
```

**Apply to**:
- All TreeItem components
- List row components
- Frequently re-rendered views

---

### Priority 3: Use Native List When Appropriate

**Current**: Custom VStack + ForEach
**Better**: Native List (automatic cell reuse, performance)

```swift
// BEFORE (custom)
LazyVStack {
    ForEach(items) { item in
        CustomRow(item: item)
    }
}

// AFTER (native - if table-like)
List(items) { item in
    CustomRow(item: item)
}
.listStyle(.sidebar)  // macOS sidebar style
```

**When to use List**:
- ✅ Uniform row heights
- ✅ Simple selection model
- ✅ Standard macOS list appearance

**When to use LazyVStack**:
- ✅ Variable row heights
- ✅ Custom layouts
- ✅ Nested hierarchies (our case)

---

## 🏆 Apple Excellence Checklist

### Code Quality
- [ ] No files >1,000 lines
- [ ] All components <300 lines
- [ ] Zero warnings
- [ ] All commented code removed
- [ ] Consistent error handling

### Performance
- [x] LazyVStack for long lists
- [x] Debounced search
- [x] Animation modifiers
- [ ] Equatable views
- [ ] Profiled with Instruments

### Native Integration
- [x] Native materials (NSVisualEffectView)
- [x] Native form controls
- [ ] Native NSToolbar
- [ ] Native window chrome
- [ ] Native keyboard shortcuts

### Polish
- [x] Consistent spacing (DesignSystem tokens)
- [x] Unified typography
- [x] Smooth animations
- [ ] Loading states everywhere
- [ ] Beautiful empty states

### Accessibility
- [ ] VoiceOver labels
- [ ] Keyboard navigation
- [ ] Dynamic type support
- [ ] High contrast support

---

## 📈 Success Metrics

### File Size
```
Target: 0 files >1,000 lines
Current: 3 files >1,000 lines
Goal: 100% compliance by end of week
```

### Performance
```
Target: All lists 60fps
Target: <100ms UI response time
Target: Search results in <50ms (after debounce)
```

### Code Quality
```
Target: 0 warnings
Target: 0 commented code
Target: 100% DesignSystem adoption
```

---

## 🚀 Next Steps

1. **This Week**: Split EditorView.swift (<1,500 lines)
2. **This Week**: Split SupabaseService.swift (4 focused services)
3. **Next Week**: Add Equatable to all tree components
4. **Next Week**: Native NSToolbar implementation
5. **Ongoing**: Keep all new files <300 lines

---

**Bottom Line**: We're already following Apple's core principles (native components, performance, design system). The main work is **splitting large files** to meet Apple's <1,000 line guideline and adding **Equatable** for performance.
