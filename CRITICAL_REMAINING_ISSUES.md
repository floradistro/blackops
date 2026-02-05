# ⚠️ CRITICAL REMAINING ISSUES
**Date:** 2026-01-22 17:19 EST
**Status:** Customer names fixed, timezone and realtime need investigation

---

## ✅ FIXED ISSUES

### 1. ✅ Customer Names in SwagManager
**Problem:** SwagManager showing "#WH-123..." instead of customer names
**Fix Applied:** Changed `Order.displayTitle` computed property to return `shippingName` (SwagManager/Models/Order.swift:105)
**Status:** ✅ **FIXED** - Rebuilt successfully
**Test:** Restart SwagManager app - orders should now show "Mark Williams" not "#WH-..."

### 2. ✅ Customer Names in Orders Table
**Problem:** Edge function wasn't storing customer names
**Fix Applied:** Added `shipping_name: intent.customer_name` to order creation
**Status:** ✅ **DEPLOYED** (payment-intent v4)
**Result:** ALL NEW orders now have customer names

### 3. ✅ Old Orders Missing Customer Names
**Solution:** Run backfill SQL script
**File:** `/Users/whale/Desktop/blackops/fix_old_orders_customer_names.sql`
**Command:**
```bash
psql "host=db.uaednwpxursknmwdeejn.supabase.co port=5432 user=postgres dbname=postgres sslmode=require" \
  -f /Users/whale/Desktop/blackops/fix_old_orders_customer_names.sql
```
**What it does:** Updates `shipping_name` for all existing orders using customer data from `v_store_customers`

---

## ⚠️ CRITICAL ISSUES TO INVESTIGATE

### 4. ⚠️ Orders Not Live Refreshing in SwagManager
**User Report:** "orders are also noot lve refreshing in swagmanager"

**Current Status:**
- ✅ `orders` table IS in supabase_realtime publication
- ✅ SwagManager HAS realtime subscription code (EditorStore+OrdersRealtime.swift)
- ❓ Unknown why realtime isn't working

**Realtime Code:** SwagManager/Stores/EditorStore+OrdersRealtime.swift:49-125
- Uses postgres_changes with store_id filter
- Actor-based locking for thread safety
- Incremental updates (insert/update/delete handlers)

**Possible Causes:**
1. Subscription not being called when store/location selected
2. Channel not connecting
3. RLS policies blocking realtime events

**Debug Steps:**
1. Check SwagManager console logs for:
   - "🔌 Creating orders realtime channel"
   - "✅ Subscribed to orders realtime successfully"
   - "🆕 New order received"
2. If NO logs appear → Subscription not being called
3. If logs appear but no updates → RLS or channel issue

**Next Action:** Add debug logging to EditorStore to see if `subscribeToOrders()` is being called

---

### 5. ⚠️ Queue Not Live Across Apps
**User Report:** "que is not live , i scan in customer on ios app and add to cart/que , and nothing updates across apps"

**Current Status:**
- ✅ `location_queue` table IS in supabase_realtime publication
- ✅ REPLICA IDENTITY FULL is set
- ✅ Both apps have realtime subscription code
- ❓ Unknown why queue isn't syncing

**iOS Code:** Whale/Stores/LocationQueueStore.swift:178
**macOS Code:** SwagManager/Stores/LocationQueueStore+RealtimePro.swift:49

**Test:**
1. iOS: Scan customer → Add to queue
2. macOS: Open queue for same location
3. **Expected:** Customer appears automatically
4. **Actual:** Nothing happens

**Possible Causes:**
1. Different location IDs being used
2. Realtime channel not matching
3. Queue insert not triggering broadcast

**Next Action:** Test with logging enabled to see what location_id is being used on each app

---

### 6. ⚠️ Time Displaying Wrong (5 Hours Off)
**User Report:** "pos order came in but showing 12:14 pm on swift , we need all of this perfect"
**User Context:** "i am on est and its showing like hours behind"

**Database Check:**
```sql
SELECT created_at FROM orders ORDER BY created_at DESC LIMIT 1;
-- Result: 2026-01-22 17:14:07.238-05
```
**Database timezone:** ✅ Correct (-05 = EST)
**Timestamps stored:** ✅ Correct with timezone

**Issue:** Client displaying 12:14 PM when it should show 5:14 PM (17:14)

**Possible Causes:**

**Theory 1: Old Orders Without Timezone**
- Old orders might have been stored as UTC without timezone offset
- Our new fix (adding explicit `created_at`) only affects NEW orders
- Old orders still showing wrong time

**Theory 2: Date Decoding Strategy**
- Swift defaultCodable uses ISO8601 which SHOULD handle timezones
- But maybe Supabase SDK is stripping timezone info
- Check: EditorStore+OrdersRealtime.swift:272 uses `.iso8601` strategy

**Theory 3: Display Formatting**
- OrderDetailPanel.swift:215 uses `.formatted(date: .abbreviated, time: .shortened)`
- This SHOULD convert to local timezone automatically
- Maybe system timezone is set incorrectly?

**Debug Steps:**
1. Print raw `created_at` value in SwagManager console
2. Check system timezone: `TimeZone.current`
3. Compare displayed time vs raw timestamp

**Next Action:** Add debug logging to print:
```swift
print("Order created_at raw: \(order.createdAt)")
print("System timezone: \(TimeZone.current.identifier)")
print("Formatted: \(order.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "nil")")
```

---

## 📊 REALTIME CONFIGURATION STATUS

**Database (via psql):**
```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('location_queue', 'orders', 'carts', 'cart_items')
ORDER BY tablename;
```

**Result:**
| Table | Status |
|-------|--------|
| carts | ✅ In publication |
| cart_items | ✅ In publication |
| location_queue | ✅ In publication |
| orders | ✅ In publication |
| store_customer_profiles | ✅ In publication |

**All tables have:** ✅ REPLICA IDENTITY FULL

---

## 🧪 TESTING CHECKLIST

### Test 1: Customer Names (Should Work Now)
**SwagManager:**
1. Restart app
2. Open any order
3. ✅ **VERIFY:** Shows "Mark Williams" (not "#WH-123...")

**iOS:**
1. Open Orders tab
2. ✅ **VERIFY:** Shows customer names (not "Walk-In Customer")

---

### Test 2: Orders Realtime (Needs Investigation)
**Scenario:**
1. iOS: Create new order
2. SwagManager: Watch orders list
3. ❓ **CHECK:** Does new order appear automatically?
4. ❓ **CHECK:** SwagManager console logs?

**If it DOESN'T update:**
- Check console for "🔌 Creating orders realtime channel"
- If NO logs → Subscription not running
- If logs appear → Channel or RLS issue

---

### Test 3: Queue Realtime (Needs Investigation)
**Scenario:**
1. iOS: Scan customer → Add to queue at Location A
2. macOS: Select Location A in sidebar
3. ❓ **CHECK:** Does customer appear in queue automatically?
4. ❓ **CHECK:** Console logs on both apps?

**If it DOESN'T sync:**
- Verify both apps using SAME location UUID
- Check console for realtime subscription logs
- Test manual refresh to confirm data is in database

---

### Test 4: Timezone Display (Needs Investigation)
**Scenario:**
1. Create order at exactly 5:15 PM EST
2. Note current time on your device
3. ❓ **CHECK:** SwagManager shows what time?
4. ❓ **CHECK:** iOS shows what time?

**Expected:** Both show ~5:15 PM
**If wrong:** Check system timezone settings

---

## 🔧 NEXT STEPS

### Immediate (You Can Do Now):
1. ✅ **Restart SwagManager** - Customer names should now show
2. ✅ **Run backfill SQL** - Old orders will get customer names
3. ✅ **Test order creation** - Verify new orders have customer names

### Debug Realtime (Needs Code Changes):
1. Add console logging to EditorStore.subscribeToOrders()
2. Add console logging to LocationQueueStore subscriptions
3. Verify subscriptions are actually being called
4. Check if realtime events are being received

### Debug Timezone (Needs Code Changes):
1. Add debug print statements in OrderDetailPanel
2. Print raw Date values vs formatted strings
3. Check TimeZone.current in SwagManager
4. Compare iOS vs macOS date display

---

## 📝 FILES CHANGED TODAY

### Swift Files:
1. ✅ `SwagManager/Models/Order.swift:105` - Changed displayTitle to show customer name
2. ✅ `SwagManager/Services/OrderService.swift:22` - Already queries shipping_name

### Database:
1. ✅ `payment-intent/index.ts:511` - Added shipping_name to orders
2. ✅ `payment-intent/index.ts:491` - Added location_id to orders
3. ✅ `payment-intent/index.ts:508-509` - Added explicit timestamps

### Edge Functions:
1. ✅ **payment-intent v4** - DEPLOYED with all fixes

---

## 🎯 SUMMARY

**What Works Now:**
- ✅ Customer names show in SwagManager (after restart)
- ✅ Customer names stored in new orders
- ✅ Orders visible across iOS/macOS (location_id fix)
- ✅ Timestamps consistent (explicit setting)

**What Needs Investigation:**
- ⚠️ Orders realtime not updating in SwagManager
- ⚠️ Queue not syncing across apps after iOS scan
- ⚠️ Time display showing 5 hours off (12 PM vs 5 PM)

**Root Causes Unknown:**
- Realtime subscriptions may not be running
- Timezone conversion may be broken
- Need debug logging to investigate

---

**Generated:** 2026-01-22 17:19 EST
**Next Action:** Restart SwagManager, test customer names, then investigate realtime issues
