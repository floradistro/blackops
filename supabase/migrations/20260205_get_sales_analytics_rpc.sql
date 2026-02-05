-- RPC function for analytics that aggregates in SQL (bypasses row limits)
-- This is much faster than fetching all rows to the client

CREATE OR REPLACE FUNCTION get_sales_analytics(
  p_store_id uuid DEFAULT NULL,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_location_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'grossSales', COALESCE(SUM(gross_sales), 0)::numeric(12,2),
    'netSales', COALESCE(SUM(net_sales), 0)::numeric(12,2),
    'totalRevenue', COALESCE(SUM(total_revenue), 0)::numeric(12,2),
    'totalCogs', COALESCE(SUM(total_cogs), 0)::numeric(12,2),
    'totalProfit', COALESCE(SUM(total_profit), 0)::numeric(12,2),
    'taxAmount', COALESCE(SUM(total_tax), 0)::numeric(12,2),
    'discountAmount', COALESCE(SUM(total_discounts), 0)::numeric(12,2),
    'shippingAmount', COALESCE(SUM(total_shipping), 0)::numeric(12,2),
    'totalOrders', COALESCE(SUM(order_count), 0),
    'completedOrders', COALESCE(SUM(completed_orders), 0),
    'cancelledOrders', COALESCE(SUM(cancelled_orders), 0),
    'uniqueCustomers', COALESCE(SUM(unique_customers), 0),
    'totalQuantity', COALESCE(SUM(quantity_sold), 0),
    'rowCount', COUNT(*),
    'dateRange', jsonb_build_object(
      'from', MIN(sale_date),
      'to', MAX(sale_date),
      'days', COUNT(DISTINCT sale_date)
    )
  ) INTO result
  FROM v_daily_sales
  WHERE (p_store_id IS NULL OR store_id = p_store_id)
    AND (p_start_date IS NULL OR sale_date >= p_start_date)
    AND (p_end_date IS NULL OR sale_date <= p_end_date)
    AND (p_location_id IS NULL OR location_id = p_location_id);

  -- Add calculated metrics
  result := result || jsonb_build_object(
    'avgOrderValue', CASE
      WHEN (result->>'totalOrders')::int > 0
      THEN ROUND(((result->>'netSales')::numeric / (result->>'totalOrders')::int)::numeric, 2)
      ELSE 0
    END,
    'profitMargin', CASE
      WHEN (result->>'netSales')::numeric > 0
      THEN ROUND((((result->>'totalProfit')::numeric / (result->>'netSales')::numeric) * 100)::numeric, 2)
      ELSE 0
    END,
    'avgDailyRevenue', CASE
      WHEN (result->'dateRange'->>'days')::int > 0
      THEN ROUND(((result->>'netSales')::numeric / (result->'dateRange'->>'days')::int)::numeric, 2)
      ELSE 0
    END,
    'avgDailyOrders', CASE
      WHEN (result->'dateRange'->>'days')::int > 0
      THEN ROUND(((result->>'totalOrders')::numeric / (result->'dateRange'->>'days')::int)::numeric, 1)
      ELSE 0
    END
  );

  RETURN result;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_sales_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_sales_analytics TO service_role;
