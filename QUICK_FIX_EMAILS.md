# Quick Fix: Emails Not Showing

## 🔍 What's Happening

Your emails ARE loading (the count "600+" is increasing), but they're not visible because:

**The `category` column doesn't exist in your database yet!**

Without categories, emails can't be grouped, so the UI filters them out.

---

## ✅ The Fix (2 Minutes)

### Step 1: Rebuild the App

The code now has a fallback "All Emails" section that will show even without categories.

```bash
# In Xcode
Cmd+Shift+K  # Clean
Cmd+B        # Build
Cmd+R        # Run
```

### Step 2: Check the Sidebar

After rebuilding, you should now see:

```
📧 Emails 600+
  ├─ 📭 All Emails (600) ⚠️
  │   ⓘ Run migration to enable categories
  │   ├─ email 1
  │   ├─ email 2
  │   └─ ... (all emails show here)
  └─ [Load More]
```

The ⚠️ warning icon indicates categories aren't set up yet.

### Step 3: Run the Migration (Enables Categories)

```bash
cd /Users/whale/Desktop/blackops
./deploy-email-categories.sh
```

This adds the `category` column to your database and organizes emails into groups.

### Step 4: Rebuild & See Categories

After migration:

```bash
# Restart the app
Cmd+R
```

Now you'll see:

```
📧 Emails 600+
  ├─ 🔐 Authentication (45)
  │   ├─ Password reset email
  │   └─ ...
  ├─ 📦 Orders (324)
  │   ├─ Order #1234
  │   └─ ...
  ├─ 📣 Campaigns (231)
  │   └─ ...
  └─ [Load More]
```

---

## 🐛 If You Still Don't See Emails

### Check the Xcode Console

Look for this output when clicking "Load More":

```
📧 Loaded 200 more emails (200 → 400)
```

If you see this, emails ARE loading. The UI just needs the rebuild.

### Force Refresh

1. Close the app completely
2. Clean build folder (Cmd+Shift+K)
3. Rebuild (Cmd+B)
4. Run (Cmd+R)

### Verify Database Has Emails

```bash
# If using Supabase
supabase db execute "SELECT COUNT(*) FROM email_sends"
```

Should show 600+ if that's what the UI displays.

---

## 📋 Summary

| Issue | Solution |
|-------|----------|
| Emails load but don't show | Rebuild app - fallback "All Emails" section added |
| Want organized categories | Run `./deploy-email-categories.sh` |
| Migration fails | Check Supabase CLI installed: `brew install supabase/tap/supabase` |
| Build errors | See BUILD_FIXES_SUMMARY.md |

---

## ✨ What You'll Get After Migration

### Before (Current):
- ✅ All emails in one flat "All Emails" section
- ⚠️ Warning: "Run migration to enable categories"

### After (With Migration):
- ✅ Organized into 7 category groups
- ✅ 40+ specific categories (Password Reset, Order Shipped, etc.)
- ✅ Color-coded icons
- ✅ Smart backfilling of existing emails
- ✅ No more warning icon

---

## 🎯 Try This Right Now

1. **Rebuild** (Cmd+Shift+K, then Cmd+B, then Cmd+R)
2. **Click "Emails"** in sidebar
3. **Click "All Emails"** (should have ⚠️ icon)
4. **See all 600+ emails** listed

Then when ready:
```bash
./deploy-email-categories.sh
```

And rebuild again to see categories! 🚀
