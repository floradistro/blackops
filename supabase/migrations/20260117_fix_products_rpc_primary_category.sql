-- Fix get_products_for_location RPC to include primary_category_id
-- This allows menu displays to filter products by their primary category
-- (e.g., Edibles, Day Drinker, Golden Hour, Darkside, Riptide)

DROP FUNCTION IF EXISTS public.get_products_for_location(uuid, text, boolean);

CREATE OR REPLACE FUNCTION public.get_products_for_location(p_location_id uuid, p_category_name text DEFAULT NULL::text, p_in_stock_only boolean DEFAULT false)
RETURNS TABLE(
    id uuid,
    name text,
    slug text,
    description text,
    sku text,
    regular_price numeric,
    sale_price numeric,
    price numeric,
    category_id uuid,
    category_name text,
    featured_image text,
    quantity numeric,
    stock_status text,
    is_in_stock boolean,
    custom_fields jsonb,
    primary_category_id uuid
)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        pbl.product_id as id,
        pbl.product_name as name,
        p.slug,
        p.description,
        pbl.product_sku as sku,
        pbl.regular_price,
        pbl.sale_price,
        pbl.current_price as price,
        pbl.category_id,
        pbl.category_name,
        pbl.featured_image,
        pbl.quantity_on_hand as quantity,
        pbl.stock_status,
        NOT pbl.is_out_of_stock as is_in_stock,
        p.custom_fields,
        p.primary_category_id
    FROM proj_products_by_location pbl
    JOIN products p ON p.id = pbl.product_id
    WHERE pbl.location_id = p_location_id
    AND (p_category_name IS NULL OR pbl.category_name ILIKE p_category_name)
    AND (NOT p_in_stock_only OR NOT pbl.is_out_of_stock)
    ORDER BY pbl.category_name, pbl.product_name;
$function$;

COMMENT ON FUNCTION public.get_products_for_location IS 'Get products with inventory for a specific location. Now includes primary_category_id for menu filtering.';
