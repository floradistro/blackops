# CRITICAL FIX: Tier Quantity (NOT just grams!)

## The Problem

I made a **terrible assumption** that tier quantities are always measured in grams. This is completely wrong!

Pricing tiers can use **ANY unit of measurement**:
- Grams (Eighth = 3.5g, Quarter = 7.0g)
- Cans (1 Can = 1 unit)
- Bottles (1 Bottle = 1 unit)
- Ounces (12 oz = 12 units)
- Any other measurement system

## What I Fixed

### ❌ Before (WRONG):
- Column name: `quantity_grams` (assumes everything is grams)
- Parameter name: `gramsToDeduct` (assumes everything is grams)
- Apps sent: `body["quantity_grams"] = tierQuantity`

### ✅ After (CORRECT):
- Column name: `tier_quantity` (generic, already existed!)
- Parameter name: `tierQuantity` (generic)
- Apps send: `body["tier_quantity"] = tierQuantity`

## Files Changed

### 1. Cart Edge Function (needs deployment)
**File**: `supabase/functions/cart/index.ts`
- ❌ Removed: `quantity_grams` parameter
- ✅ Using: `tier_quantity` (which already exists in cart_items table)
- **Version**: v33

### 2. Payment-Intent Edge Function (needs deployment)
**File**: `supabase/functions/payment-intent/index.ts`
- ❌ Removed: `gramsToDeduct` field name
- ✅ Using: `tierQuantity` field name
- ✅ Writes to: `order_items.tier_quantity` (not quantity_grams)
- ✅ Calls deduct_inventory with: `p_amount: item.tierQuantity`
- **Version**: v51

### 3. iOS App (BUILT ✅)
**File**: `Whale/Services/CartService.swift`
- ❌ Removed: `body["quantity_grams"] = tierQuantity`
- ✅ Kept: `body["tier_quantity"] = tierQuantity`

### 4. macOS App (BUILT ✅)
**File**: `SwagManager/Services/CartService.swift`
- ❌ Removed: `payload["quantity_grams"] = tierQuantity`
- ✅ Kept: `payload["tier_quantity"] = tierQuantity`

---

## REQUIRED: Deploy Edge Functions

You need to deploy both Edge Functions:

```bash
cd /Users/whale/Desktop/blackops
chmod +x deploy-fixes.sh
./deploy-fixes.sh
```

Or manually:
```bash
supabase functions deploy cart --project-ref seosfnfujvqaezowekpc
supabase functions deploy payment-intent --project-ref seosfnfujvqaezowekpc
```

---

## Why This Matters

The `tier_quantity` field is **measurement-agnostic**:
- For flower products: tier_quantity = grams (3.5, 7.0, 14.0, 28.0)
- For beverages: tier_quantity = cans/bottles (1, 6, 12, 24)
- For concentrates: tier_quantity = weight in grams
- For edibles: tier_quantity = pieces (10, 20, 100)

The inventory system and deduct_inventory() RPC should handle the correct unit based on the product/tier configuration, NOT assume everything is grams.

---

## Database Schema

### cart_items table:
- ✅ `tier_quantity` - Generic measurement value (already exists)
- ✅ `tier_label` - Human-readable tier name ("Eighth", "1 Can", etc.)
- ❌ NO `quantity_grams` column needed

### order_items table:
- ✅ `tier_quantity` - Generic measurement value (should exist)
- ✅ `tier_label` - Human-readable tier name
- ❌ NO `quantity_grams` column needed (or should be removed if exists)

---

## Build Status

- ✅ iOS (Whale): **BUILD SUCCEEDED**
- ✅ macOS (SwagManager): **BUILD SUCCEEDED**
- 🟡 Edge Functions: **NEEDS DEPLOYMENT** (you need to deploy them)

---

## After Deployment

Test adding items to cart:
1. iOS app should NO LONGER get HTTP 500 error
2. macOS app should NO LONGER get HTTP 500 error
3. Cart items should have `tier_quantity` populated
4. Orders should have `tier_quantity` in order_items

---

## My Apology

I apologize for making this assumption about grams. This was a fundamental misunderstanding of your pricing tier system. The system is correctly designed to be measurement-agnostic, and I incorrectly tried to force everything into grams.

The fix uses the existing `tier_quantity` field which works for ALL measurement types.
