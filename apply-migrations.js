#!/usr/bin/env node
// Apply pending migrations to Supabase
const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT_REF = 'uaednwpxursknmwdeejn';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

async function executeSql(sql) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({ query: sql });

    const options = {
      hostname: `${PROJECT_REF}.supabase.co`,
      path: '/rest/v1/rpc/exec_sql',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Length': postData.length
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.write(postData);
    req.end();
  });
}

async function applyMigration(filePath) {
  console.log(`Applying migration: ${path.basename(filePath)}`);
  const sql = fs.readFileSync(filePath, 'utf8');

  try {
    const result = await executeSql(sql);
    console.log(`✓ Success: ${path.basename(filePath)}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed: ${path.basename(filePath)}`);
    console.error(`  Error: ${error.message}`);
    return false;
  }
}

async function main() {
  const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
  const migrationFiles = [
    '20260119_product_field_values_and_schema_assignments.sql',
    '20260119_fix_product_stock_status.sql'
  ];

  console.log('Applying migrations...\n');

  for (const file of migrationFiles) {
    const filePath = path.join(migrationsDir, file);
    if (fs.existsSync(filePath)) {
      await applyMigration(filePath);
    } else {
      console.log(`⊘ Skipping (not found): ${file}`);
    }
  }

  console.log('\nMigrations complete!');
}

main().catch(console.error);
