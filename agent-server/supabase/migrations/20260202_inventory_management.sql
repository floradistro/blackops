-- ============================================================================
-- INVENTORY MANAGEMENT: Purchase Orders, Transfers, Receiving
-- ============================================================================
-- This migration adds full inventory management capabilities:
-- 1. Purchase orders (create, approve, receive)
-- 2. Inventory transfers with audit trail
-- 3. Receiving workflow
-- ============================================================================

-- ============================================================================
-- 1. PURCHASE ORDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id),
    supplier_id UUID REFERENCES suppliers(id),
    location_id UUID REFERENCES locations(id), -- destination location for receiving

    -- PO Details
    po_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'approved', 'ordered', 'partial', 'received', 'cancelled')),

    -- Financials
    subtotal NUMERIC(12,2) DEFAULT 0,
    tax_amount NUMERIC(12,2) DEFAULT 0,
    shipping_cost NUMERIC(12,2) DEFAULT 0,
    total_amount NUMERIC(12,2) DEFAULT 0,

    -- Dates
    order_date DATE,
    expected_delivery_date DATE,
    received_date DATE,

    -- Notes
    notes TEXT,
    internal_notes TEXT,

    -- Audit
    created_by UUID,
    approved_by UUID,
    received_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create unique index for PO numbers per store
CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_orders_po_number
ON purchase_orders(store_id, po_number);

-- ============================================================================
-- 2. PURCHASE ORDER ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),

    -- Quantities
    quantity_ordered NUMERIC(12,4) NOT NULL DEFAULT 0,
    quantity_received NUMERIC(12,4) NOT NULL DEFAULT 0,

    -- Pricing
    unit_cost NUMERIC(12,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(12,2) GENERATED ALWAYS AS (quantity_ordered * unit_cost) STORED,

    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'received', 'cancelled')),

    -- Notes
    notes TEXT,

    -- Audit
    received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. INVENTORY TRANSFERS TABLE (Audit Trail)
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,

    -- Transfer Details
    transfer_number TEXT NOT NULL,
    from_location_id UUID NOT NULL REFERENCES locations(id),
    to_location_id UUID NOT NULL REFERENCES locations(id),

    -- Status
    status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'in_transit', 'received', 'cancelled')),

    -- Notes
    notes TEXT,

    -- Audit
    initiated_by UUID,
    received_by UUID,
    initiated_at TIMESTAMPTZ DEFAULT NOW(),
    received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 4. INVENTORY TRANSFER ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory_transfer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES inventory_transfers(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    inventory_id UUID REFERENCES inventory(id),

    -- Quantities
    quantity_sent NUMERIC(12,4) NOT NULL DEFAULT 0,
    quantity_received NUMERIC(12,4) DEFAULT 0,

    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_transit', 'received', 'short', 'over')),

    -- Notes for discrepancies
    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 5. RPC: CREATE PURCHASE ORDER
-- ============================================================================
CREATE OR REPLACE FUNCTION create_purchase_order(
    p_store_id UUID,
    p_supplier_id UUID DEFAULT NULL,
    p_location_id UUID DEFAULT NULL,
    p_items JSONB DEFAULT '[]'::JSONB,
    p_notes TEXT DEFAULT NULL,
    p_expected_delivery DATE DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_po_id UUID;
    v_po_number TEXT;
    v_subtotal NUMERIC := 0;
    v_item JSONB;
BEGIN
    -- Generate PO number
    v_po_number := 'PO-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Create PO header
    INSERT INTO purchase_orders (
        store_id, supplier_id, location_id, po_number,
        notes, expected_delivery_date, created_by, status
    )
    VALUES (
        p_store_id, p_supplier_id, p_location_id, v_po_number,
        p_notes, p_expected_delivery, p_created_by, 'draft'
    )
    RETURNING id INTO v_po_id;

    -- Add items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO purchase_order_items (
            purchase_order_id, product_id, quantity_ordered, unit_cost, notes
        )
        VALUES (
            v_po_id,
            (v_item->>'product_id')::UUID,
            COALESCE((v_item->>'quantity')::NUMERIC, 0),
            COALESCE((v_item->>'unit_cost')::NUMERIC, 0),
            v_item->>'notes'
        );

        v_subtotal := v_subtotal + (COALESCE((v_item->>'quantity')::NUMERIC, 0) * COALESCE((v_item->>'unit_cost')::NUMERIC, 0));
    END LOOP;

    -- Update totals
    UPDATE purchase_orders
    SET subtotal = v_subtotal, total_amount = v_subtotal
    WHERE id = v_po_id;

    RETURN jsonb_build_object(
        'success', true,
        'purchase_order_id', v_po_id,
        'po_number', v_po_number,
        'subtotal', v_subtotal
    );
END;
$$;

-- ============================================================================
-- 6. RPC: RECEIVE PURCHASE ORDER (Full or Partial)
-- ============================================================================
CREATE OR REPLACE FUNCTION receive_purchase_order(
    p_purchase_order_id UUID,
    p_items JSONB DEFAULT NULL, -- NULL = receive all, or specify items with quantities
    p_received_by UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_po RECORD;
    v_item RECORD;
    v_receive_item JSONB;
    v_qty_to_receive NUMERIC;
    v_inventory_id UUID;
    v_items_received INTEGER := 0;
    v_total_qty_received NUMERIC := 0;
BEGIN
    -- Get PO details
    SELECT * INTO v_po FROM purchase_orders WHERE id = p_purchase_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Purchase order not found');
    END IF;

    IF v_po.status IN ('received', 'cancelled') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Purchase order already ' || v_po.status);
    END IF;

    -- Process each PO item
    FOR v_item IN
        SELECT * FROM purchase_order_items
        WHERE purchase_order_id = p_purchase_order_id
        AND status != 'received'
    LOOP
        -- Determine quantity to receive
        IF p_items IS NOT NULL THEN
            -- Look for this item in the receive list
            SELECT elem INTO v_receive_item
            FROM jsonb_array_elements(p_items) elem
            WHERE (elem->>'product_id')::UUID = v_item.product_id
            OR (elem->>'item_id')::UUID = v_item.id;

            IF v_receive_item IS NULL THEN
                CONTINUE; -- Skip items not in receive list
            END IF;

            v_qty_to_receive := COALESCE((v_receive_item->>'quantity')::NUMERIC, v_item.quantity_ordered - v_item.quantity_received);
        ELSE
            -- Receive full remaining quantity
            v_qty_to_receive := v_item.quantity_ordered - v_item.quantity_received;
        END IF;

        IF v_qty_to_receive <= 0 THEN
            CONTINUE;
        END IF;

        -- Find or create inventory record
        SELECT id INTO v_inventory_id
        FROM inventory
        WHERE product_id = v_item.product_id
        AND location_id = v_po.location_id;

        IF NOT FOUND THEN
            -- Create new inventory record
            INSERT INTO inventory (product_id, location_id, store_id, quantity)
            VALUES (v_item.product_id, v_po.location_id, v_po.store_id, 0)
            RETURNING id INTO v_inventory_id;
        END IF;

        -- Add to inventory
        UPDATE inventory
        SET quantity = quantity + v_qty_to_receive,
            updated_at = NOW()
        WHERE id = v_inventory_id;

        -- Log adjustment
        INSERT INTO inventory_adjustments (
            inventory_id, product_id, location_id,
            adjustment_type, old_quantity, new_quantity, reason, created_by
        )
        SELECT
            v_inventory_id, v_item.product_id, v_po.location_id,
            'PO_RECEIVE', inv.quantity - v_qty_to_receive, inv.quantity,
            'Received from PO ' || v_po.po_number, p_received_by
        FROM inventory inv WHERE inv.id = v_inventory_id;

        -- Update PO item
        UPDATE purchase_order_items
        SET quantity_received = quantity_received + v_qty_to_receive,
            received_at = NOW(),
            status = CASE
                WHEN quantity_received + v_qty_to_receive >= quantity_ordered THEN 'received'
                ELSE 'partial'
            END,
            updated_at = NOW()
        WHERE id = v_item.id;

        v_items_received := v_items_received + 1;
        v_total_qty_received := v_total_qty_received + v_qty_to_receive;
    END LOOP;

    -- Update PO status
    UPDATE purchase_orders
    SET status = (
            SELECT CASE
                WHEN COUNT(*) FILTER (WHERE status != 'received') = 0 THEN 'received'
                WHEN COUNT(*) FILTER (WHERE status IN ('received', 'partial')) > 0 THEN 'partial'
                ELSE status
            END
            FROM purchase_order_items
            WHERE purchase_order_id = p_purchase_order_id
        ),
        received_by = COALESCE(p_received_by, received_by),
        received_date = CASE
            WHEN (SELECT COUNT(*) FILTER (WHERE status != 'received') FROM purchase_order_items WHERE purchase_order_id = p_purchase_order_id) = 0
            THEN CURRENT_DATE
            ELSE received_date
        END,
        updated_at = NOW()
    WHERE id = p_purchase_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'items_received', v_items_received,
        'total_quantity_received', v_total_qty_received,
        'po_status', (SELECT status FROM purchase_orders WHERE id = p_purchase_order_id)
    );
END;
$$;

-- ============================================================================
-- 7. RPC: CREATE INVENTORY TRANSFER
-- ============================================================================
CREATE OR REPLACE FUNCTION create_inventory_transfer(
    p_store_id UUID,
    p_from_location_id UUID,
    p_to_location_id UUID,
    p_items JSONB, -- [{product_id, quantity}]
    p_notes TEXT DEFAULT NULL,
    p_initiated_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_transfer_id UUID;
    v_transfer_number TEXT;
    v_item JSONB;
    v_inventory RECORD;
    v_items_count INTEGER := 0;
BEGIN
    -- Validate locations are different
    IF p_from_location_id = p_to_location_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source and destination must be different');
    END IF;

    -- Generate transfer number
    v_transfer_number := 'TR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Create transfer header
    INSERT INTO inventory_transfers (
        store_id, transfer_number, from_location_id, to_location_id,
        notes, initiated_by, status
    )
    VALUES (
        p_store_id, v_transfer_number, p_from_location_id, p_to_location_id,
        p_notes, p_initiated_by, 'initiated'
    )
    RETURNING id INTO v_transfer_id;

    -- Process each item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Get source inventory
        SELECT * INTO v_inventory
        FROM inventory
        WHERE product_id = (v_item->>'product_id')::UUID
        AND location_id = p_from_location_id;

        IF NOT FOUND THEN
            -- Rollback
            DELETE FROM inventory_transfers WHERE id = v_transfer_id;
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Product ' || (v_item->>'product_id') || ' not found at source location'
            );
        END IF;

        IF v_inventory.quantity < (v_item->>'quantity')::NUMERIC THEN
            DELETE FROM inventory_transfers WHERE id = v_transfer_id;
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Insufficient quantity. Have ' || v_inventory.quantity || ', need ' || (v_item->>'quantity')
            );
        END IF;

        -- Create transfer item
        INSERT INTO inventory_transfer_items (
            transfer_id, product_id, inventory_id, quantity_sent, status
        )
        VALUES (
            v_transfer_id,
            (v_item->>'product_id')::UUID,
            v_inventory.id,
            (v_item->>'quantity')::NUMERIC,
            'pending'
        );

        -- Deduct from source
        UPDATE inventory
        SET quantity = quantity - (v_item->>'quantity')::NUMERIC,
            updated_at = NOW()
        WHERE id = v_inventory.id;

        -- Log adjustment
        INSERT INTO inventory_adjustments (
            inventory_id, product_id, location_id,
            adjustment_type, old_quantity, new_quantity, reason, created_by
        )
        VALUES (
            v_inventory.id, (v_item->>'product_id')::UUID, p_from_location_id,
            'TRANSFER_OUT', v_inventory.quantity, v_inventory.quantity - (v_item->>'quantity')::NUMERIC,
            'Transfer to ' || (SELECT name FROM locations WHERE id = p_to_location_id), p_initiated_by
        );

        v_items_count := v_items_count + 1;
    END LOOP;

    -- Update transfer status
    UPDATE inventory_transfers
    SET status = 'in_transit', updated_at = NOW()
    WHERE id = v_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'transfer_number', v_transfer_number,
        'items_count', v_items_count
    );
END;
$$;

-- ============================================================================
-- 8. RPC: RECEIVE INVENTORY TRANSFER
-- ============================================================================
CREATE OR REPLACE FUNCTION receive_inventory_transfer(
    p_transfer_id UUID,
    p_items JSONB DEFAULT NULL, -- NULL = receive all, or specify with quantities
    p_received_by UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_transfer RECORD;
    v_item RECORD;
    v_receive_item JSONB;
    v_qty_to_receive NUMERIC;
    v_dest_inventory_id UUID;
    v_items_received INTEGER := 0;
BEGIN
    -- Get transfer details
    SELECT * INTO v_transfer FROM inventory_transfers WHERE id = p_transfer_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transfer not found');
    END IF;

    IF v_transfer.status IN ('received', 'cancelled') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transfer already ' || v_transfer.status);
    END IF;

    -- Process each transfer item
    FOR v_item IN
        SELECT * FROM inventory_transfer_items
        WHERE transfer_id = p_transfer_id
        AND status NOT IN ('received')
    LOOP
        -- Determine quantity to receive
        IF p_items IS NOT NULL THEN
            SELECT elem INTO v_receive_item
            FROM jsonb_array_elements(p_items) elem
            WHERE (elem->>'product_id')::UUID = v_item.product_id
            OR (elem->>'item_id')::UUID = v_item.id;

            IF v_receive_item IS NULL THEN
                CONTINUE;
            END IF;

            v_qty_to_receive := COALESCE((v_receive_item->>'quantity')::NUMERIC, v_item.quantity_sent);
        ELSE
            v_qty_to_receive := v_item.quantity_sent;
        END IF;

        -- Find or create destination inventory record
        SELECT id INTO v_dest_inventory_id
        FROM inventory
        WHERE product_id = v_item.product_id
        AND location_id = v_transfer.to_location_id;

        IF NOT FOUND THEN
            INSERT INTO inventory (product_id, location_id, store_id, quantity)
            VALUES (v_item.product_id, v_transfer.to_location_id, v_transfer.store_id, 0)
            RETURNING id INTO v_dest_inventory_id;
        END IF;

        -- Add to destination inventory
        UPDATE inventory
        SET quantity = quantity + v_qty_to_receive,
            updated_at = NOW()
        WHERE id = v_dest_inventory_id;

        -- Log adjustment
        INSERT INTO inventory_adjustments (
            inventory_id, product_id, location_id,
            adjustment_type, old_quantity, new_quantity, reason, created_by
        )
        SELECT
            v_dest_inventory_id, v_item.product_id, v_transfer.to_location_id,
            'TRANSFER_IN', inv.quantity - v_qty_to_receive, inv.quantity,
            'Transfer from ' || (SELECT name FROM locations WHERE id = v_transfer.from_location_id), p_received_by
        FROM inventory inv WHERE inv.id = v_dest_inventory_id;

        -- Update transfer item
        UPDATE inventory_transfer_items
        SET quantity_received = v_qty_to_receive,
            status = CASE
                WHEN v_qty_to_receive >= quantity_sent THEN 'received'
                WHEN v_qty_to_receive < quantity_sent THEN 'short'
                ELSE 'received'
            END,
            updated_at = NOW()
        WHERE id = v_item.id;

        v_items_received := v_items_received + 1;
    END LOOP;

    -- Update transfer status
    UPDATE inventory_transfers
    SET status = 'received',
        received_by = p_received_by,
        received_at = NOW(),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'items_received', v_items_received,
        'transfer_status', 'received'
    );
END;
$$;

-- ============================================================================
-- 9. Add new adjustment types
-- ============================================================================
-- Update the check constraint to include new types
DO $$
BEGIN
    -- Try to alter the constraint if it exists
    ALTER TABLE inventory_adjustments
    DROP CONSTRAINT IF EXISTS inventory_adjustments_adjustment_type_check;

    ALTER TABLE inventory_adjustments
    ADD CONSTRAINT inventory_adjustments_adjustment_type_check
    CHECK (adjustment_type IN (
        'DUST_CLEANUP', 'CYCLE_COUNT', 'MANUAL', 'SHRINKAGE',
        'THEFT', 'DAMAGE', 'WASTE', 'EXPIRED', 'AUTO_ZERO',
        'TRANSFER_IN', 'TRANSFER_OUT', 'PO_RECEIVE', 'SALE'
    ));
EXCEPTION
    WHEN others THEN
        -- Constraint might not exist, that's fine
        NULL;
END $$;

-- ============================================================================
-- 10. INDEXES for performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchase_orders_store ON purchase_orders(store_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_inventory_transfers_store ON inventory_transfers(store_id);
CREATE INDEX IF NOT EXISTS idx_inventory_transfers_status ON inventory_transfers(status);
CREATE INDEX IF NOT EXISTS idx_inventory_transfer_items_transfer ON inventory_transfer_items(transfer_id);

-- ============================================================================
-- 11. RLS Policies
-- ============================================================================
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_transfer_items ENABLE ROW LEVEL SECURITY;

-- Service role bypass
CREATE POLICY "Service role has full access to purchase_orders"
ON purchase_orders FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Service role has full access to purchase_order_items"
ON purchase_order_items FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Service role has full access to inventory_transfers"
ON inventory_transfers FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Service role has full access to inventory_transfer_items"
ON inventory_transfer_items FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================================================
-- SUCCESS
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE 'Inventory management tables and RPCs created successfully';
END $$;
