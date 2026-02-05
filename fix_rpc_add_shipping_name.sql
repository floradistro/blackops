-- Fix get_orders_for_location RPC to include shipping_name field
-- This is why iOS isn't showing customer names - the RPC doesn't return the field!

CREATE OR REPLACE FUNCTION public.get_orders_for_location(
  p_store_id uuid,
  p_location_id uuid,
  p_status_group text DEFAULT NULL::text,
  p_order_type text DEFAULT NULL::text,
  p_payment_status text DEFAULT NULL::text,
  p_search text DEFAULT NULL::text,
  p_date_start timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_date_end timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_amount_min numeric DEFAULT NULL::numeric,
  p_amount_max numeric DEFAULT NULL::numeric,
  p_online_only boolean DEFAULT false,
  p_limit integer DEFAULT 200
)
RETURNS TABLE(order_data jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_status_filters TEXT[];
BEGIN
  IF p_status_group IS NOT NULL THEN
    CASE p_status_group
      WHEN 'active' THEN v_status_filters := ARRAY['pending', 'processing', 'confirmed'];
      WHEN 'in_progress' THEN v_status_filters := ARRAY['ready_for_pickup', 'out_for_delivery', 'in_transit'];
      WHEN 'completed' THEN v_status_filters := ARRAY['completed', 'delivered'];
      WHEN 'cancelled' THEN v_status_filters := ARRAY['cancelled', 'refunded'];
      ELSE v_status_filters := NULL;
    END CASE;
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
      'id', o.id,
      'order_number', o.order_number,
      'store_id', o.store_id,
      'location_id', o.location_id,
      'customer_id', o.customer_id,
      'status', o.status,
      'order_type', o.order_type,
      'payment_status', o.payment_status,
      'subtotal', o.subtotal,
      'tax_amount', o.tax_amount,
      'discount_amount', o.discount_amount,
      'total_amount', o.total_amount,
      'shipping_name', o.shipping_name,  -- ✅ ADDED - Customer name for display
      'created_at', o.created_at,
      'updated_at', o.updated_at,
      'items', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
              'id', oi.id,
              'product_id', oi.product_id,
              'product_name', p.name,
              'quantity', oi.quantity,
              'unit_price', oi.unit_price,
              'total', oi.line_total,
              'tier_label', oi.tier_name,
              'variant_name', oi.meta_data->>'variant_name'
            ))
          FROM order_items oi
          LEFT JOIN products p ON p.id = oi.product_id
          WHERE oi.order_id = o.id
        ), '[]'::jsonb),
      'location', CASE
        WHEN l.id IS NOT NULL THEN jsonb_build_object('id', l.id, 'name', l.name, 'store_id', l.store_id)
        ELSE NULL
      END
    ) AS order_data
  FROM orders o
  LEFT JOIN locations l ON l.id = o.location_id
  WHERE o.store_id = p_store_id
    AND o.location_id = p_location_id
    AND (p_status_group IS NULL OR o.status = ANY(v_status_filters))
    AND (p_order_type IS NULL OR o.order_type = p_order_type)
    AND (p_payment_status IS NULL OR o.payment_status = p_payment_status)
    AND (p_search IS NULL OR o.order_number ILIKE '%' || p_search || '%')
    AND (p_date_start IS NULL OR o.created_at >= p_date_start)
    AND (p_date_end IS NULL OR o.created_at <= p_date_end)
    AND (p_amount_min IS NULL OR o.total_amount >= p_amount_min)
    AND (p_amount_max IS NULL OR o.total_amount <= p_amount_max)
    AND (NOT p_online_only OR o.order_type IN ('pickup', 'shipping'))
  ORDER BY o.created_at DESC
  LIMIT p_limit;
END;
$function$;

\echo '✅ RPC updated to include shipping_name field'
\echo '   iOS app will now receive customer names'
\echo '   Restart iOS app to see customer names'
