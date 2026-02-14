-- Migration: Upgrade products tool to v2
-- Full catalog management: products, categories, field schemas, pricing schemas, catalogs, assignments
-- All configurable via agent using a single powerful tool

UPDATE ai_tool_registry
SET
  description = 'Full product catalog management. Create/update/delete products with field values and pricing. Manage categories, field schemas, pricing schemas, catalogs, and schema assignments. Single tool for all catalog operations.',
  definition = '{
    "name": "products",
    "description": "Full product catalog management. Products, categories, field schemas, pricing schemas, catalogs, and schema assignments.",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "The catalog action to perform",
          "enum": [
            "find", "get", "create", "update", "delete",
            "list_categories", "get_category", "create_category", "update_category", "delete_category",
            "list_field_schemas", "get_field_schema", "create_field_schema", "update_field_schema", "delete_field_schema",
            "list_pricing_schemas", "get_pricing_schema", "create_pricing_schema", "update_pricing_schema", "delete_pricing_schema",
            "list_catalogs", "create_catalog", "update_catalog",
            "assign_schema", "unassign_schema"
          ]
        },
        "product_id": {
          "type": "string",
          "description": "Product UUID (for get, update, delete)"
        },
        "category_id": {
          "type": "string",
          "description": "Category UUID (for get_category, update_category, delete_category)"
        },
        "field_schema_id": {
          "type": "string",
          "description": "Field schema UUID (for get_field_schema, update_field_schema, delete_field_schema)"
        },
        "pricing_schema_id": {
          "type": "string",
          "description": "Pricing schema UUID (for get_pricing_schema, update_pricing_schema, delete_pricing_schema, or assign to product)"
        },
        "catalog_id": {
          "type": "string",
          "description": "Catalog UUID (for update_catalog, or filter by catalog)"
        },
        "query": {
          "type": "string",
          "description": "Search query for find (matches name, sku, description)"
        },
        "name": {
          "type": "string",
          "description": "Name for create/update (product, category, schema, catalog)"
        },
        "sku": {
          "type": "string",
          "description": "Product SKU"
        },
        "description": {
          "type": "string",
          "description": "Description text"
        },
        "short_description": {
          "type": "string",
          "description": "Short product description"
        },
        "category": {
          "type": "string",
          "description": "Category name or UUID (for product create/update, or find filter)"
        },
        "status": {
          "type": "string",
          "description": "Product status (published, draft, archived)"
        },
        "type": {
          "type": "string",
          "description": "Product type (simple, variable, grouped)"
        },
        "cost_price": {
          "type": "number",
          "description": "Cost/purchase price per unit"
        },
        "wholesale_price": {
          "type": "number",
          "description": "Wholesale price"
        },
        "stock_quantity": {
          "type": "number",
          "description": "Stock quantity"
        },
        "manage_stock": {
          "type": "boolean",
          "description": "Whether to track inventory"
        },
        "featured": {
          "type": "boolean",
          "description": "Featured product flag"
        },
        "weight": {
          "type": "number",
          "description": "Product weight"
        },
        "tax_status": {
          "type": "string",
          "description": "Tax status (taxable, none)"
        },
        "tax_class": {
          "type": "string",
          "description": "Tax class"
        },
        "is_wholesale": {
          "type": "boolean",
          "description": "Available for wholesale"
        },
        "wholesale_only": {
          "type": "boolean",
          "description": "Wholesale-only product"
        },
        "minimum_wholesale_quantity": {
          "type": "number",
          "description": "Minimum wholesale order quantity"
        },
        "featured_image": {
          "type": "string",
          "description": "Featured image URL"
        },
        "field_values": {
          "type": "object",
          "description": "Custom field values as {key: value} (e.g. {thca_percentage: 25.5, strain_type: \"Hybrid\"})"
        },
        "pricing_data": {
          "type": "object",
          "description": "Embedded pricing config: {mode: \"single\"|\"tiered\", single_price: number, tiers: [{id, label, quantity, unit, price, enabled}]}"
        },
        "fields": {
          "type": "array",
          "description": "Field definitions for create/update_field_schema: [{key, label, type, required, options, unit, validation}]"
        },
        "tiers": {
          "type": "array",
          "description": "Pricing tiers for create/update_pricing_schema: [{id, label, quantity, unit, price, enabled}]"
        },
        "quality_tier": {
          "type": "string",
          "description": "Quality tier label for pricing schema"
        },
        "icon": {
          "type": "string",
          "description": "SF Symbol icon name (for category or schema)"
        },
        "parent_id": {
          "type": "string",
          "description": "Parent category UUID"
        },
        "display_order": {
          "type": "integer",
          "description": "Sort order for categories/catalogs"
        },
        "is_active": {
          "type": "boolean",
          "description": "Active flag for categories/schemas"
        },
        "is_public": {
          "type": "boolean",
          "description": "Public visibility for schemas"
        },
        "is_default": {
          "type": "boolean",
          "description": "Default catalog flag"
        },
        "vertical": {
          "type": "string",
          "description": "Catalog vertical (cannabis, real_estate, retail)"
        },
        "settings": {
          "type": "object",
          "description": "Catalog-specific settings"
        },
        "field_schema_ids": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Array of field schema UUIDs to assign on create"
        },
        "pricing_schema_ids": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Array of pricing schema UUIDs to assign on create"
        },
        "target": {
          "type": "string",
          "enum": ["category", "product"],
          "description": "Assignment target (for assign_schema/unassign_schema)"
        },
        "schema_type": {
          "type": "string",
          "enum": ["field", "pricing"],
          "description": "Schema type (for assign_schema/unassign_schema)"
        },
        "target_id": {
          "type": "string",
          "description": "Target UUID (category or product ID for assign_schema)"
        },
        "schema_id": {
          "type": "string",
          "description": "Schema UUID to assign/unassign"
        },
        "sort_order": {
          "type": "integer",
          "description": "Sort order for schema assignment"
        },
        "active_only": {
          "type": "boolean",
          "description": "Filter to active-only categories (default true)"
        },
        "public_only": {
          "type": "boolean",
          "description": "Filter to public-only schemas"
        },
        "hard": {
          "type": "boolean",
          "description": "Hard delete (true) vs soft archive (false, default)"
        },
        "limit": {
          "type": "integer",
          "description": "Max results to return (default varies by action)"
        }
      },
      "required": ["action"]
    }
  }'::jsonb,
  is_read_only = false,
  tool_mode = 'ops'
WHERE name = 'products';
