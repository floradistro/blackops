-- Fix customers tool: point at real tables (platform_users + user_creation_relationships + store_customer_profiles)
-- instead of the legacy empty `customers` table
UPDATE ai_tool_registry
SET
  version = 4,
  description = 'Full CRM: find, view, create, update, merge customers. Manage notes, activity, orders, duplicates. Queries real platform_users + store_customer_profiles data.',
  definition = jsonb_build_object(
    'input_schema', jsonb_build_object(
      'type', 'object',
      'required', jsonb_build_array('action'),
      'properties', jsonb_build_object(
        'action', jsonb_build_object(
          'type', 'string',
          'enum', jsonb_build_array('find', 'get', 'create', 'update', 'find_duplicates', 'merge', 'add_note', 'notes', 'activity', 'orders'),
          'description', 'Action to perform'
        ),
        'query', jsonb_build_object(
          'type', 'string',
          'description', 'Search term — matches against first_name, last_name, email, phone (for find action)'
        ),
        'customer_id', jsonb_build_object(
          'type', 'string',
          'description', 'Customer ID (user_creation_relationships.id) for get, update, add_note, notes, activity, orders'
        ),
        'first_name', jsonb_build_object('type', 'string', 'description', 'First name (create/update)'),
        'last_name', jsonb_build_object('type', 'string', 'description', 'Last name (create/update)'),
        'email', jsonb_build_object('type', 'string', 'description', 'Email address (create/update)'),
        'phone', jsonb_build_object('type', 'string', 'description', 'Phone number (create/update)'),
        'date_of_birth', jsonb_build_object('type', 'string', 'description', 'Date of birth YYYY-MM-DD (create/update)'),
        'status', jsonb_build_object('type', 'string', 'description', 'Filter by active/inactive (find) or set status (update)'),
        'loyalty_tier', jsonb_build_object('type', 'string', 'description', 'Filter by loyalty tier (find) or set tier (update)'),
        'loyalty_points', jsonb_build_object('type', 'number', 'description', 'Set loyalty points (update)'),
        'street_address', jsonb_build_object('type', 'string', 'description', 'Street address (create/update)'),
        'city', jsonb_build_object('type', 'string', 'description', 'City (create/update)'),
        'state', jsonb_build_object('type', 'string', 'description', 'State (create/update)'),
        'postal_code', jsonb_build_object('type', 'string', 'description', 'Postal/ZIP code (create/update)'),
        'drivers_license_number', jsonb_build_object('type', 'string', 'description', 'Drivers license (create/update)'),
        'id_verified', jsonb_build_object('type', 'boolean', 'description', 'ID verified flag (update)'),
        'medical_card_number', jsonb_build_object('type', 'string', 'description', 'Medical card number (create/update)'),
        'medical_card_expiry', jsonb_build_object('type', 'string', 'description', 'Medical card expiry YYYY-MM-DD (create/update)'),
        'is_wholesale_approved', jsonb_build_object('type', 'boolean', 'description', 'Wholesale approved (update)'),
        'wholesale_tier', jsonb_build_object('type', 'string', 'description', 'Wholesale tier (update)'),
        'wholesale_business_name', jsonb_build_object('type', 'string', 'description', 'Wholesale business name (update)'),
        'wholesale_license_number', jsonb_build_object('type', 'string', 'description', 'Wholesale license (update)'),
        'wholesale_tax_id', jsonb_build_object('type', 'string', 'description', 'Wholesale tax ID (update)'),
        'email_consent', jsonb_build_object('type', 'boolean', 'description', 'Email marketing consent (create/update)'),
        'sms_consent', jsonb_build_object('type', 'boolean', 'description', 'SMS marketing consent (create/update)'),
        'push_consent', jsonb_build_object('type', 'boolean', 'description', 'Push notification consent (update)'),
        'primary_customer_id', jsonb_build_object('type', 'string', 'description', 'Primary customer to keep (merge)'),
        'secondary_customer_id', jsonb_build_object('type', 'string', 'description', 'Secondary customer to merge into primary (merge)'),
        'note', jsonb_build_object('type', 'string', 'description', 'Note text (add_note)'),
        'created_by', jsonb_build_object('type', 'string', 'description', 'Note author (add_note)'),
        'limit', jsonb_build_object('type', 'number', 'description', 'Max results to return (default 25)'),
        'orders_limit', jsonb_build_object('type', 'number', 'description', 'Max orders to include in get (default 10)')
      )
    )
  ),
  updated_at = now()
WHERE name = 'customers';
