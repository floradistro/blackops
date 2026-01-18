-- Catalogs table: Top-level container for different business verticals
-- Each store can have multiple catalogs (e.g., Cannabis, Real Estate, etc.)
-- Categories, products, pricing templates cascade from the catalog

CREATE TABLE IF NOT EXISTS public.catalogs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    vertical VARCHAR(100), -- 'cannabis', 'real_estate', 'retail', etc.
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false, -- One catalog can be the default for the store
    settings JSONB DEFAULT '{}', -- Vertical-specific configuration
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(store_id, slug)
);

-- Add catalog_id to categories (nullable for backward compatibility)
ALTER TABLE public.categories
ADD COLUMN IF NOT EXISTS catalog_id UUID REFERENCES public.catalogs(id) ON DELETE SET NULL;

-- Add catalog_id to pricing_tier_templates if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'pricing_tier_templates') THEN
        ALTER TABLE public.pricing_tier_templates
        ADD COLUMN IF NOT EXISTS catalog_id UUID REFERENCES public.catalogs(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_catalogs_store_id ON public.catalogs(store_id);
CREATE INDEX IF NOT EXISTS idx_catalogs_vertical ON public.catalogs(vertical);
CREATE INDEX IF NOT EXISTS idx_categories_catalog_id ON public.categories(catalog_id);

-- RLS Policies
ALTER TABLE public.catalogs ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read catalogs for stores they have access to
CREATE POLICY catalogs_select ON public.catalogs
    FOR SELECT TO authenticated
    USING (
        store_id IN (
            SELECT s.id FROM stores s
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
        OR
        store_id IN (
            SELECT store_id FROM store_staff ss
            JOIN platform_users pu ON ss.user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Allow insert for store owners/staff
CREATE POLICY catalogs_insert ON public.catalogs
    FOR INSERT TO authenticated
    WITH CHECK (
        store_id IN (
            SELECT s.id FROM stores s
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Allow update for store owners/staff
CREATE POLICY catalogs_update ON public.catalogs
    FOR UPDATE TO authenticated
    USING (
        store_id IN (
            SELECT s.id FROM stores s
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Allow delete for store owners
CREATE POLICY catalogs_delete ON public.catalogs
    FOR DELETE TO authenticated
    USING (
        store_id IN (
            SELECT s.id FROM stores s
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Grant permissions
GRANT ALL ON public.catalogs TO authenticated;
GRANT SELECT ON public.catalogs TO anon;

-- Function to ensure only one default catalog per store
CREATE OR REPLACE FUNCTION ensure_single_default_catalog()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_default = true THEN
        UPDATE public.catalogs
        SET is_default = false
        WHERE store_id = NEW.store_id AND id != NEW.id AND is_default = true;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ensure_single_default_catalog_trigger ON public.catalogs;
CREATE TRIGGER ensure_single_default_catalog_trigger
    BEFORE INSERT OR UPDATE ON public.catalogs
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_default_catalog();

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_catalogs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS catalogs_updated_at ON public.catalogs;
CREATE TRIGGER catalogs_updated_at
    BEFORE UPDATE ON public.catalogs
    FOR EACH ROW
    EXECUTE FUNCTION update_catalogs_updated_at();
