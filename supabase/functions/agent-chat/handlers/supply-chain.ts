import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { logInventoryMutation } from "./inventory.ts";

export async function handlePurchaseOrders(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "list": {
      let q = sb.from("purchase_orders").select("*, supplier:suppliers(external_name, external_company), location:locations(name)")
        .eq("store_id", sid).order("created_at", { ascending: false }).limit(args.limit as number || 25);
      if (args.status) q = q.eq("status", args.status as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "get": {
      const { data, error } = await sb.from("purchase_orders")
        .select("*, items:purchase_order_items(*, product:products(name, sku)), supplier:suppliers(*)")
        .eq("id", args.purchase_order_id as string).single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      const poNumber = `PO-${Date.now().toString(36).toUpperCase()}`;
      const poType = (args.po_type as string) || "inbound";
      const { data, error } = await sb.from("purchase_orders")
        .insert({ store_id: sid, po_number: poNumber, po_type: poType,
          supplier_id: args.supplier_id, location_id: args.location_id,
          expected_delivery_date: args.expected_delivery_date, notes: args.notes,
          status: "draft", is_ai_action: true })
        .select().single();
      if (error) return { success: false, error: error.message };
      // If items provided, insert them
      if (args.items && Array.isArray(args.items) && data) {
        const items = (args.items as Array<Record<string, unknown>>).map(item => {
          const qty = Number(item.quantity) || 1;
          const price = Number(item.unit_cost || item.unit_price) || 0;
          return {
            purchase_order_id: data.id, product_id: item.product_id,
            quantity: qty, unit_price: price, subtotal: qty * price
          };
        });
        const { error: itemsErr } = await sb.from("purchase_order_items").insert(items);
        if (itemsErr) return { success: false, error: `PO created but items failed: ${itemsErr.message}`, data };
      }
      return { success: true, data };
    }
    case "approve": {
      const { data: po } = await sb.from("purchase_orders").select("status").eq("id", args.purchase_order_id as string).single();
      if (po?.status === "received") return { success: false, error: "Cannot approve — PO already received" };
      if (po?.status === "cancelled") return { success: false, error: "Cannot approve — PO is cancelled" };
      const { data, error } = await sb.from("purchase_orders")
        .update({ status: "approved" }).eq("id", args.purchase_order_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "receive": {
      // 1. Get the PO with its items and location
      const { data: po, error: poErr } = await sb.from("purchase_orders")
        .select("*, items:purchase_order_items(product_id, quantity)")
        .eq("id", args.purchase_order_id as string).single();
      if (poErr || !po) return { success: false, error: poErr?.message || "PO not found" };

      // Guard: prevent double-receive or receiving cancelled POs
      if (po.status === "received") return { success: false, error: "PO already received — cannot receive again (would duplicate inventory)" };
      if (po.status === "cancelled") return { success: false, error: "Cannot receive a cancelled PO" };

      const locationId = po.location_id;
      const items = (po as any).items || [];
      if (!items.length) return { success: false, error: "PO has no items to receive" };

      // 2. Add each item's quantity to inventory (with before/after tracking)
      const mutations: Array<{ product_id: string; before: number; after: number; delta: number }> = [];
      for (const item of items) {
        const { data: existing } = await sb.from("inventory")
          .select("quantity").eq("store_id", sid)
          .eq("product_id", item.product_id)
          .eq("location_id", locationId).single();
        const before = existing?.quantity || 0;
        const after = before + (item.quantity || 0);
        const { error: upsertErr } = await sb.from("inventory").upsert(
          { store_id: sid, product_id: item.product_id, location_id: locationId, quantity: after },
          { onConflict: "product_id,location_id" }
        );
        if (upsertErr) return { success: false, error: `Inventory upsert failed: ${upsertErr.message}` };
        mutations.push({ product_id: item.product_id, before, after, delta: item.quantity });
      }

      // 3. Mark PO as received
      const { data, error } = await sb.from("purchase_orders")
        .update({ status: "received", received_at: new Date().toISOString() })
        .eq("id", args.purchase_order_id as string).select().single();
      if (error) return { success: false, error: error.message };

      // 4. Audit log
      await logInventoryMutation(sb, sid, "po_receive", po.id, po.po_number, locationId, mutations);

      return {
        success: true,
        data: {
          ...data,
          inventory_updated: true,
          inventory_changes: mutations,
          message: `Received ${mutations.length} item(s) into inventory at location ${locationId}`
        }
      };
    }
    case "cancel": {
      const { data: po } = await sb.from("purchase_orders").select("status").eq("id", args.purchase_order_id as string).single();
      if (!po) return { success: false, error: "PO not found" };
      if (po.status === "received") return { success: false, error: "Cannot cancel — PO already received. Use inventory adjustment instead." };
      if (po.status === "cancelled") return { success: false, error: "PO is already cancelled" };
      const { data, error } = await sb.from("purchase_orders")
        .update({ status: "cancelled" }).eq("id", args.purchase_order_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown purchase_orders action: ${args.action}` };
  }
}

export async function handleTransfers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "list": {
      let q = sb.from("inventory_transfers")
        .select("*, from_location:locations!source_location_id(name), to_location:locations!destination_location_id(name)")
        .eq("store_id", sid).order("created_at", { ascending: false }).limit(args.limit as number || 25);
      if (args.status) q = q.eq("status", args.status as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      const sourceLocId = (args.from_location_id || args.source_location_id) as string;
      const items = args.items as Array<{ product_id: string; quantity: number }>;

      // Validate stock before creating transfer
      if (items?.length) {
        const shortages: string[] = [];
        for (const item of items) {
          const { data: src } = await sb.from("inventory").select("quantity, product:products(name)")
            .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", sourceLocId).single();
          const available = src?.quantity || 0;
          if (available < item.quantity) {
            const name = (src as any)?.product?.name || item.product_id;
            shortages.push(`${name}: need ${item.quantity}, have ${available}`);
          }
        }
        if (shortages.length) return { success: false, error: `Insufficient stock: ${shortages.join("; ")}` };
      }

      const transferNumber = `TR-${Date.now().toString(36).toUpperCase()}`;
      const { data: transfer, error } = await sb.from("inventory_transfers")
        .insert({
          store_id: sid,
          transfer_number: transferNumber,
          source_location_id: sourceLocId,
          destination_location_id: args.to_location_id || args.destination_location_id,
          notes: args.notes,
          status: "draft",
          is_ai_action: true
        })
        .select().single();
      if (error) return { success: false, error: error.message };

      // Insert items and deduct from source
      if (items?.length) {
        const itemRows = items.map(i => ({ transfer_id: transfer.id, product_id: i.product_id, quantity: i.quantity }));
        const { error: itemsErr } = await sb.from("inventory_transfer_items").insert(itemRows);
        if (itemsErr) return { success: false, error: `Transfer created but items failed: ${itemsErr.message}`, data: transfer };

        const mutations: Array<{ product_id: string; before: number; after: number; delta: number }> = [];
        for (const item of items) {
          const { data: src } = await sb.from("inventory").select("quantity")
            .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", sourceLocId).single();
          const before = src?.quantity || 0;
          const after = before - item.quantity;
          const { error: deductErr } = await sb.from("inventory").upsert(
            { store_id: sid, product_id: item.product_id, location_id: sourceLocId, quantity: after },
            { onConflict: "product_id,location_id" });
          if (deductErr) return { success: false, error: `Source deduct failed: ${deductErr.message}` };
          mutations.push({ product_id: item.product_id, before, after, delta: -item.quantity });
        }
        await logInventoryMutation(sb, sid, "transfer_deduct", transfer.id, transferNumber, sourceLocId, mutations);
      }
      return { success: true, data: transfer };
    }
    case "get": {
      const { data, error } = await sb.from("inventory_transfers")
        .select("*, items:inventory_transfer_items(*, product:products(name, sku))")
        .eq("id", args.transfer_id as string).single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "receive": {
      const { data: transfer } = await sb.from("inventory_transfers")
        .select("*, items:inventory_transfer_items(*)").eq("id", args.transfer_id as string).single();
      if (!transfer) return { success: false, error: "Transfer not found" };

      // Guard: prevent double-receive or receiving cancelled transfers
      if (transfer.status === "completed") return { success: false, error: "Transfer already completed — cannot receive again (would duplicate inventory)" };
      if (transfer.status === "cancelled") return { success: false, error: "Cannot receive a cancelled transfer" };

      const transferItems = (transfer as any).items || [];
      if (!transferItems.length) return { success: false, error: "Transfer has no items to receive" };

      const mutations: Array<{ product_id: string; before: number; after: number; delta: number }> = [];
      for (const item of transferItems) {
        const { data: dst } = await sb.from("inventory").select("quantity")
          .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", transfer.destination_location_id).single();
        const before = dst?.quantity || 0;
        const after = before + item.quantity;
        const { error: recvErr } = await sb.from("inventory").upsert(
          { store_id: sid, product_id: item.product_id, location_id: transfer.destination_location_id, quantity: after },
          { onConflict: "product_id,location_id" });
        if (recvErr) return { success: false, error: `Destination inventory update failed: ${recvErr.message}` };
        mutations.push({ product_id: item.product_id, before, after, delta: item.quantity });
      }
      const { data, error } = await sb.from("inventory_transfers")
        .update({ status: "completed", received_at: new Date().toISOString() }).eq("id", args.transfer_id as string).select().single();
      if (error) return { success: false, error: error.message };

      await logInventoryMutation(sb, sid, "transfer_receive", transfer.id, transfer.transfer_number, transfer.destination_location_id, mutations);

      return {
        success: true,
        data: {
          ...data,
          inventory_updated: true,
          inventory_changes: mutations,
          message: `Received ${mutations.length} item(s) at destination`
        }
      };
    }
    case "cancel": {
      const { data: transfer } = await sb.from("inventory_transfers")
        .select("*, items:inventory_transfer_items(*)").eq("id", args.transfer_id as string).single();
      if (!transfer) return { success: false, error: "Transfer not found" };

      // Guard: prevent cancelling already completed or cancelled transfers
      if (transfer.status === "completed") return { success: false, error: "Cannot cancel — transfer already completed and inventory received at destination" };
      if (transfer.status === "cancelled") return { success: false, error: "Transfer is already cancelled" };

      const transferItems = (transfer as any).items || [];
      const mutations: Array<{ product_id: string; before: number; after: number; delta: number }> = [];
      for (const item of transferItems) {
        const { data: src } = await sb.from("inventory").select("quantity")
          .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", transfer.source_location_id).single();
        const before = src?.quantity || 0;
        const after = before + item.quantity;
        const { error: restoreErr } = await sb.from("inventory").upsert(
          { store_id: sid, product_id: item.product_id, location_id: transfer.source_location_id, quantity: after },
          { onConflict: "product_id,location_id" });
        if (restoreErr) return { success: false, error: `Source inventory restore failed: ${restoreErr.message}` };
        mutations.push({ product_id: item.product_id, before, after, delta: item.quantity });
      }
      const { data, error } = await sb.from("inventory_transfers")
        .update({ status: "cancelled", cancelled_at: new Date().toISOString() }).eq("id", args.transfer_id as string).select().single();
      if (error) return { success: false, error: error.message };

      if (mutations.length) {
        await logInventoryMutation(sb, sid, "transfer_cancel_restore", transfer.id, transfer.transfer_number, transfer.source_location_id, mutations);
      }

      return {
        success: true,
        data: {
          ...data,
          inventory_restored: mutations.length > 0,
          inventory_changes: mutations,
          message: mutations.length ? `Cancelled transfer, restored ${mutations.length} item(s) to source` : "Cancelled transfer (no items to restore)"
        }
      };
    }
    default:
      return { success: false, error: `Unknown transfers action: ${args.action}` };
  }
}
