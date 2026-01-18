-- Create default "Distro" catalog for Flora Distro and assign all orphan categories
-- Run this once to migrate existing data to the catalog system

-- Create the default catalog
INSERT INTO catalogs (store_id, name, slug, vertical, is_default, is_active, description)
SELECT
    id as store_id,
    'Distro' as name,
    'distro' as slug,
    'cannabis' as vertical,
    true as is_default,
    true as is_active,
    'Main product catalog' as description
FROM stores
WHERE store_name = 'Flora Distro'
ON CONFLICT (store_id, slug) DO NOTHING;

-- Assign all categories without a catalog to the new Distro catalog
UPDATE categories
SET catalog_id = c.id
FROM catalogs c
JOIN stores s ON c.store_id = s.id
WHERE s.store_name = 'Flora Distro'
  AND c.slug = 'distro'
  AND categories.store_id = s.id
  AND categories.catalog_id IS NULL;

-- Verify
SELECT
    cat.name as catalog_name,
    COUNT(categories.id) as category_count
FROM catalogs cat
LEFT JOIN categories ON categories.catalog_id = cat.id
GROUP BY cat.name;
