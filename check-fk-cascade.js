const { createClient } = require('@supabase/supabase-js');
const { Pool } = require('pg');

// Use direct PostgreSQL connection for system queries
const pool = new Pool({
  host: 'db.uaednwpxursknmwdeejn.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'WHALE1997SWAGIESTMANAGER',
  ssl: { rejectUnauthorized: false }
});

async function checkForeignKeys() {
  console.log('🔍 FOREIGN KEY CASCADE ANALYSIS\n');
  console.log('='.repeat(80));

  try {
    // Query 1: Find all foreign keys referencing customers
    console.log('\n📋 Foreign Keys Referencing customers Table:\n');

    const fkQuery = `
      SELECT
        tc.table_schema,
        tc.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name,
        rc.update_rule,
        rc.delete_rule,
        tc.constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
      JOIN information_schema.referential_constraints rc
        ON rc.constraint_name = tc.constraint_name
        AND rc.constraint_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY'
        AND ccu.table_name = 'customers'
        AND tc.table_schema = 'public'
      ORDER BY tc.table_name;
    `;

    const result = await pool.query(fkQuery);

    if (result.rows.length === 0) {
      console.log('   ✅ No foreign keys found referencing customers table');
      console.log('   → This is unusual - checking if view is masking base table...\n');
    } else {
      console.log(`   Found ${result.rows.length} foreign key constraints:\n`);

      result.rows.forEach(row => {
        const cascadeWarning = (row.delete_rule === 'CASCADE' || row.update_rule === 'CASCADE') ? '⚠️  CASCADE' : '✅';
        console.log(`   ${cascadeWarning} ${row.table_name}.${row.column_name}`);
        console.log(`      → ${row.foreign_table_name}.${row.foreign_column_name}`);
        console.log(`      ON DELETE ${row.delete_rule} | ON UPDATE ${row.update_rule}`);
        console.log(`      Constraint: ${row.constraint_name}`);
        console.log('');
      });
    }

    // Query 2: Check for triggers on customers table
    console.log('\n📋 Triggers on customers or v_store_customers:\n');

    const triggerQuery = `
      SELECT
        tgname AS trigger_name,
        tgrelid::regclass AS table_name,
        CASE
          WHEN tgtype::integer & 1 = 1 THEN 'ROW'
          ELSE 'STATEMENT'
        END AS level,
        CASE
          WHEN tgtype::integer & 2 = 2 THEN 'BEFORE'
          WHEN tgtype::integer & 64 = 64 THEN 'INSTEAD OF'
          ELSE 'AFTER'
        END AS timing,
        CASE
          WHEN tgtype::integer & 4 = 4 THEN 'INSERT'
          WHEN tgtype::integer & 8 = 8 THEN 'DELETE'
          WHEN tgtype::integer & 16 = 16 THEN 'UPDATE'
          ELSE 'OTHER'
        END AS event,
        pg_get_functiondef(tgfoid) AS function_definition
      FROM pg_trigger
      JOIN pg_class ON pg_trigger.tgrelid = pg_class.oid
      JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
      WHERE pg_namespace.nspname = 'public'
        AND pg_class.relname IN ('customers', 'v_store_customers')
        AND NOT tgisinternal
      ORDER BY tgname;
    `;

    const triggerResult = await pool.query(triggerQuery);

    if (triggerResult.rows.length === 0) {
      console.log('   ✅ No triggers found on customers table');
    } else {
      console.log(`   ⚠️  Found ${triggerResult.rows.length} triggers:\n`);

      triggerResult.rows.forEach(row => {
        console.log(`   🔔 ${row.trigger_name}`);
        console.log(`      Table: ${row.table_name}`);
        console.log(`      Timing: ${row.timing} ${row.event} (${row.level})`);
        console.log(`      Function: ${row.function_definition?.substring(0, 200)}...`);
        console.log('');
      });
    }

    // Query 3: Check all tables with customer_id column
    console.log('\n📋 All Tables with customer_id Column:\n');

    const columnQuery = `
      SELECT
        table_name,
        column_name,
        data_type,
        is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND column_name = 'customer_id'
      ORDER BY table_name;
    `;

    const columnResult = await pool.query(columnQuery);

    console.log(`   Found ${columnResult.rows.length} tables with customer_id:\n`);

    for (const row of columnResult.rows) {
      // Count records
      try {
        const countResult = await pool.query(`SELECT COUNT(*) FROM ${row.table_name}`);
        const count = countResult.rows[0].count;
        console.log(`   📊 ${row.table_name}: ${count} records`);
      } catch (err) {
        console.log(`   📊 ${row.table_name}: (couldn't count)`);
      }
    }

    // Query 4: Check for event triggers or publication for realtime
    console.log('\n\n📋 Realtime Publications (Event Streaming):\n');

    const pubQuery = `
      SELECT
        pubname,
        puballtables,
        pubinsert,
        pubupdate,
        pubdelete
      FROM pg_publication
      WHERE pubname LIKE '%realtime%' OR pubname LIKE '%supabase%';
    `;

    const pubResult = await pool.query(pubQuery);

    if (pubResult.rows.length === 0) {
      console.log('   ℹ️  No realtime publications found');
    } else {
      console.log(`   Found ${pubResult.rows.length} realtime publications:\n`);

      pubResult.rows.forEach(row => {
        console.log(`   📡 ${row.pubname}`);
        console.log(`      All tables: ${row.puballtables}`);
        console.log(`      Events: INSERT=${row.pubinsert} UPDATE=${row.pubupdate} DELETE=${row.pubdelete}`);
        console.log('');
      });

      // Get specific tables in publications
      const pubTableQuery = `
        SELECT
          p.pubname,
          c.relname AS table_name
        FROM pg_publication p
        JOIN pg_publication_rel pr ON p.oid = pr.prpubid
        JOIN pg_class c ON pr.prrelid = c.oid
        WHERE c.relname IN ('customers', 'v_store_customers', 'orders', 'cart_items', 'loyalty_transactions')
        ORDER BY p.pubname, c.relname;
      `;

      const pubTableResult = await pool.query(pubTableQuery);

      if (pubTableResult.rows.length > 0) {
        console.log('   📋 Customer-related tables in publications:\n');
        pubTableResult.rows.forEach(row => {
          console.log(`      - ${row.table_name} → ${row.pubname}`);
        });
        console.log('');
      }
    }

    console.log('\n' + '='.repeat(80));
    console.log('\n🎯 CRITICAL FINDINGS & RECOMMENDATIONS:\n');

    // Summarize risks
    const hasCascade = result.rows.some(r => r.delete_rule === 'CASCADE');
    const hasTriggers = triggerResult.rows.length > 0;
    const hasRealtime = pubResult.rows.some(r => r.pubdelete);

    if (hasCascade) {
      console.log('⚠️  CASCADE DELETE DETECTED:');
      console.log('   → Deleting customers will CASCADE delete related records');
      console.log('   → MUST update FKs to keeper BEFORE deleting duplicates');
      console.log('');
    } else {
      console.log('✅ No CASCADE deletes found');
      console.log('   → Foreign keys use RESTRICT or NO ACTION (safe)');
      console.log('   → Still must update FKs before delete to avoid constraint violations');
      console.log('');
    }

    if (hasTriggers) {
      console.log('⚠️  TRIGGERS DETECTED:');
      console.log('   → Database triggers will fire on customer deletes');
      console.log('   → Review trigger logic to ensure it won\'t cause issues');
      console.log('   → Consider: ALTER TABLE customers DISABLE TRIGGER ALL (during transaction)');
      console.log('');
    } else {
      console.log('✅ No triggers on customers table');
      console.log('');
    }

    if (hasRealtime) {
      console.log('⚠️  REALTIME EVENTS ENABLED:');
      console.log('   → DELETE events will be broadcast to subscribed clients');
      console.log('   → Client apps must handle customer_id changes gracefully');
      console.log('   → Recommend: Run during maintenance window / low traffic');
      console.log('');
    }

    console.log('📝 SAFE DEDUPLICATION PROCEDURE:\n');
    console.log('1. BEGIN transaction');
    console.log('2. For each duplicate group:');
    console.log('   a. UPDATE orders SET customer_id = keeper_id WHERE customer_id IN (duplicate_ids)');
    console.log('   b. UPDATE loyalty_transactions SET customer_id = keeper_id WHERE customer_id IN (duplicate_ids)');
    console.log('   c. UPDATE/MERGE customer_loyalty (if exists)');
    console.log('   d. UPDATE customer_notes (if exists)');
    console.log('3. DELETE FROM customers WHERE id IN (duplicate_ids)');
    console.log('4. VERIFY no orphaned records');
    console.log('5. COMMIT');
    console.log('\n' + '='.repeat(80));

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkForeignKeys().catch(console.error);
