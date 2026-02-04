/**
 * Test all 14 consolidated tools
 */

import { createClient } from "@supabase/supabase-js";
import { executeTool, getImplementedTools } from "../src/tools/executor.js";

const SUPABASE_URL = "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI";
const STORE_ID = "cd2e1122-d511-4edb-be5d-98ef274b4baf";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

interface TestResult {
  tool: string;
  action?: string;
  success: boolean;
  error?: string;
  dataPreview?: string;
}

const results: TestResult[] = [];

async function test(tool: string, args: Record<string, unknown>, label?: string) {
  const result = await executeTool(supabase, tool, args, STORE_ID);
  const testResult: TestResult = {
    tool: label || `${tool}${args.action ? ` (${args.action})` : ""}`,
    success: result.success,
    error: result.error,
    dataPreview: result.success ? JSON.stringify(result.data).slice(0, 100) + "..." : undefined
  };
  results.push(testResult);

  const status = result.success ? "✅" : "❌";
  console.log(`${status} ${testResult.tool}`);
  if (!result.success) console.log(`   Error: ${result.error}`);
}

async function runTests() {
  console.log("🧪 Testing all 14 consolidated tools\n");
  console.log("Implemented tools:", getImplementedTools().join(", "));
  console.log("\n" + "=".repeat(60) + "\n");

  // 1. INVENTORY
  console.log("📦 INVENTORY TOOL");
  // Note: inventory adjust with invalid IDs returns error (expected)
  console.log("⏭️  inventory (adjust) - requires real inventory_id, skipping");
  // Test bulk_clear with valid location
  await test("inventory", { action: "bulk_clear", location_id: "00000000-0000-0000-0000-000000000000" }, "inventory (bulk_clear - no records)");

  // 2. INVENTORY_QUERY
  console.log("\n📊 INVENTORY_QUERY TOOL");
  await test("inventory_query", { action: "summary" });
  await test("inventory_query", { action: "velocity", days: 7 });
  await test("inventory_query", { action: "in_stock" });

  // 3. INVENTORY_AUDIT
  console.log("\n📋 INVENTORY_AUDIT TOOL");
  await test("inventory_audit", { action: "start", location_id: STORE_ID });
  await test("inventory_audit", { action: "count", product_id: "test", counted: 10 });
  await test("inventory_audit", { action: "complete" });
  await test("inventory_audit", { action: "summary" });

  // 4. COLLECTIONS
  console.log("\n🗂️ COLLECTIONS TOOL");
  await test("collections", { action: "find" });

  // 5. CUSTOMERS
  console.log("\n👥 CUSTOMERS TOOL");
  await test("customers", { action: "find", limit: 5 });
  await test("customers", { action: "find", query: "test" });

  // 6. PRODUCTS
  console.log("\n🏷️ PRODUCTS TOOL");
  await test("products", { action: "find", limit: 5 });
  await test("products", { action: "find", query: "flower" });
  await test("products", { action: "pricing_templates" });

  // 7. ANALYTICS
  console.log("\n📈 ANALYTICS TOOL");
  await test("analytics", { action: "summary", period: "last_7" });
  await test("analytics", { action: "by_location", period: "last_30" });
  await test("analytics", { action: "discover" });
  await test("analytics", { action: "employee" });

  // 8. LOCATIONS
  console.log("\n📍 LOCATIONS TOOL");
  await test("locations", {});
  await test("locations", { is_active: true });

  // 9. ORDERS
  console.log("\n🛒 ORDERS TOOL");
  await test("orders", { action: "find", limit: 5 });
  await test("orders", { action: "find", status: "completed", limit: 3 });
  await test("orders", { action: "purchase_orders" });

  // 10. SUPPLIERS
  console.log("\n🏭 SUPPLIERS TOOL");
  await test("suppliers", {});

  // 11. EMAIL
  console.log("\n📧 EMAIL TOOL");
  await test("email", { action: "list", limit: 5 });
  await test("email", { action: "templates" });

  // 12. DOCUMENTS
  console.log("\n📄 DOCUMENTS TOOL");
  console.log("⏭️  documents (external API) - requires localhost:3102 running, skipping");

  // 13. ALERTS
  console.log("\n🚨 ALERTS TOOL");
  await test("alerts", {});

  // 14. AUDIT_TRAIL
  console.log("\n📜 AUDIT_TRAIL TOOL");
  await test("audit_trail", { limit: 5 });

  // Summary
  console.log("\n" + "=".repeat(60));
  const passed = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  console.log(`\n📊 RESULTS: ${passed} passed, ${failed} failed out of ${results.length} tests`);

  if (failed > 0) {
    console.log("\n❌ Failed tests:");
    results.filter(r => !r.success).forEach(r => {
      console.log(`   - ${r.tool}: ${r.error}`);
    });
  }
}

runTests().catch(console.error);
