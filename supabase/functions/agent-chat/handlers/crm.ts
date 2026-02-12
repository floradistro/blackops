import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sanitizeFilterValue } from "../lib/utils.ts";

export async function handleCustomers(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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
        const raw = sanitizeFilterValue(String(args.query).trim());
        // Split multi-word queries so "Hannah Spivey" matches first_name=Hannah OR last_name=Spivey
        const words = raw.split(/\s+/).filter(Boolean);
        if (words.length > 1) {
          // Multi-word: each word matches any field
          const clauses = words.map(w => { const sw = sanitizeFilterValue(w); return `first_name.ilike.%${sw}%,last_name.ilike.%${sw}%`; }).join(",");
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

export async function handleOrders(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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
        const sq = sanitizeFilterValue(String(args.query));
        q = q.or(`order_number.ilike.%${sq}%`);
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
