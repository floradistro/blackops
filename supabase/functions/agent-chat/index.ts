// agent-chat/index.ts
// Production agent endpoint with SSE streaming
// Tools loaded from ai_tool_registry — same as MCP server

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@0.30.1";

// ============================================================================
// TYPES
// ============================================================================

interface AgentConfig {
  id: string;
  name: string;
  system_prompt: string;
  model: string;
  max_tokens: number;
  max_tool_calls: number;
  temperature: number;
  enabled_tools: string[];
  can_query: boolean;
  can_send: boolean;
  can_modify: boolean;
}

interface ToolDef {
  name: string;
  description: string;
  input_schema: Record<string, unknown>;
}

interface StreamEvent {
  type: "text" | "tool_start" | "tool_result" | "error" | "done" | "usage";
  text?: string;
  name?: string;
  result?: unknown;
  success?: boolean;
  error?: string;
  usage?: { input_tokens: number; output_tokens: number };
}

// ============================================================================
// TOOL REGISTRY (loaded from database)
// ============================================================================

let cachedTools: ToolDef[] = [];
let cacheTime = 0;

async function loadTools(supabase: SupabaseClient): Promise<ToolDef[]> {
  if (cachedTools.length > 0 && Date.now() - cacheTime < 60_000) return cachedTools;

  const { data, error } = await supabase
    .from("ai_tool_registry")
    .select("name, description, definition")
    .eq("is_active", true);

  if (error || !data) return cachedTools;

  cachedTools = data.map(t => ({
    name: t.name,
    description: t.description || t.definition?.description || t.name,
    input_schema: t.definition?.input_schema || { type: "object", properties: {} }
  }));
  cacheTime = Date.now();
  return cachedTools;
}

function getToolsForAgent(agent: AgentConfig, allTools: ToolDef[]): ToolDef[] {
  if (agent.enabled_tools?.length > 0) {
    return allTools.filter(t => agent.enabled_tools.includes(t.name));
  }
  return allTools;
}

// ============================================================================
// TOOL EXECUTOR — consolidated tools, same interface as MCP executor
// ============================================================================

async function executeTool(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>,
  storeId?: string,
  traceId?: string,
  userId?: string | null,
  userEmail?: string | null
): Promise<{ success: boolean; data?: unknown; error?: string }> {
  const startTime = Date.now();
  const action = args.action as string | undefined;
  let result: { success: boolean; data?: unknown; error?: string };

  try {
    switch (toolName) {
      // ---- INVENTORY ----
      case "inventory":
        result = await handleInventory(supabase, args, storeId);
        break;
      case "inventory_query":
        result = await handleInventoryQuery(supabase, args, storeId);
        break;
      case "inventory_audit":
        result = await handleInventoryAudit(supabase, args, storeId);
        break;

      // ---- SUPPLY CHAIN ----
      case "purchase_orders":
        result = await handlePurchaseOrders(supabase, args, storeId);
        break;
      case "transfers":
        result = await handleTransfers(supabase, args, storeId);
        break;

      // ---- CATALOG ----
      case "products":
        result = await handleProducts(supabase, args, storeId);
        break;
      case "collections":
        result = await handleCollections(supabase, args, storeId);
        break;

      // ---- CRM ----
      case "customers":
        result = await handleCustomers(supabase, args, storeId);
        break;
      case "orders":
        result = await handleOrders(supabase, args, storeId);
        break;

      // ---- ANALYTICS ----
      case "analytics":
        result = await handleAnalytics(supabase, args, storeId);
        break;

      // ---- OPERATIONS ----
      case "locations":
        result = await handleLocations(supabase, args, storeId);
        break;
      case "suppliers":
        result = await handleSuppliers(supabase, args, storeId);
        break;
      case "email":
        result = await handleEmail(supabase, args, storeId);
        break;
      case "documents":
        result = { success: true, data: { message: "Document generation not available in edge function" } };
        break;
      case "alerts":
        result = await handleAlerts(supabase, args, storeId);
        break;
      case "audit_trail":
        result = await handleAuditTrail(supabase, args, storeId);
        break;

      default:
        result = { success: false, error: `Unknown tool: ${toolName}` };
    }
  } catch (err) {
    result = { success: false, error: String(err) };
  }

  // Log to audit_logs
  try {
    await supabase.from("audit_logs").insert({
      action: `tool.${toolName}${action ? `.${action}` : ""}`,
      severity: result.success ? "info" : "error",
      store_id: storeId || null,
      resource_type: "mcp_tool",
      resource_id: toolName,
      request_id: traceId || null,
      details: { source: "edge_function", args },
      error_message: result.error || null,
      duration_ms: Date.now() - startTime,
      user_id: userId || null,
      user_email: userEmail || null
    });
  } catch { /* don't fail tool call if logging fails */ }

  return result;
}

// ============================================================================
// TOOL HANDLERS
// ============================================================================

async function handleInventory(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "adjust": {
      // Get current inventory
      const { data: current } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", args.product_id as string)
        .eq("location_id", args.location_id as string).single();
      const oldQty = current?.quantity || 0;
      const newQty = oldQty + (args.adjustment as number);
      const { data, error } = await sb.from("inventory")
        .upsert({ store_id: sid, product_id: args.product_id, location_id: args.location_id, quantity: newQty },
          { onConflict: "store_id,product_id,location_id" })
        .select().single();
      if (error) return { success: false, error: error.message };
      // Log adjustment
      await sb.from("inventory_adjustments").insert({
        store_id: sid, product_id: args.product_id, location_id: args.location_id,
        previous_quantity: oldQty, new_quantity: newQty,
        adjustment: args.adjustment, reason: args.reason || "API adjustment"
      }).catch(() => {});
      return { success: true, data: { ...data, previous_quantity: oldQty } };
    }
    case "set": {
      const { data, error } = await sb.from("inventory")
        .upsert({ store_id: sid, product_id: args.product_id, location_id: args.location_id, quantity: args.quantity },
          { onConflict: "store_id,product_id,location_id" })
        .select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "transfer": {
      // Deduct from source
      const { data: src } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", args.product_id as string)
        .eq("location_id", args.from_location_id as string).single();
      const srcQty = src?.quantity || 0;
      const qty = args.quantity as number;
      if (srcQty < qty) return { success: false, error: `Insufficient stock: have ${srcQty}, need ${qty}` };
      await sb.from("inventory")
        .upsert({ store_id: sid, product_id: args.product_id, location_id: args.from_location_id, quantity: srcQty - qty },
          { onConflict: "store_id,product_id,location_id" });
      // Add to destination
      const { data: dst } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", args.product_id as string)
        .eq("location_id", args.to_location_id as string).single();
      const dstQty = dst?.quantity || 0;
      await sb.from("inventory")
        .upsert({ store_id: sid, product_id: args.product_id, location_id: args.to_location_id, quantity: dstQty + qty },
          { onConflict: "store_id,product_id,location_id" });
      return { success: true, data: { transferred: qty, from: args.from_location_id, to: args.to_location_id } };
    }
    default:
      return { success: false, error: `Unknown inventory action: ${args.action}` };
  }
}

async function handleInventoryQuery(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "summary": {
      const { data, error } = await sb.from("inventory")
        .select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid);
      if (error) return { success: false, error: error.message };
      // Group by location
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
      const params: Record<string, unknown> = { p_store_id: sid };
      if (args.location_id) params.p_location_id = args.location_id;
      const { data, error } = await sb.rpc("get_inventory_velocity", params);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "by_location": {
      let q = sb.from("inventory").select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid);
      if (args.location_id) q = q.eq("location_id", args.location_id as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "in_stock": {
      const { data, error } = await sb.from("inventory")
        .select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid).gt("quantity", 0);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown inventory_query action: ${args.action}` };
  }
}

async function handleInventoryAudit(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "start": {
      // Create audit record directly
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

async function handlePurchaseOrders(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "list": {
      let q = sb.from("purchase_orders").select("*, supplier:suppliers(name), location:locations(name)")
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
      const { data, error } = await sb.from("purchase_orders")
        .insert({ store_id: sid, supplier_id: args.supplier_id, location_id: args.location_id,
          expected_delivery_date: args.expected_delivery_date, notes: args.notes, status: "draft" })
        .select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "approve": {
      const { data, error } = await sb.from("purchase_orders")
        .update({ status: "approved" }).eq("id", args.purchase_order_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "receive": {
      const { data, error } = await sb.from("purchase_orders")
        .update({ status: "received" }).eq("id", args.purchase_order_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "cancel": {
      const { data, error } = await sb.from("purchase_orders")
        .update({ status: "cancelled" }).eq("id", args.purchase_order_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown purchase_orders action: ${args.action}` };
  }
}

async function handleTransfers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "list": {
      let q = sb.from("inventory_transfers")
        .select("*, from_location:locations!from_location_id(name), to_location:locations!to_location_id(name)")
        .eq("store_id", sid).order("created_at", { ascending: false }).limit(args.limit as number || 25);
      if (args.status) q = q.eq("status", args.status as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      // Create transfer header
      const { data: transfer, error } = await sb.from("inventory_transfers")
        .insert({ store_id: sid, from_location_id: args.from_location_id, to_location_id: args.to_location_id,
          notes: args.notes, status: "pending" })
        .select().single();
      if (error) return { success: false, error: error.message };
      // Insert items and deduct from source
      const items = args.items as Array<{ product_id: string; quantity: number }>;
      if (items?.length) {
        const itemRows = items.map(i => ({ transfer_id: transfer.id, product_id: i.product_id, quantity: i.quantity }));
        await sb.from("inventory_transfer_items").insert(itemRows);
        for (const item of items) {
          const { data: src } = await sb.from("inventory").select("quantity")
            .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", args.from_location_id as string).single();
          const newQty = (src?.quantity || 0) - item.quantity;
          await sb.from("inventory").upsert(
            { store_id: sid, product_id: item.product_id, location_id: args.from_location_id, quantity: newQty },
            { onConflict: "store_id,product_id,location_id" });
        }
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
      // Get transfer and items
      const { data: transfer } = await sb.from("inventory_transfers")
        .select("*, items:inventory_transfer_items(*)").eq("id", args.transfer_id as string).single();
      if (!transfer) return { success: false, error: "Transfer not found" };
      // Add to destination inventory
      for (const item of (transfer as any).items || []) {
        const { data: dst } = await sb.from("inventory").select("quantity")
          .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", transfer.to_location_id).single();
        const newQty = (dst?.quantity || 0) + item.quantity;
        await sb.from("inventory").upsert(
          { store_id: sid, product_id: item.product_id, location_id: transfer.to_location_id, quantity: newQty },
          { onConflict: "store_id,product_id,location_id" });
      }
      const { data, error } = await sb.from("inventory_transfers")
        .update({ status: "received" }).eq("id", args.transfer_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "cancel": {
      // Get transfer and restore source inventory
      const { data: transfer } = await sb.from("inventory_transfers")
        .select("*, items:inventory_transfer_items(*)").eq("id", args.transfer_id as string).single();
      if (!transfer) return { success: false, error: "Transfer not found" };
      for (const item of (transfer as any).items || []) {
        const { data: src } = await sb.from("inventory").select("quantity")
          .eq("store_id", sid).eq("product_id", item.product_id).eq("location_id", transfer.from_location_id).single();
        const newQty = (src?.quantity || 0) + item.quantity;
        await sb.from("inventory").upsert(
          { store_id: sid, product_id: item.product_id, location_id: transfer.from_location_id, quantity: newQty },
          { onConflict: "store_id,product_id,location_id" });
      }
      const { data, error } = await sb.from("inventory_transfers")
        .update({ status: "cancelled" }).eq("id", args.transfer_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown transfers action: ${args.action}` };
  }
}

async function handleProducts(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("products").select("id, name, sku, price, status, category_id")
        .eq("store_id", sid).limit(args.limit as number || 25);
      if (args.query) q = q.or(`name.ilike.%${args.query}%,sku.ilike.%${args.query}%`);
      if (args.category) q = q.eq("category_id", args.category as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      const { data, error } = await sb.from("products")
        .insert({ store_id: sid, name: args.name, sku: args.sku, price: args.base_price })
        .select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "update": {
      const updates: Record<string, unknown> = {};
      if (args.name) updates.name = args.name;
      if (args.base_price) updates.price = args.base_price;
      const { data, error } = await sb.from("products")
        .update(updates).eq("id", args.product_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown products action: ${args.action}` };
  }
}

async function handleCollections(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("creation_collections").select("*").eq("store_id", sid);
      if (args.name) q = q.ilike("name", `%${args.name}%`);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      const { data, error } = await sb.from("creation_collections")
        .insert({ store_id: sid, name: args.name }).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown collections action: ${args.action}` };
  }
}

async function handleCustomers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("customers").select("id, full_name, email, phone, created_at")
        .eq("store_id", sid).limit(args.limit as number || 25);
      if (args.query) q = q.or(`full_name.ilike.%${args.query}%,email.ilike.%${args.query}%,phone.ilike.%${args.query}%`);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      const { data, error } = await sb.from("customers")
        .insert({ store_id: sid, first_name: args.first_name, last_name: args.last_name,
          email: args.email, phone: args.phone }).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "update": {
      const updates: Record<string, unknown> = {};
      if (args.first_name) updates.first_name = args.first_name;
      if (args.last_name) updates.last_name = args.last_name;
      if (args.email) updates.email = args.email;
      if (args.phone) updates.phone = args.phone;
      const { data, error } = await sb.from("customers")
        .update(updates).eq("id", args.customer_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown customers action: ${args.action}` };
  }
}

async function handleOrders(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("orders")
        .select("id, order_number, status, total, created_at, customer:customers(id, full_name, email)")
        .eq("store_id", sid).order("created_at", { ascending: false }).limit(args.limit as number || 25);
      if (args.status) q = q.eq("status", args.status as string);
      if (args.customer_id) q = q.eq("customer_id", args.customer_id as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "get": {
      const { data, error } = await sb.from("orders")
        .select("*, customer:customers(*), items:order_items(*, product:products(id, name, sku))")
        .eq("id", args.order_id as string).single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown orders action: ${args.action}` };
  }
}

async function handleAnalytics(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  // Resolve date range from period/days_back
  const getDateRange = () => {
    const end = args.end_date as string || new Date().toISOString().split("T")[0];
    if (args.start_date) return { start: args.start_date as string, end };
    if (args.days_back) {
      const d = new Date(); d.setDate(d.getDate() - (args.days_back as number));
      return { start: d.toISOString().split("T")[0], end };
    }
    const periodDays: Record<string, number> = {
      today: 0, yesterday: 1, last_7: 7, last_30: 30, last_90: 90,
      last_180: 180, last_365: 365, all_time: 3650
    };
    const days = periodDays[args.period as string] ?? 30;
    const d = new Date(); d.setDate(d.getDate() - days);
    return { start: d.toISOString().split("T")[0], end };
  };

  switch (args.action) {
    case "summary": {
      const params: Record<string, unknown> = { p_store_id: sid };
      const { start, end } = getDateRange();
      params.p_start_date = start;
      params.p_end_date = end;
      if (args.location_id) params.p_location_id = args.location_id;
      const { data, error } = await sb.rpc("get_sales_analytics", params);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "by_location": {
      const { start, end } = getDateRange();
      let q = sb.from("v_daily_sales").select("*").eq("store_id", sid)
        .gte("sale_date", start).lte("sale_date", end);
      if (args.location_id) q = q.eq("location_id", args.location_id as string);
      const { data, error } = await q;
      if (error) return { success: false, error: error.message };
      // Group by location
      const byLoc: Record<string, { location_id: string; revenue: number; orders: number }> = {};
      for (const row of data || []) {
        const lid = row.location_id;
        if (!byLoc[lid]) byLoc[lid] = { location_id: lid, revenue: 0, orders: 0 };
        byLoc[lid].revenue += row.net_sales || row.total_sales || 0;
        byLoc[lid].orders += row.order_count || 0;
      }
      return { success: true, data: Object.values(byLoc) };
    }
    case "detailed": {
      const { start, end } = getDateRange();
      let q = sb.from("v_daily_sales").select("*").eq("store_id", sid)
        .gte("sale_date", start).lte("sale_date", end).order("sale_date", { ascending: false });
      if (args.location_id) q = q.eq("location_id", args.location_id as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "employee": {
      const { data, error } = await sb.rpc("employee_analytics", { p_store_id: sid });
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "discover": {
      const { data, error } = await sb.rpc("get_analytics_summary", { p_store_id: sid });
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown analytics action: ${args.action}` };
  }
}

async function handleLocations(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  let q = sb.from("locations").select("id, name, address, is_active, type").eq("store_id", sid);
  if (args.is_active !== undefined) q = q.eq("is_active", args.is_active as boolean);
  if (args.name) q = q.ilike("name", `%${args.name}%`);
  const { data, error } = await q;
  return error ? { success: false, error: error.message } : { success: true, data };
}

async function handleSuppliers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  let q = sb.from("suppliers").select("id, name, email, phone, contact_name").eq("store_id", sid);
  if (args.name) q = q.ilike("name", `%${args.name}%`);
  const { data, error } = await q;
  return error ? { success: false, error: error.message } : { success: true, data };
}

async function handleEmail(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  switch (args.action) {
    case "inbox": {
      let q = sb.from("email_threads").select("*, latest_message:email_inbox(subject, from_email, created_at)")
        .eq("store_id", sid).order("updated_at", { ascending: false }).limit(args.limit as number || 25);
      if (args.status) q = q.eq("status", args.status as string);
      if (args.mailbox) q = q.eq("mailbox", args.mailbox as string);
      if (args.priority) q = q.eq("priority", args.priority as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "inbox_get": {
      const { data, error } = await sb.from("email_threads")
        .select("*, messages:email_inbox(*)").eq("id", args.thread_id as string).single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "send": {
      // Invoke send-email edge function
      const sbUrl = Deno.env.get("SUPABASE_URL")!;
      const sbKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      try {
        const resp = await fetch(`${sbUrl}/functions/v1/send-email`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${sbKey}` },
          body: JSON.stringify({ to: args.to, subject: args.subject, html: args.html, text: args.text, storeId: sid })
        });
        const result = await resp.json();
        return resp.ok ? { success: true, data: result } : { success: false, error: result.error || "Send failed" };
      } catch (err) {
        return { success: false, error: `Email send failed: ${err}` };
      }
    }
    case "send_template": {
      const sbUrl = Deno.env.get("SUPABASE_URL")!;
      const sbKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      try {
        const resp = await fetch(`${sbUrl}/functions/v1/send-email`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${sbKey}` },
          body: JSON.stringify({ to: args.to, template: args.template, template_data: args.template_data, storeId: sid })
        });
        const result = await resp.json();
        return resp.ok ? { success: true, data: result } : { success: false, error: result.error || "Send failed" };
      } catch (err) {
        return { success: false, error: `Template send failed: ${err}` };
      }
    }
    case "list": {
      const { data, error } = await sb.from("email_sends").select("*")
        .eq("store_id", sid).order("created_at", { ascending: false }).limit(args.limit as number || 50);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "get": {
      const { data, error } = await sb.from("email_sends")
        .select("*").eq("id", args.email_id as string).single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "templates": {
      const { data, error } = await sb.from("email_templates").select("*")
        .eq("store_id", sid).eq("is_active", true);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "inbox_reply": {
      const sbUrl = Deno.env.get("SUPABASE_URL")!;
      const sbKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      try {
        const resp = await fetch(`${sbUrl}/functions/v1/send-email`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${sbKey}` },
          body: JSON.stringify({ to: args.to, subject: args.subject, html: args.html, text: args.text, thread_id: args.thread_id, storeId: sid })
        });
        const result = await resp.json();
        return resp.ok ? { success: true, data: result } : { success: false, error: result.error || "Reply failed" };
      } catch (err) {
        return { success: false, error: `Reply failed: ${err}` };
      }
    }
    case "inbox_update": {
      const updates: Record<string, unknown> = {};
      if (args.status) updates.status = args.status;
      if (args.priority) updates.priority = args.priority;
      if (args.intent) updates.ai_intent = args.intent;
      if (args.ai_summary) updates.ai_summary = args.ai_summary;
      const { data, error } = await sb.from("email_threads")
        .update(updates).eq("id", args.thread_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "inbox_stats": {
      const { data, error } = await sb.from("email_threads")
        .select("status, mailbox, priority").eq("store_id", sid);
      if (error) return { success: false, error: error.message };
      const stats = {
        total: data.length,
        by_status: groupBy(data, "status"),
        by_mailbox: groupBy(data, "mailbox"),
        by_priority: groupBy(data, "priority")
      };
      return { success: true, data: stats };
    }
    default:
      return { success: false, error: `Unknown email action: ${args.action}` };
  }
}

async function handleAlerts(sb: SupabaseClient, _args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  const alerts: Array<{ type: string; severity: string; message: string; data?: unknown }> = [];

  // Low stock alerts (quantity < 10)
  const { data: lowStock } = await sb.from("inventory")
    .select("quantity, product:products(name, sku), location:locations(name)")
    .eq("store_id", sid).lt("quantity", 10).gt("quantity", 0);
  for (const item of lowStock || []) {
    alerts.push({
      type: "low_stock", severity: "warning",
      message: `Low stock: ${(item as any).product?.name || "Unknown"} (${item.quantity} remaining) at ${(item as any).location?.name || "Unknown"}`,
      data: item
    });
  }

  // Out of stock
  const { data: outOfStock } = await sb.from("inventory")
    .select("product:products(name, sku), location:locations(name)")
    .eq("store_id", sid).eq("quantity", 0);
  for (const item of outOfStock || []) {
    alerts.push({
      type: "out_of_stock", severity: "critical",
      message: `Out of stock: ${(item as any).product?.name || "Unknown"} at ${(item as any).location?.name || "Unknown"}`,
      data: item
    });
  }

  // Pending orders
  const { data: pendingOrders } = await sb.from("orders")
    .select("id, order_number, total, created_at")
    .eq("store_id", sid).eq("status", "pending");
  if (pendingOrders?.length) {
    alerts.push({
      type: "pending_orders", severity: "info",
      message: `${pendingOrders.length} pending orders requiring attention`,
      data: { count: pendingOrders.length, orders: pendingOrders.slice(0, 5) }
    });
  }

  return { success: true, data: { total: alerts.length, alerts } };
}

async function handleAuditTrail(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = (args.store_id || storeId) as string;
  const { data, error } = await sb.from("audit_logs").select("*")
    .eq("store_id", sid).order("created_at", { ascending: false })
    .limit(args.limit as number || 25);
  return error ? { success: false, error: error.message } : { success: true, data };
}

function groupBy(arr: Record<string, unknown>[], key: string): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const item of arr) {
    const val = (item[key] as string) || "unknown";
    counts[val] = (counts[val] || 0) + 1;
  }
  return counts;
}

// ============================================================================
// AGENT LOADER
// ============================================================================

async function loadAgentConfig(supabase: SupabaseClient, agentId: string): Promise<AgentConfig | null> {
  const { data, error } = await supabase.from("ai_agent_config").select("*").eq("id", agentId).single();
  if (error || !data) return null;
  return data as AgentConfig;
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const { agentId, storeId, message, conversationHistory } = await req.json();

    if (!agentId || !message) {
      return new Response(JSON.stringify({ error: "agentId and message required" }),
        { status: 400, headers: { "Content-Type": "application/json" } });
    }

    // Create client with service role for full access
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Extract user info from Authorization header (JWT token)
    const authHeader = req.headers.get("Authorization");
    let userId: string | null = null;
    let userEmail: string | null = null;

    if (authHeader && authHeader.startsWith("Bearer ")) {
      const token = authHeader.substring(7);
      try {
        // Verify and decode JWT to get user info
        const { data: { user }, error } = await supabase.auth.getUser(token);
        if (!error && user) {
          userId = user.id;
          userEmail = user.email || null;
        }
      } catch {
        // Continue without user info if token is invalid
      }
    }

    const agent = await loadAgentConfig(supabase, agentId);
    if (!agent) {
      return new Response(JSON.stringify({ error: "Agent not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } });
    }

    // Load tools from registry, filter for this agent
    const allTools = await loadTools(supabase);
    const tools = getToolsForAgent(agent, allTools);
    const traceId = crypto.randomUUID();

    // Build system prompt
    let systemPrompt = agent.system_prompt || "You are a helpful assistant.";
    if (storeId) systemPrompt += `\n\nYou are operating for store_id: ${storeId}. Always include this in tool calls that require it.`;
    if (!agent.can_modify) systemPrompt += "\n\nIMPORTANT: You have read-only access. Do not attempt to modify any data.";

    const messages: Anthropic.MessageParam[] = [
      ...(conversationHistory || []),
      { role: "user", content: message }
    ];

    // SSE stream
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: StreamEvent) => {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
        };

        let turnCount = 0, toolCallCount = 0, totalIn = 0, totalOut = 0;
        let finalResponse = "", continueLoop = true;

        try {
          while (continueLoop && turnCount < (agent.max_tool_calls || 10)) {
            turnCount++;

            const response = await anthropic.messages.create({
              model: agent.model || "claude-sonnet-4-20250514",
              max_tokens: agent.max_tokens || 4096,
              system: systemPrompt,
              tools: tools.map(t => ({ name: t.name, description: t.description, input_schema: t.input_schema })),
              messages,
              stream: true
            });

            let currentText = "";
            const toolUseBlocks: Array<{ id: string; name: string; input: Record<string, unknown> }> = [];
            let currentToolUse: { id: string; name: string; input: string } | null = null;

            for await (const event of response) {
              if (event.type === "content_block_start" && event.content_block.type === "tool_use") {
                currentToolUse = { id: event.content_block.id, name: event.content_block.name, input: "" };
                send({ type: "tool_start", name: event.content_block.name });
              } else if (event.type === "content_block_delta") {
                if (event.delta.type === "text_delta") {
                  currentText += event.delta.text;
                  send({ type: "text", text: event.delta.text });
                } else if (event.delta.type === "input_json_delta" && currentToolUse) {
                  currentToolUse.input += event.delta.partial_json;
                }
              } else if (event.type === "content_block_stop" && currentToolUse) {
                try {
                  toolUseBlocks.push({ id: currentToolUse.id, name: currentToolUse.name, input: JSON.parse(currentToolUse.input) });
                } catch { /* skip invalid JSON */ }
                currentToolUse = null;
              } else if (event.type === "message_delta" && event.usage) {
                totalOut += event.usage.output_tokens;
              } else if (event.type === "message_start" && event.message.usage) {
                totalIn += event.message.usage.input_tokens;
              }
            }

            if (toolUseBlocks.length === 0) {
              finalResponse = currentText;
              continueLoop = false;
              break;
            }

            // Execute tool calls
            const toolResults: Anthropic.MessageParam["content"] = [];
            for (const tu of toolUseBlocks) {
              toolCallCount++;
              const toolArgs = { ...tu.input };
              if (!toolArgs.store_id && storeId) toolArgs.store_id = storeId;

              const result = await executeTool(supabase, tu.name, toolArgs, storeId, traceId, userId, userEmail);
              send({ type: "tool_result", name: tu.name, success: result.success, result: result.success ? result.data : result.error });
              toolResults.push({ type: "tool_result", tool_use_id: tu.id, content: JSON.stringify(result.success ? result.data : { error: result.error }) });
            }

            messages.push({
              role: "assistant",
              content: [
                ...(currentText ? [{ type: "text" as const, text: currentText }] : []),
                ...toolUseBlocks.map(t => ({ type: "tool_use" as const, id: t.id, name: t.name, input: t.input }))
              ]
            });
            messages.push({ role: "user", content: toolResults });
          }

          send({ type: "usage", usage: { input_tokens: totalIn, output_tokens: totalOut } });
          send({ type: "done" });

          // Log execution trace
          try {
            await supabase.from("agent_execution_traces").insert({
              agent_id: agentId, store_id: storeId, user_message: message,
              final_response: finalResponse, success: true, turn_count: turnCount,
              tool_calls: toolCallCount, input_tokens: totalIn, output_tokens: totalOut
            });
          } catch { /* don't fail */ }

        } catch (err) {
          send({ type: "error", error: String(err) });
        }

        controller.close();
      }
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "*",
      },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
