-- Deduplicate platform_users by phone number
-- This fixes duplicate customers showing in v_store_customers view
-- Keep the user with the most data and earliest created_at

-- Increase statement timeout for large updates
SET statement_timeout = '10min';
SET lock_timeout = '5min';

BEGIN;

-- Create temp table with platform_users to keep (one per phone per store)
CREATE TEMP TABLE users_to_keep AS
WITH customer_relationships AS (
  -- Get all customer relationships with their platform user data
  SELECT
    ucr.id as relationship_id,
    ucr.user_id,
    ucr.store_id,
    pu.phone,
    pu.email,
    pu.first_name,
    pu.last_name,
    pu.created_at
  FROM user_creation_relationships ucr
  JOIN platform_users pu ON pu.id = ucr.user_id
  WHERE ucr.creation_type IN ('store', 'landing')
    AND pu.phone IS NOT NULL
    AND pu.phone NOT LIKE 'merged_%'
),
ranked_users AS (
  SELECT
    relationship_id,
    user_id,
    store_id,
    phone,
    email,
    -- Rank by data completeness and age
    ROW_NUMBER() OVER (
      PARTITION BY store_id, phone
      ORDER BY
        -- Prefer records with email
        CASE WHEN email IS NOT NULL AND email NOT LIKE 'merged.%' THEN 0 ELSE 1 END,
        -- Prefer more complete records
        CASE WHEN first_name IS NOT NULL THEN 0 ELSE 1 END +
        CASE WHEN last_name IS NOT NULL THEN 0 ELSE 1 END,
        -- Prefer older records
        created_at ASC
    ) as rn
  FROM customer_relationships
)
SELECT relationship_id, user_id, store_id, phone
FROM ranked_users
WHERE rn = 1;

-- Show what will be merged
SELECT
  'Duplicate relationships to merge:' as action,
  COUNT(*) as count
FROM user_creation_relationships ucr
JOIN platform_users pu ON pu.id = ucr.user_id
WHERE ucr.creation_type IN ('store', 'landing')
  AND pu.phone IS NOT NULL
  AND pu.phone NOT LIKE 'merged_%'
  AND ucr.id NOT IN (SELECT relationship_id FROM users_to_keep)
  AND EXISTS (
    SELECT 1 FROM users_to_keep k
    WHERE k.phone = pu.phone AND k.store_id = ucr.store_id
  );

-- Get all duplicate relationship IDs that need to be merged
CREATE TEMP TABLE relationships_to_merge AS
SELECT
  ucr.id as duplicate_relationship_id,
  k.relationship_id as keeper_relationship_id
FROM user_creation_relationships ucr
JOIN platform_users pu ON pu.id = ucr.user_id
JOIN users_to_keep k ON k.phone = pu.phone AND k.store_id = ucr.store_id
WHERE ucr.creation_type IN ('store', 'landing')
  AND pu.phone IS NOT NULL
  AND pu.phone NOT LIKE 'merged_%'
  AND ucr.id != k.relationship_id;

-- Show merge plan
SELECT
  'Relationships to merge' as info,
  COUNT(*) as duplicate_count
FROM relationships_to_merge;

-- Update all foreign key references to point to keeper relationships

-- 1. Update orders
UPDATE orders o
SET customer_id = rtm.keeper_relationship_id
FROM relationships_to_merge rtm
WHERE o.customer_id = rtm.duplicate_relationship_id;

-- 2. Update loyalty_transactions
UPDATE loyalty_transactions lt
SET customer_id = rtm.keeper_relationship_id
FROM relationships_to_merge rtm
WHERE lt.customer_id = rtm.duplicate_relationship_id;

-- 3. Update carts
UPDATE carts c
SET customer_id = rtm.keeper_relationship_id
FROM relationships_to_merge rtm
WHERE c.customer_id = rtm.duplicate_relationship_id;

-- 4. Update customer_loyalty (merge if keeper doesn't have one)
UPDATE customer_loyalty cl
SET customer_id = rtm.keeper_relationship_id
FROM relationships_to_merge rtm
WHERE cl.customer_id = rtm.duplicate_relationship_id
  AND NOT EXISTS (
    SELECT 1 FROM customer_loyalty
    WHERE customer_id = rtm.keeper_relationship_id
  );

-- Delete duplicate loyalty records where keeper already has one
DELETE FROM customer_loyalty cl
USING relationships_to_merge rtm
WHERE cl.customer_id = rtm.duplicate_relationship_id;

-- 5. Update customer_notes
UPDATE customer_notes cn
SET customer_id = rtm.keeper_relationship_id
FROM relationships_to_merge rtm
WHERE cn.customer_id = rtm.duplicate_relationship_id;

-- 6. Update customer_addresses
UPDATE customer_addresses ca
SET customer_id = rtm.keeper_relationship_id
FROM relationships_to_merge rtm
WHERE ca.customer_id = rtm.duplicate_relationship_id;

-- 7. Delete duplicate user_creation_relationships
-- This will CASCADE delete related records if properly configured
DELETE FROM user_creation_relationships ucr
USING relationships_to_merge rtm
WHERE ucr.id = rtm.duplicate_relationship_id;

-- Verification queries (MUST pass before COMMIT)

-- Check 1: No orphaned orders
SELECT 'Orphaned orders check:' as verification,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS ✅' ELSE 'FAIL ❌' END as status
FROM orders o
WHERE NOT EXISTS (
  SELECT 1 FROM user_creation_relationships ucr WHERE ucr.id = o.customer_id
);

-- Check 2: No orphaned loyalty_transactions
SELECT 'Orphaned loyalty_transactions check:' as verification,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS ✅' ELSE 'FAIL ❌' END as status
FROM loyalty_transactions lt
WHERE NOT EXISTS (
  SELECT 1 FROM user_creation_relationships ucr WHERE ucr.id = lt.customer_id
);

-- Check 3: Final customer count
SELECT 'Final customer relationship count:' as verification,
  COUNT(*) as count
FROM user_creation_relationships
WHERE creation_type IN ('store', 'landing');

-- Check 4: No remaining duplicates
SELECT 'Remaining duplicates check:' as verification,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS ✅' ELSE 'FAIL ❌' END as status
FROM (
  SELECT pu.phone, ucr.store_id, COUNT(*)
  FROM user_creation_relationships ucr
  JOIN platform_users pu ON pu.id = ucr.user_id
  WHERE ucr.creation_type IN ('store', 'landing')
    AND pu.phone IS NOT NULL
    AND pu.phone NOT LIKE 'merged_%'
  GROUP BY pu.phone, ucr.store_id
  HAVING COUNT(*) > 1
) dupe_check;

-- Show summary
SELECT
  'Summary:' as info,
  'Relationships remaining' as metric,
  COUNT(*) as count
FROM user_creation_relationships
WHERE creation_type IN ('store', 'landing');

COMMIT;

-- Note: Run this separately after commit to add constraint
-- ALTER TABLE user_creation_relationships
--   ADD CONSTRAINT unique_store_customer_phone
--   EXCLUDE USING btree (store_id WITH =, ((SELECT phone FROM platform_users WHERE id = user_id)) WITH =)
--   WHERE (creation_type IN ('store', 'landing'));
