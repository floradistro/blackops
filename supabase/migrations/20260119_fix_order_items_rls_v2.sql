-- Fix RLS policy for order_items using correct users table structure
-- Users are linked via users.auth_user_id = auth.uid() and have store_id directly

-- Helper function to get user's store IDs
CREATE OR REPLACE FUNCTION get_user_store_ids()
RETURNS SETOF UUID
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
    SELECT store_id FROM users WHERE auth_user_id = auth.uid() AND store_id IS NOT NULL
$$;

-- Enable RLS on order_items if not already
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "order_items_select_via_order" ON order_items;
DROP POLICY IF EXISTS "order_items_select_via_store" ON order_items;
DROP POLICY IF EXISTS "Users can view order items for their store orders" ON order_items;
DROP POLICY IF EXISTS "order_items_insert_via_store" ON order_items;
DROP POLICY IF EXISTS "order_items_update_via_store" ON order_items;
DROP POLICY IF EXISTS "order_items_delete_via_store" ON order_items;

-- SELECT: Users can read order_items for their store
CREATE POLICY "order_items_select_via_store" ON order_items
    FOR SELECT
    USING (
        store_id IN (SELECT get_user_store_ids())
        OR
        EXISTS (
            SELECT 1 FROM orders o
            WHERE o.id = order_items.order_id
            AND o.store_id IN (SELECT get_user_store_ids())
        )
    );

-- INSERT: Users can insert order_items for their store
CREATE POLICY "order_items_insert_via_store" ON order_items
    FOR INSERT
    WITH CHECK (store_id IN (SELECT get_user_store_ids()));

-- UPDATE: Users can update order_items for their store
CREATE POLICY "order_items_update_via_store" ON order_items
    FOR UPDATE
    USING (store_id IN (SELECT get_user_store_ids()));

-- DELETE: Users can delete order_items for their store
CREATE POLICY "order_items_delete_via_store" ON order_items
    FOR DELETE
    USING (store_id IN (SELECT get_user_store_ids()));

-- Fix headless_customers RLS
ALTER TABLE headless_customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "headless_customers_select_via_store" ON headless_customers;
DROP POLICY IF EXISTS "headless_customers_insert_via_store" ON headless_customers;
DROP POLICY IF EXISTS "headless_customers_update_via_store" ON headless_customers;

CREATE POLICY "headless_customers_select_via_store" ON headless_customers
    FOR SELECT
    USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY "headless_customers_insert_via_store" ON headless_customers
    FOR INSERT
    WITH CHECK (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY "headless_customers_update_via_store" ON headless_customers
    FOR UPDATE
    USING (store_id IN (SELECT get_user_store_ids()));

-- Fix users table RLS for staff lookup
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users_select_same_store" ON users;
DROP POLICY IF EXISTS "users_select_own" ON users;

-- Users can see themselves
CREATE POLICY "users_select_own" ON users
    FOR SELECT
    USING (auth_user_id = auth.uid());

-- Users can see other users in their store
CREATE POLICY "users_select_same_store" ON users
    FOR SELECT
    USING (
        store_id IN (SELECT get_user_store_ids())
    );

-- Fix order_status_history RLS
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_status_history_select_via_order" ON order_status_history;
DROP POLICY IF EXISTS "order_status_history_insert_via_order" ON order_status_history;

CREATE POLICY "order_status_history_select_via_order" ON order_status_history
    FOR SELECT
    USING (
        order_id IN (
            SELECT id FROM orders WHERE store_id IN (SELECT get_user_store_ids())
        )
    );

CREATE POLICY "order_status_history_insert_via_order" ON order_status_history
    FOR INSERT
    WITH CHECK (
        order_id IN (
            SELECT id FROM orders WHERE store_id IN (SELECT get_user_store_ids())
        )
    );

-- Grant execute on the helper function
GRANT EXECUTE ON FUNCTION get_user_store_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_store_ids() TO anon;

-- Add comments
COMMENT ON FUNCTION get_user_store_ids() IS 'Returns store IDs for the current authenticated user';
COMMENT ON POLICY "order_items_select_via_store" ON order_items IS 'Allow users to read order items for orders in their stores';
