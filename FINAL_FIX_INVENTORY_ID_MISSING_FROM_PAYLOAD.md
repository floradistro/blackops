# FINAL FIX: Inventory ID Missing From Payment Payload

## Issue Discovered

After deploying payment-intent v52 (which fixed order_items creation), verified order WH-1769111269385-699:

**✅ WORKING:**
- Order items created (1 row) ← v52 fix worked!
- tier_qty: 1 ✅
- tier_name: "1 Vape" ✅
- quantity_grams: 1.00 ✅
- Loyalty points: 21 points ✅

**❌ NOT WORKING:**
- inventory_id: NULL in order_items
- Inventory transactions: 0 rows (can't deduct without inventory_id)

## Root Cause Analysis

Traced the flow:

1. ✅ Cart database has inventory_id (verified in cart_items table)
2. ✅ Cart Edge Function returns inventory_id (selects `cart_items(*)`)
3. ❌ **iOS CartItem initializer hardcodes `inventoryId = nil`**
4. ❌ Payment payload has `inventoryId = null`
5. ❌ order_items.inventory_id = NULL

### The Bug

**File**: `/Users/whale/Desktop/swiftwhale/Whale/Stores/POSStore.swift` line 596

```swift
/// Create from server cart item
init(from server: ServerCartItem) {
    self.id = server.id
    self.productId = server.productId
    self.productName = server.productName
    self.unitPrice = server.unitPrice
    self.quantity = server.quantity
    self.tierQuantity = server.tierQuantity
    self.sku = server.sku
    self.tierLabel = server.tierLabel
    self.inventoryId = nil  // ❌ BUG: Not in server response
    self.variantId = server.variantId
    // ...
}
```

The comment said "Not in server response" but this was wrong:
- The cart Edge Function WAS returning inventory_id
- ServerCartItem struct was MISSING the field
- So the initializer couldn't access it

## Fix Applied

### 1. iOS CartService.swift - Added inventoryId to ServerCartItem

**File**: `/Users/whale/Desktop/swiftwhale/Whale/Services/CartService.swift`

Added field after line 56:
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
    let manualDiscountType: String?
    let manualDiscountValue: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case productName = "product_name"
        case sku
        case unitPrice = "unit_price"
        case quantity
        case tierLabel = "tier_label"
        case tierQuantity = "tier_quantity"
        case variantId = "variant_id"
        case variantName = "variant_name"
        case inventoryId = "inventory_id"  // ✅ ADDED
        case lineTotal = "line_total"
        case discountAmount = "discount_amount"
        case manualDiscountType = "manual_discount_type"
        case manualDiscountValue = "manual_discount_value"
    }
}
```

### 2. iOS POSStore.swift - Use server.inventoryId

**File**: `/Users/whale/Desktop/swiftwhale/Whale/Stores/POSStore.swift` line 596

```swift
// BEFORE:
self.inventoryId = nil  // Not in server response

// AFTER:
self.inventoryId = server.inventoryId
```

## Build Status

- ✅ **iOS (Whale)**: BUILD SUCCEEDED
- ✅ **macOS (SwagManager)**: BUILD SUCCEEDED (already had inventoryId field)

## Expected Results

On next customer order from iOS or macOS:

### Order Items:
```
✅ tier_qty: 1 (or 3.5, 7.0, etc.)
✅ tier_name: "1 Vape" (or "3.5g (Eighth)", etc.)
✅ quantity_grams: 1.00 (matches tier_qty)
✅ inventory_id: UUID (NOT NULL) ← THIS FIX
```

### Loyalty Transactions:
```
✅ points: ~1 point per $1
✅ transaction_type: "earned"
✅ reference_id: order ID
```

### Inventory Transactions:
```
✅ transaction_type: "sale"
✅ quantity_change: negative (deducted)
✅ reference_id: order ID
✅ inventory_id: UUID
```

## Complete Fix Chain

This completes the fix chain:

1. **v50**: Fixed loyalty points RPC parameter order ✅
2. **v51**: Changed `gramsToDeduct` to `tierQuantity` ✅
3. **v52**: Fixed order_items creation (removed non-existent `tier_quantity` column) ✅
4. **iOS Cart Fix**: Added inventory_id query when adding to cart ✅
5. **macOS Cart Fix**: Added inventory_id query when adding to cart ✅
6. **iOS Payload Fix**: THIS FIX - ServerCartItem now decodes inventory_id ✅

## All 5 Systems Should Now Work

1. ✅ Location ID (working since start)
2. ✅ Tier Quantity (fixed in v51)
3. ✅ Order Items Creation (fixed in v52)
4. ✅ Loyalty Points (fixed in v50)
5. ✅ Inventory Deduction (THIS FIX - now has inventory_id)

## Testing

Next test order will verify:
- Order created
- Order items with inventory_id populated
- Loyalty points awarded
- Inventory deducted

Run verification SQL:
```sql
-- Get most recent order
SELECT * FROM orders ORDER BY created_at DESC LIMIT 1;

-- Check order_items (should have inventory_id now!)
SELECT
    product_name,
    tier_qty,
    quantity_grams,
    inventory_id IS NOT NULL as has_inventory_id
FROM order_items
WHERE order_id = 'ORDER_ID';

-- Check loyalty
SELECT * FROM loyalty_transactions WHERE reference_id = 'ORDER_ID';

-- Check inventory
SELECT * FROM inventory_transactions WHERE reference_id = 'ORDER_ID';
```

Expected:
- order_items: has_inventory_id = true ✅
- loyalty_transactions: 1 row ✅
- inventory_transactions: 1+ rows ✅

## Summary

The iOS app was hardcoding `inventoryId = nil` in CartItem initializer because ServerCartItem struct was missing the field. Now:
- ServerCartItem decodes inventory_id from cart API response
- CartItem gets the actual inventory_id value
- Payment payload includes inventory_id
- order_items will have inventory_id populated
- Inventory deduction will work

**All 5 critical systems should now be fully operational.**
