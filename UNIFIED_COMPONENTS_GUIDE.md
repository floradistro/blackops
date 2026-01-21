# BlackOps Unified Glass Component System

## Overview

This guide documents the unified glass design system components for BlackOps. All windows (CRM, POS, MCP servers, emails, products) now use consistent, reusable components following Apple HIG standards.

## Core Philosophy

1. **Single Source of Truth**: All components use `DesignSystem.swift` for colors, spacing, typography
2. **Glass Native**: Leverage SwiftUI's native Material effects for consistency
3. **Reusability**: One component, many uses across all features
4. **Consistency**: Same visual language across CRM, POS, MCP, and email views

## Component Library Location

All unified components are in:
```
/Users/whale/Desktop/blackops/SwagManager/Components/UnifiedGlassComponents.swift
```

---

## Components

### 1. GlassProductCard

**Purpose**: Unified product display for grids and lists

**Usage**: Product selector, POS, cart, inventory

**Props**:
- `product: Product` - Product data
- `size: CardSize` - `.compact` (140x140), `.standard` (180x180), `.large` (220x220)
- `showPrice: Bool` - Display price
- `showStock: Bool` - Display stock indicator
- `onTap: () -> Void` - Tap handler

**Example**:
```swift
GlassProductCard(
    product: product,
    size: .standard,
    showPrice: true,
    showStock: true
) {
    selectedProduct = product
}
```

**Visual Features**:
- Glass material background
- Dynamic image loading with placeholder
- Stock status badge (green/yellow/red)
- Standardized borders and corner radius
- Price formatting

**Replaces**:
- ❌ `ProductCard` (ProductSelectorSheet) - DEPRECATED
- ❌ `ProductTile` (CartPanel) - DEPRECATED

---

### 2. GlassPanel

**Purpose**: Main container for detail views with optional header

**Usage**: All detail panels (CRM, MCP, Email, Product)

**Props**:
- `title: String?` - Panel title
- `showHeader: Bool` - Show/hide header (default: true)
- `headerActions: (() -> AnyView)?` - Optional header actions
- `content: () -> Content` - Panel content (ViewBuilder)

**Example**:
```swift
GlassPanel(
    title: campaign.name,
    showHeader: true,
    headerActions: {
        AnyView(
            Button("Refresh") { refresh() }
        )
    }
) {
    VStack {
        // Your content here
    }
}
```

**Visual Features**:
- Auto-scrolling content area
- Glass material header
- Consistent padding and spacing
- Full-height layout

**Use Cases**:
- ✅ EmailCampaignDetailPanel
- ✅ Meta integration panels
- ✅ MCP server config
- ✅ Email detail views

---

### 3. GlassSection

**Purpose**: Group related content with title and icon

**Usage**: Within panels to organize information

**Props**:
- `title: String` - Section title
- `subtitle: String?` - Optional subtitle
- `icon: String?` - Optional SF Symbol icon
- `content: () -> Content` - Section content

**Example**:
```swift
GlassSection(
    title: "Campaign Details",
    subtitle: "Configuration and metadata",
    icon: "info.circle"
) {
    VStack {
        // Section content
    }
}
```

**Visual Features**:
- Glass background with border
- Icon + title + subtitle layout
- Consistent padding
- Rounded corners

**Use Cases**:
- ✅ Product editor sections
- ✅ CRM detail sections
- ✅ Settings groups
- ✅ Form sections

---

### 4. GlassStatCard

**Purpose**: Display metrics with trends

**Usage**: Analytics, monitoring, dashboards

**Props**:
- `title: String` - Metric name
- `value: String` - Main value
- `subtitle: String?` - Additional info
- `icon: String?` - SF Symbol icon
- `trend: TrendIndicator?` - `.up()`, `.down()`, `.neutral()`
- `color: Color` - Accent color

**Trend Options**:
```swift
.up("15%")      // Green arrow up
.down("5%")     // Red arrow down
.neutral("0%")  // Gray dash
```

**Example**:
```swift
GlassStatCard(
    title: "Total Sales",
    value: "$12,450",
    subtitle: "Last 30 days",
    icon: "dollarsign.circle",
    trend: .up("15%"),
    color: DesignSystem.Colors.green
)
```

**Visual Features**:
- Large bold value
- Icon in accent color
- Trend indicator with icon and percentage
- Glass material background

**Replaces**:
- ❌ `StatCard` (EmailCampaignDetailPanel) - DEPRECATED
- ❌ `MCPStatCard` (MCPMonitoringView) - DEPRECATED

**Use Cases**:
- ✅ Email campaign stats
- ✅ MCP monitoring metrics
- ✅ Order analytics
- ✅ Product performance

---

### 5. GlassListItem

**Purpose**: Consistent list row with icon, badge, and trailing content

**Usage**: Lists, sidebars, settings

**Props**:
- `title: String` - Main text
- `subtitle: String?` - Secondary text
- `icon: String?` - Leading icon
- `iconColor: Color` - Icon tint
- `badge: String?` - Badge text
- `badgeColor: Color` - Badge color
- `onTap: (() -> Void)?` - Tap handler
- `trailing: () -> Content` - Trailing content

**Example**:
```swift
GlassListItem(
    title: "Campaign Name",
    subtitle: "Sent 2 hours ago",
    icon: "envelope.fill",
    iconColor: DesignSystem.Colors.blue,
    badge: "Active",
    badgeColor: DesignSystem.Colors.green,
    onTap: { selectCampaign() }
) {
    Image(systemName: "chevron.right")
        .foregroundStyle(DesignSystem.Colors.textTertiary)
}
```

**Visual Features**:
- Icon with colored background
- Badge with capsule shape
- Custom trailing content
- Glass material background
- Tap animation

**Use Cases**:
- Email campaign lists
- MCP server lists
- Order lists
- Customer lists
- Settings rows

---

### 6. GlassTextField

**Purpose**: Consistent text input with glass styling

**Usage**: Forms, settings, search

**Props**:
- `label: String` - Field label
- `placeholder: String` - Placeholder text
- `text: Binding<String>` - Text binding
- `icon: String?` - Optional leading icon

**Example**:
```swift
GlassTextField(
    label: "Campaign Name",
    placeholder: "Enter name...",
    text: $campaignName,
    icon: "envelope"
)
```

**Visual Features**:
- Glass material background
- Focus state animation
- Accent border on focus
- Optional icon
- Consistent typography

**Use Cases**:
- Product editor
- CRM forms
- Email composer
- Settings

---

### 7. GlassToggle

**Purpose**: Toggle switch with glass container

**Usage**: Settings, feature flags, options

**Props**:
- `label: String` - Toggle label
- `subtitle: String?` - Description text
- `isOn: Binding<Bool>` - State binding

**Example**:
```swift
GlassToggle(
    label: "Enable Notifications",
    subtitle: "Receive real-time updates",
    isOn: $notificationsEnabled
)
```

**Visual Features**:
- Glass background
- Label + subtitle layout
- Native SwiftUI toggle
- Consistent padding

---

### 8. GlassButton

**Purpose**: Consistent button styling

**Usage**: Actions, forms, toolbars

**Props**:
- `title: String` - Button text
- `icon: String?` - Optional SF Symbol
- `style: ButtonStyleType` - `.primary`, `.secondary`, `.destructive`, `.ghost`
- `action: () -> Void` - Tap handler

**Example**:
```swift
GlassButton("Save Changes", icon: "checkmark", style: .primary) {
    saveChanges()
}

GlassButton("Cancel", style: .ghost) {
    dismiss()
}
```

**Styles**:
- **Primary**: Accent color background, white text
- **Secondary**: Glass background, bordered
- **Destructive**: Red background, white text
- **Ghost**: Transparent, accent outline

---

### 9. GlassEmptyState

**Purpose**: Empty state placeholder with action

**Usage**: Empty lists, no data states

**Props**:
- `icon: String` - SF Symbol icon (large)
- `title: String` - Main message
- `subtitle: String` - Description
- `actionTitle: String?` - Optional button text
- `action: (() -> Void)?` - Optional action

**Example**:
```swift
GlassEmptyState(
    icon: "tray",
    title: "No Campaigns",
    subtitle: "Create your first campaign to get started",
    actionTitle: "Create Campaign",
    action: { createCampaign() }
)
```

---

## Design System Reference

### Colors

Always use `DesignSystem.Colors.*`:

```swift
// Surfaces
.surfacePrimary      // Clear (window background shows through)
.surfaceSecondary    // Subtle elevation
.surfaceTertiary     // white.opacity(0.03)
.surfaceElevated     // white.opacity(0.05)

// Text
.textPrimary         // white.opacity(0.92)
.textSecondary       // white.opacity(0.65)
.textTertiary        // white.opacity(0.40)

// Borders
.border              // white.opacity(0.08)
.borderSubtle        // white.opacity(0.04)

// Semantic
.accent              // Blue
.success / .green    // Green
.warning / .yellow   // Yellow
.error / .red        // Red
```

### Spacing

Always use `DesignSystem.Spacing.*`:

```swift
.xxs  // 2pt
.xs   // 4pt
.sm   // 8pt
.md   // 12pt
.lg   // 16pt
.xl   // 20pt
.xxl  // 24pt
.xxxl // 32pt
```

### Corner Radius

Always use `DesignSystem.Radius.*`:

```swift
.xs   // 4pt
.sm   // 6pt
.md   // 8pt  (most common)
.lg   // 12pt
.xl   // 16pt
.xxl  // 20pt
.pill // 9999 (fully rounded)
```

### Typography

Always use `DesignSystem.Typography.*`:

```swift
.largeTitle  // 34pt, bold
.title1      // 28pt, bold
.title2      // 22pt, bold
.title3      // 20pt, semibold
.headline    // 17pt, semibold
.body        // 17pt, regular
.caption1    // 12pt, regular
.caption2    // 11pt, regular
```

### Materials

Always use `DesignSystem.Materials.*`:

```swift
.ultraThin
.thin        // Most common for glass effects
.regular
.thick
.ultraThick
```

---

## Migration Guide

### Before (INCONSISTENT):

```swift
// OLD: Hardcoded colors, inconsistent spacing
VStack {
    Text(product.name)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)

    Text(formatPrice(product.price))
        .font(.system(size: 12))
}
.padding(10)
.background(Color(NSColor.windowBackgroundColor))
.cornerRadius(8)
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
)
```

### After (UNIFIED):

```swift
// NEW: Using unified component
GlassProductCard(
    product: product,
    size: .standard,
    showPrice: true,
    showStock: true
) {
    selectProduct(product)
}
```

---

## Best Practices

### ✅ DO

1. **Always use DesignSystem constants**:
   ```swift
   .foregroundStyle(DesignSystem.Colors.textPrimary)
   .padding(DesignSystem.Spacing.md)
   .cornerRadius(DesignSystem.Radius.md)
   ```

2. **Use unified components for common patterns**:
   - Products → `GlassProductCard`
   - Stats → `GlassStatCard`
   - Panels → `GlassPanel`
   - Sections → `GlassSection`

3. **Apply glass materials for depth**:
   ```swift
   .background(DesignSystem.Materials.thin)
   ```

4. **Use semantic colors**:
   ```swift
   color: DesignSystem.Colors.success  // Not .green
   ```

### ❌ DON'T

1. **Don't use system colors directly**:
   ```swift
   // BAD
   Color(NSColor.controlBackgroundColor)

   // GOOD
   DesignSystem.Colors.surfaceElevated
   ```

2. **Don't hardcode values**:
   ```swift
   // BAD
   .padding(12)
   .cornerRadius(8)

   // GOOD
   .padding(DesignSystem.Spacing.md)
   .cornerRadius(DesignSystem.Radius.md)
   ```

3. **Don't create custom product cards**:
   ```swift
   // BAD - Creating custom card
   struct MyProductCard: View { ... }

   // GOOD - Using unified component
   GlassProductCard(...)
   ```

4. **Don't use custom opacity for borders**:
   ```swift
   // BAD
   Color.primary.opacity(0.08)

   // GOOD
   DesignSystem.Colors.border
   ```

---

## Component Matrix

| Feature | Product | Stats | Panel | Section | List | Form |
|---------|---------|-------|-------|---------|------|------|
| **POS** | ✅ GlassProductCard | ✅ GlassStatCard | - | - | - | - |
| **Product Selector** | ✅ GlassProductCard | - | - | - | - | - |
| **CRM Campaigns** | - | ✅ GlassStatCard | ✅ GlassPanel | ✅ GlassSection | - | - |
| **MCP Monitoring** | - | ✅ GlassStatCard | - | ✅ GlassSection | - | - |
| **Email Details** | - | - | ✅ GlassPanel | ✅ GlassSection | ✅ GlassListItem | - |
| **Product Editor** | - | - | - | ✅ GlassSection | - | ✅ GlassTextField |
| **Settings** | - | - | - | - | ✅ GlassListItem | ✅ GlassToggle |

---

## Legacy Component Status

### DEPRECATED (Do not use in new code):

- ❌ `ProductCard` (ProductSelectorSheet.swift:218) - Use `GlassProductCard`
- ❌ `ProductTile` (CartPanel.swift:231) - Use `GlassProductCard`
- ❌ `StatCard` (EmailCampaignDetailPanel.swift:234) - Use `GlassStatCard`
- ❌ `MCPStatCard` (MCPMonitoringView.swift:234) - Use `GlassStatCard`

These components are kept for backward compatibility but will be removed in a future version.

---

## Performance Notes

1. **GlassProductCard** uses `Equatable` for performance in large grids
2. **Material effects** are GPU-accelerated (native SwiftUI)
3. **Lazy loading** recommended for lists with 100+ items
4. **Image caching** handled automatically by AsyncImage

---

## Examples by Use Case

### Email Campaign Dashboard

```swift
GlassPanel(title: campaign.name) {
    VStack(spacing: DesignSystem.Spacing.xl) {
        // Stats
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            GlassStatCard(
                title: "Delivered",
                value: "\(campaign.delivered)",
                icon: "checkmark.circle",
                trend: .up("15%"),
                color: DesignSystem.Colors.success
            )

            GlassStatCard(
                title: "Opened",
                value: "\(campaign.opened)",
                icon: "envelope.open",
                trend: .up("8%"),
                color: DesignSystem.Colors.orange
            )
        }

        // Details
        GlassSection(title: "Campaign Info", icon: "info.circle") {
            VStack {
                DetailRow(label: "Subject", value: campaign.subject)
                DetailRow(label: "Status", value: campaign.status)
            }
        }
    }
}
```

### POS Product Grid

```swift
LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
    ForEach(products) { product in
        GlassProductCard(
            product: product,
            size: .compact,
            showPrice: true,
            showStock: true
        ) {
            addToCart(product)
        }
    }
}
.padding(DesignSystem.Spacing.md)
```

### MCP Server Monitoring

```swift
VStack(spacing: DesignSystem.Spacing.lg) {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]) {
        GlassStatCard(
            title: "Uptime",
            value: "99.9%",
            icon: "checkmark.seal",
            color: DesignSystem.Colors.green
        )

        GlassStatCard(
            title: "Requests",
            value: "1,234",
            icon: "arrow.up.arrow.down",
            color: DesignSystem.Colors.blue
        )

        GlassStatCard(
            title: "Errors",
            value: "2",
            icon: "exclamationmark.triangle",
            color: DesignSystem.Colors.error
        )
    }
}
```

---

## Future Enhancements

### Planned Components

1. **GlassTable** - Unified data table with sorting/filtering
2. **GlassModal** - Consistent modal/sheet styling
3. **GlassToolbar** - Unified toolbar component
4. **GlassChart** - Chart components for analytics

### Planned Features

1. Light mode support (currently dark-mode optimized)
2. Accessibility enhancements (VoiceOver labels)
3. Animation presets for transitions
4. Haptic feedback integration

---

## Questions?

For issues or questions:
1. Check this guide first
2. Review `DesignSystem.swift` for available tokens
3. Look at existing implementations in refactored files:
   - `ProductSelectorSheet.swift`
   - `CartPanel.swift`
   - `EmailCampaignDetailPanel.swift`
   - `MCPMonitoringView.swift`

---

**Last Updated**: 2026-01-20
**Version**: 1.0
**Status**: Production Ready ✅
