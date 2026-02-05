// send-email/index.ts
// Sends emails via Resend API with template support
// Records all sends in email_sends table
// Supports thread replies (inserts into email_inbox as outbound)

import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const DEFAULT_FROM = Deno.env.get("DEFAULT_FROM_EMAIL") || "SwagManager <noreply@swagmanager.com>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
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
      const { data: tmpl, error: tmplError } = await supabase
        .from("email_templates")
        .select("*")
        .eq("slug", body.template)
        .eq("is_active", true)
        .single();

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
      html = tmpl.html_body ? renderTemplate(tmpl.html_body) : undefined;
      text = tmpl.text_body ? renderTemplate(tmpl.text_body) : undefined;

      // Fallback: if template has no html_body, use subject as text
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

    // Build Resend API payload
    const resendPayload: Record<string, unknown> = {
      from: from || DEFAULT_FROM,
      to: [to],
      subject,
    };

    if (html) resendPayload.html = html;
    if (text) resendPayload.text = text;
    if (reply_to) resendPayload.reply_to = reply_to;

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
    const emailRecord: Record<string, unknown> = {
      to_email: to,
      from_email: from || DEFAULT_FROM,
      subject,
      status: "sent",
      resend_email_id: resendData.id,
      email_type: category?.startsWith("campaign_") ? "marketing" : "transactional",
      category: category || null,
      reply_to: reply_to || null,
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
        from_email: from || DEFAULT_FROM,
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
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
