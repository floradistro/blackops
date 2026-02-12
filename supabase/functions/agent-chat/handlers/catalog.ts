import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sanitizeFilterValue } from "../lib/utils.ts";

// ============================================================================
// PRODUCTS — Full product catalog management
// Products, categories, field schemas, pricing schemas, catalogs, assignments
// ============================================================================

export async function handleProducts(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {

    // ======================== PRODUCTS ========================

    case "find": {
      const limit = args.limit as number || 25;
      let q = sb.from("products")
        .select("id, name, sku, slug, status, type, cost_price, wholesale_price, stock_quantity, stock_status, featured, primary_category_id, pricing_schema_id, catalog_id, category:categories!primary_category_id(id, name), created_at, updated_at")
        .eq("store_id", sid)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (args.query) { const sq = sanitizeFilterValue(String(args.query)); q = q.or(`name.ilike.%${sq}%,sku.ilike.%${sq}%,description.ilike.%${sq}%`); }
      if (args.category) {
        const catVal = sanitizeFilterValue(args.category as string);
        if (/^[0-9a-f]{8}-/.test(catVal)) {
          q = q.eq("primary_category_id", catVal);
        } else {
          const { data: cats } = await sb.from("categories").select("id").ilike("name", `%${catVal}%`).eq("store_id", sid).limit(1);
          if (cats?.length) q = q.eq("primary_category_id", cats[0].id);
        }
      }
      if (args.catalog_id) q = q.eq("catalog_id", args.catalog_id as string);
      if (args.status) q = q.eq("status", args.status as string);
      if (args.featured !== undefined) q = q.eq("featured", args.featured as boolean);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    case "get": {
      const pid = args.product_id as string;
      const { data: product, error: pErr } = await sb.from("products")
        .select("*, category:categories!primary_category_id(id, name, slug)")
        .eq("id", pid).single();
      if (pErr) return { success: false, error: pErr.message };

      const { data: fieldSchemas } = await sb.from("product_field_schemas")
        .select("field_schema_id, field_schema:field_schemas!field_schema_id(id, name, fields, icon)")
        .eq("product_id", pid);

      const { data: pricingSchemas } = await sb.from("product_pricing_schemas")
        .select("pricing_schema_id, pricing_schema:pricing_schemas!pricing_schema_id(id, name, tiers, quality_tier)")
        .eq("product_id", pid);

      const { data: inventory } = await sb.from("inventory")
        .select("id, quantity, location:locations!location_id(id, name)")
        .eq("product_id", pid).eq("store_id", sid);

      return {
        success: true,
        data: {
          ...product,
          field_schemas: fieldSchemas?.map(fs => fs.field_schema) || [],
          pricing_schemas: pricingSchemas?.map(ps => ps.pricing_schema) || [],
          inventory: inventory || []
        }
      };
    }

    case "create": {
      const name = args.name as string;
      if (!name) return { success: false, error: "name is required" };
      const insert: Record<string, unknown> = { store_id: sid, name };
      if (args.sku) insert.sku = args.sku;
      if (args.description) insert.description = args.description;
      if (args.short_description) insert.short_description = args.short_description;
      if (args.type) insert.type = args.type;
      if (args.status) insert.status = args.status;
      if (args.cost_price !== undefined) insert.cost_price = args.cost_price;
      if (args.wholesale_price !== undefined) insert.wholesale_price = args.wholesale_price;
      if (args.featured !== undefined) insert.featured = args.featured;
      if (args.stock_quantity !== undefined) insert.stock_quantity = args.stock_quantity;
      if (args.manage_stock !== undefined) insert.manage_stock = args.manage_stock;
      if (args.weight !== undefined) insert.weight = args.weight;
      if (args.tax_status) insert.tax_status = args.tax_status;
      if (args.tax_class) insert.tax_class = args.tax_class;
      if (args.catalog_id) insert.catalog_id = args.catalog_id;
      if (args.pricing_data) insert.pricing_data = args.pricing_data;
      // custom_fields NOT inserted directly — schema is the source of truth
      // Agent-provided field_values are filtered against schema keys post-insert
      if (args.is_wholesale !== undefined) insert.is_wholesale = args.is_wholesale;
      if (args.wholesale_only !== undefined) insert.wholesale_only = args.wholesale_only;
      if (args.minimum_wholesale_quantity !== undefined) insert.minimum_wholesale_quantity = args.minimum_wholesale_quantity;
      const catArg = (args.category || args.primary_category_id || args.category_id) as string | undefined;
      if (catArg) {
        if (/^[0-9a-f]{8}-/.test(catArg)) {
          insert.primary_category_id = catArg;
        } else {
          const { data: cats } = await sb.from("categories").select("id").ilike("name", `%${catArg}%`).eq("store_id", sid).limit(1);
          if (cats?.length) insert.primary_category_id = cats[0].id;
        }
      }
      if (args.pricing_schema_id) insert.pricing_schema_id = args.pricing_schema_id;

      const { data, error } = await sb.from("products").insert(insert).select("id, name, sku, slug, status, primary_category_id, pricing_schema_id, created_at").single();
      if (error) return { success: false, error: error.message };

      // Explicit schema assignments from args
      if (args.field_schema_ids && Array.isArray(args.field_schema_ids)) {
        const rows = (args.field_schema_ids as string[]).map(fsId => ({ product_id: data.id, field_schema_id: fsId }));
        await sb.from("product_field_schemas").insert(rows);
      }
      if (args.pricing_schema_ids && Array.isArray(args.pricing_schema_ids)) {
        const rows = (args.pricing_schema_ids as string[]).map(psId => ({ product_id: data.id, pricing_schema_id: psId }));
        await sb.from("product_pricing_schemas").insert(rows);
      }

      const productUpdates: Record<string, unknown> = {};
      const inherited: string[] = [];

      // Auto-inherit field schema from category — ALWAYS merge with schema template
      const categoryId = insert.primary_category_id as string | undefined;
      if (categoryId && !args.field_schema_ids) {
        const { data: cat } = await sb.from("categories").select("field_schema_id").eq("id", categoryId).single();
        if (cat?.field_schema_id) {
          await sb.from("product_field_schemas").upsert(
            { product_id: data.id, field_schema_id: cat.field_schema_id },
            { onConflict: "product_id,field_schema_id" }
          );
          // Schema is source of truth — only schema keys allowed
          const { data: fs } = await sb.from("field_schemas").select("fields").eq("id", cat.field_schema_id).single();
          if (fs?.fields && Array.isArray(fs.fields)) {
            const schemaKeys = new Set<string>();
            const fieldValues: Record<string, unknown> = {};
            for (const f of fs.fields) {
              const key = (f as any).key;
              if (key) { schemaKeys.add(key); fieldValues[key] = (f as any).default ?? null; }
            }
            // Only accept agent values for keys that exist in the schema
            const agentValues = (args.field_values as Record<string, unknown>) || {};
            for (const [k, v] of Object.entries(agentValues)) {
              if (schemaKeys.has(k)) fieldValues[k] = v;
            }
            productUpdates.custom_fields = fieldValues;
          }
          inherited.push(`field_schema:${cat.field_schema_id}`);
        }
        // Also check junction table for additional schemas
        const { data: catFieldSchemas } = await sb.from("category_field_schemas").select("field_schema_id").eq("category_id", categoryId);
        if (catFieldSchemas?.length) {
          const cat2 = await sb.from("categories").select("field_schema_id").eq("id", categoryId).single();
          const rows = catFieldSchemas.filter(r => r.field_schema_id !== cat2?.data?.field_schema_id).map(r => ({ product_id: data.id, field_schema_id: r.field_schema_id }));
          if (rows.length) await sb.from("product_field_schemas").insert(rows);
        }
      }

      // If pricing_schema_id provided, hydrate pricing_data from schema
      if (insert.pricing_schema_id && !args.pricing_data) {
        const { data: ps } = await sb.from("pricing_schemas").select("tiers").eq("id", insert.pricing_schema_id as string).single();
        if (ps?.tiers) productUpdates.pricing_data = ps.tiers;
      }

      // Apply any post-insert updates
      if (Object.keys(productUpdates).length > 0) {
        await sb.from("products").update(productUpdates).eq("id", data.id);
      }

      // Re-read the full product for response
      const { data: full } = await sb.from("products")
        .select("id, name, sku, slug, status, primary_category_id, pricing_schema_id, custom_fields, pricing_data, created_at")
        .eq("id", data.id).single();
      if (inherited.length && full) full.inherited = inherited;

      return { success: true, data: full || data };
    }

    case "update": {
      const pid = args.product_id as string;
      if (!pid) return { success: false, error: "product_id is required" };
      const updates: Record<string, unknown> = {};
      if (args.name !== undefined) updates.name = args.name;
      if (args.sku !== undefined) updates.sku = args.sku;
      if (args.description !== undefined) updates.description = args.description;
      if (args.short_description !== undefined) updates.short_description = args.short_description;
      if (args.type !== undefined) updates.type = args.type;
      if (args.status !== undefined) updates.status = args.status;
      if (args.cost_price !== undefined) updates.cost_price = args.cost_price;
      if (args.wholesale_price !== undefined) updates.wholesale_price = args.wholesale_price;
      if (args.featured !== undefined) updates.featured = args.featured;
      if (args.stock_quantity !== undefined) updates.stock_quantity = args.stock_quantity;
      if (args.manage_stock !== undefined) updates.manage_stock = args.manage_stock;
      if (args.weight !== undefined) updates.weight = args.weight;
      if (args.tax_status !== undefined) updates.tax_status = args.tax_status;
      if (args.tax_class !== undefined) updates.tax_class = args.tax_class;
      if (args.catalog_id !== undefined) updates.catalog_id = args.catalog_id;
      if (args.pricing_schema_id !== undefined) updates.pricing_schema_id = args.pricing_schema_id;
      if (args.pricing_data !== undefined) updates.pricing_data = args.pricing_data;
      // custom_fields filtered to schema keys only (schema = source of truth)
      if (args.field_values !== undefined) {
        const agentFV = args.field_values as Record<string, unknown>;
        // Look up product's linked field schema to get allowed keys
        const { data: pfs } = await sb.from("product_field_schemas").select("field_schema_id").eq("product_id", pid).limit(1);
        if (pfs?.length) {
          const { data: fsDef } = await sb.from("field_schemas").select("fields").eq("id", pfs[0].field_schema_id).single();
          if (fsDef?.fields && Array.isArray(fsDef.fields)) {
            const { data: existing } = await sb.from("products").select("custom_fields").eq("id", pid).single();
            const base = (existing?.custom_fields as Record<string, unknown>) || {};
            const filtered: Record<string, unknown> = { ...base };
            const schemaKeys = new Set(fsDef.fields.map((f: any) => f.key).filter(Boolean));
            for (const [k, v] of Object.entries(agentFV)) {
              if (schemaKeys.has(k)) filtered[k] = v;
            }
            updates.custom_fields = filtered;
          } else {
            updates.custom_fields = agentFV; // no schema definition found, pass through
          }
        } else {
          updates.custom_fields = agentFV; // no schema linked, pass through
        }
      }
      if (args.is_wholesale !== undefined) updates.is_wholesale = args.is_wholesale;
      if (args.wholesale_only !== undefined) updates.wholesale_only = args.wholesale_only;
      if (args.minimum_wholesale_quantity !== undefined) updates.minimum_wholesale_quantity = args.minimum_wholesale_quantity;
      if (args.featured_image !== undefined) updates.featured_image = args.featured_image;
      const updateCatArg = (args.category ?? args.primary_category_id ?? args.category_id) as string | undefined;
      if (updateCatArg !== undefined) {
        if (!updateCatArg) { updates.primary_category_id = null; }
        else if (/^[0-9a-f]{8}-/.test(updateCatArg)) { updates.primary_category_id = updateCatArg; }
        else {
          const { data: cats } = await sb.from("categories").select("id").ilike("name", `%${updateCatArg}%`).eq("store_id", sid).limit(1);
          if (cats?.length) updates.primary_category_id = cats[0].id;
        }
      }

      const { data, error } = await sb.from("products")
        .update(updates).eq("id", pid).eq("store_id", sid)
        .select("id, name, sku, slug, status, cost_price, pricing_schema_id, updated_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "delete": {
      const pid = args.product_id as string;
      if (!pid) return { success: false, error: "product_id is required" };
      if (args.hard === true) {
        const { error } = await sb.from("products").delete().eq("id", pid).eq("store_id", sid);
        return error ? { success: false, error: error.message } : { success: true, data: { id: pid, deleted: true } };
      }
      const { data, error } = await sb.from("products")
        .update({ status: "archived" }).eq("id", pid).eq("store_id", sid)
        .select("id, name, status").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ======================== CATEGORIES ========================

    case "list_categories": {
      let q = sb.from("categories")
        .select("id, name, slug, description, icon, parent_id, display_order, is_active, featured, product_count, catalog_id, field_schema_id, created_at")
        .eq("store_id", sid)
        .order("display_order", { ascending: true });
      if (args.catalog_id) q = q.eq("catalog_id", args.catalog_id as string);
      if (args.parent_id) q = q.eq("parent_id", args.parent_id as string);
      if (args.active_only !== false) q = q.eq("is_active", true);
      const { data, error } = await q.limit(args.limit as number || 100);
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    case "get_category": {
      const catId = args.category_id as string;
      const { data: cat, error: catErr } = await sb.from("categories")
        .select("*").eq("id", catId).single();
      if (catErr) return { success: false, error: catErr.message };

      const { data: fieldAssigns } = await sb.from("category_field_schemas")
        .select("sort_order, is_active, field_schema:field_schemas!field_schema_id(id, name, fields, icon)")
        .eq("category_id", catId).eq("is_active", true).order("sort_order");

      const { data: pricingAssigns } = await sb.from("category_pricing_schemas")
        .select("sort_order, is_active, pricing_schema:pricing_schemas!pricing_schema_id(id, name, tiers, quality_tier)")
        .eq("category_id", catId).eq("is_active", true).order("sort_order");

      const { data: children } = await sb.from("categories")
        .select("id, name, slug, display_order, is_active, product_count")
        .eq("parent_id", catId).order("display_order");

      return {
        success: true,
        data: {
          ...cat,
          field_schemas: fieldAssigns?.map(a => ({ ...a.field_schema, sort_order: a.sort_order })) || [],
          pricing_schemas: pricingAssigns?.map(a => ({ ...a.pricing_schema, sort_order: a.sort_order })) || [],
          subcategories: children || []
        }
      };
    }

    case "create_category": {
      const name = args.name as string;
      if (!name) return { success: false, error: "name is required" };
      const insert: Record<string, unknown> = { store_id: sid, name, slug: name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") };
      if (args.description) insert.description = args.description;
      if (args.icon) insert.icon = args.icon;
      if (args.parent_id) insert.parent_id = args.parent_id;
      if (args.catalog_id) insert.catalog_id = args.catalog_id;
      if (args.display_order !== undefined) insert.display_order = args.display_order;
      if (args.field_schema_id) insert.field_schema_id = args.field_schema_id;

      const { data, error } = await sb.from("categories").insert(insert)
        .select("id, name, slug, parent_id, catalog_id, display_order, created_at").single();
      if (error) return { success: false, error: error.message };

      if (args.field_schema_ids && Array.isArray(args.field_schema_ids)) {
        const rows = (args.field_schema_ids as string[]).map((fsId, i) => ({ category_id: data.id, field_schema_id: fsId, sort_order: i + 1 }));
        await sb.from("category_field_schemas").insert(rows);
      }
      if (args.pricing_schema_ids && Array.isArray(args.pricing_schema_ids)) {
        const rows = (args.pricing_schema_ids as string[]).map((psId, i) => ({ category_id: data.id, pricing_schema_id: psId, sort_order: i + 1 }));
        await sb.from("category_pricing_schemas").insert(rows);
      }

      return { success: true, data };
    }

    case "update_category": {
      const catId = args.category_id as string;
      if (!catId) return { success: false, error: "category_id is required" };
      const updates: Record<string, unknown> = {};
      if (args.name !== undefined) updates.name = args.name;
      if (args.description !== undefined) updates.description = args.description;
      if (args.icon !== undefined) updates.icon = args.icon;
      if (args.parent_id !== undefined) updates.parent_id = args.parent_id;
      if (args.catalog_id !== undefined) updates.catalog_id = args.catalog_id;
      if (args.display_order !== undefined) updates.display_order = args.display_order;
      if (args.is_active !== undefined) updates.is_active = args.is_active;
      if (args.featured !== undefined) updates.featured = args.featured;
      if (args.field_schema_id !== undefined) updates.field_schema_id = args.field_schema_id;

      const { data, error } = await sb.from("categories")
        .update(updates).eq("id", catId).eq("store_id", sid)
        .select("id, name, slug, is_active, display_order, updated_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "delete_category": {
      const catId = args.category_id as string;
      if (!catId) return { success: false, error: "category_id is required" };
      if (args.hard === true) {
        const { error } = await sb.from("categories").delete().eq("id", catId).eq("store_id", sid);
        return error ? { success: false, error: error.message } : { success: true, data: { id: catId, deleted: true } };
      }
      const { data, error } = await sb.from("categories")
        .update({ is_active: false }).eq("id", catId).eq("store_id", sid)
        .select("id, name, is_active").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ======================== FIELD SCHEMAS ========================

    case "list_field_schemas": {
      let q = sb.from("field_schemas")
        .select("id, name, slug, description, icon, fields, is_public, is_active, catalog_id, install_count, created_at")
        .eq("is_active", true);
      if (args.catalog_id) q = q.eq("catalog_id", args.catalog_id as string);
      if (args.public_only === true) q = q.eq("is_public", true);
      const { data, error } = await q.order("name").limit(args.limit as number || 50);
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    case "get_field_schema": {
      const fsId = (args.field_schema_id || args.schema_id) as string;
      if (!fsId) return { success: false, error: "field_schema_id is required" };
      const { data, error } = await sb.from("field_schemas").select("*").eq("id", fsId).single();
      if (error) return { success: false, error: error.message };

      const { data: assignments } = await sb.from("category_field_schemas")
        .select("category:categories!category_id(id, name)").eq("field_schema_id", fsId).eq("is_active", true);

      return { success: true, data: { ...data, assigned_categories: assignments?.map(a => a.category) || [] } };
    }

    case "create_field_schema": {
      const name = args.name as string;
      if (!name) return { success: false, error: "name is required" };
      if (!args.fields || !Array.isArray(args.fields)) return { success: false, error: "fields array is required" };
      const insert: Record<string, unknown> = {
        name,
        slug: name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""),
        fields: args.fields
      };
      if (args.description) insert.description = args.description;
      if (args.icon) insert.icon = args.icon;
      if (args.catalog_id) insert.catalog_id = args.catalog_id;
      if (args.is_public !== undefined) insert.is_public = args.is_public;

      const { data, error } = await sb.from("field_schemas").insert(insert)
        .select("id, name, slug, fields, icon, is_active, created_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "update_field_schema": {
      const fsId = (args.field_schema_id || args.schema_id) as string;
      if (!fsId) return { success: false, error: "field_schema_id is required" };
      const updates: Record<string, unknown> = {};
      if (args.name !== undefined) updates.name = args.name;
      if (args.description !== undefined) updates.description = args.description;
      if (args.icon !== undefined) updates.icon = args.icon;
      if (args.fields !== undefined) updates.fields = args.fields;
      if (args.is_public !== undefined) updates.is_public = args.is_public;
      if (args.is_active !== undefined) updates.is_active = args.is_active;
      if (args.catalog_id !== undefined) updates.catalog_id = args.catalog_id;

      const { data, error } = await sb.from("field_schemas")
        .update(updates).eq("id", fsId)
        .select("id, name, slug, fields, icon, is_active, updated_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "delete_field_schema": {
      const fsId = (args.field_schema_id || args.schema_id) as string;
      if (!fsId) return { success: false, error: "field_schema_id is required" };
      const { data, error } = await sb.from("field_schemas")
        .update({ is_active: false, deleted_at: new Date().toISOString() }).eq("id", fsId)
        .select("id, name, is_active").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ======================== PRICING SCHEMAS ========================

    case "list_pricing_schemas": {
      let q = sb.from("pricing_schemas")
        .select("id, name, slug, description, tiers, quality_tier, is_public, is_active, catalog_id, install_count, created_at")
        .eq("is_active", true);
      if (args.catalog_id) q = q.eq("catalog_id", args.catalog_id as string);
      if (args.public_only === true) q = q.eq("is_public", true);
      const { data, error } = await q.order("name").limit(args.limit as number || 50);
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    case "get_pricing_schema": {
      const psId = (args.pricing_schema_id || args.schema_id) as string;
      if (!psId) return { success: false, error: "pricing_schema_id is required" };
      const { data, error } = await sb.from("pricing_schemas").select("*").eq("id", psId).single();
      if (error) return { success: false, error: error.message };

      const { data: assignments } = await sb.from("category_pricing_schemas")
        .select("category:categories!category_id(id, name)").eq("pricing_schema_id", psId).eq("is_active", true);

      return { success: true, data: { ...data, assigned_categories: assignments?.map(a => a.category) || [] } };
    }

    case "create_pricing_schema": {
      const name = args.name as string;
      if (!name) return { success: false, error: "name is required" };
      if (!args.tiers || !Array.isArray(args.tiers)) return { success: false, error: "tiers array is required" };
      const insert: Record<string, unknown> = {
        name,
        slug: name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""),
        tiers: args.tiers
      };
      if (args.description) insert.description = args.description;
      if (args.quality_tier) insert.quality_tier = args.quality_tier;
      if (args.catalog_id) insert.catalog_id = args.catalog_id;
      if (args.is_public !== undefined) insert.is_public = args.is_public;

      const { data, error } = await sb.from("pricing_schemas").insert(insert)
        .select("id, name, slug, tiers, quality_tier, is_active, created_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "update_pricing_schema": {
      const psId = (args.pricing_schema_id || args.schema_id) as string;
      if (!psId) return { success: false, error: "pricing_schema_id is required" };
      const updates: Record<string, unknown> = {};
      if (args.name !== undefined) updates.name = args.name;
      if (args.description !== undefined) updates.description = args.description;
      if (args.tiers !== undefined) updates.tiers = args.tiers;
      if (args.quality_tier !== undefined) updates.quality_tier = args.quality_tier;
      if (args.is_public !== undefined) updates.is_public = args.is_public;
      if (args.is_active !== undefined) updates.is_active = args.is_active;
      if (args.catalog_id !== undefined) updates.catalog_id = args.catalog_id;

      const { data, error } = await sb.from("pricing_schemas")
        .update(updates).eq("id", psId)
        .select("id, name, slug, tiers, quality_tier, is_active, updated_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "delete_pricing_schema": {
      const psId = (args.pricing_schema_id || args.schema_id) as string;
      if (!psId) return { success: false, error: "pricing_schema_id is required" };
      const { data, error } = await sb.from("pricing_schemas")
        .update({ is_active: false, deleted_at: new Date().toISOString() }).eq("id", psId)
        .select("id, name, is_active").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ======================== CATALOGS ========================

    case "list_catalogs": {
      const { data, error } = await sb.from("catalogs")
        .select("id, name, slug, description, vertical, is_active, is_default, display_order, created_at")
        .eq("store_id", sid).order("display_order");
      return error ? { success: false, error: error.message } : { success: true, count: data?.length, data };
    }

    case "create_catalog": {
      const name = args.name as string;
      if (!name) return { success: false, error: "name is required" };
      // Resolve owner_user_id from store
      const { data: store } = await sb.from("stores").select("owner_user_id").eq("id", sid).single();
      const insert: Record<string, unknown> = {
        store_id: sid, name,
        slug: name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""),
        owner_user_id: store?.owner_user_id
      };
      if (args.description) insert.description = args.description;
      if (args.vertical) insert.vertical = args.vertical;
      if (args.is_default !== undefined) insert.is_default = args.is_default;
      if (args.settings) insert.settings = args.settings;

      const { data, error } = await sb.from("catalogs").insert(insert)
        .select("id, name, slug, vertical, is_default, created_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    case "update_catalog": {
      const catId = args.catalog_id as string;
      if (!catId) return { success: false, error: "catalog_id is required" };
      const updates: Record<string, unknown> = {};
      if (args.name !== undefined) updates.name = args.name;
      if (args.description !== undefined) updates.description = args.description;
      if (args.vertical !== undefined) updates.vertical = args.vertical;
      if (args.is_active !== undefined) updates.is_active = args.is_active;
      if (args.is_default !== undefined) updates.is_default = args.is_default;
      if (args.settings !== undefined) updates.settings = args.settings;
      if (args.display_order !== undefined) updates.display_order = args.display_order;

      const { data, error } = await sb.from("catalogs")
        .update(updates).eq("id", catId).eq("store_id", sid)
        .select("id, name, slug, vertical, is_active, is_default, updated_at").single();
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ======================== SCHEMA ASSIGNMENTS ========================

    case "assign_schema": {
      const target = args.target as string; // "category" or "product"
      const schemaType = args.schema_type as string; // "field" or "pricing"
      const targetId = args.target_id as string;
      const schemaId = args.schema_id as string;
      if (!target || !schemaType || !targetId || !schemaId) {
        return { success: false, error: "target (category|product), schema_type (field|pricing), target_id, and schema_id are required" };
      }

      const table = target === "product"
        ? (schemaType === "field" ? "product_field_schemas" : "product_pricing_schemas")
        : (schemaType === "field" ? "category_field_schemas" : "category_pricing_schemas");
      const fkCol = target === "product" ? "product_id" : "category_id";
      const schemaCol = schemaType === "field" ? "field_schema_id" : "pricing_schema_id";

      const row: Record<string, unknown> = { [fkCol]: targetId, [schemaCol]: schemaId };
      if (args.sort_order !== undefined) row.sort_order = args.sort_order;

      const { data, error } = await sb.from(table).upsert(row, { onConflict: `${fkCol},${schemaCol}` }).select().single();
      if (error) return { success: false, error: error.message };

      // Hydrate product with schema data
      if (target === "product") {
        const productUpdates: Record<string, unknown> = {};
        if (schemaType === "pricing") {
          const { data: schema } = await sb.from("pricing_schemas").select("tiers, quality_tier").eq("id", schemaId).single();
          productUpdates.pricing_schema_id = schemaId;
          if (schema?.tiers) productUpdates.pricing_data = schema.tiers;
        }
        if (schemaType === "field") {
          // Schema is source of truth — rebuild custom_fields from schema keys only
          const { data: schema } = await sb.from("field_schemas").select("fields").eq("id", schemaId).single();
          if (schema?.fields && Array.isArray(schema.fields)) {
            const { data: product } = await sb.from("products").select("custom_fields").eq("id", targetId).single();
            const existing = (product?.custom_fields as Record<string, unknown>) || {};
            const rebuilt: Record<string, unknown> = {};
            for (const f of schema.fields) {
              const key = (f as any).key;
              if (key) rebuilt[key] = (key in existing) ? existing[key] : ((f as any).default ?? null);
            }
            productUpdates.custom_fields = rebuilt;
          }
        }
        if (Object.keys(productUpdates).length > 0) {
          await sb.from("products").update(productUpdates).eq("id", targetId);
        }
      }

      return { success: true, data };
    }

    case "unassign_schema": {
      const target = args.target as string;
      const schemaType = args.schema_type as string;
      const targetId = args.target_id as string;
      const schemaId = args.schema_id as string;
      if (!target || !schemaType || !targetId || !schemaId) {
        return { success: false, error: "target (category|product), schema_type (field|pricing), target_id, and schema_id are required" };
      }

      const table = target === "product"
        ? (schemaType === "field" ? "product_field_schemas" : "product_pricing_schemas")
        : (schemaType === "field" ? "category_field_schemas" : "category_pricing_schemas");
      const fkCol = target === "product" ? "product_id" : "category_id";
      const schemaCol = schemaType === "field" ? "field_schema_id" : "pricing_schema_id";

      const { error } = await sb.from(table).delete().eq(fkCol, targetId).eq(schemaCol, schemaId);
      return error ? { success: false, error: error.message } : { success: true, data: { removed: true, target, schema_type: schemaType, target_id: targetId, schema_id: schemaId } };
    }

    default:
      return { success: false, error: `Unknown products action: ${args.action}` };
  }
}

export async function handleCollections(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  switch (args.action) {
    case "find": {
      let q = sb.from("creation_collections").select("*").eq("store_id", sid);
      if (args.name) { const sn = sanitizeFilterValue(args.name as string); q = q.ilike("name", `%${sn}%`); }
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
