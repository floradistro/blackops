// send-email/index.ts
// Sends emails via Resend API with template support
// Records all sends in email_sends table
// Supports thread replies (inserts into email_inbox as outbound)

import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const DEFAULT_FROM = Deno.env.get("DEFAULT_FROM_EMAIL") || "SwagManager <noreply@swagmanager.com>";

// H3 FIX: Default to restrictive CORS
const ALLOWED_ORIGINS_STR = Deno.env.get("ALLOWED_ORIGINS") || "http://localhost:3000,http://127.0.0.1:3000";
const SEND_EMAIL_ORIGINS = ALLOWED_ORIGINS_STR.split(",").map(s => s.trim());

const corsHeaders = {
  "Access-Control-Allow-Origin": SEND_EMAIL_ORIGINS.includes("*") ? "*" : SEND_EMAIL_ORIGINS[0],
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

interface SendRequest {
  to: string;
  subject?: string;
  html?: string;
  text?: string;
  from?: string;
  reply_to?: string;
  template?: string;
  template_data?: Record<string, unknown>;
  category?: string;
  storeId?: string;
  // Threading support
  thread_id?: string;
  in_reply_to?: string;
  references?: string[];
  // File attachments (base64-encoded)
  attachments?: { filename: string; content: string }[];
}

function verifyAuth(req: Request): boolean {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return false;
  const token = auth.slice(7);
  return token === SUPABASE_SERVICE_ROLE_KEY || token === (Deno.env.get("SERVICE_ROLE_JWT") || "");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Auth: only service_role can send emails
  if (!verifyAuth(req)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body: SendRequest = await req.json();
    const { to, from, reply_to, category, storeId, thread_id, in_reply_to, references } = body;
    let { subject, html, text } = body;

    if (!to) {
      return new Response(JSON.stringify({ error: "to is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Template rendering
    if (body.template) {
      let tmplQ = supabase
        .from("email_templates")
        .select("*")
        .eq("slug", body.template)
        .eq("is_active", true);
      // Find store-specific template first, fall back to global
      if (storeId) tmplQ = tmplQ.or(`store_id.eq.${storeId},is_global.eq.true`);
      tmplQ = tmplQ.order("is_global", { ascending: true }).limit(1); // store-specific first
      const { data: tmpl, error: tmplError } = await tmplQ.single();

      if (tmplError || !tmpl) {
        return new Response(JSON.stringify({ error: `Template "${body.template}" not found` }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Render template variables: replace {{var}} with template_data values
      const templateData = body.template_data || {};
      const renderTemplate = (str: string): string => {
        return str.replace(/\{\{(\w+)\}\}/g, (_match, key) => {
          return String(templateData[key] ?? `{{${key}}}`);
        });
      };

      subject = renderTemplate(tmpl.subject || "");
      html = tmpl.html_content ? renderTemplate(tmpl.html_content) : undefined;
      text = tmpl.text_content ? renderTemplate(tmpl.text_content) : undefined;

      // Fallback: if template has no html_content, use subject as text
      if (!html && !text) {
        text = subject;
      }
    }

    if (!subject || (!html && !text)) {
      return new Response(JSON.stringify({ error: "subject and html or text required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Auto-branding: resolve store sender identity + wrap content in branded template
    let brandedReplyTo = reply_to;
    let brandedFrom = from;

    if (storeId) {
      // Get store branding
      const { data: store } = await supabase
        .from("stores")
        .select("store_name, logo_url, brand_colors, store_tagline, email")
        .eq("id", storeId)
        .single();

      // Get store email settings (authoritative sender config)
      const { data: emailSettings } = await supabase
        .from("store_email_settings")
        .select("from_name, from_email, reply_to, vendor_logo, email_header_image_url")
        .eq("store_id", storeId)
        .single();

      const storeName = store?.store_name || emailSettings?.from_name || "";
      const storeFromEmail = emailSettings?.from_email || store?.email || "";
      const logoUrl = emailSettings?.vendor_logo || emailSettings?.email_header_image_url || store?.logo_url;

      // Use store sender identity if caller didn't specify
      if (!brandedFrom && storeFromEmail) {
        brandedFrom = `${storeName} <${storeFromEmail}>`;
      }
      if (!brandedReplyTo && (emailSettings?.reply_to || store?.email)) {
        brandedReplyTo = emailSettings?.reply_to || store?.email;
      }

      // Wrap plain/simple HTML in branded template
      if (store && html && !html.trim().toLowerCase().startsWith("<html") && !html.trim().toLowerCase().startsWith("<!doctype")) {
        let colors = store.brand_colors;
        if (typeof colors === "string") {
          try { colors = JSON.parse(colors); } catch { colors = {}; }
        }
        const primary = (colors as any)?.primary || "#0EA5E9";
        const tagline = store.store_tagline || "";
        const logoHtml = logoUrl
          ? `<img src="${logoUrl}" alt="${storeName}" style="max-width:200px;max-height:60px;margin:0 auto;display:block;" />`
          : `<h1 style="margin:0;font-size:24px;color:#ffffff;">${storeName}</h1>`;

        html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:20px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">
  <tr><td style="background:${primary};padding:24px;text-align:center;border-radius:8px 8px 0 0;">
    ${logoHtml}
  </td></tr>
  <tr><td style="background:#ffffff;padding:32px 24px;border-left:1px solid #e4e4e7;border-right:1px solid #e4e4e7;">
    ${html}
  </td></tr>
  <tr><td style="background:#fafafa;padding:16px 24px;text-align:center;font-size:12px;color:#71717a;border:1px solid #e4e4e7;border-top:0;border-radius:0 0 8px 8px;">
    ${storeName}${tagline ? ` &mdash; ${tagline}` : ""}
  </td></tr>
</table>
</td></tr>
</table>
</body>
</html>`;
      }
    }

    // Build Resend API payload
    const resendPayload: Record<string, unknown> = {
      from: brandedFrom || from || DEFAULT_FROM,
      to: [to],
      subject,
    };

    if (html) resendPayload.html = html;
    if (text) resendPayload.text = text;
    if (brandedReplyTo) resendPayload.reply_to = brandedReplyTo;

    // File attachments (base64)
    if (body.attachments && body.attachments.length > 0) {
      resendPayload.attachments = body.attachments.map(att => ({
        filename: att.filename,
        content: att.content, // base64 string — Resend accepts this directly
      }));
    }

    // Threading headers for email clients
    const headers: Record<string, string> = {};
    if (in_reply_to) headers["In-Reply-To"] = in_reply_to;
    if (references && references.length > 0) headers["References"] = references.join(" ");
    if (Object.keys(headers).length > 0) resendPayload.headers = headers;

    // Send via Resend API
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(resendPayload),
    });

    const resendData = await resendRes.json();

    if (!resendRes.ok) {
      return new Response(JSON.stringify({
        error: resendData.message || `Resend API error: ${resendRes.status}`,
      }), {
        status: resendRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Record in email_sends table
    // Extract display name from "Name <email>" format for from_name
    const actualFrom = brandedFrom || from || DEFAULT_FROM;
    const fromNameMatch = actualFrom.match(/^(.+?)\s*<.+>$/);
    const fromNameStr = fromNameMatch ? fromNameMatch[1].trim() : actualFrom;
    const fromEmailStr = actualFrom.match(/<(.+)>/)?.[1] || actualFrom;

    const emailRecord: Record<string, unknown> = {
      to_email: to,
      from_email: fromEmailStr,
      from_name: fromNameStr,
      subject,
      status: "sent",
      sent_at: new Date().toISOString(),
      resend_email_id: resendData.id,
      email_type: category?.startsWith("campaign_") ? "marketing" : "transactional",
      category: category || null,
      reply_to: brandedReplyTo || null,
    };
    if (storeId) emailRecord.store_id = storeId;

    const { data: emailSend, error: insertError } = await supabase
      .from("email_sends")
      .insert(emailRecord)
      .select("id")
      .single();

    if (insertError) {
      console.error("Failed to record email_send:", insertError.message);
    }

    // If this is a thread reply, also record in email_inbox as outbound
    if (thread_id) {
      const inboxRecord: Record<string, unknown> = {
        thread_id,
        resend_email_id: resendData.id,
        direction: "outbound",
        from_email: brandedFrom || from || DEFAULT_FROM,
        to_email: to,
        subject,
        body_html: html || null,
        body_text: text || null,
        in_reply_to: in_reply_to || null,
        references: references || [],
        status: "replied",
        replied_at: new Date().toISOString(),
      };
      if (storeId) inboxRecord.store_id = storeId;

      const { error: inboxError } = await supabase
        .from("email_inbox")
        .insert(inboxRecord);

      if (inboxError) {
        console.error("Failed to record inbox outbound:", inboxError.message);
      }
    }

    return new Response(JSON.stringify({
      success: true,
      id: resendData.id,
      email_send_id: emailSend?.id || null,
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("send-email error:", err);
    // M5 FIX: Sanitize error — don't leak internal details to client
    const safeError = err instanceof Error ? err.message.replace(/at\s+.*$/gm, "").trim() : "Internal server error";
    return new Response(JSON.stringify({ error: safeError.slice(0, 200) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
