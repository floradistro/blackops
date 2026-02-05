# 🔍 Debug Realtime Sync Issue

## What to Check:

### On iPad - Check Console Logs:
Look for these messages when you add/remove/add Fahad:

```
🛒 addCustomerToQueue: customer=Fahad Khan, locationId=..., storeId=...
Creating cart for customer B3076A6C-...
🔌 Creating realtime channel: cart-updates-46AF4E33-...
✅ Subscribed to realtime for cart 46AF4E33-...
```

**Key Question:** When you add Fahad the SECOND time (after removing), does it show the SAME cart ID `46AF4E33`?

### On Mac - Check Console Logs:
When Fahad appears in queue, look for:

```
[CartStore] loadCart called - customerId: B3076A6C-..., locationId: ...
[CartStore] 🔌 Creating realtime channel: cart-updates-46AF4E33-...
[CartStore] ✅ Subscribed to realtime for cart 46AF4E33-...
```

**Key Question:** Is the Mac subscribed to cart `46AF4E33`?

---

## 🚨 Most Likely Issue:

When you **remove** Fahad from the queue, the apps UNSUBSCRIBE from the cart's realtime channel.

When you **add** Fahad again, the apps create/get the SAME cart (46AF4E33), but:
- One device subscribes to the realtime channel
- Other device doesn't re-subscribe (because it thinks it's already subscribed, or vice versa)

---

## 🔧 The Real Fix Needed:

**Apps need to re-subscribe to cart when customer is re-added to queue.**

Currently, when you remove from queue, the apps probably do:
```swift
removeFromQueue() {
    // Delete queue entry
    // Unsubscribe from cart realtime ← PROBLEM
}
```

Then when you add again:
```swift
addToQueue() {
    // Create/get cart (reuses same cart ID)
    // Add to queue
    // Subscribe to realtime... but maybe doesn't?
}
```

---

## ✅ Quick Test:

**Instead of remove + add:**
1. Add Fahad on iPad
2. On Mac, click on Fahad in queue (opens same cart)
3. On iPad, add a product
4. Does Mac see it? **If YES, realtime works!**
5. If NO, both devices aren't subscribed to same cart

**Then test remove + add:**
1. Remove Fahad from queue on iPad
2. Add Fahad again on iPad
3. On Mac, click on Fahad in queue
4. On iPad, add a product
5. Does Mac see it? **If NO, that's the issue**

---

## 💡 Expected Behavior:

When customer is in queue, BOTH devices should show:
```
✅ Subscribed to realtime for cart 46AF4E33-6DEE-4E53-9839-6459F89FEF88
```

If one device shows a DIFFERENT cart ID, that's the problem!

---

## 🎯 What Needs to Be Fixed:

**Option 1:** Apps should NEVER unsubscribe from carts
- Keep subscriptions alive even after removing from queue
- Only unsubscribe when app closes

**Option 2:** Apps should ALWAYS re-subscribe when opening a cart
- Check if already subscribed before creating new channel
- Unsubscribe old channel, subscribe to new one

**Option 3:** Use a single realtime subscription per customer
- Subscribe to customer's carts, not individual cart IDs
- Automatically handles cart changes

---

**Next:** Share the console logs from both devices when you do add → remove → add.
