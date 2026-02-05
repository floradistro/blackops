# CRITICAL BUG FIX: Order Items Not Being Created

## Problem Discovered

Checked the most recent orders and found **CRITICAL BUG**:

### Order: WH-1769110920255-402 (macOS)
- ✅ Order created with location_id
- ✅ Loyalty points awarded (26 points)
- ❌ **ZERO order_items created**
- ❌ **ZERO inventory transactions**

### Order: WH-1769110975345-300 (iOS)
- ✅ Order created with location_id
- ✅ Loyalty points awarded (21 points)
- ❌ **ZERO order_items created**
- ❌ **ZERO inventory transactions**

**Both orders completed successfully but have NO items!**

---

## Root Cause

### Bug in payment-intent Edge Function (v51)

**File**: `supabase/functions/payment-intent/index.ts` lines 573-597

The Edge Function was trying to insert a **column that doesn't exist**:

```typescript
const orderItems = intent.cart_items.map((item: CartItem) => ({
  order_id: order.id,
  store_id: intent.store_id,
  product_id: item.productId,
  product_name: item.productName,
  product_sku: item.productSku,
  quantity: item.quantity,
  tier_qty: item.tierQty,            // ✅ Exists in table
  tier_name: item.tierName,
  unit_price: item.unitPrice,
  line_subtotal: item.lineTotal,
  line_total: item.lineTotal,
  location_id: item.locationId || intent.location_id,
  inventory_id: item.inventoryId,
  tier_quantity: item.tierQuantity,  // ❌ DOESN'T EXIST!
}));

const { error: itemsError } = await supabase
  .from("order_items")
  .insert(orderItems);

if (itemsError) {
  console.error("Failed to insert order items:", itemsError);
  // Don't fail the whole order for items error  // ❌ SILENTLY SWALLOWING ERROR!
}
```

### Issues:

1. **Wrong column name**: `tier_quantity` doesn't exist in order_items table (the column is `tier_qty`)
2. **Silent failure**: Error was logged but NOT thrown, so order completed without items
3. **Missing quantity_grams**: Wasn't being set at all

---

## Database Schema

**order_items table has these columns:**
- ✅ `tier_qty` (NUMERIC) - the tier quantity value
- ✅ `quantity_grams` (NUMERIC) - for gram-based measurements
- ❌ NO `tier_quantity` column

---

## Fix Applied (v52)

### 1. Removed non-existent column

```typescript
// ❌ BEFORE:
tier_qty: item.tierQty,
tier_quantity: item.tierQuantity,  // doesn't exist!

// ✅ AFTER:
tier_qty: item.tierQty || item.tierQuantity || 1,
quantity_grams: item.tierQty || item.tierQuantity || 1,
```

### 2. Made error handling fail-fast

```typescript
// ❌ BEFORE:
if (itemsError) {
  console.error("Failed to insert order items:", itemsError);
  // Don't fail the whole order for items error
}

// ✅ AFTER:
if (itemsError) {
  console.error("❌ CRITICAL: Failed to insert order items:", itemsError);
  console.error("Order items data:", JSON.stringify(orderItems, null, 2));
  // This is critical - order without items is invalid
  throw new Error(`Failed to create order items: ${itemsError.message}`);
}

console.log(`✅ Successfully created ${orderItems.length} order items`);
```

### 3. Fallback values for tier quantity

```typescript
tier_qty: item.tierQty || item.tierQuantity || 1
```

This handles both field names (`tierQty` from macOS, `tierQuantity` from iOS) and falls back to 1 if neither is present.

---

## Deployment

**Deployed**: payment-intent v52
**Project**: uaednwpxursknmwdeejn
**Time**: 2026-01-22 14:46

---

## Impact

### Before Fix:
- Orders were created successfully
- Loyalty points were awarded ✅
- But **NO order items** were created ❌
- Customer paid but order has no record of what they bought ❌
- Inventory was never deducted ❌

### After Fix:
- Orders will be created with items ✅
- Loyalty points awarded ✅
- Inventory deducted ✅
- Order items have proper tier_qty and quantity_grams ✅
- If order_items insert fails, the entire transaction will fail ✅

---

## Testing Required

### Next Test Sale:

1. Make a sale on **either app**
2. Verify in database:

```sql
-- Get most recent order
SELECT * FROM orders ORDER BY created_at DESC LIMIT 1;

-- Check order_items (should have rows now!)
SELECT
    product_name,
    quantity,
    tier_qty,
    tier_name,
    quantity_grams,
    inventory_id
FROM order_items
WHERE order_id = 'ORDER_ID_HERE';

-- Check loyalty
SELECT * FROM loyalty_transactions WHERE reference_id = 'ORDER_ID_HERE';

-- Check inventory
SELECT * FROM inventory_transactions WHERE reference_id = 'ORDER_ID_HERE';
```

### Expected Results:

```
order_items:
✅ Should have 1+ rows (not 0!)
✅ tier_qty populated (1, 3.5, 7.0, etc.)
✅ tier_name populated ("1 Can", "4-Pack", "3.5g (Eighth)")
✅ quantity_grams populated (same as tier_qty)
✅ inventory_id populated (UUID)

loyalty_transactions:
✅ Points awarded (~1 per $1)

inventory_transactions:
✅ Inventory deducted by tier_qty amount
```

---

## Summary

**This was a CRITICAL bug** that made orders appear successful but:
- No record of what items were sold
- No inventory deduction
- Customer paid but cart items not saved

The bug was caused by:
1. Trying to insert to a non-existent column (`tier_quantity`)
2. Silently catching the error instead of failing
3. Order completing even though items weren't saved

**Fix deployed in v52** which:
1. Uses correct column name (`tier_qty`)
2. Adds `quantity_grams` for inventory deduction
3. Fails the entire transaction if order_items can't be created
4. Handles both `tierQty` and `tierQuantity` field names

---

## Critical Orders with No Items

These orders completed but have NO items:

1. WH-1769110920255-402 ($26.68) - macOS POS
2. WH-1769110975345-300 ($21.44) - iOS POS

Customer was charged but no record of items purchased. This needs manual reconciliation.
