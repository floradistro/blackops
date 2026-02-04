/**
 * Test Purchase Orders and Transfers tools end-to-end
 */

import { createClient } from "@supabase/supabase-js";
import { executeTool, getImplementedTools } from "../src/tools/executor.js";

const SUPABASE_URL = "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI";
const STORE_ID = "cd2e1122-d511-4edb-be5d-98ef274b4baf";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function test(name: string, tool: string, args: Record<string, unknown>) {
  console.log(`\n🧪 ${name}`);
  const result = await executeTool(supabase, tool, args, STORE_ID);
  if (result.success) {
    console.log(`   ✅ SUCCESS`);
    console.log(`   📦 ${JSON.stringify(result.data).slice(0, 200)}...`);
  } else {
    console.log(`   ❌ FAILED: ${result.error}`);
  }
  return result;
}

async function runTests() {
  console.log("=".repeat(70));
  console.log("TESTING PURCHASE ORDERS & TRANSFERS TOOLS");
  console.log("=".repeat(70));

  // Check what tools are implemented
  console.log("\nImplemented tools:", getImplementedTools().join(", "));

  // Get test data
  const { data: locations } = await supabase.from("locations").select("id, name").limit(3);
  const { data: products } = await supabase.from("products").select("id, name").limit(3);
  const { data: suppliers } = await supabase.from("suppliers").select("id, name").limit(1);

  console.log("\nTest data:");
  console.log("  Locations:", locations?.map(l => l.name).join(", "));
  console.log("  Products:", products?.map(p => p.name).join(", "));
  console.log("  Suppliers:", suppliers?.map(s => s.name).join(", "));

  const location1 = locations?.[0];
  const location2 = locations?.[1];
  const product1 = products?.[0];
  const product2 = products?.[1];
  const supplier1 = suppliers?.[0];

  if (!location1 || !location2 || !product1) {
    console.log("\n❌ Missing test data!");
    return;
  }

  // ==========================================================================
  // PURCHASE ORDERS TESTS
  // ==========================================================================
  console.log("\n" + "=".repeat(70));
  console.log("PURCHASE ORDERS");
  console.log("=".repeat(70));

  // 1. List existing POs
  await test("List purchase orders", "purchase_orders", { action: "list", limit: 5 });

  // 2. Create a new PO
  const createResult = await test("Create purchase order", "purchase_orders", {
    action: "create",
    supplier_id: supplier1?.id,
    location_id: location1.id,
    items: [
      { product_id: product1.id, quantity: 100, unit_price: 5.99 },
      { product_id: product2?.id || product1.id, quantity: 50, unit_price: 12.99 }
    ],
    notes: "Test PO from inventory tools test"
  });

  const poId = (createResult.data as any)?.purchase_order_id;
  if (!poId) {
    console.log("\n❌ Failed to create PO, skipping remaining PO tests");
  } else {
    console.log(`\n   Created PO ID: ${poId}`);

    // 3. Get PO details
    await test("Get purchase order details", "purchase_orders", {
      action: "get",
      purchase_order_id: poId
    });

    // 4. Add more items
    await test("Add items to PO", "purchase_orders", {
      action: "add_items",
      purchase_order_id: poId,
      items: [
        { product_id: product1.id, quantity: 25, unit_price: 3.99 }
      ]
    });

    // 5. Approve the PO
    await test("Approve purchase order", "purchase_orders", {
      action: "approve",
      purchase_order_id: poId
    });

    // 6. Get inventory before receiving
    const { data: invBefore } = await supabase
      .from("inventory")
      .select("quantity")
      .eq("product_id", product1.id)
      .eq("location_id", location1.id)
      .single();
    console.log(`\n   Inventory before receive: ${invBefore?.quantity || 0}`);

    // 7. Receive the PO (partial - just first item)
    await test("Receive purchase order (partial)", "purchase_orders", {
      action: "receive",
      purchase_order_id: poId,
      items: [
        { product_id: product1.id, quantity: 50 } // Receive half of first item
      ]
    });

    // 8. Check inventory after receiving
    const { data: invAfter } = await supabase
      .from("inventory")
      .select("quantity")
      .eq("product_id", product1.id)
      .eq("location_id", location1.id)
      .single();
    console.log(`   Inventory after partial receive: ${invAfter?.quantity || 0}`);

    // 9. Receive remaining
    await test("Receive purchase order (remaining)", "purchase_orders", {
      action: "receive",
      purchase_order_id: poId
    });

    // 10. Get final PO status
    await test("Get PO final status", "purchase_orders", {
      action: "get",
      purchase_order_id: poId
    });
  }

  // ==========================================================================
  // TRANSFERS TESTS
  // ==========================================================================
  console.log("\n" + "=".repeat(70));
  console.log("INVENTORY TRANSFERS");
  console.log("=".repeat(70));

  // 1. List existing transfers
  await test("List transfers", "transfers", { action: "list", limit: 5 });

  // Get inventory at source location
  const { data: srcInvData } = await supabase
    .from("inventory")
    .select("id, product_id, quantity, products(name)")
    .eq("location_id", location1.id)
    .gt("quantity", 5)
    .limit(1)
    .single();

  if (!srcInvData) {
    console.log("\n⚠️  No inventory with qty > 5 at source location, skipping transfer tests");
  } else {
    console.log(`\n   Source inventory: ${(srcInvData.products as any)?.name} - ${srcInvData.quantity} units`);

    // 2. Create a transfer
    const transferResult = await test("Create inventory transfer", "transfers", {
      action: "create",
      from_location_id: location1.id,
      to_location_id: location2.id,
      items: [
        { product_id: srcInvData.product_id, quantity: 5 }
      ],
      notes: "Test transfer from inventory tools test"
    });

    const transferId = (transferResult.data as any)?.transfer_id;
    if (!transferId) {
      console.log("\n❌ Failed to create transfer, skipping remaining transfer tests");
    } else {
      console.log(`   Created Transfer ID: ${transferId}`);

      // 3. Get transfer details
      await test("Get transfer details", "transfers", {
        action: "get",
        transfer_id: transferId
      });

      // 4. Check source inventory (should be reduced)
      const { data: srcAfter } = await supabase
        .from("inventory")
        .select("quantity")
        .eq("id", srcInvData.id)
        .single();
      console.log(`\n   Source inventory after transfer: ${srcAfter?.quantity}`);

      // 5. Receive the transfer
      await test("Receive transfer", "transfers", {
        action: "receive",
        transfer_id: transferId
      });

      // 6. Check destination inventory
      const { data: destInv } = await supabase
        .from("inventory")
        .select("quantity")
        .eq("product_id", srcInvData.product_id)
        .eq("location_id", location2.id)
        .single();
      console.log(`   Destination inventory after receive: ${destInv?.quantity}`);

      // 7. Get final transfer status
      await test("Get transfer final status", "transfers", {
        action: "get",
        transfer_id: transferId
      });
    }
  }

  // ==========================================================================
  // TEST CANCEL WORKFLOWS
  // ==========================================================================
  console.log("\n" + "=".repeat(70));
  console.log("CANCEL WORKFLOWS");
  console.log("=".repeat(70));

  // Create a PO and cancel it
  const cancelPOResult = await test("Create PO for cancellation", "purchase_orders", {
    action: "create",
    location_id: location1.id,
    items: [{ product_id: product1.id, quantity: 10, unit_price: 1.00 }],
    notes: "PO to be cancelled"
  });

  const cancelPoId = (cancelPOResult.data as any)?.purchase_order_id;
  if (cancelPoId) {
    await test("Cancel purchase order", "purchase_orders", {
      action: "cancel",
      purchase_order_id: cancelPoId
    });
  }

  // Create a transfer and cancel it
  if (srcInvData && srcInvData.quantity > 10) {
    const cancelTransferResult = await test("Create transfer for cancellation", "transfers", {
      action: "create",
      from_location_id: location1.id,
      to_location_id: location2.id,
      items: [{ product_id: srcInvData.product_id, quantity: 2 }],
      notes: "Transfer to be cancelled"
    });

    const cancelTransferId = (cancelTransferResult.data as any)?.transfer_id;
    if (cancelTransferId) {
      // Check inventory before cancel
      const { data: beforeCancel } = await supabase
        .from("inventory")
        .select("quantity")
        .eq("id", srcInvData.id)
        .single();
      console.log(`\n   Source inventory before cancel: ${beforeCancel?.quantity}`);

      await test("Cancel transfer", "transfers", {
        action: "cancel",
        transfer_id: cancelTransferId
      });

      // Check inventory restored
      const { data: afterCancel } = await supabase
        .from("inventory")
        .select("quantity")
        .eq("id", srcInvData.id)
        .single();
      console.log(`   Source inventory after cancel (restored): ${afterCancel?.quantity}`);
    }
  }

  console.log("\n" + "=".repeat(70));
  console.log("TESTS COMPLETE");
  console.log("=".repeat(70));
}

runTests().catch(console.error);
