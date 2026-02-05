# macOS SwagManager Audit Report
**Date:** 2026-01-22
**Objective:** Verify macOS app is wired identically to iOS with all business logic in backend only

---

## ✅ ALIGNED WITH iOS (Working Correctly)

### 1. Edge Function Integration
**Location:** `SwagManager/Services/PaymentService.swift`
**Status:** ✅ CORRECT

```swift
// Uses payment-intent edge function (same as iOS)
let url = SupabaseConfig.url.appendingPathComponent("functions/v1/payment-intent")
```

- Sends cartItems with inventoryId and tierQuantity
- Polls for completion
- No local business logic
- **100% aligned with iOS**

---

### 2. Cart Operations
**Location:** `SwagManager/Services/CartService.swift`
**Status:** ✅ CORRECT

```swift
// Uses cart edge function (same as iOS)
let url = baseURL.appendingPathComponent("functions/v1/cart")
```

- All cart operations server-side
- Returns ServerCart with calculated totals
- No local price calculations
- **100% aligned with iOS**

---

### 3. Inventory ID Query (CartPanel)
**Location:** `SwagManager/Views/Cart/CartPanel.swift:376-406`
**Status:** ✅ CORRECT

```swift
// Queries inventory_id for product at location (CORRECT)
let inventory: [InventoryID] = try await SupabaseService.shared.client
    .from("inventory")
    .select("id")
    .eq("product_id", value: productId.uuidString)
    .eq("location_id", value: locId.uuidString)
    .gt("available_quantity", value: 0)
    .order("available_quantity", ascending: false)
    .limit(1)
    .execute()
    .value

inventoryId = inventory.first?.id
```

- **Matches iOS pattern exactly**
- Queries inventory at specific location
- Filters by available_quantity > 0
- Orders by highest stock first

---

### 4. Customer Model
**Location:** `SwagManager/Models/Customer.swift:23`
**Status:** ✅ CORRECT

```swift
var loyaltyPoints: Int?
```

- Has loyaltyPoints property
- Properly decoded from v_store_customers view
- **100% aligned with iOS**

---

### 5. Customer Detail View
**Location:** `SwagManager/Views/Editor/CustomerDetailPanel.swift:50-55`
**Status:** ✅ CORRECT

```swift
StatCard(
    title: "Loyalty Points",
    value: "\(customer.loyaltyPoints ?? 0)",
    icon: "star.fill",
    color: Color(customer.loyaltyTierColor)
)
```

- Shows loyalty points in stat card
- Displays tier color
- **Aligned with iOS customer detail view**

---

## ❌ CRITICAL ISSUES (NOT Aligned with iOS)

### 🔴 ISSUE 1: ProductSelectorSheet Missing inventory_id Query
**Location:** `SwagManager/Views/Cart/ProductSelectorSheet.swift:203-219`
**Severity:** CRITICAL
**Impact:** Orders will NOT deduct from correct location inventory

**Current Code:**
```swift
private func addToCart(product: Product, quantity: Int, tier: PricingTier?) async {
    guard let cartId = cartStore.cart?.id else { return }

    do {
        cartStore.cart = try await CartService().addToCart(
            cartId: cartId,
            productId: product.id,
            quantity: quantity,
            tierLabel: tier?.label,
            tierQuantity: tier?.quantity,
            variantId: nil
            // ❌ MISSING: inventoryId is NOT queried or passed
        )
    } catch {
        NSLog("❌ Cart error: \(error)")
    }
}
```

**Problem:**
- Does NOT query inventory table for inventory_id
- Does NOT pass location_id to determine which location's inventory to use
- inventoryId parameter defaults to nil
- Edge function will create order without inventory deduction

**iOS Behavior:**
- ALWAYS queries inventory_id before adding to cart
- ALWAYS filters by location_id
- ALWAYS checks available_quantity > 0
- ALWAYS passes inventoryId to edge function

**Fix Required:**
```swift
private func addToCart(product: Product, quantity: Int, tier: PricingTier?) async {
    guard let cartId = cartStore.cart?.id else { return }

    // 1. Get inventory_id for this product at cart's location
    var inventoryId: UUID? = nil
    if let locId = cartStore.cart?.locationId {
        do {
            struct InventoryID: Codable {
                let id: UUID
            }

            let inventory: [InventoryID] = try await SupabaseService.shared.client
                .from("inventory")
                .select("id")
                .eq("product_id", value: product.id.uuidString)
                .eq("location_id", value: locId.uuidString)
                .gt("available_quantity", value: 0)
                .order("available_quantity", ascending: false)
                .limit(1)
                .execute()
                .value

            inventoryId = inventory.first?.id
        } catch {
            NSLog("⚠️ Failed to query inventory: \(error)")
        }
    }

    do {
        cartStore.cart = try await CartService().addToCart(
            cartId: cartId,
            productId: product.id,
            quantity: quantity,
            tierLabel: tier?.label,
            tierQuantity: tier?.quantity,
            variantId: nil,
            inventoryId: inventoryId  // ✅ NOW PASSED
        )
    } catch {
        NSLog("❌ Cart error: \(error)")
    }
}
```

---

### 🟡 ISSUE 2: Queue Views Missing Loyalty Points Display
**Location:** `SwagManager/Views/Queue/LocationQueueView.swift:225-313`
**Severity:** MEDIUM
**Impact:** Users cannot see customer loyalty points in queue (inconsistent with iOS)

**Current Code (QueueEntryRow):**
```swift
VStack(alignment: .leading, spacing: 4) {
    HStack {
        Text(entry.customerName)
            .font(.headline)
        // ❌ MISSING: Loyalty points badge
    }

    if let phone = entry.customerPhone {
        Text(phone)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    // Shows cart items and total, but NOT loyalty points
}
```

**iOS Behavior:**
- Shows loyalty points badge next to customer name in queue
- Yellow star icon with points count for positive balance
- Red icon for negative balance
- Visible in both ManualCustomerEntrySheet and DockCartContent

**Fix Required:**
Add loyalty points badge similar to iOS implementation

---

### 🟡 ISSUE 3: Sidebar Queue Entries Missing Loyalty Points
**Location:** `SwagManager/Views/Editor/Sidebar/SidebarQueuesSection.swift:166-232`
**Severity:** MEDIUM
**Impact:** Sidebar queue entries don't show loyalty points (inconsistent with iOS)

**Current Code (QueueEntryRow):**
```swift
HStack(spacing: 6) {
    // Shows customer name, cart items, cart total
    Text(customerName)
        .font(.system(size: 10))
        .lineLimit(1)
    // ❌ MISSING: Loyalty points badge
}
```

**iOS Behavior:**
- Cart dock shows customer pill with loyalty points badge
- Visible in real-time as points update

**Fix Required:**
1. Fetch customer data for queue entries (if available)
2. Display loyalty points badge next to customer name
3. Match iOS styling (compact badge with star icon)

---

## 📊 SUMMARY

### Backend Architecture
✅ **PERFECT** - All business logic is server-side
- No local price calculations
- No local inventory logic
- Single source of truth in edge functions
- 100% aligned with iOS backend pattern

### Critical Gaps
🔴 **1 CRITICAL BUG** - ProductSelectorSheet inventory_id query
🟡 **2 UI INCONSISTENCIES** - Missing loyalty points in queue views

### Overall Alignment
- **Edge Functions:** 100% aligned ✅
- **Business Logic:** 100% server-side ✅
- **Inventory Tracking:** 50% aligned ⚠️ (CartPanel ✅, ProductSelectorSheet ❌)
- **Customer UI:** 67% aligned ⚠️ (Detail view ✅, Queue views ❌)

---

## 🎯 RECOMMENDED FIXES (Priority Order)

### Priority 1 - CRITICAL
**Fix ProductSelectorSheet inventory_id query**
- Copy pattern from CartPanel.swift:376-406
- Ensure inventory_id is queried and passed to CartService
- Test with order to verify inventory deduction

### Priority 2 - HIGH
**Add loyalty points to LocationQueueView**
- Fetch customer loyalty points when loading queue
- Add badge to QueueEntryRow
- Match iOS badge design (star icon + points count)

### Priority 3 - MEDIUM
**Add loyalty points to SidebarQueuesSection**
- Fetch customer data in QueueEntryRow
- Display compact loyalty badge
- Consider space constraints in sidebar

---

## ✅ VERIFICATION CHECKLIST

After fixes, verify:
- [ ] ProductSelectorSheet queries inventory_id before adding to cart
- [ ] Test order from ProductSelectorSheet deducts inventory correctly
- [ ] Test order from CartPanel deducts inventory correctly (should already work)
- [ ] LocationQueueView shows customer loyalty points
- [ ] SidebarQueuesSection shows customer loyalty points (if space allows)
- [ ] Loyalty points update in real-time when orders complete
- [ ] End-to-end macOS order flow matches iOS behavior exactly

---

**Report Generated:** 2026-01-22
**macOS Build:** SwagManager (latest)
**iOS Reference:** Whale POS (production)
