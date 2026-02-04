-- Consolidated Tool Registry Update
-- Following Anthropic's best practices: 39 tools → 14 consolidated tools
-- "More tools don't always lead to better outcomes"
-- "Claude Code uses about a dozen tools"

-- First, deactivate all old tools
UPDATE ai_tool_registry SET is_active = false;

-- Delete old tools (optional - you can keep them inactive for history)
-- DELETE FROM ai_tool_registry;

-- Insert consolidated tools
INSERT INTO ai_tool_registry (name, description, definition, is_active) VALUES

-- 1. INVENTORY - Unified inventory management
('inventory', 'Manage inventory: adjust quantities, set stock levels, transfer between locations, bulk operations', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["adjust", "set", "transfer", "bulk_adjust", "bulk_set", "bulk_clear"],
        "description": "Action to perform"
      },
      "product_id": {"type": "string", "description": "Product ID"},
      "location_id": {"type": "string", "description": "Location ID"},
      "inventory_id": {"type": "string", "description": "Inventory record ID (alternative to product_id+location_id)"},
      "quantity": {"type": "number", "description": "Quantity for set/transfer actions"},
      "adjustment": {"type": "number", "description": "Quantity change (+/-) for adjust action"},
      "reason": {"type": "string", "description": "Reason for adjustment"},
      "from_location_id": {"type": "string", "description": "Source location for transfer"},
      "to_location_id": {"type": "string", "description": "Destination location for transfer"},
      "adjustments": {"type": "array", "description": "Array of adjustments for bulk_adjust"},
      "items": {"type": "array", "description": "Array of items for bulk_set"}
    },
    "required": ["action"]
  }
}'::jsonb, true),

-- 2. INVENTORY_QUERY - Query inventory data
('inventory_query', 'Query inventory: get summary, check stock levels, view velocity, inventory by location', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["summary", "velocity", "by_location", "in_stock"],
        "default": "summary",
        "description": "Query type"
      },
      "location_id": {"type": "string", "description": "Filter by location"},
      "days": {"type": "number", "default": 30, "description": "Days for velocity calculation"}
    }
  }
}'::jsonb, true),

-- 3. INVENTORY_AUDIT - Audit workflow
('inventory_audit', 'Inventory audit workflow: start audit, record counts, complete audit, view summary', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["start", "count", "complete", "summary"],
        "description": "Audit action"
      },
      "location_id": {"type": "string", "description": "Location being audited"},
      "product_id": {"type": "string", "description": "Product being counted"},
      "counted": {"type": "number", "description": "Counted quantity"}
    },
    "required": ["action"]
  }
}'::jsonb, true),

-- 4. COLLECTIONS - Manage collections
('collections', 'Manage collections: find, create, update themes and icons', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["find", "create", "get_theme", "set_theme", "set_icon"],
        "default": "find",
        "description": "Action to perform"
      },
      "name": {"type": "string", "description": "Collection name (for find/create)"},
      "description": {"type": "string", "description": "Collection description (for create)"},
      "collection_id": {"type": "string", "description": "Collection ID (for theme/icon operations)"},
      "theme": {"type": "object", "description": "Theme settings (for set_theme)"},
      "icon": {"type": "string", "description": "Icon name (for set_icon)"}
    }
  }
}'::jsonb, true),

-- 5. CUSTOMERS - Manage customers
('customers', 'Manage customers: find/search, create new, update existing', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["find", "create", "update"],
        "default": "find",
        "description": "Action to perform"
      },
      "query": {"type": "string", "description": "Search query (name, email, phone)"},
      "email": {"type": "string", "description": "Customer email"},
      "phone": {"type": "string", "description": "Customer phone"},
      "first_name": {"type": "string", "description": "First name"},
      "last_name": {"type": "string", "description": "Last name"},
      "customer_id": {"type": "string", "description": "Customer ID (for update)"},
      "loyalty_points": {"type": "number", "description": "Loyalty points (for update)"},
      "limit": {"type": "number", "default": 20, "description": "Max results for find"}
    }
  }
}'::jsonb, true),

-- 6. PRODUCTS - Manage products
('products', 'Manage products: find/search, create new, update existing, view pricing templates', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["find", "create", "update", "pricing_templates"],
        "default": "find",
        "description": "Action to perform"
      },
      "query": {"type": "string", "description": "Search query (name, SKU, brand)"},
      "product_id": {"type": "string", "description": "Product ID (for update)"},
      "name": {"type": "string", "description": "Product name"},
      "sku": {"type": "string", "description": "Product SKU"},
      "category": {"type": "string", "description": "Product category"},
      "brand": {"type": "string", "description": "Product brand"},
      "base_price": {"type": "number", "description": "Base price"},
      "status": {"type": "string", "description": "Product status"},
      "limit": {"type": "number", "default": 20, "description": "Max results for find"}
    }
  }
}'::jsonb, true),

-- 7. ANALYTICS - Unified analytics
('analytics', 'Analytics and reporting: sales summary, by location, detailed reports, data discovery, employee stats', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["summary", "by_location", "detailed", "discover", "employee"],
        "default": "summary",
        "description": "Report type"
      },
      "period": {
        "type": "string",
        "enum": ["today", "yesterday", "last_7", "last_30", "last_90", "ytd", "mtd"],
        "default": "last_30",
        "description": "Time period for report"
      },
      "location_id": {"type": "string", "description": "Filter by location"}
    }
  }
}'::jsonb, true),

-- 8. LOCATIONS - Find locations
('locations', 'Find and list store locations', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "name": {"type": "string", "description": "Search by location name"},
      "is_active": {"type": "boolean", "description": "Filter by active status"}
    }
  }
}'::jsonb, true),

-- 9. ORDERS - Manage orders
('orders', 'Manage orders: find/list, get details, view purchase orders', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["find", "get", "purchase_orders"],
        "default": "find",
        "description": "Action to perform"
      },
      "order_id": {"type": "string", "description": "Order ID (for get)"},
      "status": {"type": "string", "description": "Filter by status (for find)"},
      "customer_id": {"type": "string", "description": "Filter by customer (for find)"},
      "limit": {"type": "number", "default": 50, "description": "Max results for find"}
    }
  }
}'::jsonb, true),

-- 10. SUPPLIERS - Find suppliers
('suppliers', 'Find and list suppliers', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "name": {"type": "string", "description": "Search by supplier name"}
    }
  }
}'::jsonb, true),

-- 11. EMAIL - Unified email tool
('email', 'Send emails, use templates, list sent emails, view email details', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["send", "send_template", "list", "get", "templates"],
        "description": "Email action"
      },
      "to": {"type": "string", "description": "Recipient email (for send/send_template)"},
      "subject": {"type": "string", "description": "Email subject (for send)"},
      "html": {"type": "string", "description": "HTML body (for send)"},
      "text": {"type": "string", "description": "Plain text body (for send)"},
      "template": {"type": "string", "description": "Template slug (for send_template)"},
      "template_data": {"type": "object", "description": "Template variables (for send_template)"},
      "email_id": {"type": "string", "description": "Email ID (for get)"},
      "limit": {"type": "number", "default": 50, "description": "Max results for list"}
    },
    "required": ["action"]
  }
}'::jsonb, true),

-- 12. DOCUMENTS - Document generation
('documents', 'Generate documents like COAs (Certificates of Analysis)', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {"type": "string", "description": "Document action"},
      "product_id": {"type": "string", "description": "Product ID"},
      "template": {"type": "string", "description": "Document template"}
    }
  }
}'::jsonb, true),

-- 13. ALERTS - System alerts
('alerts', 'Get system alerts: low stock warnings, pending orders', '{
  "input_schema": {
    "type": "object",
    "properties": {}
  }
}'::jsonb, true),

-- 14. AUDIT_TRAIL - View audit logs
('audit_trail', 'View system audit logs and activity history', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "limit": {"type": "number", "default": 50, "description": "Max results"}
    }
  }
}'::jsonb, true),

-- 15. PURCHASE_ORDERS - Full purchase order management
('purchase_orders', 'Manage purchase orders: create, list, get details, add items, approve, receive inventory, cancel', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["create", "list", "get", "add_items", "approve", "receive", "cancel"],
        "description": "Action to perform"
      },
      "purchase_order_id": {"type": "string", "description": "PO ID (for get/add_items/approve/receive/cancel)"},
      "supplier_id": {"type": "string", "description": "Supplier ID (for create)"},
      "location_id": {"type": "string", "description": "Destination location ID (for create/receive)"},
      "items": {
        "type": "array",
        "description": "Items array [{product_id, quantity, unit_cost}] for create/add_items, or [{product_id, quantity}] for receive",
        "items": {
          "type": "object",
          "properties": {
            "product_id": {"type": "string"},
            "quantity": {"type": "number"},
            "unit_cost": {"type": "number"}
          }
        }
      },
      "notes": {"type": "string", "description": "Notes for the PO"},
      "expected_delivery_date": {"type": "string", "description": "Expected delivery date (YYYY-MM-DD)"},
      "status": {"type": "string", "description": "Filter by status (for list)"},
      "limit": {"type": "number", "default": 50, "description": "Max results for list"}
    },
    "required": ["action"]
  }
}'::jsonb, true),

-- 16. TRANSFERS - Inventory transfers between locations
('transfers', 'Transfer inventory between locations: create transfer, list, get details, receive at destination, cancel', '{
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["create", "list", "get", "receive", "cancel"],
        "description": "Action to perform"
      },
      "transfer_id": {"type": "string", "description": "Transfer ID (for get/receive/cancel)"},
      "from_location_id": {"type": "string", "description": "Source location ID (for create)"},
      "to_location_id": {"type": "string", "description": "Destination location ID (for create)"},
      "items": {
        "type": "array",
        "description": "Items to transfer [{product_id, quantity}]",
        "items": {
          "type": "object",
          "properties": {
            "product_id": {"type": "string"},
            "quantity": {"type": "number"}
          }
        }
      },
      "notes": {"type": "string", "description": "Notes for the transfer"},
      "status": {"type": "string", "description": "Filter by status (for list)"},
      "limit": {"type": "number", "default": 50, "description": "Max results for list"}
    },
    "required": ["action"]
  }
}'::jsonb, true)

ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  definition = EXCLUDED.definition,
  is_active = true,
  updated_at = NOW();

-- Show results
SELECT name, description, is_active FROM ai_tool_registry WHERE is_active = true ORDER BY name;
