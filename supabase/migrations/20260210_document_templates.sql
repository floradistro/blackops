-- Document templates for any document type (CSV, JSON, text, markdown, HTML, PDF)
-- Templates store reusable structures with {{placeholder}} variables

CREATE TABLE IF NOT EXISTS document_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id),
  name TEXT NOT NULL,
  description TEXT,
  document_type TEXT NOT NULL CHECK (document_type IN ('csv', 'json', 'text', 'markdown', 'html', 'pdf')),
  content TEXT,                    -- Template body with {{placeholders}}
  headers TEXT[],                  -- For CSV: column headers
  schema JSONB DEFAULT '[]',       -- Field definitions: [{name, type, required, default, description}]
  metadata JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_templates_store ON document_templates(store_id);
CREATE INDEX IF NOT EXISTS idx_document_templates_type ON document_templates(document_type);
CREATE INDEX IF NOT EXISTS idx_document_templates_name ON document_templates(store_id, name);

ALTER TABLE document_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on document_templates"
  ON document_templates FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Store members can manage templates"
  ON document_templates FOR ALL
  USING (store_id IN (
    SELECT store_id FROM store_staff WHERE user_id = auth.uid()
  ) OR auth.uid() IS NULL);

-- Update ai_tool_registry: add comprehensive documents tool
INSERT INTO ai_tool_registry (name, category, description, definition, is_active, tool_mode)
VALUES (
  'documents',
  'documents',
  'Comprehensive document management. Create, find, delete documents of any type (CSV, JSON, text, markdown, HTML, PDF). Manage reusable templates. Generate documents from profiles.',
  '{
    "description": "Document management",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": ["create", "find", "delete", "create_template", "list_templates", "from_template", "list_stores", "list_profiles", "generate", "bulk_generate"],
          "description": "Action to perform"
        },
        "store_id": { "type": "string", "description": "Store UUID" },
        "store_name": { "type": "string", "description": "Store name (for searching)" },
        "document_type": { "type": "string", "description": "Document type: csv, json, text, markdown, html, pdf" },
        "name": { "type": "string", "description": "Document or template name" },
        "content": { "type": "string", "description": "Document content (text, markdown, HTML, JSON string)" },
        "headers": { "type": "array", "items": { "type": "string" }, "description": "CSV column headers" },
        "rows": { "type": "array", "description": "CSV rows as arrays or objects" },
        "data": { "type": "object", "description": "Data to fill template placeholders or document metadata" },
        "template_id": { "type": "string", "description": "Template UUID for from_template action" },
        "schema": { "type": "array", "description": "Template field definitions [{name, type, required, default}]" },
        "description": { "type": "string", "description": "Template or document description" },
        "profile_id": { "type": "string", "description": "Document profile UUID (for generate action)" },
        "product_name": { "type": "string", "description": "Product name for document header" },
        "strain": { "type": "string", "description": "Strain name" },
        "batch_id": { "type": "string", "description": "Batch/lot number" },
        "sample_size": { "type": "string", "description": "Sample size" },
        "products": { "type": "array", "description": "Products array for bulk_generate" },
        "limit": { "type": "integer", "description": "Limit results" },
        "confirm": { "type": "boolean", "description": "Confirm destructive actions" }
      },
      "required": ["action"]
    }
  }',
  true,
  'ops'
)
ON CONFLICT (name) DO UPDATE SET
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  definition = EXCLUDED.definition,
  is_active = EXCLUDED.is_active,
  tool_mode = EXCLUDED.tool_mode;
