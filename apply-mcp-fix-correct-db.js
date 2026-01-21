#!/usr/bin/env node
// Apply MCP columns migration to the CORRECT database (uaednwpxursknmwdeejn)

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

const migration = `
-- Add rpc_function and edge_function columns to ai_tool_registry
ALTER TABLE ai_tool_registry
ADD COLUMN IF NOT EXISTS rpc_function text,
ADD COLUMN IF NOT EXISTS edge_function text,
ADD COLUMN IF NOT EXISTS tool_mode text,
ADD COLUMN IF NOT EXISTS requires_user_id boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS requires_store_id boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_read_only boolean DEFAULT false;

-- Update existing tools with their RPC functions
UPDATE ai_tool_registry
SET rpc_function = name || '_query'
WHERE rpc_function IS NULL AND edge_function IS NULL;

-- Set tool_mode based on category
UPDATE ai_tool_registry
SET tool_mode = category
WHERE tool_mode IS NULL;
`;

(async () => {
  console.log('🔧 Applying MCP columns migration to CORRECT database (uaednwpxursknmwdeejn)...\n');

  const { data, error } = await supabase.rpc('exec_sql', { sql_query: migration });

  if (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }

  console.log('✅ Migration applied successfully!\n');

  // Verify the columns were added
  console.log('🔍 Verifying migration...');
  const { data: verify, error: verifyError } = await supabase
    .from('ai_tool_registry')
    .select('name, rpc_function, edge_function, tool_mode')
    .limit(5);

  if (verifyError) {
    console.error('❌ Verification failed:', verifyError);
    process.exit(1);
  }

  console.log('\n✅ First 5 tools after migration:');
  verify.forEach((tool, i) => {
    console.log(`  ${i + 1}. ${tool.name}`);
    console.log(`     rpc_function: ${tool.rpc_function || '(null)'}`);
    console.log(`     edge_function: ${tool.edge_function || '(null)'}`);
    console.log(`     tool_mode: ${tool.tool_mode || '(null)'}`);
    console.log('');
  });

  console.log('✅ Done! Restart SwagManager to see the changes.');
})();
