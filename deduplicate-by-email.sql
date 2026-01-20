-- Deduplicate platform_users by email (second pass after phone deduplication)
-- Keep the user with the most data and earliest created_at

-- Increase statement timeout for large updates
SET statement_timeout = '10min';
SET lock_timeout = '5min';

BEGIN;

-- Create temp table with email-based duplicates to merge
CREATE TEMP TABLE email_users_to_keep AS
WITH customer_relationships AS (
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
    AND pu.email IS NOT NULL
    AND pu.email NOT LIKE 'merged.%'
),
ranked_users AS (
  SELECT
    relationship_id,
    user_id,
    store_id,
    email,
    phone,
    -- Rank by data completeness and age
    ROW_NUMBER() OVER (
      PARTITION BY store_id, email
      ORDER BY
        -- Prefer records with phone
        CASE WHEN phone IS NOT NULL AND phone NOT LIKE 'merged_%' THEN 0 ELSE 1 END,
        -- Prefer more complete records
        CASE WHEN first_name IS NOT NULL THEN 0 ELSE 1 END +
        CASE WHEN last_name IS NOT NULL THEN 0 ELSE 1 END,
        -- Prefer older records
        created_at ASC
    ) as rn
  FROM customer_relationships
)
SELECT relationship_id, user_id, store_id, email
FROM ranked_users
WHERE rn = 1;

-- Show what will be merged
SELECT
  'Duplicate email relationships to merge:' as action,
  COUNT(*) as count
FROM user_creation_relationships ucr
JOIN platform_users pu ON pu.id = ucr.user_id
WHERE ucr.creation_type IN ('store', 'landing')
  AND pu.email IS NOT NULL
  AND pu.email NOT LIKE 'merged.%'
  AND ucr.id NOT IN (SELECT relationship_id FROM email_users_to_keep)
  AND EXISTS (
    SELECT 1 FROM email_users_to_keep k
    WHERE k.email = pu.email AND k.store_id = ucr.store_id
  );

-- Get all duplicate relationship IDs that need to be merged (by email)
CREATE TEMP TABLE email_relationships_to_merge AS
SELECT
  ucr.id as duplicate_relationship_id,
  k.relationship_id as keeper_relationship_id
FROM user_creation_relationships ucr
JOIN platform_users pu ON pu.id = ucr.user_id
JOIN email_users_to_keep k ON k.email = pu.email AND k.store_id = ucr.store_id
WHERE ucr.creation_type IN ('store', 'landing')
  AND pu.email IS NOT NULL
  AND pu.email NOT LIKE 'merged.%'
  AND ucr.id != k.relationship_id;

-- Show merge plan
SELECT
  'Email relationships to merge' as info,
  COUNT(*) as duplicate_count
FROM email_relationships_to_merge;

-- Update all foreign key references to point to keeper relationships

-- 1. Update orders
UPDATE orders o
SET customer_id = rtm.keeper_relationship_id
FROM email_relationships_to_merge rtm
WHERE o.customer_id = rtm.duplicate_relationship_id;

-- 2. Update loyalty_transactions
UPDATE loyalty_transactions lt
SET customer_id = rtm.keeper_relationship_id
FROM email_relationships_to_merge rtm
WHERE lt.customer_id = rtm.duplicate_relationship_id;

-- 3. Update carts
UPDATE carts c
SET customer_id = rtm.keeper_relationship_id
FROM email_relationships_to_merge rtm
WHERE c.customer_id = rtm.duplicate_relationship_id;

-- 4. Update customer_loyalty (merge if keeper doesn't have one)
UPDATE customer_loyalty cl
SET customer_id = rtm.keeper_relationship_id
FROM email_relationships_to_merge rtm
WHERE cl.customer_id = rtm.duplicate_relationship_id
  AND NOT EXISTS (
    SELECT 1 FROM customer_loyalty
    WHERE customer_id = rtm.keeper_relationship_id
  );

-- Delete duplicate loyalty records where keeper already has one
DELETE FROM customer_loyalty cl
USING email_relationships_to_merge rtm
WHERE cl.customer_id = rtm.duplicate_relationship_id;

-- 5. Update customer_notes
UPDATE customer_notes cn
SET customer_id = rtm.keeper_relationship_id
FROM email_relationships_to_merge rtm
WHERE cn.customer_id = rtm.duplicate_relationship_id;

-- 6. Update customer_addresses
UPDATE customer_addresses ca
SET customer_id = rtm.keeper_relationship_id
FROM email_relationships_to_merge rtm
WHERE ca.customer_id = rtm.duplicate_relationship_id;

-- 7. Delete duplicate user_creation_relationships
DELETE FROM user_creation_relationships ucr
USING email_relationships_to_merge rtm
WHERE ucr.id = rtm.duplicate_relationship_id;

-- Verification queries

-- Check 1: No remaining email duplicates
SELECT 'Remaining email duplicates check:' as verification,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS ✅' ELSE 'FAIL ❌' END as status
FROM (
  SELECT pu.email, ucr.store_id, COUNT(*)
  FROM user_creation_relationships ucr
  JOIN platform_users pu ON pu.id = ucr.user_id
  WHERE ucr.creation_type IN ('store', 'landing')
    AND pu.email IS NOT NULL
    AND pu.email NOT LIKE 'merged.%'
  GROUP BY pu.email, ucr.store_id
  HAVING COUNT(*) > 1
) dupe_check;

-- Check 2: No remaining phone duplicates
SELECT 'Remaining phone duplicates check:' as verification,
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

-- Check 3: Final customer count
SELECT 'Final customer relationship count:' as verification,
  COUNT(*) as count
FROM user_creation_relationships
WHERE creation_type IN ('store', 'landing');

-- Show summary
SELECT
  'Summary:' as info,
  'Relationships remaining' as metric,
  COUNT(*) as count
FROM user_creation_relationships
WHERE creation_type IN ('store', 'landing');

COMMIT;
