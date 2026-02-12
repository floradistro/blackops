// agent-chat/handlers/inventory.ts — Inventory management handlers

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export async function handleInventory(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "adjust": {
      const productId = args.product_id as string;
      const locationId = args.location_id as string;
      const adjustment = args.adjustment as number;
      const reason = args.reason as string || "Manual adjustment";

      const { data: product } = await sb.from("products").select("name, sku").eq("id", productId).single();
      const { data: location } = await sb.from("locations").select("name").eq("id", locationId).single();

      const { data: current } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", productId).eq("location_id", locationId).single();
      const qtyBefore = current?.quantity || 0;
      const qtyAfter = qtyBefore + adjustment;
      if (qtyAfter < 0) {
        return { success: false, error: `Cannot adjust to negative quantity: current ${qtyBefore}, adjustment ${adjustment} would result in ${qtyAfter}` };
      }

      const { error } = await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: locationId, quantity: qtyAfter },
          { onConflict: "store_id,product_id,location_id" }).select().single();
      if (error) return { success: false, error: error.message };

      await sb.from("inventory_adjustments").insert({
        store_id: sid, product_id: productId, location_id: locationId,
        previous_quantity: qtyBefore, new_quantity: qtyAfter, adjustment, reason
      }).catch((err: unknown) => console.error("[audit]", err));

      const sign = adjustment >= 0 ? "+" : "";
      return {
        success: true,
        data: {
          intent: `Adjust inventory for ${product?.name || 'product'} at ${location?.name || 'location'}: ${sign}${adjustment} units`,
          product: product ? { id: productId, name: product.name, sku: product.sku } : { id: productId },
          location: location ? { id: locationId, name: location.name } : { id: locationId },
          adjustment, reason,
          before_state: { quantity: qtyBefore },
          after_state: { quantity: qtyAfter },
          change: { from: qtyBefore, to: qtyAfter, delta: adjustment }
        }
      };
    }
    case "set": {
      const productId = args.product_id as string;
      const locationId = args.location_id as string;
      const newQty = args.quantity as number;

      const { data: product } = await sb.from("products").select("name, sku").eq("id", productId).single();
      const { data: location } = await sb.from("locations").select("name").eq("id", locationId).single();

      const { data: current } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", productId).eq("location_id", locationId).single();
      const qtyBefore = current?.quantity || 0;

      const { error } = await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: locationId, quantity: newQty },
          { onConflict: "store_id,product_id,location_id" }).select().single();
      if (error) return { success: false, error: error.message };

      const delta = newQty - qtyBefore;
      const sign = delta >= 0 ? "+" : "";
      return {
        success: true,
        data: {
          intent: `Set inventory for ${product?.name || 'product'} at ${location?.name || 'location'} to ${newQty} units`,
          product: product ? { id: productId, name: product.name, sku: product.sku } : { id: productId },
          location: location ? { id: locationId, name: location.name } : { id: locationId },
          before_state: { quantity: qtyBefore },
          after_state: { quantity: newQty },
          change: { from: qtyBefore, to: newQty, delta, description: `${sign}${delta} units` }
        }
      };
    }
    case "transfer": {
      const qty = args.quantity as number;
      const productId = args.product_id as string;
      const fromLocationId = args.from_location_id as string;
      const toLocationId = args.to_location_id as string;

      const { data: product } = await sb.from("products").select("name, sku").eq("id", productId).single();
      const { data: fromLocation } = await sb.from("locations").select("name").eq("id", fromLocationId).single();
      const { data: toLocation } = await sb.from("locations").select("name").eq("id", toLocationId).single();

      const { data: srcBefore } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid).eq("product_id", productId).eq("location_id", fromLocationId).single();
      const { data: dstBefore } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid).eq("product_id", productId).eq("location_id", toLocationId).single();

      const srcQtyBefore = srcBefore?.quantity || 0;
      const dstQtyBefore = dstBefore?.quantity || 0;

      if (srcQtyBefore < qty) {
        return { success: false, error: `Insufficient stock at ${fromLocation?.name || fromLocationId}: have ${srcQtyBefore}, need ${qty}` };
      }

      await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: fromLocationId, quantity: srcQtyBefore - qty },
          { onConflict: "store_id,product_id,location_id" });
      await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: toLocationId, quantity: dstQtyBefore + qty },
          { onConflict: "store_id,product_id,location_id" });

      const srcQtyAfter = srcQtyBefore - qty;
      const dstQtyAfter = dstQtyBefore + qty;

      return {
        success: true,
        data: {
          intent: `Transfer ${qty} units of ${product?.name || 'product'} from ${fromLocation?.name || 'source'} to ${toLocation?.name || 'destination'}`,
          product: product ? { id: productId, name: product.name, sku: product.sku } : { id: productId },
          from_location: fromLocation ? { id: fromLocationId, name: fromLocation.name } : { id: fromLocationId },
          to_location: toLocation ? { id: toLocationId, name: toLocation.name } : { id: toLocationId },
          quantity_transferred: qty,
          before_state: { from_quantity: srcQtyBefore, to_quantity: dstQtyBefore, total: srcQtyBefore + dstQtyBefore },
          after_state: { from_quantity: srcQtyAfter, to_quantity: dstQtyAfter, total: srcQtyAfter + dstQtyAfter }
        }
      };
    }
    default:
      return { success: false, error: `Unknown inventory action: ${args.action}` };
  }
}

export async function handleInventoryQuery(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "summary": {
      const { data, error } = await sb.from("inventory")
        .select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid).limit(1000);
      if (error) return { success: false, error: error.message };
      const byLocation: Record<string, { location_name: string; items: number; total_qty: number }> = {};
      for (const row of data || []) {
        const locId = row.location_id;
        if (!byLocation[locId]) byLocation[locId] = { location_name: (row as any).location?.name || locId, items: 0, total_qty: 0 };
        byLocation[locId].items++;
        byLocation[locId].total_qty += row.quantity || 0;
      }
      return { success: true, data: { total_items: data?.length || 0, by_location: Object.values(byLocation) } };
    }
    case "velocity": {
      const days = (args.days as number) || 30;
      const categoryId = args.category_id as string;
      const productId = args.product_id as string;
      const locationId = args.location_id as string;
      const limit = (args.limit as number) || 50;
      const { data, error } = await sb.rpc("get_product_velocity", {
        p_store_id: sid || null, p_days: days, p_location_id: locationId || null,
        p_category_id: categoryId || null, p_product_id: productId || null, p_limit: limit
      });
      if (error) return { success: false, error: error.message };
      const products = (data || []).map((row: any) => ({
        productId: row.product_id, name: row.product_name, sku: row.product_sku,
        category: row.category_name, locationId: row.location_id, locationName: row.location_name,
        totalQty: row.units_sold, totalRevenue: row.revenue, orderCount: row.order_count,
        velocityPerDay: row.daily_velocity, revenuePerDay: row.daily_revenue,
        currentStock: row.current_stock, daysOfStock: row.days_of_stock,
        avgPrice: row.avg_unit_price, stockAlert: row.stock_status
      }));
      return { success: true, data: { days, filters: { categoryId, locationId, productId }, products } };
    }
    case "by_location": {
      let q = sb.from("inventory").select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid);
      if (args.location_id) q = q.eq("location_id", args.location_id as string);
      const { data, error } = await q.limit(100);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "in_stock": {
      const { data, error } = await sb.from("inventory")
        .select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid).gt("quantity", 0).limit(100);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown inventory_query action: ${args.action}` };
  }
}

export async function handleInventoryAudit(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "start": {
      const { data, error } = await sb.from("inventory_audits")
        .insert({ store_id: sid, location_id: args.location_id, status: "in_progress", started_at: new Date().toISOString() })
        .select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "count": {
      const { data, error } = await sb.from("inventory_audit_items")
        .update({ counted_quantity: args.counted })
        .eq("audit_id", args.audit_id).eq("product_id", args.product_id).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "complete": {
      const { data, error } = await sb.from("inventory_audits")
        .update({ status: "completed", completed_at: new Date().toISOString() })
        .eq("id", args.audit_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "summary": {
      const { data, error } = await sb.from("inventory_audits")
        .select("*, items:inventory_audit_items(*)").eq("store_id", sid)
        .order("created_at", { ascending: false }).limit(args.limit as number || 5);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown inventory_audit action: ${args.action}` };
  }
}

export async function logInventoryMutation(
  sb: SupabaseClient, storeId: string, action: string,
  referenceId: string, referenceNumber: string, locationId: string,
  mutations: Array<{ product_id: string; before: number; after: number; delta: number }>
) {
  try {
    await sb.from("audit_logs").insert({
      store_id: storeId, action: `inventory.${action}`, severity: "info",
      resource_type: "inventory_mutation", resource_id: referenceId, source: "agent_chat",
      details: {
        trigger: action, reference_id: referenceId, reference_number: referenceNumber,
        location_id: locationId, mutations,
        total_items: mutations.length, total_units: mutations.reduce((s, m) => s + Math.abs(m.delta), 0)
      }
    });
  } catch (_) { /* telemetry should never block operations */ }
}
