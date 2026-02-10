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
  description: string;
  system_prompt: string;
  model: string;
  max_tokens: number;
  max_tool_calls: number;
  temperature: number;
  enabled_tools: string[];
  can_query: boolean;
  can_send: boolean;
  can_modify: boolean;
  tone: string;
  verbosity: string;
  api_key: string | null;
  store_id: string | null;
  context_config: {
    includeLocations?: boolean;
    locationIds?: string[];
    includeCustomers?: boolean;
    customerSegments?: string[];
    // Context window management (chars, ~4 chars per token)
    max_history_chars?: number;       // total history budget (default 400K ~100K tokens)
    max_tool_result_chars?: number;   // per tool result (default 40K ~10K tokens)
    max_message_chars?: number;       // per history message (default 20K ~5K tokens)
  } | null;
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
  conversationId?: string;
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
    .eq("is_active", true)
    .neq("tool_mode", "code");

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

/** Extract concise metrics from tool results for audit logging (never full payloads). */
function summarizeResult(toolName: string, action: string | undefined, data: unknown): Record<string, unknown> {
  const d = data as Record<string, unknown>;
  try {
    switch (toolName) {
      case "analytics": {
        switch (action) {
          case "summary": {
            // RPC returns object with camelCase keys (totalRevenue, totalOrders, etc.)
            if (Array.isArray(d)) {
              const row = d[0] || {};
              return { total_revenue: row.totalRevenue || row.total_revenue, total_orders: row.totalOrders || row.total_orders, avg_order: row.avgOrderValue || row.avg_order_value, rows: d.length };
            }
            return { total_revenue: d.totalRevenue || d.total_revenue, total_orders: d.totalOrders || d.total_orders, avg_order: d.avgOrderValue, profit_margin: d.profitMargin, unique_customers: d.uniqueCustomers };
          }
          case "by_location":
            return { locations: Array.isArray(d) ? d.length : 0, total_revenue: Array.isArray(d) ? d.reduce((s: number, r: any) => s + (r.revenue || 0), 0) : 0 };
          case "detailed":
            return { rows: Array.isArray(d) ? d.length : 0 };
          case "by_category":
            return { categories: d.categories ? (d.categories as any[]).length : 0, total_revenue: d.totalRevenue, days: d.days };
          case "product_sales":
            return { products: d.products ? (d.products as any[]).length : 0, total_revenue: d.totalRevenue, total_units: d.totalUnits, days: d.days };
          case "category_velocity":
            return { items: d.results ? (d.results as any[]).length : 0, days: d.days };
          case "customers":
          case "customer_intelligence":
            return { rows: Array.isArray(d) ? d.length : (d.customers ? (d.customers as any[]).length : 0) };
          case "products":
          case "product_intelligence":
            return { rows: Array.isArray(d) ? d.length : 0 };
          case "inventory_intelligence":
            return { rows: Array.isArray(d) ? d.length : 0 };
          case "marketing":
          case "marketing_intelligence":
            return { rows: Array.isArray(d) ? d.length : 0 };
          case "fraud":
          case "fraud_detection":
            return { total_orders: d.totalOrders, high_risk: d.highRisk, medium_risk: d.mediumRisk, avg_risk_score: d.avgRiskScore };
          case "employee":
          case "employee_performance":
            return { rows: Array.isArray(d) ? d.length : 0 };
          case "behavior":
          case "behavioral_analytics":
            return { sessions: (d.summary as any)?.sessions, page_views: (d.summary as any)?.pageViews };
          case "full":
          case "business_intelligence":
            return { rows: Array.isArray(d) ? d.length : 0 };
          case "discover":
            return { rows: Array.isArray(d) ? d.length : 0 };
          default:
            return { rows: Array.isArray(d) ? d.length : 1 };
        }
      }
      case "inventory":
        return { action, rows: Array.isArray(d) ? d.length : 1 };
      case "inventory_query":
        return { action, rows: Array.isArray(d) ? d.length : (d.products ? (d.products as any[]).length : (d.summary ? 1 : 0)) };
      case "purchase_orders":
        if (action === "list") return { count: Array.isArray(d) ? d.length : (d.purchase_orders ? (d.purchase_orders as any[]).length : 0) };
        return { po_id: d.id, po_number: d.po_number, status: d.status };
      case "transfers":
        if (action === "list") return { count: Array.isArray(d) ? d.length : 0 };
        return { transfer_id: d.id, transfer_number: d.transfer_number, status: d.status };
      case "orders":
        return { count: Array.isArray(d) ? d.length : (d.orders ? (d.orders as any[]).length : 1) };
      case "customers":
        return { count: Array.isArray(d) ? d.length : (d.customers ? (d.customers as any[]).length : 1) };
      case "products":
        return { count: Array.isArray(d) ? d.length : (d.products ? (d.products as any[]).length : 1) };
      case "audit_trail":
        return { count: d.count, days: d.days, actions: d.summary ? Object.keys(d.summary as object).length : 0 };
      case "telemetry":
        return { action, count: d.count || (Array.isArray(d) ? d.length : 0) };
      case "alerts":
        return { total: d.total };
      default:
        // Generic: just report row count if array
        return { rows: Array.isArray(d) ? d.length : 1 };
    }
  } catch {
    return { rows: Array.isArray(d) ? d.length : 1 };
  }
}

async function executeTool(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>,
  storeId?: string,
  traceId?: string,
  userId?: string | null,
  userEmail?: string | null,
  source?: string,
  conversationId?: string
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
        result = await handleDocuments(supabase, args, storeId);
        break;
      case "alerts":
        result = await handleAlerts(supabase, args, storeId);
        break;
      case "audit_trail":
        result = await handleAuditTrail(supabase, args, storeId);
        break;
      case "web_search":
        result = await handleWebSearch(supabase, args, storeId);
        break;
      case "telemetry":
        result = await handleTelemetry(supabase, args, storeId);
        break;

      default:
        result = { success: false, error: `Unknown tool: ${toolName}` };
    }
  } catch (err) {
    result = { success: false, error: String(err) };
  }

  // Log to audit_logs with result summary
  try {
    const details: Record<string, unknown> = { source: source || "edge_function", args };
    // Add concise result summary (never full payload — just key metrics)
    if (result.success && result.data) {
      details.result_summary = summarizeResult(toolName, action, result.data);
    }
    await supabase.from("audit_logs").insert({
      action: `tool.${toolName}${action ? `.${action}` : ""}`,
      severity: result.success ? "info" : "error",
      store_id: storeId || null,
      resource_type: "mcp_tool",
      resource_id: toolName,
      request_id: traceId || null,
      conversation_id: conversationId || null,
      source: source || "edge_function",
      details,
      error_message: result.error || null,
      duration_ms: Date.now() - startTime,
      user_id: userId || null,
      user_email: userEmail || null
    });
  } catch (err) { console.error("[audit]", err); }

  return result;
}

// ============================================================================
// TOOL HANDLERS
// ============================================================================

async function handleInventory(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string; // Always use server-verified storeId, never trust args.store_id
  switch (args.action) {
    case "adjust": {
      const productId = args.product_id as string;
      const locationId = args.location_id as string;
      const adjustment = args.adjustment as number;
      const reason = args.reason as string || "Manual adjustment";

      // STEP 1: Fetch product and location names
      const { data: product } = await sb.from("products")
        .select("name, sku").eq("id", productId).single();
      const { data: location } = await sb.from("locations")
        .select("name").eq("id", locationId).single();

      // STEP 2: Capture BEFORE state
      const { data: current } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", productId)
        .eq("location_id", locationId).single();
      const qtyBefore = current?.quantity || 0;

      // STEP 3: Calculate new quantity
      const qtyAfter = qtyBefore + adjustment;
      if (qtyAfter < 0) {
        return {
          success: false,
          error: `Cannot adjust to negative quantity: current ${qtyBefore}, adjustment ${adjustment} would result in ${qtyAfter}`
        };
      }

      // STEP 4: Perform the adjustment
      const { data, error } = await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: locationId, quantity: qtyAfter },
          { onConflict: "store_id,product_id,location_id" })
        .select().single();
      if (error) return { success: false, error: error.message };

      // Log adjustment
      await sb.from("inventory_adjustments").insert({
        store_id: sid, product_id: productId, location_id: locationId,
        previous_quantity: qtyBefore, new_quantity: qtyAfter,
        adjustment, reason
      }).catch((err: unknown) => console.error("[audit]", err));

      // STEP 5: Return full observability data
      const sign = adjustment >= 0 ? "+" : "";
      return {
        success: true,
        data: {
          intent: `Adjust inventory for ${product?.name || 'product'} at ${location?.name || 'location'}: ${sign}${adjustment} units`,
          product: product ? { id: productId, name: product.name, sku: product.sku } : { id: productId },
          location: location ? { id: locationId, name: location.name } : { id: locationId },
          adjustment,
          reason,
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

      // STEP 1: Fetch product and location names
      const { data: product } = await sb.from("products")
        .select("name, sku").eq("id", productId).single();
      const { data: location } = await sb.from("locations")
        .select("name").eq("id", locationId).single();

      // STEP 2: Capture BEFORE state
      const { data: current } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", productId)
        .eq("location_id", locationId).single();
      const qtyBefore = current?.quantity || 0;

      // STEP 3: Set new quantity
      const { data, error } = await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: locationId, quantity: newQty },
          { onConflict: "store_id,product_id,location_id" })
        .select().single();
      if (error) return { success: false, error: error.message };

      // STEP 4: Return full observability data
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

      // STEP 1: Fetch product and location names (for rich telemetry)
      const { data: product } = await sb.from("products")
        .select("name, sku").eq("id", productId).single();
      const { data: fromLocation } = await sb.from("locations")
        .select("name").eq("id", fromLocationId).single();
      const { data: toLocation } = await sb.from("locations")
        .select("name").eq("id", toLocationId).single();

      // STEP 2: Capture BEFORE state (quantities at both locations)
      const { data: srcBefore } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", productId)
        .eq("location_id", fromLocationId).single();
      const { data: dstBefore } = await sb.from("inventory")
        .select("quantity").eq("store_id", sid)
        .eq("product_id", productId)
        .eq("location_id", toLocationId).single();

      const srcQtyBefore = srcBefore?.quantity || 0;
      const dstQtyBefore = dstBefore?.quantity || 0;

      // Validation: check sufficient stock
      if (srcQtyBefore < qty) {
        return {
          success: false,
          error: `Insufficient stock at ${fromLocation?.name || fromLocationId}: have ${srcQtyBefore}, need ${qty}`
        };
      }

      // STEP 3: Perform the transfer
      // Deduct from source
      await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: fromLocationId, quantity: srcQtyBefore - qty },
          { onConflict: "store_id,product_id,location_id" });
      // Add to destination
      await sb.from("inventory")
        .upsert({ store_id: sid, product_id: productId, location_id: toLocationId, quantity: dstQtyBefore + qty },
          { onConflict: "store_id,product_id,location_id" });

      // STEP 4: Capture AFTER state (new quantities)
      const srcQtyAfter = srcQtyBefore - qty;
      const dstQtyAfter = dstQtyBefore + qty;

      // STEP 5: Return full observability data
      return {
        success: true,
        data: {
          intent: `Transfer ${qty} units of ${product?.name || 'product'} from ${fromLocation?.name || 'source'} to ${toLocation?.name || 'destination'}`,
          product: product ? { id: productId, name: product.name, sku: product.sku } : { id: productId },
          from_location: fromLocation ? { id: fromLocationId, name: fromLocation.name } : { id: fromLocationId },
          to_location: toLocation ? { id: toLocationId, name: toLocation.name } : { id: toLocationId },
          quantity_transferred: qty,
          before_state: {
            from_quantity: srcQtyBefore,
            to_quantity: dstQtyBefore,
            total: srcQtyBefore + dstQtyBefore
          },
          after_state: {
            from_quantity: srcQtyAfter,
            to_quantity: dstQtyAfter,
            total: srcQtyAfter + dstQtyAfter
          }
        }
      };
    }
    default:
      return { success: false, error: `Unknown inventory action: ${args.action}` };
  }
}

async function handleInventoryQuery(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "summary": {
      const { data, error } = await sb.from("inventory")
        .select("*, product:products(name, sku), location:locations(name)")
        .eq("store_id", sid).limit(1000);
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
      const days = (args.days as number) || 30;
      const categoryId = args.category_id as string;
      const productId = args.product_id as string;
      const locationId = args.location_id as string;
      const limit = (args.limit as number) || 50;

      // Use get_product_velocity RPC with full filter support
      const { data, error } = await sb.rpc("get_product_velocity", {
        p_store_id: sid || null,
        p_days: days,
        p_location_id: locationId || null,
        p_category_id: categoryId || null,
        p_product_id: productId || null,
        p_limit: limit
      });
      if (error) return { success: false, error: error.message };

      const products = (data || []).map((row: any) => ({
        productId: row.product_id,
        name: row.product_name,
        sku: row.product_sku,
        category: row.category_name,
        locationId: row.location_id,
        locationName: row.location_name,
        totalQty: row.units_sold,
        totalRevenue: row.revenue,
        orderCount: row.order_count,
        velocityPerDay: row.daily_velocity,
        revenuePerDay: row.daily_revenue,
        currentStock: row.current_stock,
        daysOfStock: row.days_of_stock,
        avgPrice: row.avg_unit_price,
        stockAlert: row.stock_status
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

async function handleInventoryAudit(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
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

// Helper: log inventory mutations to audit_logs for full traceability
async function logInventoryMutation(
  sb: SupabaseClient, storeId: string, action: string,
  referenceId: string, referenceNumber: string, locationId: string,
  mutations: Array<{ product_id: string; before: number; after: number; delta: number }>
) {
  try {
    await sb.from("audit_logs").insert({
      store_id: storeId,
      action: `inventory.${action}`,
      severity: "info",
      resource_type: "inventory_mutation",
      resource_id: referenceId,
      source: "agent_chat",
      details: {
        trigger: action,
        reference_id: referenceId,
        reference_number: referenceNumber,
        location_id: locationId,
        mutations,
        total_items: mutations.length,
        total_units: mutations.reduce((s, m) => s + Math.abs(m.delta), 0)
      }
    });
  } catch (_) { /* telemetry should never block operations */ }
}

async function handlePurchaseOrders(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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

async function handleTransfers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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

async function handleProducts(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("products").select("id, name, sku, slug, status, primary_category_id, category:categories!primary_category_id(name)")
        .eq("store_id", sid).limit(args.limit as number || 25);
      if (args.query) q = q.or(`name.ilike.%${args.query}%,sku.ilike.%${args.query}%`);
      if (args.category) {
        const catVal = args.category as string;
        // If it looks like a UUID, use directly; otherwise resolve name to ID
        if (/^[0-9a-f]{8}-/.test(catVal)) {
          q = q.eq("primary_category_id", catVal);
        } else {
          const { data: cats } = await sb.from("categories").select("id").ilike("name", `%${catVal}%`).eq("store_id", sid).limit(1);
          if (cats?.length) q = q.eq("primary_category_id", cats[0].id);
          else q = q.ilike("name", `%${catVal}%`); // fallback to name search
        }
      }
      if (args.name) q = q.ilike("name", `%${args.name}%`);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "create": {
      const { data, error } = await sb.from("products")
        .insert({ store_id: sid, name: args.name, sku: args.sku })
        .select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "update": {
      const updates: Record<string, unknown> = {};
      if (args.name) updates.name = args.name;
      if (args.base_price) updates.cost_price = args.base_price;
      const { data, error } = await sb.from("products")
        .update(updates).eq("id", args.product_id as string).select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown products action: ${args.action}` };
  }
}

async function handleCollections(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("creation_collections").select("*").eq("store_id", sid);
      if (args.name) q = q.ilike("name", `%${args.name}%`);
      const { data, error } = await q.limit(100);
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
  const sid = storeId as string;
  switch (args.action) {

    // ---- FIND: search customers via v_store_customers view ----
    case "find": {
      const limit = args.limit as number || 25;
      let q = sb.from("v_store_customers")
        .select("id, platform_user_id, first_name, last_name, email, phone, loyalty_points, loyalty_tier, total_spent, total_orders, lifetime_value, is_active, created_at")
        .eq("store_id", sid)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (args.query) {
        const raw = String(args.query).trim();
        // Split multi-word queries so "Hannah Spivey" matches first_name=Hannah OR last_name=Spivey
        const words = raw.split(/\s+/).filter(Boolean);
        if (words.length > 1) {
          // Multi-word: each word matches any field
          const clauses = words.map(w => `first_name.ilike.%${w}%,last_name.ilike.%${w}%`).join(",");
          q = q.or(`${clauses},email.ilike.%${raw}%,phone.ilike.%${raw}%`);
        } else {
          const term = `%${raw}%`;
          q = q.or(`first_name.ilike.${term},last_name.ilike.${term},email.ilike.${term},phone.ilike.${term}`);
        }
      }
      if (args.status === "active") q = q.eq("is_active", true);
      if (args.status === "inactive") q = q.eq("is_active", false);
      if (args.loyalty_tier) q = q.eq("loyalty_tier", args.loyalty_tier as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    // ---- GET: full customer detail with orders, activity, notes ----
    case "get": {
      const custId = args.customer_id as string;
      const { data: customer, error: custErr } = await sb.from("v_store_customers")
        .select("*").eq("id", custId).single();
      if (custErr) return { success: false, error: custErr.message };

      const { data: orders } = await sb.from("orders")
        .select("id, order_number, status, total_amount, payment_status, fulfillment_status, created_at")
        .eq("customer_id", custId)
        .order("created_at", { ascending: false })
        .limit(args.orders_limit as number || 10);

      const { data: notes } = await sb.from("customer_notes")
        .select("id, note, created_by, created_at")
        .eq("customer_id", custId)
        .order("created_at", { ascending: false }).limit(10);

      const { data: activity } = await sb.from("customer_activity")
        .select("id, activity_type, description, created_at")
        .eq("customer_id", custId)
        .order("created_at", { ascending: false }).limit(10);

      const { data: profile } = await sb.from("store_customer_profiles")
        .select("*").eq("relationship_id", custId).maybeSingle();

      return { success: true, data: { ...customer, profile, orders, notes, activity } };
    }

    // ---- CREATE: new customer (platform_user + relationship + profile) ----
    case "create": {
      const email = args.email as string | undefined;
      const phone = args.phone as string | undefined;
      const firstName = args.first_name as string;
      const lastName = args.last_name as string;
      if (!firstName && !lastName) return { success: false, error: "first_name or last_name is required" };

      // Check for existing platform_user by email or phone
      let platformUserId: string | null = null;
      if (email) {
        const { data: existing } = await sb.from("platform_users")
          .select("id").eq("email", email).maybeSingle();
        if (existing) platformUserId = existing.id;
      }
      if (!platformUserId && phone) {
        const { data: existing } = await sb.from("platform_users")
          .select("id").eq("phone", phone).maybeSingle();
        if (existing) platformUserId = existing.id;
      }

      // Create platform_user if not found
      if (!platformUserId) {
        const puInsert: Record<string, unknown> = { first_name: firstName, last_name: lastName };
        if (email) puInsert.email = email;
        if (phone) puInsert.phone = phone;
        if (args.date_of_birth) puInsert.date_of_birth = args.date_of_birth;
        const { data: newPu, error: puErr } = await sb.from("platform_users")
          .insert(puInsert).select("id").single();
        if (puErr) return { success: false, error: `Failed to create platform user: ${puErr.message}` };
        platformUserId = newPu.id;
      }

      // Check if relationship already exists for this store
      const { data: existingRel } = await sb.from("user_creation_relationships")
        .select("id").eq("user_id", platformUserId).eq("store_id", sid).maybeSingle();
      if (existingRel) {
        const { data: existing } = await sb.from("v_store_customers")
          .select("*").eq("id", existingRel.id).single();
        return { success: true, data: existing, note: "Customer already exists for this store" };
      }

      // Create relationship
      const { data: rel, error: relErr } = await sb.from("user_creation_relationships")
        .insert({
          user_id: platformUserId, creation_id: sid, creation_type: "store",
          store_id: sid, role: "user", status: "active",
          email_consent: args.email_consent ?? false,
          sms_consent: args.sms_consent ?? false,
        }).select("id").single();
      if (relErr) return { success: false, error: `Failed to create customer relationship: ${relErr.message}` };

      // Create store profile
      const profileInsert: Record<string, unknown> = { relationship_id: rel.id };
      if (args.street_address) profileInsert.street_address = args.street_address;
      if (args.city) profileInsert.city = args.city;
      if (args.state) profileInsert.state = args.state;
      if (args.postal_code) profileInsert.postal_code = args.postal_code;
      if (args.drivers_license_number) profileInsert.drivers_license_number = args.drivers_license_number;
      if (args.medical_card_number) profileInsert.medical_card_number = args.medical_card_number;
      if (args.medical_card_expiry) profileInsert.medical_card_expiry = args.medical_card_expiry;
      await sb.from("store_customer_profiles").insert(profileInsert);

      const { data: created } = await sb.from("v_store_customers")
        .select("*").eq("id", rel.id).single();
      return { success: true, data: created };
    }

    // ---- UPDATE: modify customer identity or store profile ----
    case "update": {
      const custId = args.customer_id as string;
      const { data: rel, error: relErr } = await sb.from("user_creation_relationships")
        .select("id, user_id").eq("id", custId).single();
      if (relErr) return { success: false, error: `Customer not found: ${relErr.message}` };

      // Update platform_users (identity fields)
      const puUpdates: Record<string, unknown> = {};
      if (args.first_name !== undefined) puUpdates.first_name = args.first_name;
      if (args.last_name !== undefined) puUpdates.last_name = args.last_name;
      if (args.email !== undefined) puUpdates.email = args.email;
      if (args.phone !== undefined) puUpdates.phone = args.phone;
      if (args.date_of_birth !== undefined) puUpdates.date_of_birth = args.date_of_birth;
      if (Object.keys(puUpdates).length > 0) {
        puUpdates.updated_at = new Date().toISOString();
        const { error: puErr } = await sb.from("platform_users")
          .update(puUpdates).eq("id", rel.user_id);
        if (puErr) return { success: false, error: `Failed to update user: ${puErr.message}` };
      }

      // Update relationship (consent, status)
      const relUpdates: Record<string, unknown> = {};
      if (args.status !== undefined) relUpdates.status = args.status;
      if (args.email_consent !== undefined) relUpdates.email_consent = args.email_consent;
      if (args.sms_consent !== undefined) relUpdates.sms_consent = args.sms_consent;
      if (args.push_consent !== undefined) relUpdates.push_consent = args.push_consent;
      if (Object.keys(relUpdates).length > 0) {
        relUpdates.updated_at = new Date().toISOString();
        await sb.from("user_creation_relationships").update(relUpdates).eq("id", custId);
      }

      // Update store profile (loyalty, address, ID, wholesale)
      const profUpdates: Record<string, unknown> = {};
      if (args.loyalty_points !== undefined) profUpdates.loyalty_points = args.loyalty_points;
      if (args.loyalty_tier !== undefined) profUpdates.loyalty_tier = args.loyalty_tier;
      if (args.street_address !== undefined) profUpdates.street_address = args.street_address;
      if (args.city !== undefined) profUpdates.city = args.city;
      if (args.state !== undefined) profUpdates.state = args.state;
      if (args.postal_code !== undefined) profUpdates.postal_code = args.postal_code;
      if (args.drivers_license_number !== undefined) profUpdates.drivers_license_number = args.drivers_license_number;
      if (args.id_verified !== undefined) profUpdates.id_verified = args.id_verified;
      if (args.medical_card_number !== undefined) profUpdates.medical_card_number = args.medical_card_number;
      if (args.medical_card_expiry !== undefined) profUpdates.medical_card_expiry = args.medical_card_expiry;
      if (args.is_wholesale_approved !== undefined) profUpdates.is_wholesale_approved = args.is_wholesale_approved;
      if (args.wholesale_tier !== undefined) profUpdates.wholesale_tier = args.wholesale_tier;
      if (args.wholesale_business_name !== undefined) profUpdates.wholesale_business_name = args.wholesale_business_name;
      if (args.wholesale_license_number !== undefined) profUpdates.wholesale_license_number = args.wholesale_license_number;
      if (args.wholesale_tax_id !== undefined) profUpdates.wholesale_tax_id = args.wholesale_tax_id;
      if (Object.keys(profUpdates).length > 0) {
        profUpdates.updated_at = new Date().toISOString();
        const { error: profErr } = await sb.from("store_customer_profiles")
          .update(profUpdates).eq("relationship_id", custId);
        if (profErr) return { success: false, error: `Failed to update profile: ${profErr.message}` };
      }

      const { data: updated } = await sb.from("v_store_customers")
        .select("*").eq("id", custId).single();
      return { success: true, data: updated };
    }

    // ---- FIND_DUPLICATES: identify potential duplicate customer accounts ----
    case "find_duplicates": {
      // Try RPC first (may not exist yet)
      const { data: dupes, error: dupeErr } = await sb.rpc("find_duplicate_customers", { p_store_id: sid });
      if (!dupeErr && dupes) return { success: true, data: dupes };

      // Fallback: manual duplicate detection by phone
      const { data: byPhone, error: phErr } = await sb.from("v_store_customers")
        .select("id, first_name, last_name, email, phone, total_spent, total_orders, created_at")
        .eq("store_id", sid).not("phone", "is", null).order("phone");
      if (phErr) return { success: false, error: phErr.message };

      const phoneMap = new Map<string, typeof byPhone>();
      for (const c of byPhone || []) {
        if (!c.phone) continue;
        const normalized = c.phone.replace(/\D/g, "").slice(-10);
        if (!phoneMap.has(normalized)) phoneMap.set(normalized, []);
        phoneMap.get(normalized)!.push(c);
      }
      const phoneDupes = Array.from(phoneMap.entries())
        .filter(([_, custs]) => custs.length > 1)
        .map(([phone, custs]) => ({ phone, count: custs.length, customers: custs }));

      // Also check by exact name match
      const { data: byName } = await sb.from("v_store_customers")
        .select("id, first_name, last_name, email, phone, total_spent, total_orders, created_at")
        .eq("store_id", sid).order("last_name").order("first_name");
      const nameMap = new Map<string, typeof byName>();
      for (const c of byName || []) {
        const key = `${(c.first_name || "").toLowerCase().trim()} ${(c.last_name || "").toLowerCase().trim()}`;
        if (!key.trim()) continue;
        if (!nameMap.has(key)) nameMap.set(key, []);
        nameMap.get(key)!.push(c);
      }
      const nameDupes = Array.from(nameMap.entries())
        .filter(([_, custs]) => custs.length > 1)
        .map(([name, custs]) => ({ name, count: custs.length, customers: custs }));

      return {
        success: true,
        data: {
          by_phone: phoneDupes,
          by_name: nameDupes,
          total_phone_dupes: phoneDupes.reduce((s, d) => s + d.count, 0),
          total_name_dupes: nameDupes.reduce((s, d) => s + d.count, 0),
        }
      };
    }

    // ---- MERGE: merge two customer records into one ----
    case "merge": {
      const primaryId = args.primary_customer_id as string;
      const secondaryId = args.secondary_customer_id as string;
      if (!primaryId || !secondaryId) return { success: false, error: "primary_customer_id and secondary_customer_id required" };
      if (primaryId === secondaryId) return { success: false, error: "Cannot merge a customer with itself" };

      // Verify both exist and belong to this store
      const { data: primary } = await sb.from("v_store_customers").select("*").eq("id", primaryId).eq("store_id", sid).single();
      const { data: secondary } = await sb.from("v_store_customers").select("*").eq("id", secondaryId).eq("store_id", sid).single();
      if (!primary) return { success: false, error: `Primary customer ${primaryId} not found in this store` };
      if (!secondary) return { success: false, error: `Secondary customer ${secondaryId} not found in this store` };

      // Reassign all child records from secondary to primary
      const reassignTables = [
        "orders", "customer_activity", "customer_notes", "customer_addresses",
        "customer_loyalty", "customer_sessions", "customer_email_preferences",
        "customer_segment_memberships", "customer_payment_profiles",
      ];
      const reassignResults: Record<string, string> = {};
      for (const table of reassignTables) {
        const { error, count } = await sb.from(table)
          .update({ customer_id: primaryId }).eq("customer_id", secondaryId);
        reassignResults[table] = error ? `error: ${error.message}` : `moved ${count ?? "?"} rows`;
      }

      // Merge profile stats
      const { data: primaryProf } = await sb.from("store_customer_profiles")
        .select("*").eq("relationship_id", primaryId).maybeSingle();
      const { data: secondaryProf } = await sb.from("store_customer_profiles")
        .select("*").eq("relationship_id", secondaryId).maybeSingle();
      if (primaryProf && secondaryProf) {
        await sb.from("store_customer_profiles").update({
          total_spent: parseFloat(primaryProf.total_spent || 0) + parseFloat(secondaryProf.total_spent || 0),
          total_orders: (primaryProf.total_orders || 0) + (secondaryProf.total_orders || 0),
          loyalty_points: (primaryProf.loyalty_points || 0) + (secondaryProf.loyalty_points || 0),
          lifetime_points_earned: (primaryProf.lifetime_points_earned || 0) + (secondaryProf.lifetime_points_earned || 0),
          first_order_at: primaryProf.first_order_at && secondaryProf.first_order_at
            ? (primaryProf.first_order_at < secondaryProf.first_order_at ? primaryProf.first_order_at : secondaryProf.first_order_at)
            : primaryProf.first_order_at || secondaryProf.first_order_at,
          last_order_at: primaryProf.last_order_at && secondaryProf.last_order_at
            ? (primaryProf.last_order_at > secondaryProf.last_order_at ? primaryProf.last_order_at : secondaryProf.last_order_at)
            : primaryProf.last_order_at || secondaryProf.last_order_at,
          updated_at: new Date().toISOString(),
        }).eq("relationship_id", primaryId);
        await sb.from("store_customer_profiles").delete().eq("relationship_id", secondaryId);
      }

      // Mark secondary as merged
      await sb.from("user_creation_relationships").update({
        status: "merged",
        relationship_data: { merged_into: primaryId, merged_at: new Date().toISOString() },
        updated_at: new Date().toISOString(),
      }).eq("id", secondaryId);

      // Fill in missing identity fields from secondary
      const { data: primaryRel } = await sb.from("user_creation_relationships").select("user_id").eq("id", primaryId).single();
      const { data: secondaryRel } = await sb.from("user_creation_relationships").select("user_id").eq("id", secondaryId).single();
      if (primaryRel && secondaryRel) {
        const { data: pPu } = await sb.from("platform_users").select("*").eq("id", primaryRel.user_id).single();
        const { data: sPu } = await sb.from("platform_users").select("*").eq("id", secondaryRel.user_id).single();
        if (pPu && sPu) {
          const fills: Record<string, unknown> = {};
          if (!pPu.email && sPu.email && !sPu.email.startsWith("merged.")) fills.email = sPu.email;
          if (!pPu.phone && sPu.phone && !sPu.phone.startsWith("merged_")) fills.phone = sPu.phone;
          if (!pPu.date_of_birth && sPu.date_of_birth) fills.date_of_birth = sPu.date_of_birth;
          if (Object.keys(fills).length > 0) await sb.from("platform_users").update(fills).eq("id", primaryRel.user_id);
          // Mark secondary identity as merged
          const marks: Record<string, unknown> = {};
          if (sPu.email && !sPu.email.startsWith("merged.")) marks.email = `merged.${sPu.email}`;
          if (sPu.phone && !sPu.phone.startsWith("merged_")) marks.phone = `merged_${sPu.phone}`;
          if (Object.keys(marks).length > 0) await sb.from("platform_users").update(marks).eq("id", secondaryRel.user_id);
        }
      }

      const { data: merged } = await sb.from("v_store_customers").select("*").eq("id", primaryId).single();
      return { success: true, data: { merged_customer: merged, reassign_results: reassignResults } };
    }

    // ---- ADD_NOTE ----
    case "add_note": {
      const { data, error } = await sb.from("customer_notes")
        .insert({ customer_id: args.customer_id, note: args.note, created_by: args.created_by || "agent" })
        .select().single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- NOTES ----
    case "notes": {
      const { data, error } = await sb.from("customer_notes")
        .select("id, note, created_by, created_at")
        .eq("customer_id", args.customer_id as string)
        .order("created_at", { ascending: false }).limit(args.limit as number || 25);
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- ACTIVITY ----
    case "activity": {
      const { data, error } = await sb.from("customer_activity")
        .select("id, activity_type, description, metadata, created_at")
        .eq("customer_id", args.customer_id as string)
        .order("created_at", { ascending: false }).limit(args.limit as number || 25);
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- ORDERS: customer order history ----
    case "orders": {
      const { data, error } = await sb.from("orders")
        .select("id, order_number, status, total_amount, subtotal, tax_amount, payment_status, fulfillment_status, payment_method, created_at")
        .eq("customer_id", args.customer_id as string)
        .order("created_at", { ascending: false }).limit(args.limit as number || 25);
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    default:
      return { success: false, error: `Unknown customers action: ${args.action}. Valid: find, get, create, update, find_duplicates, merge, add_note, notes, activity, orders` };
  }
}

async function handleOrders(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("orders")
        .select("id, order_number, status, total_amount, subtotal, tax_amount, created_at, customer_id, customer:v_store_customers!customer_id(id, first_name, last_name, email, phone)")
        .eq("store_id", sid).order("created_at", { ascending: false }).limit(args.limit as number || 25);
      if (args.status) q = q.eq("status", args.status as string);
      if (args.customer_id) q = q.eq("customer_id", args.customer_id as string);
      if (args.order_number) q = q.eq("order_number", args.order_number as string);
      if (args.query) {
        // Search by order number or customer name
        q = q.or(`order_number.ilike.%${args.query}%`);
      }
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }
    case "get": {
      const { data, error } = await sb.from("orders")
        .select("*, customer:v_store_customers!customer_id(id, first_name, last_name, email, phone, loyalty_points, total_spent, total_orders), items:order_items(*, product:products(id, name, sku))")
        .eq("id", args.order_id as string).single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    default:
      return { success: false, error: `Unknown orders action: ${args.action}` };
  }
}

async function handleAnalytics(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  const locationId = args.location_id as string;
  const daysBack = args.days_back as number;

  // Resolve date range from period/days_back/custom dates
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
  const { start: startDate, end: endDate } = getDateRange();

  switch (args.action) {
    case "summary": {
      const params: Record<string, unknown> = { p_store_id: sid, p_start_date: startDate, p_end_date: endDate };
      if (locationId) params.p_location_id = locationId;
      const { data, error } = await sb.rpc("get_sales_analytics", params);
      return error ? { success: false, error: error.message } : { success: true, data };
    }
    case "by_location": {
      let q = sb.from("v_daily_sales").select("*").eq("store_id", sid)
        .gte("sale_date", startDate).lte("sale_date", endDate);
      if (locationId) q = q.eq("location_id", locationId);
      const { data, error } = await q;
      if (error) return { success: false, error: error.message };
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
      let q = sb.from("v_daily_sales").select("*").eq("store_id", sid)
        .gte("sale_date", startDate).lte("sale_date", endDate).order("sale_date", { ascending: false });
      if (locationId) q = q.eq("location_id", locationId);
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

    // ---- Category & Product Sales (NEW) ----

    case "by_category": {
      const days = daysBack || 30;
      const { data, error } = await sb.rpc("get_category_performance", {
        p_store_id: sid || null,
        p_location_id: locationId || null,
        p_days: days
      });
      if (error) return { success: false, error: error.message };
      const categories = (data || []).map((row: any) => ({
        categoryId: row.category_id,
        categoryName: row.category_name,
        orderCount: row.order_count,
        totalGrams: row.total_grams,
        totalRevenue: row.total_revenue,
        avgPricePerGram: row.avg_price_per_gram,
        revenueShare: row.revenue_share
      }));
      return {
        success: true,
        data: {
          days,
          locationId: locationId || "all",
          categories,
          totalRevenue: categories.reduce((s: number, c: any) => s + parseFloat(c.totalRevenue || 0), 0)
        }
      };
    }

    case "category_velocity": {
      const days = daysBack || 30;
      const categoryName = args.category_name as string;
      const { data, error } = await sb.rpc("get_inventory_velocity", {
        p_store_id: sid || null,
        p_location_id: locationId || null,
        p_category_name: categoryName || null,
        p_days: days
      });
      if (error) return { success: false, error: error.message };
      const results = (data || []).map((row: any) => ({
        locationId: row.location_id,
        locationName: row.location_name,
        locationType: row.location_type,
        categoryId: row.category_id,
        categoryName: row.category_name,
        currentStock: row.current_stock,
        totalSold: row.sold_in_period,
        dailyVelocity: row.daily_velocity,
        daysOfStock: row.days_of_stock,
        stockAlert: row.status
      }));
      return { success: true, data: { days, categoryFilter: categoryName || "all", results } };
    }

    case "product_sales": {
      const days = daysBack || 30;
      const categoryId = args.category_id as string;
      const productId = args.product_id as string;
      const limit = (args.limit as number) || 50;
      const { data, error } = await sb.rpc("get_product_velocity", {
        p_store_id: sid || null,
        p_days: days,
        p_location_id: locationId || null,
        p_category_id: categoryId || null,
        p_product_id: productId || null,
        p_limit: limit
      });
      if (error) return { success: false, error: error.message };
      const products = (data || []).map((row: any) => ({
        productId: row.product_id,
        name: row.product_name,
        sku: row.product_sku,
        category: row.category_name,
        locationId: row.location_id,
        locationName: row.location_name,
        totalQty: row.units_sold,
        totalRevenue: row.revenue,
        orderCount: row.order_count,
        velocityPerDay: row.daily_velocity,
        revenuePerDay: row.daily_revenue,
        currentStock: row.current_stock,
        daysOfStock: row.days_of_stock,
        avgPrice: row.avg_unit_price,
        stockAlert: row.stock_status
      }));
      return {
        success: true,
        data: {
          days,
          filters: { categoryId, locationId, productId },
          products,
          totalUnits: products.reduce((s: number, p: any) => s + parseFloat(p.totalQty || 0), 0),
          totalRevenue: products.reduce((s: number, p: any) => s + parseFloat(p.totalRevenue || 0), 0)
        }
      };
    }

    // ---- Intelligence Actions ----

    case "customers":
    case "customer_intelligence": {
      const { data, error } = await sb.rpc("get_customer_intelligence", { p_store_id: sid || null });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "products":
    case "product_intelligence": {
      const { data, error } = await sb.rpc("get_product_intelligence", { p_store_id: sid || null });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "inventory_intelligence": {
      const { data, error } = await sb.rpc("get_inventory_intelligence", { p_store_id: sid || null });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "marketing":
    case "marketing_intelligence": {
      const { data, error } = await sb.rpc("get_marketing_intelligence", {
        p_store_id: sid || null, p_start_date: startDate, p_end_date: endDate
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "fraud":
    case "fraud_detection": {
      let q = sb.from("v_fraud_detection").select("*").order("risk_score", { ascending: false }).limit(100);
      if (sid) q = q.eq("store_id", sid);
      if (args.risk_level) q = q.eq("risk_level", args.risk_level as string);
      const { data, error } = await q;
      if (error) return { success: false, error: error.message };
      return {
        success: true,
        data: {
          totalOrders: data?.length || 0,
          highRisk: data?.filter((o: any) => o.risk_level === "high").length || 0,
          mediumRisk: data?.filter((o: any) => o.risk_level === "medium").length || 0,
          avgRiskScore: data?.length ? Math.round(data.reduce((s: number, o: any) => s + o.risk_score, 0) / data.length) : 0,
          orders: data
        }
      };
    }

    case "employee_performance": {
      let q = sb.from("v_employee_performance").select("*").order("total_revenue", { ascending: false });
      if (sid) q = q.eq("store_id", sid);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "behavior":
    case "behavioral_analytics": {
      let q = sb.from("v_behavioral_analytics").select("*")
        .gte("visit_date", startDate).lte("visit_date", endDate);
      if (sid) q = q.eq("store_id", sid);
      const { data, error } = await q;
      if (error) return { success: false, error: error.message };
      const totals = (data || []).reduce((acc: any, row: any) => ({
        sessions: acc.sessions + (row.sessions || 0),
        pageViews: acc.pageViews + (row.page_views || 0),
        rageClicks: acc.rageClicks + (row.total_rage_clicks || 0),
        uxIssues: acc.uxIssues + (row.sessions_with_ux_issues || 0)
      }), { sessions: 0, pageViews: 0, rageClicks: 0, uxIssues: 0 });
      return {
        success: true,
        data: {
          summary: {
            ...totals,
            avgPagesPerSession: totals.sessions ? Math.round((totals.pageViews / totals.sessions) * 100) / 100 : 0,
            uxIssueRate: totals.sessions ? Math.round((totals.uxIssues / totals.sessions) * 10000) / 100 : 0
          }
        }
      };
    }

    case "full":
    case "business_intelligence": {
      const { data, error } = await sb.rpc("get_business_intelligence", {
        p_store_id: sid || null, p_start_date: startDate, p_end_date: endDate
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    default:
      return { success: false, error: `Unknown analytics action: ${args.action}. Available: summary, by_location, detailed, by_category, category_velocity, product_sales, discover, employee, customers, products, inventory_intelligence, marketing, fraud, employee_performance, behavior, full` };
  }
}

async function handleLocations(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  let q = sb.from("locations").select("id, name, address_line1, city, state, is_active, type").eq("store_id", sid);
  if (args.is_active !== undefined) q = q.eq("is_active", args.is_active as boolean);
  if (args.name) q = q.ilike("name", `%${args.name}%`);
  const { data, error } = await q.limit(100);
  return error ? { success: false, error: error.message } : { success: true, data };
}

async function handleSuppliers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  let q = sb.from("suppliers").select("id, external_name, external_company, contact_name, contact_email, contact_phone, city, state, is_active").eq("store_id", sid);
  if (args.name) q = q.or(`external_name.ilike.%${args.name}%,external_company.ilike.%${args.name}%,contact_name.ilike.%${args.name}%`);
  const { data, error } = await q.limit(100);
  return error ? { success: false, error: error.message } : { success: true, data };
}

async function handleEmail(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
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
        .eq("store_id", sid).eq("is_active", true).limit(100);
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
        .select("status, mailbox, priority").eq("store_id", sid).limit(1000);
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

// ---- DOCUMENTS ----

function escapeCSV(val: unknown): string {
  if (val === null || val === undefined) return "";
  const str = String(val);
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return '"' + str.replace(/"/g, '""') + '"';
  }
  return str;
}

function fillTemplate(template: string, data: Record<string, unknown>): string {
  return template.replace(/\{\{(\w+(?:\.\w+)*)\}\}/g, (match, key) => {
    const parts = (key as string).split(".");
    let val: unknown = data;
    for (const p of parts) {
      if (val === null || val === undefined) return match;
      val = (val as Record<string, unknown>)[p];
    }
    return val !== null && val !== undefined ? String(val) : match;
  });
}

async function handleDocuments(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  const action = args.action as string;

  switch (action) {
    case "create": {
      const docType = (args.document_type as string) || "text";
      const name = args.name as string;
      if (!name) return { success: false, error: "name is required" };

      let content: string;
      const extMap: Record<string, string> = { csv: "csv", json: "json", text: "txt", markdown: "md", html: "html" };
      const mimeMap: Record<string, string> = {
        csv: "text/csv", json: "application/json", text: "text/plain",
        markdown: "text/markdown", html: "text/html",
      };
      const ext = extMap[docType] || "txt";
      const mime = mimeMap[docType] || "text/plain";

      if (docType === "csv") {
        const headers = args.headers as string[];
        const rows = args.rows as unknown[][];
        if (!headers || !rows) return { success: false, error: "headers and rows required for CSV" };
        const lines = [headers.map(escapeCSV).join(",")];
        for (const row of rows) {
          if (Array.isArray(row)) {
            lines.push(row.map(escapeCSV).join(","));
          } else {
            lines.push(headers.map(h => escapeCSV((row as Record<string, unknown>)[h])).join(","));
          }
        }
        content = lines.join("\n");
      } else if (docType === "json") {
        const jsonData = args.data || args.content;
        content = typeof jsonData === "string" ? jsonData : JSON.stringify(jsonData, null, 2);
      } else {
        content = (args.content as string) || "";
      }

      const safeName = name.replace(/[^a-zA-Z0-9_\-]/g, "_");
      const fileName = `${safeName}_${Date.now()}.${ext}`;
      const storagePath = `${sid}/${fileName}`;

      const { error: uploadErr } = await sb.storage
        .from("documents")
        .upload(storagePath, new TextEncoder().encode(content), { contentType: mime, upsert: true });
      if (uploadErr) return { success: false, error: `Upload failed: ${uploadErr.message}` };

      const { data: urlData } = sb.storage.from("documents").getPublicUrl(storagePath);
      const fileUrl = urlData.publicUrl;
      const sizeBytes = new TextEncoder().encode(content).length;

      const { data: record, error: insertErr } = await sb.from("store_documents").insert({
        store_id: sid,
        document_type: docType,
        file_name: fileName,
        file_url: fileUrl,
        file_size: sizeBytes,
        file_type: mime,
        document_name: name,
        source_name: "Documents Edge Function",
        document_date: new Date().toISOString().split("T")[0],
        data: { document_type: docType },
        metadata: { size_bytes: sizeBytes },
      }).select("id, document_name, file_url, created_at").single();

      if (insertErr) return { success: false, error: insertErr.message };
      return { success: true, data: { id: record.id, name: record.document_name, type: docType, url: record.file_url, size: sizeBytes } };
    }

    case "find": {
      let query = sb.from("store_documents")
        .select("id, document_type, document_name, reference_number, file_url, file_type, file_size, created_at, metadata");
      if (sid) query = query.eq("store_id", sid);
      if (args.document_type) query = query.eq("document_type", args.document_type as string);
      if (args.name) query = query.ilike("document_name", `%${args.name}%`);
      query = query.order("created_at", { ascending: false });
      if (args.limit) query = query.limit(args.limit as number);

      const { data, error } = await query;
      if (error) return { success: false, error: error.message };
      return {
        success: true,
        data: {
          count: data?.length || 0,
          documents: (data || []).map(d => ({
            id: d.id, type: d.document_type, name: d.document_name,
            reference: d.reference_number, url: d.file_url,
            size: d.file_size, created: d.created_at,
          })),
        },
      };
    }

    case "delete": {
      if (!args.confirm) return { success: false, error: "Set confirm: true to delete" };
      let query = sb.from("store_documents").delete().eq("store_id", sid);
      if (args.document_type) query = query.eq("document_type", args.document_type as string);
      if (args.name) query = query.ilike("document_name", `%${args.name}%`);
      const { data, error } = await query.select("id");
      if (error) return { success: false, error: error.message };
      return { success: true, data: { deleted: data?.length || 0 } };
    }

    case "create_template": {
      if (!args.name) return { success: false, error: "name is required" };
      if (!args.document_type) return { success: false, error: "document_type is required" };
      const { data, error } = await sb.from("document_templates").insert({
        store_id: sid || null,
        name: args.name as string,
        description: (args.description as string) || null,
        document_type: args.document_type as string,
        content: (args.content as string) || null,
        headers: (args.headers as string[]) || null,
        schema: (args.schema as unknown[]) || [],
        metadata: (args.data as Record<string, unknown>) || {},
      }).select("id, name, document_type, created_at").single();
      if (error) return { success: false, error: error.message };
      return { success: true, data: { template_id: data.id, name: data.name, type: data.document_type } };
    }

    case "list_templates": {
      let query = sb.from("document_templates")
        .select("id, name, description, document_type, headers, schema, created_at")
        .eq("is_active", true);
      if (sid) query = query.or(`store_id.eq.${sid},store_id.is.null`);
      if (args.document_type) query = query.eq("document_type", args.document_type as string);
      if (args.limit) query = query.limit(args.limit as number);
      query = query.order("created_at", { ascending: false });

      const { data, error } = await query;
      if (error) return { success: false, error: error.message };
      return {
        success: true,
        data: {
          count: data?.length || 0,
          templates: (data || []).map(t => ({
            id: t.id, name: t.name, description: t.description,
            type: t.document_type, headers: t.headers,
            fields: (t.schema as unknown[])?.length || 0,
          })),
        },
      };
    }

    case "from_template": {
      const templateId = args.template_id as string;
      if (!templateId) return { success: false, error: "template_id is required" };

      const { data: template, error: tErr } = await sb.from("document_templates")
        .select("*").eq("id", templateId).single();
      if (tErr || !template) return { success: false, error: "Template not found" };

      const tData = { ...(template.metadata as Record<string, unknown>), ...(args.data as Record<string, unknown> || {}), date: new Date().toISOString().split("T")[0] };
      const docType = template.document_type as string;
      const docName = (args.name as string) || fillTemplate(template.name, tData);

      let content: string;
      if (docType === "csv") {
        const headers = template.headers as string[] || [];
        const rows = args.rows as unknown[][];
        if (!rows) return { success: false, error: "rows required for CSV template" };
        const lines = [headers.map(escapeCSV).join(",")];
        for (const row of rows) {
          if (Array.isArray(row)) lines.push(row.map(escapeCSV).join(","));
          else lines.push(headers.map(h => escapeCSV((row as Record<string, unknown>)[h])).join(","));
        }
        content = lines.join("\n");
      } else if (docType === "json") {
        content = template.content ? fillTemplate(template.content as string, tData) : JSON.stringify(tData, null, 2);
      } else {
        content = template.content ? fillTemplate(template.content as string, tData) : "";
      }

      const extMap: Record<string, string> = { csv: "csv", json: "json", text: "txt", markdown: "md", html: "html" };
      const mimeMap: Record<string, string> = {
        csv: "text/csv", json: "application/json", text: "text/plain",
        markdown: "text/markdown", html: "text/html",
      };
      const ext = extMap[docType] || "txt";
      const mime = mimeMap[docType] || "text/plain";
      const safeName = docName.replace(/[^a-zA-Z0-9_\-]/g, "_");
      const fileName = `${safeName}_${Date.now()}.${ext}`;
      const storagePath = `${sid}/${fileName}`;

      const { error: uploadErr } = await sb.storage
        .from("documents")
        .upload(storagePath, new TextEncoder().encode(content), { contentType: mime, upsert: true });
      if (uploadErr) return { success: false, error: `Upload failed: ${uploadErr.message}` };

      const { data: urlData } = sb.storage.from("documents").getPublicUrl(storagePath);
      const sizeBytes = new TextEncoder().encode(content).length;

      const { data: record, error: insertErr } = await sb.from("store_documents").insert({
        store_id: sid,
        document_type: docType,
        file_name: fileName,
        file_url: urlData.publicUrl,
        file_size: sizeBytes,
        file_type: mime,
        document_name: docName,
        source_name: "Documents Edge Function",
        document_date: new Date().toISOString().split("T")[0],
        data: { template_id: template.id, template_name: template.name },
        metadata: { size_bytes: sizeBytes, from_template: true },
      }).select("id, document_name, file_url, created_at").single();

      if (insertErr) return { success: false, error: insertErr.message };
      return { success: true, data: { id: record.id, name: record.document_name, type: docType, template: template.name, url: record.file_url, size: sizeBytes } };
    }

    default:
      return { success: false, error: `Unknown documents action: ${action}. Valid: create, find, delete, create_template, list_templates, from_template` };
  }
}

async function handleAlerts(sb: SupabaseClient, _args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  const alerts: Array<{ type: string; severity: string; message: string; data?: unknown }> = [];

  // Low stock alerts (quantity < 10)
  const { data: lowStock } = await sb.from("inventory")
    .select("quantity, product:products(name, sku), location:locations(name)")
    .eq("store_id", sid).lt("quantity", 10).gt("quantity", 0).limit(100);
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
    .eq("store_id", sid).eq("quantity", 0).limit(100);
  for (const item of outOfStock || []) {
    alerts.push({
      type: "out_of_stock", severity: "critical",
      message: `Out of stock: ${(item as any).product?.name || "Unknown"} at ${(item as any).location?.name || "Unknown"}`,
      data: item
    });
  }

  // Pending orders
  const { data: pendingOrders } = await sb.from("orders")
    .select("id, order_number, total_amount, created_at")
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
  const sid = storeId as string;
  const limit = Math.min((args.limit as number) || 50, 200);
  const days = (args.days as number) || 1;
  const cutoff = new Date(Date.now() - days * 86400_000).toISOString();

  // "search" action: full-text search across logs
  if (args.action === "search") {
    const query = args.query as string;
    if (!query) return { success: false, error: "query parameter is required for search action" };
    const { data, error } = await sb.from("audit_logs")
      .select("id, action, severity, source, resource_type, resource_id, user_email, details, created_at")
      .eq("store_id", sid)
      .gte("created_at", cutoff)
      .or(`action.ilike.%${query}%,error_message.ilike.%${query}%,user_email.ilike.%${query}%,resource_id.ilike.%${query}%`)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error) return { success: false, error: error.message };
    return { success: true, data: { query, entries: data, count: data?.length || 0, days } };
  }

  // Default action: filtered list
  let q = sb.from("audit_logs")
    .select("id, action, severity, source, resource_type, resource_id, details, user_email, created_at")
    .eq("store_id", sid)
    .gte("created_at", cutoff)
    .order("created_at", { ascending: false })
    .limit(limit);

  // Optional filters
  if (args.action_filter) q = q.ilike("action", `%${args.action_filter}%`);
  if (args.resource_type) q = q.eq("resource_type", args.resource_type as string);
  if (args.severity) q = q.eq("severity", args.severity as string);
  if (args.source) q = q.eq("source", args.source as string);

  const { data, error } = await q;
  if (error) return { success: false, error: error.message };

  // Summarize by action for quick overview
  const byAction: Record<string, number> = {};
  for (const entry of data || []) {
    byAction[entry.action] = (byAction[entry.action] || 0) + 1;
  }

  return { success: true, data: { entries: data, summary: byAction, days, count: data?.length || 0 } };
}

async function handleWebSearch(sb: SupabaseClient, args: Record<string, unknown>, _storeId?: string) {
  const query = args.query as string;
  const numResults = (args.num_results as number) || 5;

  // Read from platform_secrets table first, fall back to env var
  const { data: secret } = await sb.from("platform_secrets").select("value").eq("key", "exa_api_key").single();
  const exaApiKey = secret?.value || Deno.env.get("EXA_API_KEY");

  if (!exaApiKey) {
    return { success: false, error: "Exa API key not configured. Add 'exa_api_key' to platform_secrets table." };
  }

  if (!query) {
    return { success: false, error: "Query parameter is required" };
  }

  try {
    const response = await fetch("https://api.exa.ai/search", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": exaApiKey
      },
      body: JSON.stringify({
        query,
        numResults,
        useAutoprompt: true,
        type: "auto"
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      return { success: false, error: `Exa API error: ${response.status} - ${errorText}` };
    }

    const data = await response.json();
    return {
      success: true,
      data: {
        query,
        results: data.results || [],
        autopromptString: data.autopromptString
      }
    };
  } catch (err) {
    return { success: false, error: `Web search failed: ${err}` };
  }
}

async function handleTelemetry(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  const hoursBack = (args.hours_back as number) || 24;
  const limit = Math.min((args.limit as number) || 50, 200);

  switch (args.action) {
    // ---- conversation_detail: Full conversation with messages + audit entries ----
    case "conversation_detail": {
      const convId = args.conversation_id as string;
      if (!convId) return { success: false, error: "conversation_id is required" };

      const [convResult, msgResult, auditResult] = await Promise.all([
        sb.from("ai_conversations").select("*").eq("id", convId).eq("store_id", sid).single(),
        sb.from("ai_messages").select("*").eq("conversation_id", convId).order("created_at", { ascending: true }),
        sb.from("audit_logs").select("id, action, severity, duration_ms, status_code, error_message, resource_id, input_tokens, output_tokens, model, created_at")
          .eq("conversation_id", convId).order("created_at", { ascending: true }).limit(200)
      ]);
      if (convResult.error) return { success: false, error: convResult.error.message };
      return {
        success: true,
        data: {
          conversation: convResult.data,
          messages: msgResult.data || [],
          audit_entries: auditResult.data || [],
          message_count: msgResult.data?.length || 0,
          audit_count: auditResult.data?.length || 0
        }
      };
    }

    // ---- conversations: List recent conversations ----
    case "conversations": {
      const convLimit = Math.min((args.limit as number) || 20, 100);
      let q = sb.from("ai_conversations")
        .select("*")
        .eq("store_id", sid)
        .gte("created_at", new Date(Date.now() - hoursBack * 3600_000).toISOString())
        .order("created_at", { ascending: false })
        .limit(convLimit);
      if (args.agent_id) q = q.eq("agent_id", args.agent_id as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data: { count: data?.length || 0, conversations: data } };
    }

    // ---- agent_performance: Agent-level analytics via RPC ----
    case "agent_performance": {
      const agentId = args.agent_id as string;
      if (!agentId) return { success: false, error: "agent_id is required" };
      const days = (args.days as number) || 7;
      const { data, error } = await sb.rpc("get_agent_analytics", { p_agent_id: agentId, p_days: days });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- tool_analytics: Per-tool performance metrics via RPC ----
    case "tool_analytics": {
      const { data, error } = await sb.rpc("get_tool_analytics", {
        p_store_id: sid || null,
        p_hours_back: hoursBack,
        p_tool_name: (args.tool_name as string) || null
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- tool_timeline: Time-bucketed tool metrics via RPC ----
    case "tool_timeline": {
      const bucketMinutes = (args.bucket_minutes as number) || 15;
      const { data, error } = await sb.rpc("get_tool_timeline", {
        p_store_id: sid || null,
        p_hours_back: hoursBack,
        p_bucket_minutes: bucketMinutes,
        p_tool_name: (args.tool_name as string) || null
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- trace: Full trace reconstruction via RPC ----
    case "trace": {
      const traceId = args.trace_id as string;
      if (!traceId) return { success: false, error: "trace_id is required" };
      const { data, error } = await sb.rpc("get_trace", { p_trace_id: traceId });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- span_detail: Individual span deep-dive via RPC ----
    case "span_detail": {
      const spanId = args.span_id as string;
      if (!spanId) return { success: false, error: "span_id is required" };
      const { data, error } = await sb.rpc("get_tool_trace_detail", { p_span_id: spanId });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- error_patterns: Error correlation + burst detection via RPC ----
    case "error_patterns": {
      const { data, error } = await sb.rpc("get_tool_error_patterns", {
        p_store_id: sid || null,
        p_hours_back: hoursBack
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- token_usage: Token consumption by model/day ----
    case "token_usage": {
      const cutoff = new Date(Date.now() - hoursBack * 3600_000).toISOString();
      // Build base query — if agent_id is provided, get conversation IDs first
      let conversationFilter: string[] | null = null;
      if (args.agent_id) {
        const { data: convs } = await sb.from("ai_conversations")
          .select("id").eq("agent_id", args.agent_id as string).eq("store_id", sid);
        conversationFilter = convs?.map(c => c.id) || [];
      }

      let q = sb.from("audit_logs")
        .select("model, input_tokens, output_tokens, total_cost, created_at")
        .eq("store_id", sid)
        .gte("created_at", cutoff)
        .not("input_tokens", "is", null);
      if (conversationFilter !== null) {
        if (conversationFilter.length === 0) return { success: true, data: { rows: [], summary: { total_input: 0, total_output: 0, total_cost: 0 } } };
        q = q.in("conversation_id", conversationFilter);
      }
      const { data, error } = await q.order("created_at", { ascending: false }).limit(1000);
      if (error) return { success: false, error: error.message };

      // Aggregate in-memory by model + day
      const buckets: Record<string, { model: string; day: string; requests: number; input_tokens: number; output_tokens: number; total_cost: number }> = {};
      for (const row of data || []) {
        const day = (row.created_at as string).substring(0, 10);
        const model = row.model || "unknown";
        const key = `${model}|${day}`;
        if (!buckets[key]) buckets[key] = { model, day, requests: 0, input_tokens: 0, output_tokens: 0, total_cost: 0 };
        buckets[key].requests++;
        buckets[key].input_tokens += row.input_tokens || 0;
        buckets[key].output_tokens += row.output_tokens || 0;
        buckets[key].total_cost += parseFloat(row.total_cost || "0");
      }
      const rows = Object.values(buckets).sort((a, b) => b.day.localeCompare(a.day) || b.total_cost - a.total_cost);
      const summary = rows.reduce((acc, r) => ({
        total_input: acc.total_input + r.input_tokens,
        total_output: acc.total_output + r.output_tokens,
        total_cost: acc.total_cost + r.total_cost,
        total_requests: acc.total_requests + r.requests
      }), { total_input: 0, total_output: 0, total_cost: 0, total_requests: 0 });
      return { success: true, data: { rows, summary, hours_back: hoursBack } };
    }

    // ---- sources: List all telemetry sources with counts ----
    case "sources": {
      const cutoff = new Date(Date.now() - hoursBack * 3600_000).toISOString();
      const { data, error } = await sb.from("audit_logs")
        .select("source, severity, created_at")
        .eq("store_id", sid)
        .gte("created_at", cutoff)
        .not("source", "is", null)
        .limit(5000);
      if (error) return { success: false, error: error.message };

      // Aggregate by source
      const sourceMap: Record<string, { source: string; count: number; errors: number; last_seen: string }> = {};
      for (const row of data || []) {
        const src = row.source as string;
        if (!sourceMap[src]) sourceMap[src] = { source: src, count: 0, errors: 0, last_seen: row.created_at as string };
        sourceMap[src].count++;
        if (row.severity === "error") sourceMap[src].errors++;
        if ((row.created_at as string) > sourceMap[src].last_seen) sourceMap[src].last_seen = row.created_at as string;
      }
      const sources = Object.values(sourceMap).sort((a, b) => b.count - a.count);
      return { success: true, data: { sources, total_entries: data?.length || 0, hours_back: hoursBack } };
    }

    default:
      return { success: false, error: `Unknown telemetry action: ${args.action}. Available: conversation_detail, conversations, agent_performance, tool_analytics, tool_timeline, trace, span_detail, error_patterns, token_usage, sources. For activity logs and inventory changes, use the audit_trail tool instead.` };
  }
}

function groupBy(arr: Record<string, unknown>[], key: string): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const item of arr) {
    const val = (item[key] as string) || "unknown";
    counts[val] = (counts[val] || 0) + 1;
  }
  return counts;
}

function validateUUID(value: unknown, name: string): string {
  const s = String(value || "");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)) {
    throw new Error(`Invalid UUID for ${name}: ${s}`);
  }
  return s;
}

function validateNumber(value: unknown, name: string, opts?: { min?: number; max?: number }): number {
  const n = Number(value);
  if (isNaN(n)) throw new Error(`Invalid number for ${name}: ${value}`);
  if (opts?.min !== undefined && n < opts.min) throw new Error(`${name} must be >= ${opts.min}`);
  if (opts?.max !== undefined && n > opts.max) throw new Error(`${name} must be <= ${opts.max}`);
  return n;
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

// Default client — overridden per-agent if api_key is set
const defaultAnthropicKey = Deno.env.get("ANTHROPIC_API_KEY")!;

function getAnthropicClient(agent: AgentConfig): Anthropic {
  const key = agent.api_key || defaultAnthropicKey;
  return new Anthropic({ apiKey: key });
}

// CORS: use ALLOWED_ORIGINS env var (comma-separated) or fall back to wildcard for local dev
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") || "*").split(",").map((s: string) => s.trim());

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowedOrigin = ALLOWED_ORIGINS.includes("*") ? "*" : (ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]);
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: getCorsHeaders(req) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
    });
  }

  try {
    // ── Auth gate: require valid JWT or service-role key ──
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing authorization" }),
        { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
    }

    const token = authHeader.substring(7);

    // Create service-role client for data operations
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Decode JWT to check role (service_role keys bypass getUser)
    let user: { id: string; email?: string } | null = null;
    let isServiceRole = false;
    try {
      const payloadB64 = token.split(".")[1];
      if (payloadB64) {
        const payload = JSON.parse(atob(payloadB64));
        if (payload.role === "service_role") {
          isServiceRole = true;
        }
      }
    } catch (_) { /* not a valid JWT — will fail getUser below */ }

    if (!isServiceRole) {
      // Validate user JWT
      const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(token);
      if (authError || !authUser) {
        return new Response(JSON.stringify({ error: "Invalid or expired token" }),
          { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
      }
      user = authUser;
    }

    const body = await req.json();
    const { agentId, message, conversationHistory, source, conversationId } = body;
    // storeId: prefer request body, fall back to agent's configured store_id
    let storeId: string | undefined = body.storeId;

    if (!agentId || !message) {
      return new Response(JSON.stringify({ error: "agentId and message required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
    }

    // Verify user has access to the requested store (skip for service_role — has full access)
    if (storeId && !isServiceRole) {
      const userClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: `Bearer ${token}` } } }
      );
      const { data: storeAccess, error: storeErr } = await userClient
        .from("stores")
        .select("id")
        .eq("id", storeId)
        .limit(1);
      if (storeErr || !storeAccess?.length) {
        return new Response(JSON.stringify({ error: "Access denied to store" }),
          { status: 403, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
      }
    }

    // User info: from JWT for user tokens, from body for service_role
    const userId: string = user?.id || body.userId || "";
    const userEmail: string | null = user?.email || body.userEmail || null;

    const agent = await loadAgentConfig(supabase, agentId);
    if (!agent) {
      return new Response(JSON.stringify({ error: "Agent not found" }),
        { status: 404, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
    }

    // Load tools from registry, filter for this agent
    const allTools = await loadTools(supabase);
    const tools = getToolsForAgent(agent, allTools);
    const traceId = crypto.randomUUID();

    // Resolve or create conversation in ai_conversations
    let activeConversationId: string;
    if (conversationId) {
      activeConversationId = conversationId;
    } else {
      // Create new conversation (user_id FK requires valid auth.users ID — null if invalid)
      let conv = await supabase.from("ai_conversations").insert({
        store_id: storeId || null,
        user_id: userId || null,
        agent_id: agentId,
        title: message.substring(0, 100),
        metadata: { agentName: agent.name, source: source || "whale_chat" }
      }).select("id").single();
      if (conv.error && userId) {
        // FK violation on user_id — retry without it
        conv = await supabase.from("ai_conversations").insert({
          store_id: storeId || null,
          agent_id: agentId,
          title: message.substring(0, 100),
          metadata: { agentName: agent.name, source: source || "whale_chat", userId, userEmail }
        }).select("id").single();
      }
      activeConversationId = conv.data?.id || crypto.randomUUID();
    }

    // Build system prompt from agent config
    let systemPrompt = agent.system_prompt || "You are a helpful assistant.";
    if (storeId) systemPrompt += `\n\nYou are operating for store_id: ${storeId}. Always include this in tool calls that require it.`;
    if (!agent.can_modify) systemPrompt += "\n\nIMPORTANT: You have read-only access. Do not attempt to modify any data.";

    // Tone & verbosity from agent config
    if (agent.tone && agent.tone !== "professional") {
      systemPrompt += `\n\nTone: Respond in a ${agent.tone} tone.`;
    }
    if (agent.verbosity === "concise") {
      systemPrompt += "\n\nBe concise — short answers, minimal explanation.";
    } else if (agent.verbosity === "verbose") {
      systemPrompt += "\n\nBe thorough — provide detailed answers with full context.";
    }

    // Context config — enrich with location/customer context
    if (agent.context_config) {
      const ctx = agent.context_config;
      if (ctx.includeLocations && ctx.locationIds?.length) {
        systemPrompt += `\n\nFocus on these locations: ${ctx.locationIds.join(", ")}`;
      }
      if (ctx.includeCustomers && ctx.customerSegments?.length) {
        systemPrompt += `\n\nFocus on these customer segments: ${ctx.customerSegments.join(", ")}`;
      }
    }

    // Per-agent Anthropic client (uses agent's api_key if set)
    const anthropic = getAnthropicClient(agent);

    // Token budget management — read limits from agent config, fall back to defaults
    // ~4 chars per token as rough estimate; reserve 50K tokens for system+tools+response
    const ctxCfg = agent.context_config;
    const MAX_HISTORY_CHARS = ctxCfg?.max_history_chars || 400_000;       // ~100K tokens
    const MAX_TOOL_RESULT_CHARS = ctxCfg?.max_tool_result_chars || 40_000; // ~10K tokens
    const MAX_MESSAGE_CHARS = ctxCfg?.max_message_chars || 20_000;         // ~5K tokens

    // Truncate and compact conversation history
    function compactHistory(history: Anthropic.MessageParam[]): Anthropic.MessageParam[] {
      if (!history?.length) return [];
      let totalChars = 0;
      const compacted: Anthropic.MessageParam[] = [];
      // Work backwards from most recent, keep what fits
      for (let i = history.length - 1; i >= 0; i--) {
        const msg = history[i];
        let content = msg.content;
        // Truncate individual message content
        if (typeof content === "string") {
          if (content.length > MAX_MESSAGE_CHARS) content = content.substring(0, MAX_MESSAGE_CHARS) + "\n...[truncated]";
        } else if (Array.isArray(content)) {
          content = content.map((block: any) => {
            if (block.type === "text" && block.text?.length > MAX_MESSAGE_CHARS) {
              return { ...block, text: block.text.substring(0, MAX_MESSAGE_CHARS) + "\n...[truncated]" };
            }
            if (block.type === "tool_result" && typeof block.content === "string" && block.content.length > MAX_TOOL_RESULT_CHARS) {
              return { ...block, content: block.content.substring(0, MAX_TOOL_RESULT_CHARS) + "\n...[truncated]" };
            }
            return block;
          });
        }
        const msgChars = JSON.stringify(content).length;
        if (totalChars + msgChars > MAX_HISTORY_CHARS) break;
        totalChars += msgChars;
        compacted.unshift({ ...msg, content });
      }
      // Ensure history starts with user message (API requirement)
      while (compacted.length > 0 && compacted[0].role !== "user") compacted.shift();
      return compacted;
    }

    const messages: Anthropic.MessageParam[] = [
      ...compactHistory(conversationHistory || []),
      { role: "user", content: message }
    ];

    // Insert user message to ai_messages + audit_logs
    try {
      await supabase.from("ai_messages").insert({
        conversation_id: activeConversationId,
        role: "user",
        content: [{ type: "text", text: message }]
      });
    } catch (err) { console.error("[audit]", err); }
    try {
      await supabase.from("audit_logs").insert({
        action: "chat.user_message",
        severity: "info",
        store_id: storeId || null,
        resource_type: "chat_message",
        resource_id: agentId,
        request_id: traceId,
        conversation_id: activeConversationId,
        user_id: userId || null,
        user_email: userEmail || null,
        source: source || "whale_chat",
        details: {
          message,
          agent_id: agentId,
          agent_name: agent.name,
          model: agent.model,
          temperature: agent.temperature,
          tone: agent.tone,
          verbosity: agent.verbosity,
          system_prompt: systemPrompt,
          max_tokens: agent.max_tokens,
          max_tool_calls: agent.max_tool_calls,
          enabled_tools: agent.enabled_tools,
          can_query: agent.can_query,
          can_send: agent.can_send,
          can_modify: agent.can_modify,
          conversation_id: activeConversationId,
          user_id: userId,
          user_email: userEmail,
          source: source || "whale_chat",
          conversation_history_length: conversationHistory?.length || 0
        }
      });
    } catch (err) { console.error("[audit]", err); }

    // SSE stream
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: StreamEvent) => {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
        };

        let turnCount = 0, toolCallCount = 0, totalIn = 0, totalOut = 0;
        let finalResponse = "", continueLoop = true;
        const chatStartTime = Date.now();
        let allTextResponses: string[] = [];
        let allToolNames: string[] = [];

        try {
          while (continueLoop && turnCount < (agent.max_tool_calls || 10)) {
            turnCount++;

            const response = await anthropic.messages.create({
              model: agent.model || "claude-sonnet-4-20250514",
              max_tokens: agent.max_tokens || 4096,
              temperature: agent.temperature ?? 0.7,
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
                  const rawInput = currentToolUse.input.trim() || "{}";
                  toolUseBlocks.push({ id: currentToolUse.id, name: currentToolUse.name, input: JSON.parse(rawInput) });
                } catch (err) { console.error("[json-parse]", err); }
                currentToolUse = null;
              } else if (event.type === "message_delta" && event.usage) {
                totalOut += event.usage.output_tokens;
              } else if (event.type === "message_start" && event.message.usage) {
                totalIn += event.message.usage.input_tokens;
              }
            }

            // Collect text from this turn (whether or not there were tool calls)
            if (currentText) {
              allTextResponses.push(currentText);
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
              allToolNames.push(tu.name);
              const toolArgs = { ...tu.input };
              if (!toolArgs.store_id && storeId) toolArgs.store_id = storeId;

              const result = await executeTool(supabase, tu.name, toolArgs, storeId, traceId, userId, userEmail, source, activeConversationId);
              send({ type: "tool_result", name: tu.name, success: result.success, result: result.success ? result.data : result.error });
              let resultJson = JSON.stringify(result.success ? result.data : { error: result.error });
              if (resultJson.length > MAX_TOOL_RESULT_CHARS) {
                resultJson = resultJson.substring(0, MAX_TOOL_RESULT_CHARS) + '..."truncated"}';
              }
              toolResults.push({ type: "tool_result", tool_use_id: tu.id, content: resultJson });
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

          // Insert assistant message to ai_messages
          const fullResponse = allTextResponses.join("\n\n") || finalResponse;
          const usedToolNames = [...new Set(allToolNames)];
          try {
            await supabase.from("ai_messages").insert({
              conversation_id: activeConversationId,
              role: "assistant",
              content: [{ type: "text", text: fullResponse }],
              is_tool_use: toolCallCount > 0,
              tool_names: usedToolNames.length > 0 ? usedToolNames : null,
              token_count: totalIn + totalOut
            });
          } catch (err) { console.error("[audit]", err); }

          // Update conversation metadata with latest stats
          try {
            await supabase.from("ai_conversations").update({
              metadata: {
                agentName: agent.name,
                source: source || "whale_chat",
                model: agent.model,
                lastTurnTokens: totalIn + totalOut,
                lastToolCalls: toolCallCount,
                lastDurationMs: Date.now() - chatStartTime
              }
            }).eq("id", activeConversationId);
          } catch (err) { console.error("[audit]", err); }

          // Audit log: assistant response (prompt + response + telemetry for dashboard)
          try {
            await supabase.from("audit_logs").insert({
              action: "chat.assistant_response",
              severity: "info",
              store_id: storeId || null,
              resource_type: "chat_message",
              resource_id: agentId,
              request_id: traceId,
              conversation_id: activeConversationId,
              duration_ms: Date.now() - chatStartTime,
              user_id: userId || null,
              user_email: userEmail || null,
              source: source || "whale_chat",
              input_tokens: totalIn,
              output_tokens: totalOut,
              model: agent.model || "claude-sonnet-4-20250514",
              details: {
                message,
                response: fullResponse,
                agent_id: agentId,
                agent_name: agent.name,
                model: agent.model,
                temperature: agent.temperature,
                tone: agent.tone,
                verbosity: agent.verbosity,
                system_prompt: systemPrompt,
                turn_count: turnCount,
                tool_calls: toolCallCount,
                tool_names: usedToolNames,
                input_tokens: totalIn,
                output_tokens: totalOut,
                total_tokens: totalIn + totalOut,
                conversation_id: activeConversationId,
                user_id: userId,
                user_email: userEmail,
                source: source || "whale_chat",
                can_query: agent.can_query,
                can_send: agent.can_send,
                can_modify: agent.can_modify
              }
            });
          } catch (err) { console.error("[audit]", err); }

          send({ type: "done", conversationId: activeConversationId });

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
        ...getCorsHeaders(req),
      },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
  }
});
