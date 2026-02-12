// agent-chat/lib/utils.ts — Shared utility functions

/** Strip characters that could manipulate PostgREST filter syntax */
export function sanitizeFilterValue(val: string): string {
  return val.replace(/[,.\\\(\)]/g, "");
}

/** Group array items by a key, returning counts */
export function groupBy(arr: Record<string, unknown>[], key: string): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const item of arr) {
    const val = (item[key] as string) || "unknown";
    counts[val] = (counts[val] || 0) + 1;
  }
  return counts;
}

/** Escape a value for CSV output */
export function escapeCSV(val: unknown): string {
  if (val === null || val === undefined) return "";
  const str = String(val);
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return '"' + str.replace(/"/g, '""') + '"';
  }
  return str;
}

/** Fill {{key}} placeholders in a template string */
export function fillTemplate(template: string, data: Record<string, unknown>): string {
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

/** Extract concise metrics from tool results for audit logging (never full payloads). */
export function summarizeResult(toolName: string, action: string | undefined, data: unknown): Record<string, unknown> {
  const d = data as Record<string, unknown>;
  try {
    switch (toolName) {
      case "analytics": {
        switch (action) {
          case "summary": {
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
        return { action, count: Array.isArray(d) ? d.length : (d.count ?? (d.products ? (d.products as any[]).length : (d.id ? 1 : 0))) };
      case "audit_trail":
        return { count: d.count, days: d.days, actions: d.summary ? Object.keys(d.summary as object).length : 0 };
      case "telemetry":
        return { action, count: d.count || (Array.isArray(d) ? d.length : 0) };
      case "alerts":
        return { total: d.total };
      default:
        return { rows: Array.isArray(d) ? d.length : 1 };
    }
  } catch {
    return { rows: Array.isArray(d) ? d.length : 1 };
  }
}

export function validateUUID(value: unknown, name: string): string {
  const s = String(value || "");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)) {
    throw new Error(`Invalid UUID for ${name}: ${s}`);
  }
  return s;
}

export function validateNumber(value: unknown, name: string, opts?: { min?: number; max?: number }): number {
  const n = Number(value);
  if (isNaN(n)) throw new Error(`Invalid number for ${name}: ${value}`);
  if (opts?.min !== undefined && n < opts.min) throw new Error(`${name} must be >= ${opts.min}`);
  if (opts?.max !== undefined && n > opts.max) throw new Error(`${name} must be <= ${opts.max}`);
  return n;
}

/** Timeout wrapper for tool execution */
export function withTimeout<T>(promise: Promise<T>, ms: number, name: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`Tool ${name} timed out after ${ms}ms`)), ms)
    ),
  ]);
}

/** Strip sensitive details from error messages */
export function sanitizeError(err: unknown): string {
  const msg = String(err);
  return msg
    .replace(/sk-[a-zA-Z0-9_-]+/g, "sk-***")
    .replace(/key[=:]\s*["']?[a-zA-Z0-9_-]{20,}["']?/gi, "key=***")
    .replace(/password[=:]\s*["']?[^\s"']+["']?/gi, "password=***")
    .replace(/\n\s+at\s+.*/g, "")
    .substring(0, 500);
}
