-- Fix v_daily_sales view COGS calculation
--
-- BUG: The view was using SUM(cost_per_unit * quantity) for COGS
-- but cost_per_unit is actually the TOTAL line cost (not per-unit cost)
-- This caused COGS to be multiplied by quantity, making it way too high
-- Result: Profit showed as negative because COGS > Revenue
--
-- FIX: Use SUM(cost_per_unit) directly since it already represents total line COGS
-- DEPLOYED: 2026-02-05

CREATE OR REPLACE VIEW v_daily_sales AS
SELECT o.store_id,
   o.channel,
   date(o.order_date) AS sale_date,
   o.location_id,
   o.payment_method,
   o.employee_id,
   count(DISTINCT o.id) AS order_count,
   sum(o.subtotal) AS gross_sales,
   sum(o.discount_amount) AS total_discounts,
   sum(o.total_amount) AS net_sales,
   sum(o.tax_amount) AS total_tax,
   sum(o.shipping_amount) AS total_shipping,
   avg(o.total_amount) AS avg_order_value,
   count(DISTINCT
       CASE
           WHEN o.status = 'completed'::text THEN o.id
           ELSE NULL::uuid
       END) AS completed_orders,
   count(DISTINCT
       CASE
           WHEN o.status = 'cancelled'::text THEN o.id
           ELSE NULL::uuid
       END) AS cancelled_orders,
   count(DISTINCT o.customer_id) AS unique_customers,
   sum(o.total_amount) AS total_revenue,
   -- FIX: cost_per_unit is already total line cost, don't multiply by quantity
   COALESCE(sum(oi_agg.total_cogs), 0::numeric) AS total_cogs,
   sum(o.total_amount) - COALESCE(sum(oi_agg.total_cogs), 0::numeric) AS total_profit,
   COALESCE(sum(oi_agg.quantity_sold), 0::numeric) AS quantity_sold
  FROM orders o
    LEFT JOIN ( SELECT order_items.order_id,
           -- FIXED: Just sum cost_per_unit (it's already total line COGS)
           sum(order_items.cost_per_unit) AS total_cogs,
           sum(order_items.quantity) AS quantity_sold
          FROM order_items
         GROUP BY order_items.order_id) oi_agg ON oi_agg.order_id = o.id
 WHERE (o.status <> ALL (ARRAY['pending'::text, 'cancelled'::text, 'failed'::text])) AND o.payment_status = 'paid'::text
 GROUP BY o.store_id, o.channel, (date(o.order_date)), o.location_id, o.payment_method, o.employee_id;

-- Ensure grants are in place
GRANT SELECT ON v_daily_sales TO authenticated;
GRANT SELECT ON v_daily_sales TO service_role;
GRANT SELECT ON v_daily_sales TO anon;
