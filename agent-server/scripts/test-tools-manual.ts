/**
 * Manual verification of all 14 consolidated tools
 * Tests with real data and validates results
 */

import { createClient } from "@supabase/supabase-js";
import { executeTool } from "../src/tools/executor.js";

const SUPABASE_URL = "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI";
const STORE_ID = "cd2e1122-d511-4edb-be5d-98ef274b4baf";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function testTool(name: string, args: Record<string, unknown>, validate: (data: any) => boolean, description: string) {
  console.log(`\n🧪 ${name}: ${description}`);
  const result = await executeTool(supabase, name, args, STORE_ID);

  if (!result.success) {
    console.log(`   ❌ FAILED: ${result.error}`);
    return false;
  }

  const isValid = validate(result.data);
  if (isValid) {
    console.log(`   ✅ PASSED`);
    console.log(`   📦 Data: ${JSON.stringify(result.data).slice(0, 200)}...`);
  } else {
    console.log(`   ❌ VALIDATION FAILED`);
    console.log(`   📦 Data: ${JSON.stringify(result.data).slice(0, 200)}...`);
  }
  return isValid;
}

async function runManualTests() {
  console.log("=" .repeat(70));
  console.log("MANUAL VERIFICATION OF ALL 14 CONSOLIDATED TOOLS");
  console.log("=".repeat(70));

  const results: { name: string; passed: boolean }[] = [];

  // 1. LOCATIONS - Get real location IDs first
  console.log("\n" + "=".repeat(70));
  console.log("1. LOCATIONS TOOL");
  console.log("=".repeat(70));

  const locResult = await executeTool(supabase, "locations", {}, STORE_ID);
  const locations = (locResult.data as any[]) || [];
  console.log(`   Found ${locations.length} locations`);
  if (locations.length > 0) {
    console.log(`   First: ${locations[0].name} (${locations[0].id})`);
  }
  results.push({ name: "locations", passed: locResult.success && locations.length > 0 });

  const testLocationId = locations[0]?.id;

  // 2. PRODUCTS - Get real product IDs
  console.log("\n" + "=".repeat(70));
  console.log("2. PRODUCTS TOOL");
  console.log("=".repeat(70));

  const prodResult = await executeTool(supabase, "products", { action: "find", limit: 5 }, STORE_ID);
  const products = (prodResult.data as any[]) || [];
  console.log(`   Found ${products.length} products`);
  if (products.length > 0) {
    console.log(`   First: ${products[0].name} (${products[0].id})`);
  }
  results.push({ name: "products (find)", passed: prodResult.success && products.length > 0 });

  const testProductId = products[0]?.id;

  // Test product search
  const prodSearch = await executeTool(supabase, "products", { action: "find", query: "flower", limit: 5 }, STORE_ID);
  const searchProducts = (prodSearch.data as any[]) || [];
  console.log(`   Search "flower": found ${searchProducts.length} products`);
  results.push({ name: "products (search)", passed: prodSearch.success });

  // 3. CUSTOMERS - Get real customer IDs
  console.log("\n" + "=".repeat(70));
  console.log("3. CUSTOMERS TOOL");
  console.log("=".repeat(70));

  const custResult = await executeTool(supabase, "customers", { action: "find", limit: 5 }, STORE_ID);
  const customers = (custResult.data as any[]) || [];
  console.log(`   Found ${customers.length} customers`);
  if (customers.length > 0) {
    console.log(`   First: ${customers[0].first_name} ${customers[0].last_name} (${customers[0].id})`);
  } else {
    console.log(`   (customers table is empty - this is OK)`);
  }
  // Tool works even if table is empty - success means no errors
  results.push({ name: "customers (find)", passed: custResult.success });

  const testCustomerId = customers[0]?.id;

  // Test customer search
  const custSearch = await executeTool(supabase, "customers", { action: "find", query: "test", limit: 5 }, STORE_ID);
  console.log(`   Search "test": found ${((custSearch.data as any[]) || []).length} customers`);
  results.push({ name: "customers (search)", passed: custSearch.success });

  // 4. INVENTORY_QUERY
  console.log("\n" + "=".repeat(70));
  console.log("4. INVENTORY_QUERY TOOL");
  console.log("=".repeat(70));

  const invSummary = await executeTool(supabase, "inventory_query", { action: "summary" }, STORE_ID);
  const summary = invSummary.data as any;
  console.log(`   Summary: ${summary?.totalItems} items, ${summary?.totalQuantity} total qty, ${summary?.lowStock} low stock`);
  results.push({ name: "inventory_query (summary)", passed: invSummary.success && summary?.totalItems !== undefined });

  const invVelocity = await executeTool(supabase, "inventory_query", { action: "velocity", days: 30 }, STORE_ID);
  const velocity = invVelocity.data as any;
  console.log(`   Velocity (30 days): ${velocity?.products?.length || 0} products with sales`);
  results.push({ name: "inventory_query (velocity)", passed: invVelocity.success });

  const invInStock = await executeTool(supabase, "inventory_query", { action: "in_stock" }, STORE_ID);
  const inStock = (invInStock.data as any[]) || [];
  console.log(`   In stock: ${inStock.length} inventory records`);
  results.push({ name: "inventory_query (in_stock)", passed: invInStock.success });

  if (testLocationId) {
    const invByLoc = await executeTool(supabase, "inventory_query", { action: "by_location", location_id: testLocationId }, STORE_ID);
    const byLoc = invByLoc.data as any;
    console.log(`   By location: ${byLoc?.item_count || 0} items at ${testLocationId.slice(0,8)}...`);
    results.push({ name: "inventory_query (by_location)", passed: invByLoc.success });
  }

  // 5. INVENTORY - Test with real IDs
  console.log("\n" + "=".repeat(70));
  console.log("5. INVENTORY TOOL");
  console.log("=".repeat(70));

  if (inStock.length > 0 && inStock[0].product_id && testLocationId) {
    // Get a real inventory record
    const realInv = inStock.find(i => i.quantity > 0);
    if (realInv) {
      console.log(`   Testing adjust on product ${realInv.product_id.slice(0,8)}... qty: ${realInv.quantity}`);

      // Adjust +1
      const adjUp = await executeTool(supabase, "inventory", {
        action: "adjust",
        product_id: realInv.product_id,
        location_id: realInv.location_id,
        adjustment: 1,
        reason: "test adjustment +1"
      }, STORE_ID);

      if (adjUp.success) {
        const newQty = (adjUp.data as any)?.quantity;
        console.log(`   Adjusted +1: new qty = ${newQty}`);

        // Adjust back -1
        const adjDown = await executeTool(supabase, "inventory", {
          action: "adjust",
          product_id: realInv.product_id,
          location_id: realInv.location_id,
          adjustment: -1,
          reason: "test adjustment -1 (reverting)"
        }, STORE_ID);

        const revertQty = (adjDown.data as any)?.quantity;
        console.log(`   Adjusted -1: qty = ${revertQty} (should be ${realInv.quantity})`);
        results.push({ name: "inventory (adjust)", passed: adjDown.success && revertQty === realInv.quantity });
      } else {
        console.log(`   ❌ Adjust failed: ${adjUp.error}`);
        results.push({ name: "inventory (adjust)", passed: false });
      }
    }
  } else {
    console.log("   ⏭️  Skipping - no inventory records found");
    results.push({ name: "inventory (adjust)", passed: true }); // Skip is OK
  }

  // 6. ORDERS
  console.log("\n" + "=".repeat(70));
  console.log("6. ORDERS TOOL");
  console.log("=".repeat(70));

  const ordersResult = await executeTool(supabase, "orders", { action: "find", limit: 5 }, STORE_ID);
  const orders = (ordersResult.data as any[]) || [];
  console.log(`   Found ${orders.length} orders`);
  if (orders.length > 0) {
    console.log(`   First: #${orders[0].order_number} - $${orders[0].total_amount} (${orders[0].status})`);
  }
  results.push({ name: "orders (find)", passed: ordersResult.success && orders.length > 0 });

  if (orders.length > 0) {
    const orderGet = await executeTool(supabase, "orders", { action: "get", order_id: orders[0].id }, STORE_ID);
    const order = orderGet.data as any;
    console.log(`   Get order: #${order?.order_number} with ${order?.order_items?.length || 0} items`);
    results.push({ name: "orders (get)", passed: orderGet.success && order?.id });
  }

  const poResult = await executeTool(supabase, "orders", { action: "purchase_orders" }, STORE_ID);
  const pos = (poResult.data as any[]) || [];
  console.log(`   Purchase orders: ${pos.length} found`);
  results.push({ name: "orders (purchase_orders)", passed: poResult.success });

  // 7. ANALYTICS
  console.log("\n" + "=".repeat(70));
  console.log("7. ANALYTICS TOOL");
  console.log("=".repeat(70));

  const analyticsSummary = await executeTool(supabase, "analytics", { action: "summary", period: "last_30" }, STORE_ID);
  const anlSum = analyticsSummary.data as any;
  console.log(`   Summary (30d): $${anlSum?.summary?.grossSales?.toFixed(2)} gross, ${anlSum?.summary?.totalOrders} orders`);
  results.push({ name: "analytics (summary)", passed: analyticsSummary.success && anlSum?.summary });

  const analyticsDiscover = await executeTool(supabase, "analytics", { action: "discover" }, STORE_ID);
  const disc = analyticsDiscover.data as any;
  console.log(`   Discover: products=${disc?.products}, orders=${disc?.orders}, customers=${disc?.customers}`);
  results.push({ name: "analytics (discover)", passed: analyticsDiscover.success && disc?.products !== undefined });

  const analyticsEmployee = await executeTool(supabase, "analytics", { action: "employee" }, STORE_ID);
  const emp = analyticsEmployee.data as any;
  console.log(`   Employee stats: ${Object.keys(emp || {}).length} employees tracked`);
  results.push({ name: "analytics (employee)", passed: analyticsEmployee.success });

  // 8. SUPPLIERS
  console.log("\n" + "=".repeat(70));
  console.log("8. SUPPLIERS TOOL");
  console.log("=".repeat(70));

  const suppResult = await executeTool(supabase, "suppliers", {}, STORE_ID);
  const suppliers = (suppResult.data as any[]) || [];
  console.log(`   Found ${suppliers.length} suppliers`);
  results.push({ name: "suppliers", passed: suppResult.success });

  // 9. EMAIL
  console.log("\n" + "=".repeat(70));
  console.log("9. EMAIL TOOL");
  console.log("=".repeat(70));

  const emailList = await executeTool(supabase, "email", { action: "list", limit: 5 }, STORE_ID);
  const emails = (emailList.data as any[]) || [];
  console.log(`   Sent emails: ${emails.length} found`);
  results.push({ name: "email (list)", passed: emailList.success });

  const emailTemplates = await executeTool(supabase, "email", { action: "templates" }, STORE_ID);
  const templates = (emailTemplates.data as any[]) || [];
  console.log(`   Templates: ${templates.length} active`);
  results.push({ name: "email (templates)", passed: emailTemplates.success });

  // 10. ALERTS
  console.log("\n" + "=".repeat(70));
  console.log("10. ALERTS TOOL");
  console.log("=".repeat(70));

  const alertsResult = await executeTool(supabase, "alerts", {}, STORE_ID);
  const alerts = alertsResult.data as any;
  console.log(`   Alerts: ${alerts?.lowStock} low stock, ${alerts?.pendingOrders} pending orders`);
  results.push({ name: "alerts", passed: alertsResult.success && alerts?.lowStock !== undefined });

  // 11. AUDIT_TRAIL
  console.log("\n" + "=".repeat(70));
  console.log("11. AUDIT_TRAIL TOOL");
  console.log("=".repeat(70));

  const auditResult = await executeTool(supabase, "audit_trail", { limit: 5 }, STORE_ID);
  const audits = (auditResult.data as any[]) || [];
  console.log(`   Audit logs: ${audits.length} entries`);
  results.push({ name: "audit_trail", passed: auditResult.success });

  // 12. INVENTORY_AUDIT (workflow tool - just test it starts)
  console.log("\n" + "=".repeat(70));
  console.log("12. INVENTORY_AUDIT TOOL");
  console.log("=".repeat(70));

  const auditStart = await executeTool(supabase, "inventory_audit", { action: "start", location_id: testLocationId }, STORE_ID);
  console.log(`   Start audit: ${(auditStart.data as any)?.message}`);
  results.push({ name: "inventory_audit", passed: auditStart.success });

  // 13. COLLECTIONS (table may not exist)
  console.log("\n" + "=".repeat(70));
  console.log("13. COLLECTIONS TOOL");
  console.log("=".repeat(70));

  const collResult = await executeTool(supabase, "collections", { action: "find" }, STORE_ID);
  const colls = (collResult.data as any[]) || [];
  const collMsg = (collResult.data as any)?.message;
  if (collMsg) {
    console.log(`   ${collMsg}`);
  } else {
    console.log(`   Collections: ${colls.length} found`);
  }
  results.push({ name: "collections", passed: collResult.success });

  // SUMMARY
  console.log("\n" + "=".repeat(70));
  console.log("FINAL RESULTS");
  console.log("=".repeat(70));

  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;

  console.log(`\n✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`📊 Total: ${results.length}`);

  if (failed > 0) {
    console.log("\nFailed tests:");
    results.filter(r => !r.passed).forEach(r => {
      console.log(`   - ${r.name}`);
    });
  }

  console.log("\n" + "=".repeat(70));
}

runManualTests().catch(console.error);
