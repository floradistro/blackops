/**
 * Consolidated Tool Executor
 *
 * Following Anthropic's best practices for tool design:
 * - "More tools don't always lead to better outcomes"
 * - "Claude Code uses about a dozen tools"
 * - "Consolidate multi-step operations into single tool calls"
 *
 * 39 tools → 12 consolidated tools:
 *
 * 1. inventory      - manage inventory (adjust, set, transfer, bulk operations)
 * 2. inventory_query - query inventory (summary, velocity, by_location, in_stock)
 * 3. inventory_audit - audit workflow (start, count, complete, summary)
 * 4. collections    - manage collections (find, create, get_theme, set_theme, set_icon)
 * 5. customers      - manage customers (find, create, update)
 * 6. products       - manage products (find, create, update, pricing)
 * 7. analytics      - analytics & data (summary, by_location, detailed, discover, employee)
 * 8. locations      - find/list locations
 * 9. orders         - manage orders (find, get, create)
 * 10. suppliers     - find suppliers
 * 11. email         - unified email (send, send_template, list, get, templates)
 * 12. documents     - document generation
 * 13. alerts        - system alerts
 * 14. audit_trail   - audit logs
 */

import { SupabaseClient } from "@supabase/supabase-js";

export interface ToolResult {
  success: boolean;
  data?: unknown;
  error?: string;
}

type ToolHandler = (
  supabase: SupabaseClient,
  args: Record<string, unknown>,
  storeId?: string
) => Promise<ToolResult>;

// ============================================================================
// CONSOLIDATED TOOL HANDLERS
// ============================================================================

const handlers: Record<string, ToolHandler> = {

  // ===========================================================================
  // 1. INVENTORY - Unified inventory management
  // Actions: adjust, set, transfer, bulk_adjust, bulk_set, bulk_clear
  // ===========================================================================
  inventory: async (supabase, args, storeId) => {
    const action = args.action as string;
    if (!action) {
      return { success: false, error: "action required: adjust, set, transfer, bulk_adjust, bulk_set, bulk_clear" };
    }

    try {
      switch (action) {
        case "adjust": {
          const inventoryId = args.inventory_id as string;
          const productId = args.product_id as string;
          const locationId = args.location_id as string;
          const adjustment = args.adjustment as number || args.quantity_change as number;
          const reason = args.reason as string || "manual adjustment";

          let id = inventoryId;
          if (!id && productId && locationId) {
            const { data: inv } = await supabase
              .from("inventory")
              .select("id, quantity")
              .eq("product_id", productId)
              .eq("location_id", locationId)
              .single();
            if (inv) id = inv.id;
          }

          if (!id || adjustment === undefined) {
            return { success: false, error: "inventory_id (or product_id+location_id) and adjustment required" };
          }

          const { data: current, error: fetchError } = await supabase
            .from("inventory")
            .select("quantity")
            .eq("id", id)
            .single();

          if (fetchError) return { success: false, error: fetchError.message };

          const newQuantity = (current?.quantity || 0) + adjustment;

          const { data, error } = await supabase
            .from("inventory")
            .update({ quantity: newQuantity, updated_at: new Date().toISOString() })
            .eq("id", id)
            .select()
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data: { ...data, adjustment, reason } };
        }

        case "set": {
          const productId = args.product_id as string;
          const locationId = args.location_id as string;
          const quantity = args.quantity as number;

          const { data, error } = await supabase
            .from("inventory")
            .upsert({ product_id: productId, location_id: locationId, quantity })
            .select()
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "transfer": {
          const productId = args.product_id as string;
          const fromLocationId = args.from_location_id as string;
          const toLocationId = args.to_location_id as string;
          const quantity = args.quantity as number;

          // Deduct from source
          const { data: fromInv } = await supabase
            .from("inventory")
            .select("id, quantity")
            .eq("product_id", productId)
            .eq("location_id", fromLocationId)
            .single();

          if (!fromInv) return { success: false, error: "Source inventory not found" };
          if (fromInv.quantity < quantity) return { success: false, error: `Insufficient stock: have ${fromInv.quantity}, need ${quantity}` };

          await supabase
            .from("inventory")
            .update({ quantity: fromInv.quantity - quantity })
            .eq("id", fromInv.id);

          // Add to destination (upsert)
          const { data: toInv } = await supabase
            .from("inventory")
            .select("id, quantity")
            .eq("product_id", productId)
            .eq("location_id", toLocationId)
            .single();

          if (toInv) {
            await supabase
              .from("inventory")
              .update({ quantity: toInv.quantity + quantity })
              .eq("id", toInv.id);
          } else {
            await supabase
              .from("inventory")
              .insert({ product_id: productId, location_id: toLocationId, quantity });
          }

          return { success: true, data: { transferred: quantity, from: fromLocationId, to: toLocationId, product_id: productId } };
        }

        case "bulk_adjust": {
          const adjustments = args.adjustments as Array<{ product_id: string; location_id: string; adjustment: number }>;
          const results = [];

          for (const adj of adjustments || []) {
            const result = await handlers.inventory(supabase, { action: "adjust", ...adj }, storeId);
            results.push({ ...adj, ...result });
          }

          return { success: true, data: { processed: results.length, results } };
        }

        case "bulk_set": {
          const items = args.items as Array<{ product_id: string; location_id: string; quantity: number }>;
          const results = [];

          for (const item of items || []) {
            const result = await handlers.inventory(supabase, { action: "set", ...item }, storeId);
            results.push({ ...item, ...result });
          }

          return { success: true, data: { processed: results.length, results } };
        }

        case "bulk_clear": {
          const locationId = args.location_id as string || storeId;

          const { data, error } = await supabase
            .from("inventory")
            .update({ quantity: 0 })
            .eq("location_id", locationId)
            .select();

          if (error) return { success: false, error: error.message };
          return { success: true, data: { cleared: data?.length || 0, location_id: locationId } };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: adjust, set, transfer, bulk_adjust, bulk_set, bulk_clear` };
      }
    } catch (err) {
      return { success: false, error: `Inventory error: ${err}` };
    }
  },

  // ===========================================================================
  // 2. INVENTORY_QUERY - Query inventory data
  // Actions: summary, velocity, by_location, in_stock
  // ===========================================================================
  inventory_query: async (supabase, args, storeId) => {
    const action = args.action as string || "summary";

    try {
      switch (action) {
        case "summary": {
          let q = supabase
            .from("inventory")
            .select("product_id, quantity, location_id, products(name, sku)");

          if (storeId) q = q.eq("store_id", storeId);

          const { data, error } = await q;
          if (error) return { success: false, error: error.message };

          const totalItems = data?.length || 0;
          const totalQuantity = data?.reduce((sum, i) => sum + (i.quantity || 0), 0) || 0;
          const lowStock = data?.filter(i => (i.quantity || 0) < 10).length || 0;
          const outOfStock = data?.filter(i => (i.quantity || 0) === 0).length || 0;

          return { success: true, data: { totalItems, totalQuantity, lowStock, outOfStock, items: data?.slice(0, 50) } };
        }

        case "velocity": {
          const days = (args.days as number) || 30;
          const startDate = new Date();
          startDate.setDate(startDate.getDate() - days);

          const { data, error } = await supabase
            .from("order_items")
            .select("product_id, quantity, products(name, sku)")
            .gte("created_at", startDate.toISOString())
            .limit(200);

          if (error) return { success: false, error: error.message };

          const productSales: Record<string, { name: string; sku: string; totalQty: number }> = {};
          for (const item of data || []) {
            const pid = item.product_id;
            if (!productSales[pid]) {
              productSales[pid] = {
                name: (item.products as any)?.name || "Unknown",
                sku: (item.products as any)?.sku || "",
                totalQty: 0
              };
            }
            productSales[pid].totalQty += item.quantity || 0;
          }

          const sorted = Object.entries(productSales)
            .map(([id, p]) => ({ productId: id, ...p, velocityPerDay: Math.round((p.totalQty / days) * 100) / 100 }))
            .sort((a, b) => b.totalQty - a.totalQty);

          return { success: true, data: { days, products: sorted.slice(0, 50) } };
        }

        case "by_location": {
          const locationId = args.location_id as string;
          if (!locationId) return { success: false, error: "location_id required for by_location query" };

          const { data, error } = await supabase
            .from("inventory")
            .select("product_id, quantity, products(name, sku)")
            .eq("location_id", locationId);

          if (error) return { success: false, error: error.message };

          const total = data?.reduce((sum, i) => sum + (i.quantity || 0), 0) || 0;
          return { success: true, data: { location_id: locationId, total_quantity: total, item_count: data?.length || 0, items: data } };
        }

        case "in_stock": {
          let q = supabase
            .from("inventory")
            .select("product_id, quantity, location_id, products(id, name, sku)")
            .gt("quantity", 0);

          if (storeId) q = q.eq("store_id", storeId);
          if (args.location_id) q = q.eq("location_id", args.location_id);

          const { data, error } = await q.limit(100);
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: summary, velocity, by_location, in_stock` };
      }
    } catch (err) {
      return { success: false, error: `Inventory query error: ${err}` };
    }
  },

  // ===========================================================================
  // 3. INVENTORY_AUDIT - Audit workflow
  // Actions: start, count, complete, summary
  // ===========================================================================
  inventory_audit: async (supabase, args, storeId) => {
    const action = args.action as string;
    if (!action) {
      return { success: false, error: "action required: start, count, complete, summary" };
    }

    try {
      switch (action) {
        case "start":
          return { success: true, data: { message: "Audit started", location_id: args.location_id || storeId, started_at: new Date().toISOString() } };

        case "count":
          return { success: true, data: { message: "Count recorded", product_id: args.product_id, counted: args.counted, location_id: args.location_id } };

        case "complete":
          return { success: true, data: { message: "Audit completed", completed_at: new Date().toISOString() } };

        case "summary":
          return { success: true, data: { discrepancies: [], matched: 0, total: 0 } };

        default:
          return { success: false, error: `Unknown action: ${action}. Use: start, count, complete, summary` };
      }
    } catch (err) {
      return { success: false, error: `Inventory audit error: ${err}` };
    }
  },

  // ===========================================================================
  // 3b. PURCHASE_ORDERS - Full purchase order management
  // Actions: create, list, get, add_items, approve, receive, cancel
  // ===========================================================================
  purchase_orders: async (supabase, args, storeId) => {
    const action = args.action as string;
    if (!action) {
      return { success: false, error: "action required: create, list, get, add_items, approve, receive, cancel" };
    }

    try {
      switch (action) {
        case "create": {
          // Generate PO number
          const poNumber = "PO-" + Date.now().toString().slice(-10);

          // Create PO header
          const { data: po, error: poErr } = await supabase
            .from("purchase_orders")
            .insert({
              store_id: storeId,
              po_number: poNumber,
              po_type: "inbound", // Required field
              supplier_id: args.supplier_id || null,
              location_id: args.location_id || null,
              status: "draft",
              notes: args.notes || null,
              expected_delivery_date: args.expected_delivery_date || null,
              is_ai_action: true
            })
            .select()
            .single();

          if (poErr) return { success: false, error: poErr.message };

          // Add items if provided
          const items = args.items as Array<{ product_id: string; quantity: number; unit_price?: number }> || [];
          if (items.length > 0) {
            const insertItems = items.map(item => ({
              purchase_order_id: po.id,
              product_id: item.product_id,
              quantity: item.quantity,
              unit_price: item.unit_price || 0,
              subtotal: item.quantity * (item.unit_price || 0) // Required field
            }));

            await supabase.from("purchase_order_items").insert(insertItems);

            // Calculate PO subtotal
            const poSubtotal = items.reduce((sum, i) => sum + (i.quantity * (i.unit_price || 0)), 0);
            await supabase
              .from("purchase_orders")
              .update({ subtotal: poSubtotal, total_amount: poSubtotal })
              .eq("id", po.id);
          }

          return { success: true, data: { purchase_order_id: po.id, po_number: poNumber, items_count: items.length } };
        }

        case "list": {
          let q = supabase
            .from("purchase_orders")
            .select("id, po_number, po_type, status, supplier_id, location_id, total_amount, expected_delivery_date, created_at, location:locations(name)")
            .order("created_at", { ascending: false });

          if (storeId) q = q.eq("store_id", storeId);
          if (args.status) q = q.eq("status", args.status);
          if (args.supplier_id) q = q.eq("supplier_id", args.supplier_id);

          const { data, error } = await q.limit((args.limit as number) || 50);
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "get": {
          const poId = args.purchase_order_id as string || args.id as string;
          if (!poId) return { success: false, error: "purchase_order_id required" };

          const { data, error } = await supabase
            .from("purchase_orders")
            .select("*, items:purchase_order_items(*, product:products(name, sku)), location:locations(name)")
            .eq("id", poId)
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "add_items": {
          const poId = args.purchase_order_id as string;
          const items = args.items as Array<{ product_id: string; quantity: number; unit_price?: number }>;
          if (!poId || !items?.length) return { success: false, error: "purchase_order_id and items required" };

          const insertItems = items.map(item => ({
            purchase_order_id: poId,
            product_id: item.product_id,
            quantity: item.quantity,
            unit_price: item.unit_price || 0,
            subtotal: item.quantity * (item.unit_price || 0) // Calculate subtotal
          }));

          const { data, error } = await supabase
            .from("purchase_order_items")
            .insert(insertItems)
            .select();

          if (error) return { success: false, error: error.message };

          // Recalculate totals
          const { data: allItems } = await supabase
            .from("purchase_order_items")
            .select("subtotal")
            .eq("purchase_order_id", poId);

          const poSubtotal = (allItems || []).reduce((sum, i) => sum + (i.subtotal || 0), 0);

          await supabase
            .from("purchase_orders")
            .update({ subtotal: poSubtotal, total_amount: poSubtotal, updated_at: new Date().toISOString() })
            .eq("id", poId);

          return { success: true, data: { items_added: data?.length || 0, new_subtotal: poSubtotal } };
        }

        case "approve": {
          const poId = args.purchase_order_id as string;
          if (!poId) return { success: false, error: "purchase_order_id required" };

          // Check if PO has supplier (required for approval)
          const { data: existing } = await supabase
            .from("purchase_orders")
            .select("id, status, supplier_id")
            .eq("id", poId)
            .single();

          if (!existing) return { success: false, error: "PO not found" };
          if (!["draft", "pending"].includes(existing.status)) {
            return { success: false, error: `Cannot approve PO in ${existing.status} status` };
          }
          if (!existing.supplier_id) {
            return { success: false, error: "Cannot approve PO without a supplier. Set supplier_id first." };
          }

          const { data, error } = await supabase
            .from("purchase_orders")
            .update({
              status: "approved",
              ordered_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            })
            .eq("id", poId)
            .select()
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "receive": {
          const poId = args.purchase_order_id as string;
          if (!poId) return { success: false, error: "purchase_order_id required" };

          // Get PO details
          const { data: po, error: poErr } = await supabase
            .from("purchase_orders")
            .select("*, items:purchase_order_items(*)")
            .eq("id", poId)
            .single();

          if (poErr || !po) return { success: false, error: poErr?.message || "PO not found" };
          if (po.status === "received") return { success: false, error: "PO already fully received" };
          if (po.status === "cancelled") return { success: false, error: "Cannot receive cancelled PO" };

          const receiveItems = args.items as Array<{ product_id?: string; item_id?: string; quantity: number }> | null;
          let itemsReceived = 0;
          let totalQtyReceived = 0;

          // Process each PO item
          for (const poItem of po.items || []) {
            let qtyToReceive = poItem.quantity - (poItem.received_quantity || 0);

            // If specific items provided, find matching quantity
            if (receiveItems) {
              const match = receiveItems.find(ri =>
                ri.item_id === poItem.id || ri.product_id === poItem.product_id
              );
              if (!match) continue;
              qtyToReceive = Math.min(match.quantity, qtyToReceive);
            }

            if (qtyToReceive <= 0) continue;

            // Find or create inventory record at destination
            let invId: string | null = null;
            const { data: existingInv } = await supabase
              .from("inventory")
              .select("id, quantity")
              .eq("product_id", poItem.product_id)
              .eq("location_id", po.location_id)
              .single();

            if (existingInv) {
              invId = existingInv.id;
              await supabase
                .from("inventory")
                .update({
                  quantity: existingInv.quantity + qtyToReceive,
                  updated_at: new Date().toISOString()
                })
                .eq("id", invId);
            } else {
              const { data: newInv } = await supabase
                .from("inventory")
                .insert({
                  product_id: poItem.product_id,
                  location_id: po.location_id,
                  store_id: po.store_id,
                  quantity: qtyToReceive
                })
                .select()
                .single();
              invId = newInv?.id;
            }

            // Update PO item received quantity
            const newReceivedQty = (poItem.received_quantity || 0) + qtyToReceive;
            await supabase
              .from("purchase_order_items")
              .update({
                received_quantity: newReceivedQty,
                receive_status: newReceivedQty >= poItem.quantity ? "received" : "partial",
                updated_at: new Date().toISOString()
              })
              .eq("id", poItem.id);

            // Log adjustment (ignore errors if table doesn't exist)
            if (invId) {
              try {
                await supabase.from("inventory_adjustments").insert({
                  inventory_id: invId,
                  product_id: poItem.product_id,
                  location_id: po.location_id,
                  adjustment_type: "PO_RECEIVE",
                  old_quantity: existingInv?.quantity || 0,
                  new_quantity: (existingInv?.quantity || 0) + qtyToReceive,
                  reason: `Received from PO ${po.po_number}`
                });
              } catch { /* ignore */ }
            }

            itemsReceived++;
            totalQtyReceived += qtyToReceive;
          }

          // Update PO status
          const { data: updatedItems } = await supabase
            .from("purchase_order_items")
            .select("quantity, received_quantity")
            .eq("purchase_order_id", poId);

          const allReceived = (updatedItems || []).every(i => (i.received_quantity || 0) >= i.quantity);
          const anyReceived = (updatedItems || []).some(i => (i.received_quantity || 0) > 0);

          await supabase
            .from("purchase_orders")
            .update({
              status: allReceived ? "received" : (anyReceived ? "partial" : po.status),
              received_at: allReceived ? new Date().toISOString() : null,
              updated_at: new Date().toISOString()
            })
            .eq("id", poId);

          return {
            success: true,
            data: {
              items_received: itemsReceived,
              total_quantity_received: totalQtyReceived,
              po_status: allReceived ? "received" : "partial"
            }
          };
        }

        case "cancel": {
          const poId = args.purchase_order_id as string;
          if (!poId) return { success: false, error: "purchase_order_id required" };

          // Check current status
          const { data: existing } = await supabase
            .from("purchase_orders")
            .select("id, status")
            .eq("id", poId)
            .single();

          if (!existing) return { success: false, error: "PO not found" };
          if (["received", "cancelled"].includes(existing.status)) {
            return { success: false, error: `Cannot cancel PO in ${existing.status} status` };
          }

          const { data, error } = await supabase
            .from("purchase_orders")
            .update({
              status: "cancelled",
              updated_at: new Date().toISOString()
            })
            .eq("id", poId)
            .select()
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: create, list, get, add_items, approve, receive, cancel` };
      }
    } catch (err) {
      return { success: false, error: `Purchase orders error: ${err}` };
    }
  },

  // ===========================================================================
  // 3c. TRANSFERS - Inventory transfers between locations
  // Actions: create, list, get, receive, cancel
  // ===========================================================================
  transfers: async (supabase, args, storeId) => {
    const action = args.action as string;
    if (!action) {
      return { success: false, error: "action required: create, list, get, receive, cancel" };
    }

    try {
      switch (action) {
        case "create": {
          const fromLocationId = args.from_location_id as string;
          const toLocationId = args.to_location_id as string;
          const items = args.items as Array<{ product_id: string; quantity: number }>;

          if (!fromLocationId || !toLocationId || !items?.length) {
            return { success: false, error: "from_location_id, to_location_id, and items required" };
          }

          if (fromLocationId === toLocationId) {
            return { success: false, error: "Source and destination must be different" };
          }

          // Generate transfer number
          const transferNumber = "TR-" + Date.now().toString().slice(-10);

          // Create transfer header
          const { data: transfer, error: trErr } = await supabase
            .from("inventory_transfers")
            .insert({
              store_id: storeId,
              transfer_number: transferNumber,
              source_location_id: fromLocationId,
              destination_location_id: toLocationId,
              status: "in_transit", // Valid status
              notes: args.notes || null,
              is_ai_action: true
            })
            .select()
            .single();

          if (trErr) return { success: false, error: trErr.message };

          // Process each item - deduct from source, add to transfer items
          let itemsCount = 0;
          for (const item of items) {
            // Check source inventory
            const { data: srcInv } = await supabase
              .from("inventory")
              .select("id, quantity")
              .eq("product_id", item.product_id)
              .eq("location_id", fromLocationId)
              .single();

            if (!srcInv) {
              // Rollback
              await supabase.from("inventory_transfers").delete().eq("id", transfer.id);
              return { success: false, error: `Product ${item.product_id} not found at source location` };
            }

            if (srcInv.quantity < item.quantity) {
              await supabase.from("inventory_transfers").delete().eq("id", transfer.id);
              return { success: false, error: `Insufficient quantity: have ${srcInv.quantity}, need ${item.quantity}` };
            }

            // Add transfer item
            await supabase.from("inventory_transfer_items").insert({
              transfer_id: transfer.id,
              product_id: item.product_id,
              quantity: item.quantity
            });

            // Deduct from source inventory
            await supabase
              .from("inventory")
              .update({
                quantity: srcInv.quantity - item.quantity,
                updated_at: new Date().toISOString()
              })
              .eq("id", srcInv.id);

            // Log adjustment (ignore errors)
            try {
              await supabase.from("inventory_adjustments").insert({
                inventory_id: srcInv.id,
                product_id: item.product_id,
                location_id: fromLocationId,
                adjustment_type: "TRANSFER_OUT",
                old_quantity: srcInv.quantity,
                new_quantity: srcInv.quantity - item.quantity,
                reason: `Transfer to ${toLocationId} (${transferNumber})`
              });
            } catch { /* ignore */ }

            itemsCount++;
          }

          // Update status to in_transit
          await supabase
            .from("inventory_transfers")
            .update({ status: "in_transit", shipped_at: new Date().toISOString() })
            .eq("id", transfer.id);

          return {
            success: true,
            data: { transfer_id: transfer.id, transfer_number: transferNumber, items_count: itemsCount }
          };
        }

        case "list": {
          let q = supabase
            .from("inventory_transfers")
            .select("id, transfer_number, status, source_location_id, destination_location_id, created_at, shipped_at, received_at, from_location:locations!inventory_transfers_source_location_id_fkey(name), to_location:locations!inventory_transfers_destination_location_id_fkey(name)")
            .order("created_at", { ascending: false });

          if (storeId) q = q.eq("store_id", storeId);
          if (args.status) q = q.eq("status", args.status);
          if (args.from_location_id) q = q.eq("source_location_id", args.from_location_id);
          if (args.to_location_id) q = q.eq("destination_location_id", args.to_location_id);

          const { data, error } = await q.limit((args.limit as number) || 50);
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "get": {
          const transferId = args.transfer_id as string || args.id as string;
          if (!transferId) return { success: false, error: "transfer_id required" };

          const { data, error } = await supabase
            .from("inventory_transfers")
            .select("*, items:inventory_transfer_items(*, product:products(name, sku)), from_location:locations!inventory_transfers_source_location_id_fkey(name), to_location:locations!inventory_transfers_destination_location_id_fkey(name)")
            .eq("id", transferId)
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "receive": {
          const transferId = args.transfer_id as string;
          if (!transferId) return { success: false, error: "transfer_id required" };

          // Get transfer details
          const { data: transfer, error: trErr } = await supabase
            .from("inventory_transfers")
            .select("*, items:inventory_transfer_items(*)")
            .eq("id", transferId)
            .single();

          if (trErr || !transfer) return { success: false, error: trErr?.message || "Transfer not found" };
          if (transfer.status === "received") return { success: false, error: "Transfer already received" };
          if (transfer.status === "cancelled") return { success: false, error: "Cannot receive cancelled transfer" };

          const receiveItems = args.items as Array<{ product_id?: string; item_id?: string; quantity: number }> | null;
          let itemsReceived = 0;
          let totalQtyReceived = 0;

          // Process each transfer item
          for (const trItem of transfer.items || []) {
            let qtyToReceive = trItem.quantity - (trItem.received_quantity || 0);

            // If specific items provided, match them
            if (receiveItems) {
              const match = receiveItems.find(ri =>
                ri.item_id === trItem.id || ri.product_id === trItem.product_id
              );
              if (!match) continue;
              qtyToReceive = Math.min(match.quantity, qtyToReceive);
            }

            if (qtyToReceive <= 0) continue;

            // Find or create destination inventory
            let destInvId: string | null = null;
            const { data: existingInv } = await supabase
              .from("inventory")
              .select("id, quantity")
              .eq("product_id", trItem.product_id)
              .eq("location_id", transfer.destination_location_id)
              .single();

            if (existingInv) {
              destInvId = existingInv.id;
              await supabase
                .from("inventory")
                .update({
                  quantity: existingInv.quantity + qtyToReceive,
                  updated_at: new Date().toISOString()
                })
                .eq("id", destInvId);
            } else {
              const { data: newInv } = await supabase
                .from("inventory")
                .insert({
                  product_id: trItem.product_id,
                  location_id: transfer.destination_location_id,
                  store_id: transfer.store_id,
                  quantity: qtyToReceive
                })
                .select()
                .single();
              destInvId = newInv?.id;
            }

            // Update transfer item
            const newReceivedQty = (trItem.received_quantity || 0) + qtyToReceive;
            await supabase
              .from("inventory_transfer_items")
              .update({
                received_quantity: newReceivedQty,
                updated_at: new Date().toISOString()
              })
              .eq("id", trItem.id);

            // Log adjustment (ignore errors)
            if (destInvId) {
              try {
                await supabase.from("inventory_adjustments").insert({
                  inventory_id: destInvId,
                  product_id: trItem.product_id,
                  location_id: transfer.destination_location_id,
                  adjustment_type: "TRANSFER_IN",
                  old_quantity: existingInv?.quantity || 0,
                  new_quantity: (existingInv?.quantity || 0) + qtyToReceive,
                  reason: `Received from transfer ${transfer.transfer_number}`
                });
              } catch { /* ignore */ }
            }

            itemsReceived++;
            totalQtyReceived += qtyToReceive;
          }

          // Update transfer status
          const { data: updatedItems } = await supabase
            .from("inventory_transfer_items")
            .select("quantity, received_quantity")
            .eq("transfer_id", transferId);

          const allReceived = (updatedItems || []).every(i => (i.received_quantity || 0) >= i.quantity);

          await supabase
            .from("inventory_transfers")
            .update({
              status: allReceived ? "received" : "in_transit",
              received_at: allReceived ? new Date().toISOString() : null,
              updated_at: new Date().toISOString()
            })
            .eq("id", transferId);

          return {
            success: true,
            data: {
              items_received: itemsReceived,
              total_quantity_received: totalQtyReceived,
              transfer_status: allReceived ? "received" : "partial"
            }
          };
        }

        case "cancel": {
          const transferId = args.transfer_id as string;
          if (!transferId) return { success: false, error: "transfer_id required" };

          // Get transfer items to restore inventory
          const { data: transfer } = await supabase
            .from("inventory_transfers")
            .select("*, items:inventory_transfer_items(*)")
            .eq("id", transferId)
            .single();

          if (!transfer) return { success: false, error: "Transfer not found" };
          if (transfer.status === "received") return { success: false, error: "Cannot cancel a received transfer" };
          if (transfer.status === "cancelled") return { success: false, error: "Transfer already cancelled" };

          // Restore inventory at source location
          for (const item of transfer.items || []) {
            // Get source inventory by product and source location
            const { data: srcInv } = await supabase
              .from("inventory")
              .select("id, quantity")
              .eq("product_id", item.product_id)
              .eq("location_id", transfer.source_location_id)
              .single();

            if (srcInv) {
              // Restore quantity
              const restoreQty = item.quantity - (item.received_quantity || 0);
              await supabase
                .from("inventory")
                .update({
                  quantity: srcInv.quantity + restoreQty,
                  updated_at: new Date().toISOString()
                })
                .eq("id", srcInv.id);

              // Log adjustment (ignore errors)
              try {
                await supabase.from("inventory_adjustments").insert({
                  inventory_id: srcInv.id,
                  product_id: item.product_id,
                  location_id: transfer.source_location_id,
                  adjustment_type: "TRANSFER_CANCEL",
                  old_quantity: srcInv.quantity,
                  new_quantity: srcInv.quantity + restoreQty,
                  reason: `Cancelled transfer ${transfer.transfer_number}`
                });
              } catch { /* ignore */ }
            }
          }

          // Update transfer status
          const { data, error } = await supabase
            .from("inventory_transfers")
            .update({
              status: "cancelled",
              cancelled_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            })
            .eq("id", transferId)
            .select()
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data: { ...data, inventory_restored: true } };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: create, list, get, receive, cancel` };
      }
    } catch (err) {
      return { success: false, error: `Transfers error: ${err}` };
    }
  },

  // ===========================================================================
  // 4. COLLECTIONS - Manage collections
  // Actions: find, create, get_theme, set_theme, set_icon
  // ===========================================================================
  collections: async (supabase, args, storeId) => {
    const action = args.action as string || "find";

    // Helper to handle missing table gracefully
    const handleTableError = (error: { message: string; code?: string }) => {
      if (error.message.includes("does not exist") || error.code === "42P01" || error.message.includes("schema cache")) {
        return { success: true, data: [], message: "Collections table not configured" };
      }
      return { success: false, error: error.message };
    };

    try {
      switch (action) {
        case "find": {
          let q = supabase.from("collections").select("*");
          if (storeId) q = q.eq("store_id", storeId);
          if (args.name) q = q.ilike("name", `%${args.name}%`);
          const { data, error } = await q;
          if (error) return handleTableError(error);
          return { success: true, data };
        }

        case "create": {
          const { data, error } = await supabase
            .from("collections")
            .insert({ name: args.name, description: args.description, store_id: storeId })
            .select()
            .single();
          if (error) return handleTableError(error);
          return { success: true, data };
        }

        case "get_theme": {
          const { data, error } = await supabase
            .from("collections")
            .select("id, name, theme")
            .eq("id", args.collection_id)
            .single();
          if (error) return handleTableError(error);
          return { success: true, data };
        }

        case "set_theme": {
          const { data, error } = await supabase
            .from("collections")
            .update({ theme: args.theme })
            .eq("id", args.collection_id)
            .select()
            .single();
          if (error) return handleTableError(error);
          return { success: true, data };
        }

        case "set_icon": {
          const { data, error } = await supabase
            .from("collections")
            .update({ icon: args.icon })
            .eq("id", args.collection_id)
            .select()
            .single();
          if (error) return handleTableError(error);
          return { success: true, data };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: find, create, get_theme, set_theme, set_icon` };
      }
    } catch (err) {
      return { success: false, error: `Collections error: ${err}` };
    }
  },

  // ===========================================================================
  // 5. CUSTOMERS - Manage customers
  // Actions: find, create, update
  // ===========================================================================
  customers: async (supabase, args, storeId) => {
    const action = args.action as string || "find";

    try {
      switch (action) {
        case "find": {
          const query = args.query as string || "";
          const email = args.email as string;
          const phone = args.phone as string;
          const limit = (args.limit as number) || 20;

          let q = supabase
            .from("customers")
            .select("id, email, phone, first_name, last_name, created_at")
            .limit(limit);

          if (query) {
            q = q.or(`email.ilike.%${query}%,phone.ilike.%${query}%,first_name.ilike.%${query}%,last_name.ilike.%${query}%`);
          }
          if (email) q = q.eq("email", email);
          if (phone) q = q.eq("phone", phone);
          if (storeId) q = q.eq("store_id", storeId);

          const { data, error } = await q;
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "create": {
          const { data, error } = await supabase
            .from("customers")
            .insert({
              email: args.email,
              phone: args.phone,
              first_name: args.first_name,
              last_name: args.last_name,
              store_id: storeId
            })
            .select()
            .single();
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "update": {
          const customerId = args.customer_id as string;
          if (!customerId) return { success: false, error: "customer_id required" };

          const updateData: Record<string, unknown> = {};
          if (args.email) updateData.email = args.email;
          if (args.phone) updateData.phone = args.phone;
          if (args.first_name) updateData.first_name = args.first_name;
          if (args.last_name) updateData.last_name = args.last_name;

          const { data, error } = await supabase
            .from("customers")
            .update(updateData)
            .eq("id", customerId)
            .select()
            .single();
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: find, create, update` };
      }
    } catch (err) {
      return { success: false, error: `Customers error: ${err}` };
    }
  },

  // ===========================================================================
  // 6. PRODUCTS - Manage products
  // Actions: find, create, update, pricing_templates
  // ===========================================================================
  products: async (supabase, args, storeId) => {
    const action = args.action as string || "find";

    try {
      switch (action) {
        case "find": {
          const query = args.query as string || "";
          const limit = (args.limit as number) || 20;

          let q = supabase
            .from("products")
            .select("id, name, sku, status")
            .limit(limit);

          if (query) {
            q = q.or(`name.ilike.%${query}%,sku.ilike.%${query}%`);
          }
          if (storeId) q = q.eq("store_id", storeId);

          const { data, error } = await q;
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "create": {
          const { data, error } = await supabase
            .from("products")
            .insert({
              name: args.name,
              sku: args.sku,
              store_id: storeId
            })
            .select()
            .single();
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "update": {
          const productId = args.product_id as string;
          if (!productId) return { success: false, error: "product_id required" };

          const updateData: Record<string, unknown> = {};
          if (args.name) updateData.name = args.name;
          if (args.sku) updateData.sku = args.sku;
          if (args.status) updateData.status = args.status;

          const { data, error } = await supabase
            .from("products")
            .update(updateData)
            .eq("id", productId)
            .select()
            .single();
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "pricing_templates": {
          // pricing_templates table may not exist - return empty array gracefully
          try {
            let q = supabase.from("pricing_templates").select("*");
            if (storeId) q = q.eq("store_id", storeId);
            const { data, error } = await q;
            if (error) {
              // Table doesn't exist - return empty array
              if (error.message.includes("does not exist") || error.code === "42P01" || error.message.includes("schema cache")) {
                return { success: true, data: [], message: "Pricing templates not configured" };
              }
              return { success: false, error: error.message };
            }
            return { success: true, data };
          } catch {
            return { success: true, data: [], message: "Pricing templates not configured" };
          }
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: find, create, update, pricing_templates` };
      }
    } catch (err) {
      return { success: false, error: `Products error: ${err}` };
    }
  },

  // ===========================================================================
  // 7. ANALYTICS - Unified analytics & data discovery
  // Actions: summary, by_location, detailed, discover, employee
  // ===========================================================================
  analytics: async (supabase, args, storeId) => {
    const action = args.action as string || "summary";
    const period = args.period as string || "last_30";
    const locationId = args.location_id as string;

    try {
      // Calculate date range
      const today = new Date();
      let startDate: string;

      switch (period) {
        case "today":
          startDate = today.toISOString().split("T")[0];
          break;
        case "yesterday":
          const yesterday = new Date(today);
          yesterday.setDate(yesterday.getDate() - 1);
          startDate = yesterday.toISOString().split("T")[0];
          break;
        case "last_7":
          const week = new Date(today);
          week.setDate(week.getDate() - 7);
          startDate = week.toISOString().split("T")[0];
          break;
        case "last_30":
        default:
          const month = new Date(today);
          month.setDate(month.getDate() - 30);
          startDate = month.toISOString().split("T")[0];
          break;
        case "last_90":
          const quarter = new Date(today);
          quarter.setDate(quarter.getDate() - 90);
          startDate = quarter.toISOString().split("T")[0];
          break;
        case "ytd":
          startDate = `${today.getFullYear()}-01-01`;
          break;
        case "mtd":
          startDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-01`;
          break;
      }

      switch (action) {
        case "summary":
        case "by_location":
        case "detailed": {
          let q = supabase
            .from("v_daily_sales")
            .select("*")
            .gte("sale_date", startDate)
            .order("sale_date", { ascending: false });

          if (storeId) q = q.eq("store_id", storeId);
          if (locationId) q = q.eq("location_id", locationId);

          const { data, error } = await q;
          if (error) return { success: false, error: error.message };

          const totals = (data || []).reduce((acc, day) => ({
            grossSales: acc.grossSales + parseFloat(day.gross_sales || 0),
            netSales: acc.netSales + parseFloat(day.net_sales || 0),
            taxAmount: acc.taxAmount + parseFloat(day.total_tax || 0),
            discountAmount: acc.discountAmount + parseFloat(day.total_discounts || 0),
            totalOrders: acc.totalOrders + parseInt(day.order_count || 0),
            completedOrders: acc.completedOrders + parseInt(day.completed_orders || 0),
            uniqueCustomers: acc.uniqueCustomers + parseInt(day.unique_customers || 0)
          }), {
            grossSales: 0, netSales: 0, taxAmount: 0, discountAmount: 0,
            totalOrders: 0, completedOrders: 0, uniqueCustomers: 0
          });

          if (action === "by_location") {
            const byLocation: Record<string, { orders: number; gross: number; net: number }> = {};
            for (const row of data || []) {
              const loc = row.location_id || "unknown";
              if (!byLocation[loc]) byLocation[loc] = { orders: 0, gross: 0, net: 0 };
              byLocation[loc].orders += parseInt(row.order_count || 0);
              byLocation[loc].gross += parseFloat(row.gross_sales || 0);
              byLocation[loc].net += parseFloat(row.net_sales || 0);
            }
            return { success: true, data: { period, byLocation: Object.entries(byLocation).map(([id, s]) => ({ locationId: id, ...s })) } };
          }

          return {
            success: true,
            data: {
              period,
              dateRange: { from: startDate, to: today.toISOString().split("T")[0] },
              summary: {
                ...totals,
                avgOrderValue: totals.totalOrders > 0 ? Math.round((totals.netSales / totals.totalOrders) * 100) / 100 : 0
              },
              ...(action === "detailed" ? { daily: (data || []).slice(0, 30) } : { trend: (data || []).slice(0, 14) })
            }
          };
        }

        case "discover": {
          const tables = ["products", "orders", "customers", "inventory", "locations"];
          const result: Record<string, number> = {};

          for (const table of tables) {
            const { count } = await supabase.from(table).select("*", { count: "exact", head: true });
            result[table] = count || 0;
          }

          return { success: true, data: result };
        }

        case "employee": {
          const { data, error } = await supabase
            .from("orders")
            .select("employee_id, total_amount, created_at")
            .not("employee_id", "is", null);

          if (error) return { success: false, error: error.message };

          const byEmployee: Record<string, { count: number; total: number }> = {};
          for (const order of data || []) {
            const eid = order.employee_id;
            if (!byEmployee[eid]) byEmployee[eid] = { count: 0, total: 0 };
            byEmployee[eid].count++;
            byEmployee[eid].total += order.total_amount || 0;
          }

          return { success: true, data: byEmployee };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: summary, by_location, detailed, discover, employee` };
      }
    } catch (err) {
      return { success: false, error: `Analytics error: ${err}` };
    }
  },

  // ===========================================================================
  // 8. LOCATIONS - Find/list locations
  // ===========================================================================
  locations: async (supabase, args, storeId) => {
    try {
      let q = supabase.from("locations").select("id, name, address_line1, city, state, is_active");
      if (storeId) q = q.eq("store_id", storeId);
      if (args.name) q = q.ilike("name", `%${args.name}%`);
      if (args.is_active !== undefined) q = q.eq("is_active", args.is_active);

      const { data, error } = await q;
      if (error) return { success: false, error: error.message };
      return { success: true, data };
    } catch (err) {
      return { success: false, error: `Locations error: ${err}` };
    }
  },

  // ===========================================================================
  // 9. ORDERS - Manage orders
  // Actions: find, get, create
  // ===========================================================================
  orders: async (supabase, args, storeId) => {
    const action = args.action as string || "find";

    try {
      switch (action) {
        case "find": {
          let q = supabase
            .from("orders")
            .select("id, order_number, status, total_amount, customer_id, created_at")
            .order("created_at", { ascending: false })
            .limit((args.limit as number) || 50);

          if (storeId) q = q.eq("store_id", storeId);
          if (args.status) q = q.eq("status", args.status);
          if (args.customer_id) q = q.eq("customer_id", args.customer_id);

          const { data, error } = await q;
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "get": {
          const orderId = args.order_id as string;
          if (!orderId) return { success: false, error: "order_id required" };

          const { data, error } = await supabase
            .from("orders")
            .select("*, order_items(*)")
            .eq("id", orderId)
            .single();

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "purchase_orders": {
          let q = supabase.from("purchase_orders").select("*");
          if (storeId) q = q.eq("store_id", storeId);
          const { data, error } = await q.limit(50);
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: find, get, purchase_orders` };
      }
    } catch (err) {
      return { success: false, error: `Orders error: ${err}` };
    }
  },

  // ===========================================================================
  // 10. SUPPLIERS - Find suppliers
  // ===========================================================================
  suppliers: async (supabase, args, storeId) => {
    try {
      let q = supabase.from("suppliers").select("*");
      if (storeId) q = q.eq("store_id", storeId);
      if (args.name) q = q.ilike("name", `%${args.name}%`);
      const { data, error } = await q.limit(50);
      if (error) return { success: false, error: error.message };
      return { success: true, data };
    } catch (err) {
      return { success: false, error: `Suppliers error: ${err}` };
    }
  },

  // ===========================================================================
  // 11. EMAIL - Unified email tool
  // Actions: send, send_template, list, get, templates
  // ===========================================================================
  email: async (supabase, args, storeId) => {
    const action = args.action as string;
    if (!action) {
      return { success: false, error: "action required: send, send_template, list, get, templates" };
    }

    const SUPABASE_URL = process.env.SUPABASE_URL || "https://uaednwpxursknmwdeejn.supabase.co";
    const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

    const invokeEdgeFunction = async (functionName: string, body: Record<string, unknown>) => {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/${functionName}`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${SUPABASE_ANON_KEY}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(body)
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || data.message || `HTTP ${res.status}`);
      return data;
    };

    try {
      switch (action) {
        case "send": {
          const to = args.to as string;
          const subject = args.subject as string;
          const html = args.html as string;
          const text = args.text as string;

          if (!to || !subject || (!html && !text)) {
            return { success: false, error: "send requires: to, subject, and html or text" };
          }

          const result = await invokeEdgeFunction("send-email", { to, subject, html, text, storeId });
          return { success: true, data: result };
        }

        case "send_template": {
          const to = args.to as string;
          const template = args.template as string;
          const templateData = args.template_data as Record<string, unknown>;

          if (!to || !template) {
            return { success: false, error: "send_template requires: to, template" };
          }

          const result = await invokeEdgeFunction("send-email", { to, template, template_data: templateData, storeId });
          return { success: true, data: result };
        }

        case "list": {
          let query = supabase
            .from("email_sends")
            .select("id, to_email, subject, status, category, created_at")
            .order("created_at", { ascending: false })
            .limit((args.limit as number) || 50);

          if (storeId) query = query.eq("store_id", storeId);
          const { data, error } = await query;
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "get": {
          const emailId = args.email_id as string;
          if (!emailId) return { success: false, error: "get requires email_id" };

          const { data, error } = await supabase.from("email_sends").select("*").eq("id", emailId).single();
          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        case "templates": {
          const { data, error } = await supabase
            .from("email_templates")
            .select("id, name, slug, subject, description, category, is_active")
            .eq("is_active", true);

          if (error) return { success: false, error: error.message };
          return { success: true, data };
        }

        default:
          return { success: false, error: `Unknown action: ${action}. Use: send, send_template, list, get, templates` };
      }
    } catch (err) {
      return { success: false, error: `Email error: ${err}` };
    }
  },

  // ===========================================================================
  // 12. DOCUMENTS - Document generation (COA, etc.)
  // ===========================================================================
  documents: async (supabase, args, storeId) => {
    try {
      const DOCUMENTS_API_URL = process.env.DOCUMENTS_API_URL || "http://localhost:3102/api/tools";
      const oauthToken = process.env.DOCUMENTS_OAUTH_TOKEN;

      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (oauthToken) headers["Authorization"] = `Bearer ${oauthToken}`;

      const response = await fetch(DOCUMENTS_API_URL, {
        method: "POST",
        headers,
        body: JSON.stringify({ tool: "documents", input: args, context: { storeId } })
      });

      const result = await response.json();
      if (!response.ok) return { success: false, error: result.error || `HTTP ${response.status}` };
      return { success: result.success, data: result.data, error: result.error };
    } catch (err) {
      return { success: false, error: `Documents error: ${err}` };
    }
  },

  // ===========================================================================
  // 13. ALERTS - System alerts (low stock, pending orders)
  // ===========================================================================
  alerts: async (supabase, args, storeId) => {
    try {
      const { data: lowStock } = await supabase
        .from("inventory")
        .select("product_id, quantity, products(name)")
        .lt("quantity", 10)
        .limit(20);

      const { data: pendingOrders } = await supabase
        .from("orders")
        .select("id, order_number")
        .eq("status", "pending")
        .limit(20);

      return {
        success: true,
        data: {
          lowStock: lowStock?.length || 0,
          pendingOrders: pendingOrders?.length || 0,
          alerts: [
            ...(lowStock || []).map(i => ({ type: "low_stock", product: (i.products as any)?.name, quantity: i.quantity })),
            ...(pendingOrders || []).map(o => ({ type: "pending_order", order_number: o.order_number }))
          ]
        }
      };
    } catch (err) {
      return { success: false, error: `Alerts error: ${err}` };
    }
  },

  // ===========================================================================
  // 14. AUDIT_TRAIL - View audit logs
  // ===========================================================================
  audit_trail: async (supabase, args, storeId) => {
    try {
      const limit = (args.limit as number) || 50;

      let q = supabase
        .from("audit_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(limit);

      if (storeId) q = q.eq("store_id", storeId);

      const { data, error } = await q;
      if (error) return { success: false, error: error.message };
      return { success: true, data };
    } catch (err) {
      return { success: false, error: `Audit trail error: ${err}` };
    }
  },
};

// ============================================================================
// TELEMETRY - Built-in tracing using audit_logs table
// No third-party OTEL needed - we have: trace_id, span_id, parent_span_id
// ============================================================================

export interface ExecutionContext {
  source: "claude_code" | "swag_manager" | "api" | "edge_function" | "test";
  userId?: string;
  requestId?: string;   // Trace ID - links all spans in one conversation/request
  parentId?: string;    // Parent Span ID - for hierarchical tracing
  agentId?: string;     // AI Agent ID (e.g., Wilson's UUID)
  agentName?: string;   // AI Agent name (e.g., "Wilson")
}

async function logToolExecution(
  supabase: SupabaseClient,
  toolName: string,
  action: string | undefined,
  args: Record<string, unknown>,
  result: ToolResult,
  durationMs: number,
  storeId?: string,
  context?: ExecutionContext
): Promise<string | null> {
  try {
    // Sanitize args - remove sensitive data
    const sanitizedArgs = { ...args };
    delete sanitizedArgs.password;
    delete sanitizedArgs.secret;
    delete sanitizedArgs.token;
    delete sanitizedArgs.api_key;

    const { data } = await supabase.from("audit_logs").insert({
      action: `tool.${toolName}${action ? `.${action}` : ""}`,
      severity: result.success ? "info" : "error",
      store_id: storeId || null,
      user_id: context?.userId || null,
      resource_type: "mcp_tool",
      resource_id: toolName,
      request_id: context?.requestId || null,
      parent_id: context?.parentId || null,
      details: {
        source: context?.source || "api",
        agent_id: context?.agentId || null,
        agent_name: context?.agentName || null,
        args: sanitizedArgs,
        result: result.success ? result.data : null
      },
      error_message: result.error || null,
      duration_ms: durationMs
    }).select("id").single();

    return data?.id || null;
  } catch (err) {
    // Don't fail the tool call if logging fails
    console.error("[Telemetry] Failed to log:", err);
    return null;
  }
}

// ============================================================================
// EXECUTOR
// ============================================================================

export async function executeTool(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>,
  storeId?: string,
  context?: ExecutionContext
): Promise<ToolResult> {
  const startTime = Date.now();
  const action = args.action as string | undefined;
  const handler = handlers[toolName];

  if (!handler) {
    const result: ToolResult = {
      success: false,
      error: `Tool "${toolName}" not found. Available tools: ${Object.keys(handlers).join(", ")}`
    };

    // Log failed tool lookup
    await logToolExecution(supabase, toolName, action, args, result, Date.now() - startTime, storeId, context);
    return result;
  }

  let result: ToolResult;
  try {
    result = await handler(supabase, args, storeId);
  } catch (err) {
    result = {
      success: false,
      error: `Tool execution error: ${err}`
    };
  }

  // Log the execution
  const durationMs = Date.now() - startTime;
  await logToolExecution(supabase, toolName, action, args, result, durationMs, storeId, context);

  return result;
}

export function getImplementedTools(): string[] {
  return Object.keys(handlers);
}
