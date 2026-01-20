# Customer Deduplication Plan - Comprehensive Safety Analysis

## Current State
- **Total Records:** 16,610
- **Unique Customers (by phone):** 7,136
- **Duplicate Records:** 9,474 (57% waste)
- **Tables with FK to customers:**
  - `orders`: 61,447 records
  - `cart_items`: 1,030 records
  - `order_items`: 98,027 records
  - `customer_loyalty`: 0 records (safe)
  - `customer_notes`: 0 records (safe)
  - `customer_addresses`: 0 records (safe)

## Critical Dependencies
### HIGH RISK - Data Loss Potential
1. **orders.customer_id** → Must preserve all order relationships
2. **cart_items** → Active shopping carts, must preserve
3. **order_items** → Line items tied to orders

### NO RISK
- customer_loyalty (empty table)
- customer_notes (empty table)
- customer_addresses (empty table)

## Edge Cases Identified

### Case 1: Same ID Duplicates (Literal Duplicate Rows)
**Example:** ID `d46c9563-7c08-4bef-a116-17f3a38625ae` appears 2x
- **Risk:** NONE - These are exact duplicates
- **Action:** DELETE FROM customers WHERE ctid NOT IN (SELECT MIN(ctid)...)
- **Data Loss:** ZERO

### Case 2: Different IDs, Same Phone (True Duplicates)
**Example:** Phone `2019058727` has 2 different customer IDs
- **Risk:** HIGH - Orders split across both IDs
- **Action:**
  1. Choose keeper (oldest created_at OR most complete data)
  2. UPDATE orders SET customer_id = keeper_id WHERE customer_id IN (dupe_ids)
  3. DELETE FROM customers WHERE id IN (dupe_ids)
- **Data Loss:** ZERO if done correctly

### Case 3: Different Emails (Conflict)
**Example:** Same phone, email changed over time
- **Risk:** MEDIUM - Which email is correct?
- **Action:** Keep most recent OR most complete record
- **Data Loss:** Older email addresses (acceptable)

### Case 4: Different Names (Conflict)
**Example:** Name spelling variations or corrections
- **Risk:** LOW - Names can be corrected later
- **Action:** Keep most complete record
- **Data Loss:** Old spelling (acceptable)

## Merge Strategy

### Phase 1: Literal Duplicate Removal (SAFE)
```sql
-- Remove exact duplicate rows (same ID appearing multiple times)
DELETE FROM customers a USING customers b
WHERE a.ctid < b.ctid
  AND a.id = b.id;
```
**Risk:** ZERO - PostgreSQL guarantees no data loss for duplicate rows

### Phase 2: Phone-Based Deduplication (CAREFUL)
For each group of customers with same (store_id, phone):

1. **Select Keeper:**
   ```sql
   ROW_NUMBER() OVER (
     PARTITION BY store_id, phone
     ORDER BY
       -- Prefer records with email
       CASE WHEN email IS NOT NULL THEN 0 ELSE 1 END,
       -- Prefer more complete records
       CASE WHEN first_name IS NOT NULL THEN 0 ELSE 1 END +
       CASE WHEN last_name IS NOT NULL THEN 0 ELSE 1 END,
       -- Prefer oldest (first created)
       created_at ASC
   )
   ```

2. **Merge Foreign Keys:**
   ```sql
   -- Update orders
   UPDATE orders SET customer_id = keeper_id
   WHERE customer_id IN (duplicate_ids);

   -- Update cart_items
   UPDATE cart_items SET customer_id = keeper_id
   WHERE customer_id IN (duplicate_ids);
   ```

3. **Delete Duplicates:**
   ```sql
   DELETE FROM customers WHERE id IN (duplicate_ids);
   ```

### Phase 3: Add Constraints (PREVENT FUTURE)
```sql
ALTER TABLE customers
  ADD CONSTRAINT customers_store_phone_unique
  UNIQUE (store_id, phone)
  WHERE phone IS NOT NULL;
```

## Safety Measures

### 1. Backup Strategy
```bash
# Full customers table backup
pg_dump -h db.uaednwpxursknmwdeejn.supabase.co \
  -U postgres -d postgres \
  -t customers -t orders -t cart_items \
  -f customers_backup_$(date +%Y%m%d).sql
```

### 2. Dry-Run Analysis
Before executing, run analysis script that:
- Counts total duplicates
- Shows merge plan for each group
- Identifies conflicts
- Estimates final record count
- NO WRITES TO DATABASE

### 3. Transaction Wrapper
```sql
BEGIN;
-- All operations here
-- Verify counts
SELECT COUNT(*) FROM customers; -- Should be ~7,136
SELECT COUNT(*) FROM orders WHERE customer_id NOT IN (SELECT id FROM customers); -- Should be 0
-- If good:
COMMIT;
-- If bad:
ROLLBACK;
```

### 4. Verification Queries
After merge, verify:
```sql
-- No orphaned orders
SELECT COUNT(*) FROM orders o
LEFT JOIN customers c ON c.id = o.customer_id
WHERE c.id IS NULL;
-- Should be 0

-- No orphaned cart items
SELECT COUNT(*) FROM cart_items ci
LEFT JOIN customers c ON c.id = ci.customer_id
WHERE c.id IS NULL;
-- Should be 0

-- No remaining duplicates
SELECT phone, COUNT(*)
FROM customers
WHERE phone IS NOT NULL
GROUP BY store_id, phone
HAVING COUNT(*) > 1;
-- Should be 0 rows
```

## Rollback Plan

### If Something Goes Wrong:
1. **ROLLBACK** transaction (if still in progress)
2. **DROP** unique constraint (if added)
3. **RESTORE** from backup:
   ```bash
   psql -h db.uaednwpxursknmwdeejn.supabase.co \
     -U postgres -d postgres \
     -f customers_backup_YYYYMMDD.sql
   ```

## Expected Outcome

### Before:
- 16,610 customer records
- 9,474 duplicates
- Slow UI performance

### After:
- ~7,136 unique customer records
- 0 duplicates
- All 61,447 orders preserved
- All cart_items preserved
- Fast UI performance
- Future duplicates prevented

## Data Loss Risk Assessment

| Scenario | Risk | Mitigation |
|----------|------|------------|
| Literal duplicate rows | ZERO | Safe to delete |
| Orders lose customer link | ZERO | FK update before delete |
| Cart items lose customer | ZERO | FK update before delete |
| Email conflicts | LOW | Keep most recent |
| Name conflicts | LOW | Keep most complete |
| Transaction failure | ZERO | Rollback |
| Database corruption | VERY LOW | Full backup |

## Execution Checklist

- [ ] Review this plan
- [ ] Create backup
- [ ] Run dry-run analysis script
- [ ] Review dry-run output
- [ ] Execute in transaction
- [ ] Verify counts
- [ ] Test UI (load customers)
- [ ] Test order lookups
- [ ] If all good: COMMIT
- [ ] Add unique constraint
- [ ] Test creating new customer (should prevent dupes)

## Next Steps

1. Get your approval on this plan
2. Create comprehensive dry-run script
3. Review dry-run output together
4. Execute with your supervision
5. Verify results
6. Celebrate cleaned data! 🎉
