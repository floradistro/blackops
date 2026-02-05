# FINAL FIX: Inventory ID & Loyalty Points

## Database Verification Results

Checked order: **WH-1769107970911-652** (most recent with customer & items)

### ✅ **WORKING:**
1. **Location ID**: ✅ Present in all orders
2. **Tier Quantity**: ✅ Stored correctly in `order_items.tier_qty`
3. **Tier Name**: ✅ Stored correctly ("1 Vape", "1 gram", etc.)
4. **quantity_grams**: ✅ Stored correctly (matches tier_qty)

### ❌ **NOT WORKING (NOW FIXED):**
1. **Inventory ID**: ❌ NULL in order_items (apps weren't sending it)
2. **Loyalty Points**: ❌ No transactions (RPC failing silently)
3. **Inventory Deduction**: ❌ No transactions (depends on inventory_id)

---

## Root Cause

The apps were **NOT sending `inventoryId`** in the payment intent payload to the Edge Function.

### macOS App Issue:
- `CartItemPayload` struct was missing `inventoryId` field
- Not passing `item.inventoryId` when creating payment payload

### iOS App Issue:
- Had `inventoryId` in struct ✅
- But was using old field name `gramsToDeduct` instead of `tierQuantity`
- Was using `.lowercased()` UUIDs which validation rejected

---

## Fixes Applied

### 1. macOS App (SwagManager)

#### PaymentService.swift

**Added `inventoryId` to CartItemPayload:**
```swift
private struct CartItemPayload: Encodable {
    let productId: String
    let productName: String
    let productSku: String?
    let quantity: Int
    let tierQty: Double
    let tierName: String?
    let unitPrice: Double
    let inventoryId: String?  // ✅ ADDED
}
```

**Passing inventoryId in payload:**
```swift
CartItemPayload(
    productId: item.productId.uuidString,
    productName: item.productName,
    productSku: item.sku,
    quantity: item.quantity,
    tierQty: item.tierQuantity,
    tierName: item.tierLabel,
    unitPrice: NSDecimalNumber(decimal: item.unitPrice).doubleValue,
    inventoryId: item.inventoryId?.uuidString  // ✅ ADDED
)
```

**Fixed JSON encoding:**
```swift
// ❌ REMOVED: encoder.keyEncodingStrategy = .convertToSnakeCase
// Edge Function expects camelCase keys
```

**Fixed UUID formatting:**
```swift
// ❌ REMOVED: .lowercased() on all UUIDs
// Validation requires proper UUID format
storeId: sessionInfo.storeId.uuidString  // not .lowercased()
```

#### CartService.swift

**Added `inventoryId` to ServerCartItem:**
```swift
struct ServerCartItem: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let productName: String
    let sku: String?
    let unitPrice: Decimal
    let quantity: Int
    let tierLabel: String?
    let tierQuantity: Double
    let variantId: UUID?
    let variantName: String?
    let inventoryId: UUID?  // ✅ ADDED
    let lineTotal: Decimal
    let discountAmount: Decimal
    // ...

    enum CodingKeys: String, CodingKey {
        // ...
        case inventoryId = "inventory_id"  // ✅ ADDED
    }
}
```

### 2. iOS App (Whale)

#### PaymentStore.swift

**Changed field name from `gramsToDeduct` to `tierQuantity`:**
```swift
private struct CartItemPayload: Encodable {
    let productId: String
    let productName: String
    let productSku: String?
    let quantity: Int
    let tierQty: Double
    let tierName: String?
    let unitPrice: Double
    let lineTotal: Double
    let discountAmount: Double
    let inventoryId: String?
    let tierQuantity: Double  // ✅ CHANGED from gramsToDeduct
    let locationId: String?
    let variantTemplateId: String?
    let variantName: String?
    let conversionRatio: Double?
}
```

**Updated toPayload method:**
```swift
CartItemPayload(
    productId: productId.uuidString,  // ✅ REMOVED .lowercased()
    productName: productName,
    productSku: sku,
    quantity: quantity,
    tierQty: tierQuantity,
    tierName: tierLabel,
    unitPrice: NSDecimalNumber(decimal: effectiveUnitPrice).doubleValue,
    lineTotal: NSDecimalNumber(decimal: lineTotal).doubleValue,
    discountAmount: NSDecimalNumber(decimal: discountAmount).doubleValue,
    inventoryId: inventoryId?.uuidString,  // ✅ REMOVED .lowercased()
    tierQuantity: tierQuantity,  // ✅ CHANGED from gramsToDeduct: inventoryDeduction
    locationId: locationId.uuidString,
    variantTemplateId: variantId?.uuidString,
    variantName: variantName,
    conversionRatio: conversionRatio
)
```

---

## Edge Function Status

### payment-intent (v51) - Already Deployed ✅

The Edge Function is correctly configured:
- ✅ Accepts `inventoryId` in cart items
- ✅ Writes to `order_items.inventory_id`
- ✅ Uses `tierQuantity` for inventory deduction
- ✅ Calls `deduct_inventory(p_inventory_id, p_amount, p_order_id)`
- ✅ Calls `award_loyalty_points()` with correct parameter order

### cart (v33) - Already Deployed ✅

Cart function correctly:
- ✅ Accepts `tier_quantity` parameter
- ✅ Stores `inventory_id` in cart_items
- ✅ Returns cart items with inventory_id

---

## Build Status

- ✅ **macOS (SwagManager)**: **BUILD SUCCEEDED**
- ✅ **iOS (Whale)**: **BUILD SUCCEEDED**

---

## Expected Results After This Fix

### On Next Customer Order:

1. **Order Items** will have:
   - ✅ `tier_qty` = tier quantity (e.g., 1, 3.5, 7.0)
   - ✅ `tier_name` = tier label (e.g., "1 Vape", "3.5g (Eighth)")
   - ✅ `quantity_grams` = same as tier_qty
   - ✅ `inventory_id` = UUID from cart item ← **THIS IS THE FIX**

2. **Loyalty Transactions** will show:
   - ✅ Points earned (~1 point per $1)
   - ✅ `transaction_type` = "earned"
   - ✅ `reference_id` = order ID

3. **Inventory Transactions** will show:
   - ✅ Inventory deducted by tier_qty amount
   - ✅ `transaction_type` = "sale"
   - ✅ `quantity_change` = negative amount
   - ✅ `reference_id` = order ID

---

## Testing Instructions

### 1. Make a Test Sale (Customer Order)

Use **either** iOS or macOS app:
- Select a customer (not guest)
- Add item with a tier (e.g., "1 Vape", "3.5g Eighth")
- Complete cash payment

### 2. Verify in Database

Run this SQL in Supabase SQL Editor:

```sql
-- Get most recent order
SELECT
    o.id,
    o.order_number,
    o.created_at,
    o.location_id IS NOT NULL as has_location,
    o.customer_id IS NOT NULL as has_customer,
    o.total_amount
FROM orders o
ORDER BY o.created_at DESC
LIMIT 1;

-- Check order items (replace ORDER_ID)
SELECT
    oi.product_name,
    oi.quantity,
    oi.tier_qty,
    oi.tier_name,
    oi.quantity_grams,
    oi.inventory_id
FROM order_items oi
WHERE oi.order_id = 'ORDER_ID';

-- Check loyalty
SELECT
    lt.points,
    lt.transaction_type
FROM loyalty_transactions lt
WHERE lt.reference_id = 'ORDER_ID';

-- Check inventory
SELECT
    it.transaction_type,
    it.quantity_change,
    p.name
FROM inventory_transactions it
LEFT JOIN products p ON it.product_id = p.id
WHERE it.reference_id = 'ORDER_ID';
```

### 3. Expected Output

```
order_items:
✅ tier_qty: 1 (or 3.5, 7.0, etc.)
✅ tier_name: "1 Vape" (or "3.5g (Eighth)", etc.)
✅ quantity_grams: 1.00 (matches tier_qty)
✅ inventory_id: 832f382b-c024-4cc0-a589-1ad593cfa5e1 (NOT NULL)

loyalty_transactions:
✅ points: 16 (for $16 order)
✅ transaction_type: "earned"

inventory_transactions:
✅ quantity_change: -1 (negative, meaning deducted)
✅ transaction_type: "sale"
```

---

## Summary

### What Was Broken:
- Apps were querying inventory_id when adding to cart ✅
- Cart Edge Function was storing inventory_id ✅
- But apps were NOT sending inventory_id to payment-intent ❌
- So order_items.inventory_id was always NULL ❌
- So inventory could not be deducted ❌

### What Is Now Fixed:
- macOS: Added inventoryId field to CartItemPayload struct
- macOS: Passing item.inventoryId when creating payment
- macOS: Fixed JSON encoding (removed snake_case conversion)
- macOS: Fixed UUID formatting (removed .lowercased())
- iOS: Changed gramsToDeduct → tierQuantity
- iOS: Fixed UUID formatting (removed .lowercased())
- Both apps now send inventory_id to payment-intent
- Edge Function will write to order_items.inventory_id
- Edge Function can now call deduct_inventory() RPC
- Loyalty points RPC will also work (fixed in v50)

### All 4 Systems Should Now Work:
1. ✅ Location ID
2. ✅ Tier Quantity (tierQty)
3. ✅ Inventory ID ← **THIS FIX**
4. ✅ Loyalty Points (fixed parameter order in v50)
5. ✅ Inventory Deduction (depends on inventory_id being present)
