# Fahad Khan Accounts Merged

## Summary

Merged all duplicate Fahad Khan accounts into the main account with email **FAHAD@CWSCOMMERCIAL.COM**.

---

## Target Account

**ID**: `b3076a6c-98b5-4def-9fc2-ea3f8f3f2804`
**Name**: Fahad Khan
**Email**: FAHAD@CWSCOMMERCIAL.COM
**Phone**: 8283204633

### Final Stats After Merge

- **Total Orders**: 794 orders
- **Total Spent**: $24,520.56
- **Loyalty Transactions**: 207 transactions
- **Current Points**: -2761 (net redeemed/expired)

---

## Merged Accounts

### Duplicate Account 1
**ID**: `61db48c1-fb1b-41d2-8d47-7c63dd1b86d1`
**Merged**: 6 orders, $163.26
**Status**: Deactivated

### Duplicate Account 2
**ID**: `b077780d-2f3b-46a4-ac82-32e1215befac`
**Merged**: 1 order, $32.00
**Status**: Deactivated

---

## Actions Performed

### 1. ✅ Moved Orders
```sql
-- Moved 7 orders from duplicates to target
UPDATE orders
SET customer_id = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804'
WHERE customer_id IN (
    '61db48c1-fb1b-41d2-8d47-7c63dd1b86d1',
    'b077780d-2f3b-46a4-ac82-32e1215befac'
);
```

**Result**:
- Before: 787 orders
- After: 794 orders (+7)

### 2. ✅ Moved Loyalty Transactions
```sql
-- Moved 5 loyalty transactions
UPDATE loyalty_transactions
SET customer_id = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804'
WHERE customer_id IN (
    '61db48c1-fb1b-41d2-8d47-7c63dd1b86d1',
    'b077780d-2f3b-46a4-ac82-32e1215befac'
);
```

**Result**: 5 transactions moved

### 3. ✅ Deactivated Duplicate Accounts
```sql
-- Deactivated duplicates
UPDATE user_creation_relationships
SET status = 'inactive'
WHERE id IN (
    '61db48c1-fb1b-41d2-8d47-7c63dd1b86d1',
    'b077780d-2f3b-46a4-ac82-32e1215befac'
);
```

**Result**: 2 accounts deactivated

---

## Database State

### Orders Table
- **Customer ID**: b3076a6c-98b5-4def-9fc2-ea3f8f3f2804
- **Order Count**: 794
- **Total Amount**: $24,520.56
- **Date Range**: 2024-08-23 to 2026-01-22

### Loyalty Transactions Table
- **Customer ID**: b3076a6c-98b5-4def-9fc2-ea3f8f3f2804
- **Transaction Count**: 207
- **Total Points**: -2761 (net after redemptions/expiry)

### User Creation Relationships
- **Target Account**: Active
- **Duplicate 1**: Inactive
- **Duplicate 2**: Inactive

---

## Other Fahad Khan Accounts Found

There are **27 additional** Fahad Khan accounts in the system with **no orders** and **0 loyalty points**. These are likely test accounts or abandoned registrations.

If you want to clean these up too, I can deactivate them. They include:
- 15df22b5-5bde-4249-a0e4-84d9a90e8fe0
- b3120f58-a09a-4ea5-9b78-aa4c1f6b7a43
- ef4bcebe-e635-4c1e-b72f-e0ec5f0ce73c
- 85fac72d-f8bf-4b5e-8a4b-cf270511a7c2
- ... and 23 more

---

## Verification

To verify the merge, search for "Fahad Khan" or email "FAHAD@CWSCOMMERCIAL.COM" in the POS system. You should see:

- ✅ One active account for Fahad Khan
- ✅ 794 orders in order history
- ✅ Correct email (FAHAD@CWSCOMMERCIAL.COM)
- ✅ Correct phone (8283204633)

The duplicate accounts will no longer appear in search results (status=inactive).

---

## Next Steps

If you want to also merge/clean up:
1. The 27 other empty Fahad Khan accounts
2. Any other duplicate customer accounts in the system

Let me know and I can run a similar merge process.
