-- Add COA (Certificate of Analysis) tools to ai_tool_registry

INSERT INTO ai_tool_registry (name, category, description, parameters, is_active, tool_mode)
VALUES
  (
    'generate_coa',
    'coa',
    'Generate a Certificate of Analysis (COA) for a product. Supports both cannabis and peptide COAs.',
    '{
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["cannabis", "peptide"],
          "description": "Type of COA to generate"
        },
        "product_data": {
          "type": "object",
          "description": "Product information for COA generation",
          "properties": {
            "name": { "type": "string" },
            "slug": { "type": "string" },
            "sequence": { "type": "string" },
            "molecular_weight": { "type": "string" },
            "molecular_formula": { "type": "string" },
            "purity": { "type": "string" },
            "lot_number": { "type": "string" },
            "batch_id": { "type": "string" },
            "catalog_number": { "type": "string" }
          }
        },
        "options": {
          "type": "object",
          "description": "Additional options for COA generation"
        }
      },
      "required": ["type", "product_data"]
    }',
    true,
    'generation'
  ),
  (
    'coa_list',
    'coa',
    'List all COAs for a store',
    '{
      "type": "object",
      "properties": {
        "limit": { "type": "integer", "default": 50 },
        "offset": { "type": "integer", "default": 0 }
      }
    }',
    true,
    'ops'
  ),
  (
    'coa_get_url',
    'coa',
    'Get the public URL for a COA PDF',
    '{
      "type": "object",
      "properties": {
        "filename": { "type": "string", "description": "Name of the COA PDF file" }
      },
      "required": ["filename"]
    }',
    true,
    'ops'
  ),
  (
    'generate_peptide_coa',
    'coa',
    'Generate a peptide-specific Certificate of Analysis with HPLC purity, mass spec, and sequence data',
    '{
      "type": "object",
      "properties": {
        "name": { "type": "string", "description": "Product name" },
        "slug": { "type": "string", "description": "URL-friendly product slug" },
        "sequence": { "type": "string", "description": "Amino acid sequence" },
        "molecular_weight": { "type": "string", "description": "Molecular weight in Da" },
        "molecular_formula": { "type": "string", "description": "Chemical formula" },
        "purity": { "type": "string", "description": "Expected purity percentage" }
      },
      "required": ["name", "slug"]
    }',
    true,
    'generation'
  ),
  (
    'generate_cannabis_coa',
    'coa',
    'Generate a cannabis-specific Certificate of Analysis with cannabinoid profile and terpene data',
    '{
      "type": "object",
      "properties": {
        "name": { "type": "string", "description": "Sample name" },
        "strain": { "type": "string", "description": "Strain name" },
        "batch_id": { "type": "string", "description": "Batch identifier" },
        "sample_type": { "type": "string", "enum": ["Flower", "Concentrate", "Edible", "Tincture"] },
        "thc_total": { "type": "number", "description": "Total THC percentage" },
        "cbd_total": { "type": "number", "description": "Total CBD percentage" }
      },
      "required": ["name"]
    }',
    true,
    'generation'
  )
ON CONFLICT (name) DO UPDATE SET
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  parameters = EXCLUDED.parameters,
  is_active = EXCLUDED.is_active,
  tool_mode = EXCLUDED.tool_mode;

-- Add comment
COMMENT ON TABLE ai_tool_registry IS 'Registry of all AI/MCP tools available in the platform. COA tools added for certificate generation.';
