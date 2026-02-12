import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export async function handleAnalytics(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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
      const { data, error } = await q.limit(500);
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
      const { data, error } = await q.limit(args.limit as number || 500);
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
      const { data, error } = await q.limit(200);
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "behavior":
    case "behavioral_analytics": {
      let q = sb.from("v_behavioral_analytics").select("*")
        .gte("visit_date", startDate).lte("visit_date", endDate);
      if (sid) q = q.eq("store_id", sid);
      const { data, error } = await q.limit(500);
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
