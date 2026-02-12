import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sanitizeFilterValue, escapeCSV, fillTemplate, groupBy } from "../lib/utils.ts";

export async function handleEmail(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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

export async function handleDocuments(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
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
      if (args.name) { const sn = sanitizeFilterValue(args.name as string); query = query.ilike("document_name", `%${sn}%`); }
      query = query.order("created_at", { ascending: false }).limit(args.limit as number || 50);

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
      if (args.name) { const sn = sanitizeFilterValue(args.name as string); query = query.ilike("document_name", `%${sn}%`); }
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
