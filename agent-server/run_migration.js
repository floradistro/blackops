// Run enhanced telemetry migration
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SUPABASE_URL = 'https://uaednwpxursknmwdeejn.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function runMigration() {
  console.log('Running enhanced telemetry migration...');

  // Read the migration file
  const migrationPath = join(__dirname, '../supabase/migrations/20260205_enhanced_telemetry.sql');
  const sql = readFileSync(migrationPath, 'utf-8');

  // Split into statements and run
  const statements = sql.split(';').filter(s => s.trim().length > 0);

  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i].trim() + ';';
    if (stmt.startsWith('--') || stmt === ';') continue;

    console.log(`Executing statement ${i + 1}/${statements.length}...`);

    const { error } = await supabase.rpc('exec_sql', { sql_query: stmt }).maybeSingle();

    if (error && !error.message.includes('already exists')) {
      console.error(`Error on statement ${i + 1}:`, error.message);
      console.error('Statement:', stmt.slice(0, 100) + '...');
    }
  }

  console.log('Migration complete!');

  // Verify columns exist
  const { data, error } = await supabase
    .from('audit_logs')
    .select('id, trace_id, span_id, span_kind, service_name')
    .limit(1);

  if (error) {
    console.error('Verification failed:', error.message);
  } else {
    console.log('Verified new columns exist:', Object.keys(data[0] || {}));
  }
}

runMigration().catch(console.error);
