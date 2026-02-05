# 🔍 Mac App Realtime Diagnostic

## What to Check Right Now:

### 1. Open Console.app on Mac

```bash
# Or run this to see live logs:
log stream --predicate 'process == "SwagManager"' --level debug
```

### 2. Look for These Log Messages:

#### ✅ GOOD - Subscription Created:
```
[LocationQueueStore] 🔌 Starting PRO realtime subscription for location...
[LocationQueueStore] Subscribing to channel with filter: location_id=eq....
[LocationQueueStore] ✅ SUBSCRIBED to PRO realtime for location...
```

```
[CartStore] 🔌 Creating realtime channel: cart-updates-...
[CartStore] Subscribing to channel...
[CartStore] ✅ Subscribed to realtime for cart...
```

#### ❌ BAD - Subscription Failed:
```
[LocationQueueStore] ❌ Subscription error: <some error>
[CartStore] ❌ Subscription error: <some error>
```

#### ⚠️ CONCERNING - No Logs At All:
If you don't see ANY of these messages, then:
- The subscription functions aren't being called
- The code isn't executing
- There's a crash happening silently

### 3. Quick Test:

1. **Force quit Mac SwagManager** (Cmd+Q)
2. **Open Console.app** (Applications → Utilities → Console)
3. **Filter for "SwagManager"** in the search box
4. **Launch SwagManager**
5. **Sign in** and select a location
6. **Watch for subscription messages**

### 4. What to Look For:

- Do you see `🔌 Starting PRO realtime subscription`?
- Do you see `✅ SUBSCRIBED`?
- Do you see any `❌` error messages?
- Do you see `🔄 Cart update received` when you add items?

### 5. Copy and Paste:

**Please copy and paste the ENTIRE console output** when you:
1. Launch the app
2. Sign in
3. Select a location
4. Try to add something to queue/cart

This will tell us exactly what's happening (or not happening).

---

## If You Don't See ANY Subscription Logs:

That means the subscription functions aren't being called at all, which suggests:
1. The code path to `subscribeToRealtimePro()` isn't being reached
2. There's a guard clause preventing execution
3. The location/cart isn't being loaded properly

---

## Expected Behavior:

When you select a location, you should see:
```
[LocationQueueStore] 🔌 Starting PRO realtime subscription for location <UUID>
[LocationQueueStore] Subscribing to channel with filter: location_id=eq.<UUID>
[LocationQueueStore] ✅ SUBSCRIBED to PRO realtime for location <UUID>
```

When you open a cart, you should see:
```
[CartStore] 🔌 Creating realtime channel: cart-updates-<ID>-<timestamp>
[CartStore] Subscribing to channel...
[CartStore] ✅ Subscribed to realtime for cart <UUID>
```

If you see these messages, realtime IS working. If not, we'll know what to fix next.
