# 🐛 CRITICAL BUG: Loyalty Points Not Being Awarded Automatically

## Problem

**Loyalty points are NOT being awarded automatically** when orders are completed. The `payment-intent` edge function is not calling the `award_loyalty_points` RPC.

## Evidence

### Timeline
- **3:19 PM**: Order WH-1769113195960-755 → ✅ Points awarded (16 points)
- **3:45 PM**: Created store_customer_profiles record for Fahad Khan
- **3:47 PM**: Order WH-1769114868757-387 → ❌ NO points awarded
- **3:48 PM**: Order WH-1769114883612-139 → ❌ NO points awarded

### Orders Missing Loyalty Points
| Order | Time | Amount | Customer | Status |
|-------|------|--------|----------|--------|
| WH-1769114868757-387 | 3:47:48 PM | $16 | Fahad Khan | ❌ NO loyalty transaction |
| WH-1769114883612-139 | 3:48:03 PM | $16 | Fahad Khan | ❌ NO loyalty transaction (manually fixed) |

## Root Cause Analysis

### What We Know

1. **RPC Function Works**: Manually calling `award_loyalty_points` RPC successfully creates loyalty transactions
2. **No Duplicate Prevention**: The RPC doesn't check for existing transactions, allowing duplicates
3. **Edge Function Not Calling RPC**: The `payment-intent` edge function is not calling `award_loyalty_points` for new orders

### Possible Causes

1. **Edge Function Code Issue**:
   - Missing `await` on the RPC call (failing silently)
   - Try/catch block swallowing errors
   - Conditional logic skipping the loyalty award step

2. **Timing Issue**:
   - Creating `store_customer_profiles` record triggered a change in behavior
   - Edge function may check if profile exists before awarding points

3. **Deployment Issue**:
   - Latest edge function version (v53) may not have been deployed correctly
   - Code rollback or cache issue

## Manual Fixes Applied

### Order 1: WH-1769114883612-139
- Manually created loyalty transaction: +16 points
- **Issue**: Called RPC multiple times during testing, created 3 total transactions
- **Fix**: Deleted 2 duplicate transactions, kept 1

### Order 2: WH-1769114868757-387
- Manually created loyalty transaction: +16 points
- Balance updated: 1781 → 1797

### Fahad Khan Final Balance
**1,797 loyalty points** ✅

---

## Permanent Fix Required

### 1. Check Edge Function Code

Location: `supabase/functions/payment-intent/index.ts`

**Look for this code block** (around the order creation):

```typescript
// Award loyalty points for customer orders
if (intent.customer_id) {
  await supabase.rpc("award_loyalty_points", {
    p_customer_id: intent.customer_id,
    p_order_id: order.id,
    p_order_total: intent.totals.total,
    p_store_id: intent.store_id,
  });
}
```

**Check for issues**:
- [ ] Is this code block present?
- [ ] Is it wrapped in try/catch that's swallowing errors?
- [ ] Is there a conditional that might skip it?
- [ ] Is the `await` keyword present?

### 2. Add Duplicate Prevention to RPC

The `award_loyalty_points` RPC function should check if a transaction already exists:

```sql
CREATE OR REPLACE FUNCTION award_loyalty_points(
  p_customer_id UUID,
  p_order_id UUID,
  p_order_total NUMERIC,
  p_store_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_points INT;
  v_current_balance INT;
  v_new_balance INT;
BEGIN
  -- Check if points already awarded for this order
  IF EXISTS (
    SELECT 1 FROM loyalty_transactions
    WHERE reference_id = p_order_id
    AND customer_id = p_customer_id
    AND transaction_type = 'earned'
  ) THEN
    RETURN; -- Already awarded, skip
  END IF;

  -- Calculate points (1 point per dollar)
  v_points := FLOOR(p_order_total);

  IF v_points <= 0 THEN
    RETURN;
  END IF;

  -- Get current balance
  SELECT COALESCE(loyalty_points, 0) INTO v_current_balance
  FROM store_customer_profiles
  WHERE relationship_id = p_customer_id;

  v_new_balance := v_current_balance + v_points;

  -- Create transaction
  INSERT INTO loyalty_transactions (
    customer_id,
    transaction_type,
    points,
    reference_type,
    reference_id,
    description,
    balance_before,
    balance_after
  ) VALUES (
    p_customer_id,
    'earned',
    v_points,
    'order',
    p_order_id,
    'Earned ' || v_points || ' points from order',
    v_current_balance,
    v_new_balance
  );

  -- Update balance
  INSERT INTO store_customer_profiles (relationship_id, loyalty_points)
  VALUES (p_customer_id, v_new_balance)
  ON CONFLICT (relationship_id)
  DO UPDATE SET loyalty_points = v_new_balance;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 3. Add Error Logging to Edge Function

Add comprehensive logging to see when/why loyalty points fail:

```typescript
// Award loyalty points for customer orders
if (intent.customer_id) {
  try {
    console.log(`Awarding loyalty points for order ${order.id}, customer ${intent.customer_id}`);

    const { data, error } = await supabase.rpc("award_loyalty_points", {
      p_customer_id: intent.customer_id,
      p_order_id: order.id,
      p_order_total: intent.totals.total,
      p_store_id: intent.store_id,
    });

    if (error) {
      console.error(`Failed to award loyalty points: ${error.message}`);
      // Don't throw - loyalty failure shouldn't break order creation
    } else {
      console.log(`Successfully awarded loyalty points`);
    }
  } catch (err) {
    console.error(`Exception awarding loyalty points: ${err.message}`);
    // Don't throw - loyalty failure shouldn't break order creation
  }
}
```

### 4. Deploy and Test

```bash
# Deploy edge function
supabase functions deploy payment-intent

# Test with a small order
# Verify loyalty transaction is created
# Check Supabase logs for any errors
```

---

## Testing Checklist

After fixing the edge function:

- [ ] Create a test order with a customer account
- [ ] Verify loyalty transaction is created in `loyalty_transactions` table
- [ ] Verify balance is updated in `store_customer_profiles`
- [ ] Check Supabase edge function logs for any errors
- [ ] Verify no duplicate transactions are created if RPC is called twice
- [ ] Test with $0 orders (should skip loyalty)
- [ ] Test with guest orders (no customer_id, should skip loyalty)

---

## Impact

**All orders created after 3:45 PM on 2026-01-22 are missing loyalty points**.

This affects:
- Customer satisfaction (not earning expected rewards)
- Loyalty program integrity
- Business metrics

**Priority**: 🔴 **CRITICAL** - Fix immediately

---

## Workaround Until Fixed

For any orders missing loyalty points, run this script:

```javascript
// award_missing_points.js
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'YOUR_SUPABASE_URL';
const serviceRoleKey = 'YOUR_SERVICE_ROLE_KEY';
const supabase = createClient(supabaseUrl, serviceRoleKey);

async function awardMissingPoints() {
  // Find orders without loyalty transactions
  const { data: orders } = await supabase
    .from('orders')
    .select('id, customer_id, total_amount, created_at')
    .not('customer_id', 'is', null)
    .gte('created_at', '2026-01-22T15:45:00')
    .order('created_at', { ascending: true });

  for (const order of orders) {
    // Check if transaction exists
    const { data: existing } = await supabase
      .from('loyalty_transactions')
      .select('id')
      .eq('reference_id', order.id)
      .eq('transaction_type', 'earned');

    if (!existing || existing.length === 0) {
      console.log(`Missing: ${order.id} ($${order.total_amount})`);

      // Award points manually
      await supabase.rpc('award_loyalty_points', {
        p_customer_id: order.customer_id,
        p_order_id: order.id,
        p_order_total: parseFloat(order.total_amount),
        p_store_id: 'cd2e1122-d511-4edb-be5d-98ef274b4baf'
      });
    }
  }
}

awardMissingPoints();
```

---

## Summary

**Problem**: Edge function not calling `award_loyalty_points` RPC
**Impact**: Customers not earning loyalty points on orders
**Fix Required**: Check/fix edge function code, add duplicate prevention, add logging
**Priority**: CRITICAL

**Manual fixes applied for Fahad Khan**:
- ✅ Order WH-1769114868757-387: +16 points
- ✅ Order WH-1769114883612-139: +16 points (removed 2 duplicates)
- ✅ Current balance: 1,797 points
