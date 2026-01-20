-- Fix RLS policy for order_items to allow access through orders
-- This ensures that if a user can see an order, they can see its items

-- First check if RLS is enabled on order_items
DO $$
BEGIN
    -- Enable RLS if not already enabled
    ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'RLS already enabled or table does not exist';
END $$;

-- Drop existing policy if it exists (to recreate cleanly)
DROP POLICY IF EXISTS "order_items_select_via_order" ON order_items;
DROP POLICY IF EXISTS "order_items_select_via_store" ON order_items;
DROP POLICY IF EXISTS "Users can view order items for their store orders" ON order_items;

-- Create policy: Users can read order_items if they can access the parent order
-- This uses the same store_id check that orders uses
CREATE POLICY "order_items_select_via_store" ON order_items
    FOR SELECT
    USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM orders o
            WHERE o.id = order_items.order_id
            AND o.store_id IN (
                SELECT store_id FROM store_users WHERE user_id = auth.uid()
            )
        )
    );

-- Also add insert/update/delete policies for completeness
DROP POLICY IF EXISTS "order_items_insert_via_store" ON order_items;
CREATE POLICY "order_items_insert_via_store" ON order_items
    FOR INSERT
    WITH CHECK (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "order_items_update_via_store" ON order_items;
CREATE POLICY "order_items_update_via_store" ON order_items
    FOR UPDATE
    USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "order_items_delete_via_store" ON order_items;
CREATE POLICY "order_items_delete_via_store" ON order_items
    FOR DELETE
    USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

-- Also fix headless_customers RLS if needed
DROP POLICY IF EXISTS "headless_customers_select_via_store" ON headless_customers;
CREATE POLICY "headless_customers_select_via_store" ON headless_customers
    FOR SELECT
    USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

-- Fix users table RLS for staff lookup
DROP POLICY IF EXISTS "users_select_same_store" ON users;
CREATE POLICY "users_select_same_store" ON users
    FOR SELECT
    USING (
        -- Users can see other users in stores they have access to
        id IN (
            SELECT su.user_id FROM store_users su
            WHERE su.store_id IN (
                SELECT store_id FROM store_users WHERE user_id = auth.uid()
            )
        )
        OR id = auth.uid()
    );

-- Fix order_status_history RLS
DROP POLICY IF EXISTS "order_status_history_select_via_order" ON order_status_history;
CREATE POLICY "order_status_history_select_via_order" ON order_status_history
    FOR SELECT
    USING (
        order_id IN (
            SELECT id FROM orders
            WHERE store_id IN (
                SELECT store_id FROM store_users WHERE user_id = auth.uid()
            )
        )
    );

COMMENT ON POLICY "order_items_select_via_store" ON order_items IS 'Allow users to read order items for orders in their stores';
