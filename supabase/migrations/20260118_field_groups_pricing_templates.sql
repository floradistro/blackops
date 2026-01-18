-- Field Groups (Custom Field Definitions per Category)
CREATE TABLE IF NOT EXISTS public.field_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  -- Fields is an array of field definitions:
  -- { key: string, label: string, type: 'text'|'number'|'select'|'multiselect'|'boolean'|'date'|'url',
  --   required: boolean, options: string[], default_value: any, validation: object }
  fields JSONB NOT NULL DEFAULT '[]',
  -- Which categories this field group applies to (empty = all)
  category_ids UUID[] DEFAULT '{}',
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_field_groups_store ON public.field_groups(store_id, is_active);

-- Pricing Templates (Discount/Markup Rules)
CREATE TABLE IF NOT EXISTS public.pricing_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  -- Type: 'discount', 'markup', 'tiered', 'bundle', 'bogo'
  type TEXT NOT NULL CHECK (type IN ('discount', 'markup', 'tiered', 'bundle', 'bogo')),
  -- Rules contain the pricing logic:
  -- { percentage: number, fixed_amount: number, min_quantity: number,
  --   tiers: [{min_qty, max_qty, percentage}],
  --   applies_to: { categories: [], products: [], all: boolean } }
  rules JSONB NOT NULL DEFAULT '{}',
  -- Higher priority rules are evaluated first
  priority INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  -- Optional date range for limited-time promotions
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pricing_templates_store ON public.pricing_templates(store_id, is_active);
CREATE INDEX IF NOT EXISTS idx_pricing_templates_dates ON public.pricing_templates(starts_at, ends_at)
  WHERE starts_at IS NOT NULL OR ends_at IS NOT NULL;

-- Updated_at triggers
CREATE OR REPLACE FUNCTION update_field_groups_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS field_groups_updated_at ON public.field_groups;
CREATE TRIGGER field_groups_updated_at
  BEFORE UPDATE ON public.field_groups
  FOR EACH ROW
  EXECUTE FUNCTION update_field_groups_updated_at();

CREATE OR REPLACE FUNCTION update_pricing_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS pricing_templates_updated_at ON public.pricing_templates;
CREATE TRIGGER pricing_templates_updated_at
  BEFORE UPDATE ON public.pricing_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_pricing_templates_updated_at();

-- RLS Policies
ALTER TABLE public.field_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pricing_templates ENABLE ROW LEVEL SECURITY;

-- Field Groups: users can access their store's data
CREATE POLICY field_groups_select ON public.field_groups
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

CREATE POLICY field_groups_insert ON public.field_groups
  FOR INSERT TO authenticated
  WITH CHECK (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN platform_users pu ON s.owner_user_id = pu.id
      WHERE pu.auth_id = auth.uid()
    )
  );

CREATE POLICY field_groups_update ON public.field_groups
  FOR UPDATE TO authenticated
  USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN platform_users pu ON s.owner_user_id = pu.id
      WHERE pu.auth_id = auth.uid()
    )
  );

CREATE POLICY field_groups_delete ON public.field_groups
  FOR DELETE TO authenticated
  USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN platform_users pu ON s.owner_user_id = pu.id
      WHERE pu.auth_id = auth.uid()
    )
  );

-- Pricing Templates: users can access their store's data
CREATE POLICY pricing_templates_select ON public.pricing_templates
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

CREATE POLICY pricing_templates_insert ON public.pricing_templates
  FOR INSERT TO authenticated
  WITH CHECK (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN platform_users pu ON s.owner_user_id = pu.id
      WHERE pu.auth_id = auth.uid()
    )
  );

CREATE POLICY pricing_templates_update ON public.pricing_templates
  FOR UPDATE TO authenticated
  USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN platform_users pu ON s.owner_user_id = pu.id
      WHERE pu.auth_id = auth.uid()
    )
  );

CREATE POLICY pricing_templates_delete ON public.pricing_templates
  FOR DELETE TO authenticated
  USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN platform_users pu ON s.owner_user_id = pu.id
      WHERE pu.auth_id = auth.uid()
    )
  );

-- Grant permissions
GRANT ALL ON public.field_groups TO authenticated;
GRANT SELECT ON public.field_groups TO anon;
GRANT ALL ON public.pricing_templates TO authenticated;
GRANT SELECT ON public.pricing_templates TO anon;

-- Insert some sample data for Flora Distro (store_id: cd2e1122-d511-4edb-be5d-98ef274b4baf)
INSERT INTO public.field_groups (store_id, name, description, fields, category_ids, sort_order) VALUES
(
  'cd2e1122-d511-4edb-be5d-98ef274b4baf',
  'Cannabis Info',
  'THC/CBD percentages and strain information',
  '[
    {"key": "thc_percentage", "label": "THC %", "type": "number", "required": true},
    {"key": "cbd_percentage", "label": "CBD %", "type": "number", "required": false},
    {"key": "strain_type", "label": "Strain Type", "type": "select", "options": ["Indica", "Sativa", "Hybrid"], "required": true},
    {"key": "terpenes", "label": "Terpenes", "type": "multiselect", "options": ["Myrcene", "Limonene", "Caryophyllene", "Pinene", "Linalool", "Humulene"]}
  ]'::jsonb,
  '{}',
  1
),
(
  'cd2e1122-d511-4edb-be5d-98ef274b4baf',
  'Product Dimensions',
  'Weight and size information',
  '[
    {"key": "weight", "label": "Weight (g)", "type": "number", "required": true},
    {"key": "length", "label": "Length (cm)", "type": "number"},
    {"key": "width", "label": "Width (cm)", "type": "number"},
    {"key": "height", "label": "Height (cm)", "type": "number"}
  ]'::jsonb,
  '{}',
  2
);

INSERT INTO public.pricing_templates (store_id, name, description, type, rules, priority) VALUES
(
  'cd2e1122-d511-4edb-be5d-98ef274b4baf',
  'Wholesale Discount',
  '30% off for wholesale customers',
  'discount',
  '{"percentage": -30, "applies_to": {"all": true}}'::jsonb,
  10
),
(
  'cd2e1122-d511-4edb-be5d-98ef274b4baf',
  'Bulk Pricing',
  'Tiered pricing for bulk orders',
  'tiered',
  '{
    "tiers": [
      {"min_qty": 1, "max_qty": 9, "percentage": 0},
      {"min_qty": 10, "max_qty": 49, "percentage": -10},
      {"min_qty": 50, "max_qty": 99, "percentage": -20},
      {"min_qty": 100, "percentage": -30}
    ],
    "applies_to": {"all": true}
  }'::jsonb,
  5
);
