#!/usr/bin/env node
// Apply team channels migration
const fs = require('fs');
const { Pool } = require('pg');

// Read SQL migration file
const sql = fs.readFileSync('./supabase/migrations/20260119_team_channels_setup.sql', 'utf8');

// Create PostgreSQL connection
const pool = new Pool({
  host: 'db.uaednwpxursknmwdeejn.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD || 'your-db-password-here',
  ssl: { rejectUnauthorized: false }
});

async function applyMigration() {
  const client = await pool.connect();
  try {
    console.log('Applying team channels migration...');
    await client.query(sql);
    console.log('✅ Migration applied successfully!');
    console.log('Default channels created for all stores.');
  } catch (error) {
    console.error('❌ Migration failed:');
    console.error(error.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

applyMigration();
