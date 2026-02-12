// agent-chat/handlers/operations.ts — Locations, Suppliers, Alerts, Audit Trail handlers

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sanitizeFilterValue } from "../lib/utils.ts";

export async function handleLocations(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  let q = sb.from("locations").select("id, name, address_line1, city, state, is_active, type").eq("store_id", sid);
  if (args.is_active !== undefined) q = q.eq("is_active", args.is_active as boolean);
  if (args.name) { const sn = sanitizeFilterValue(args.name as string); q = q.ilike("name", `%${sn}%`); }
  const { data, error } = await q.limit(100);
  return error ? { success: false, error: error.message } : { success: true, data };
}

export async function handleSuppliers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  let q = sb.from("suppliers").select("id, external_name, external_company, contact_name, contact_email, contact_phone, city, state, is_active").eq("store_id", sid);
  if (args.name) { const sn = sanitizeFilterValue(args.name as string); q = q.or(`external_name.ilike.%${sn}%,external_company.ilike.%${sn}%,contact_name.ilike.%${sn}%`); }
  const { data, error } = await q.limit(100);
  return error ? { success: false, error: error.message } : { success: true, data };
}

export async function handleAlerts(sb: SupabaseClient, _args: Record<string, unknown>, storeId?: string) {
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
    .eq("store_id", sid).eq("status", "pending").limit(100);
  if (pendingOrders?.length) {
    alerts.push({
      type: "pending_orders", severity: "info",
      message: `${pendingOrders.length} pending orders requiring attention`,
      data: { count: pendingOrders.length, orders: pendingOrders.slice(0, 5) }
    });
  }

  return { success: true, data: { total: alerts.length, alerts } };
}

export async function handleAuditTrail(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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
      .or(`action.ilike.%${sanitizeFilterValue(query)}%,error_message.ilike.%${sanitizeFilterValue(query)}%,user_email.ilike.%${sanitizeFilterValue(query)}%,resource_id.ilike.%${sanitizeFilterValue(query)}%`)
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
  if (args.action_filter) { const sf = sanitizeFilterValue(args.action_filter as string); q = q.ilike("action", `%${sf}%`); }
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
