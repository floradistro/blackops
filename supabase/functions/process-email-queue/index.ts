// process-email-queue/index.ts
// Drains email_queue: atomically claims pending items, renders templates, sends via Resend
// Called every minute by pg_cron via call_process_email_queue()

import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BATCH_SIZE = 20;
const SEND_DELAY_MS = 550; // Resend allows 2 req/sec — 550ms between sends

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

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

  // Auth: only service_role can trigger queue processing
  if (!verifyAuth(req)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let processed = 0;
  let succeeded = 0;
  let failed = 0;

  try {
    // Atomically claim pending items (prevents duplicate sends from concurrent runs)
    const { data: items, error: claimError } = await supabase.rpc(
      "claim_email_queue_items",
      { batch_limit: BATCH_SIZE }
    );

    if (claimError) throw claimError;
    if (!items || items.length === 0) {
      return new Response(JSON.stringify({ processed: 0, succeeded: 0, failed: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Process each item with rate limiting
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      processed++;

      // Rate limiting: wait between sends (except before first)
      if (i > 0) {
        await new Promise((r) => setTimeout(r, SEND_DELAY_MS));
      }

      try {
        // Look up store email settings for from_name/from_email
        let fromName = "";
        let fromEmail = "";
        let replyTo: string | undefined;

        if (item.store_id) {
          const { data: settings } = await supabase
            .from("store_email_settings")
            .select("from_name, from_email, reply_to, vendor_logo, email_header_image_url")
            .eq("store_id", item.store_id)
            .single();

          if (settings) {
            fromName = settings.from_name || "";
            fromEmail = settings.from_email || "";
            replyTo = settings.reply_to || undefined;
          }

          // Fallback to store table
          if (!fromName || !fromEmail) {
            const { data: store } = await supabase
              .from("stores")
              .select("store_name, email")
              .eq("id", item.store_id)
              .single();
            if (store) {
              fromName = fromName || store.store_name || "Store";
              fromEmail = fromEmail || store.email || "";
            }
          }
        }

        if (!fromEmail) {
          throw new Error("No from_email configured for store");
        }

        // Look up template
        let html: string | undefined;
        let text: string | undefined;
        let subject = item.subject;

        if (item.template_slug) {
          const tmplQuery = supabase
            .from("email_templates")
            .select("subject, html_content, text_content")
            .eq("slug", item.template_slug)
            .eq("is_active", true);

          // Scope to store or global
          if (item.store_id) {
            tmplQuery.or(`store_id.eq.${item.store_id},is_global.eq.true`);
          } else {
            tmplQuery.eq("is_global", true);
          }

          const { data: tmpl } = await tmplQuery
            .order("is_global", { ascending: true })
            .limit(1)
            .single();

          if (tmpl) {
            const data = item.data || {};
            const render = (str: string): string =>
              str.replace(/\{\{(\w+)\}\}/g, (_, key) => String(data[key] ?? `{{${key}}}`));

            subject = subject || render(tmpl.subject || "");
            html = tmpl.html_content ? render(tmpl.html_content) : undefined;
            text = tmpl.text_content ? render(tmpl.text_content) : undefined;
          }
        }

        if (!subject) {
          throw new Error(`No subject for template ${item.template_slug}`);
        }

        if (!html && !text) {
          text = subject;
        }

        // Send via Resend API
        const resendPayload: Record<string, unknown> = {
          from: `${fromName} <${fromEmail}>`,
          to: [item.to_email],
          subject,
        };
        if (html) resendPayload.html = html;
        if (text) resendPayload.text = text;
        if (replyTo) resendPayload.reply_to = replyTo;

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
          throw new Error(resendData.message || `Resend ${resendRes.status}`);
        }

        // Mark queue item as sent
        await supabase
          .from("email_queue")
          .update({ status: "sent", processed_at: new Date().toISOString() })
          .eq("id", item.id);

        // Record in email_sends
        await supabase.from("email_sends").insert({
          store_id: item.store_id,
          to_email: item.to_email,
          to_name: item.to_name || null,
          from_email: fromEmail,
          from_name: fromName,
          subject,
          email_type: item.email_type || "transactional",
          category: item.category || null,
          status: "sent",
          sent_at: new Date().toISOString(),
          resend_email_id: resendData.id,
          customer_id: item.customer_id || null,
          order_id: item.order_id || null,
          metadata: { template_slug: item.template_slug, queue_id: item.id },
        });

        succeeded++;
      } catch (err) {
        failed++;
        const errorMsg = err instanceof Error ? err.message : String(err);
        console.error(`Queue item ${item.id} failed:`, errorMsg);

        // Mark as failed if max attempts reached, otherwise back to pending for retry
        const newStatus = item.attempts >= item.max_attempts ? "failed" : "pending";
        await supabase
          .from("email_queue")
          .update({
            status: newStatus,
            error_message: errorMsg,
            processed_at: new Date().toISOString(),
          })
          .eq("id", item.id);
      }
    }

    return new Response(JSON.stringify({ processed, succeeded, failed }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("process-email-queue error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
