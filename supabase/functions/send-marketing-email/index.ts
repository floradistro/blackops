// send-marketing-email/index.ts
// Processes marketing_sends for a campaign: renders template, sends via Resend
// Uses atomic claim to prevent duplicate sends from concurrent invocations
// Injects CAN-SPAM unsubscribe footer for legal compliance

import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const SEND_DELAY_MS = 550; // Resend allows 2 req/sec

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

const DEFAULT_UNSUBSCRIBE_FOOTER = `<div style="margin-top:32px;padding-top:16px;border-top:1px solid #e4e4e7;text-align:center;font-size:11px;color:#a1a1aa;">
  <p>You received this email because you subscribed to our mailing list.</p>
  <p>If you no longer wish to receive these emails, please contact us to unsubscribe.</p>
</div>`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // Auth: only service_role can trigger campaign sends
  if (!verifyAuth(req)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body = await req.json();
    const { campaign_id } = body;

    if (!campaign_id) {
      return new Response(JSON.stringify({ error: "campaign_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get campaign details
    const { data: campaign, error: campError } = await supabase
      .from("email_campaigns")
      .select("*")
      .eq("id", campaign_id)
      .single();

    if (campError || !campaign) {
      return new Response(JSON.stringify({ error: "Campaign not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get store email settings
    let fromName = "";
    let fromEmail = "";
    let unsubscribeFooter = DEFAULT_UNSUBSCRIBE_FOOTER;

    if (campaign.store_id) {
      const { data: settings } = await supabase
        .from("store_email_settings")
        .select("from_name, from_email, unsubscribe_footer_html")
        .eq("store_id", campaign.store_id)
        .single();

      if (settings) {
        fromName = campaign.from_name || settings.from_name || "";
        fromEmail = campaign.from_email || settings.from_email || "";
        if (settings.unsubscribe_footer_html) {
          unsubscribeFooter = settings.unsubscribe_footer_html;
        }
      }

      // Fallback to store table
      if (!fromName || !fromEmail) {
        const { data: store } = await supabase
          .from("stores")
          .select("store_name, email")
          .eq("id", campaign.store_id)
          .single();
        if (store) {
          fromName = fromName || store.store_name || "Store";
          fromEmail = fromEmail || store.email || "";
        }
      }
    }

    if (!fromEmail) {
      return new Response(JSON.stringify({ error: "No from_email configured for store" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Resolve template HTML
    let templateHtml: string | undefined;
    let templateText: string | undefined;

    if (campaign.template_slug) {
      const { data: tmpl } = await supabase
        .from("email_templates")
        .select("html_content, text_content")
        .eq("slug", campaign.template_slug)
        .eq("is_active", true)
        .or(`store_id.eq.${campaign.store_id},is_global.eq.true`)
        .order("is_global", { ascending: true })
        .limit(1)
        .single();

      if (tmpl) {
        templateHtml = tmpl.html_content || undefined;
        templateText = tmpl.text_content || undefined;
      }
    }

    const baseHtml = templateHtml || campaign.html_content;
    const baseText = templateText || campaign.text_content;

    // Atomically claim pending sends (prevents duplicates from concurrent invocations)
    const { data: sends, error: claimError } = await supabase.rpc(
      "claim_marketing_sends",
      { p_campaign_id: campaign_id, batch_limit: 50 }
    );

    if (claimError) throw claimError;
    if (!sends || sends.length === 0) {
      return new Response(JSON.stringify({ processed: 0, message: "No pending sends" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let succeeded = 0;
    let failed = 0;

    for (let i = 0; i < sends.length; i++) {
      const send = sends[i];

      // Rate limiting
      if (i > 0) {
        await new Promise((r) => setTimeout(r, SEND_DELAY_MS));
      }

      try {
        // Render template with campaign data + per-recipient data
        const data = { ...(campaign.template_data || {}), customer_email: send.email };
        const render = (str: string): string =>
          str.replace(/\{\{(\w+)\}\}/g, (_, key) => String(data[key] ?? `{{${key}}}`));

        let html = baseHtml ? render(baseHtml) : undefined;
        const text = baseText ? render(baseText) : undefined;
        const subject = render(campaign.subject || "");

        if (!subject || (!html && !text)) {
          throw new Error("No content to send");
        }

        // Inject CAN-SPAM unsubscribe footer into HTML
        if (html) {
          // Insert before closing </body> or append at end
          const bodyCloseIdx = html.toLowerCase().lastIndexOf("</body>");
          if (bodyCloseIdx !== -1) {
            html = html.slice(0, bodyCloseIdx) + unsubscribeFooter + html.slice(bodyCloseIdx);
          } else {
            html += unsubscribeFooter;
          }
        }

        // Send via Resend
        const resendPayload: Record<string, unknown> = {
          from: `${fromName} <${fromEmail}>`,
          to: [send.email],
          subject,
        };
        if (html) resendPayload.html = html;
        if (text) resendPayload.text = text;
        if (campaign.reply_to) resendPayload.reply_to = campaign.reply_to;

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

        // Update marketing_send
        await supabase
          .from("marketing_sends")
          .update({
            status: "sent",
            sent_at: new Date().toISOString(),
            resend_email_id: resendData.id,
          })
          .eq("id", send.id);

        succeeded++;
      } catch (err) {
        failed++;
        const errorMsg = err instanceof Error ? err.message : String(err);
        console.error(`Marketing send ${send.id} failed:`, errorMsg);

        // Mark as failed (not "bounced" — API failure is not a bounce)
        await supabase
          .from("marketing_sends")
          .update({ status: "failed", error_message: errorMsg })
          .eq("id", send.id);
      }
    }

    // Update campaign status if all sends processed
    const { count: pendingCount } = await supabase
      .from("marketing_sends")
      .select("*", { count: "exact", head: true })
      .eq("campaign_id", campaign_id)
      .in("status", ["pending", "sending"]);

    if (pendingCount === 0) {
      await supabase
        .from("email_campaigns")
        .update({
          status: "sent",
          sent_at: campaign.sent_at || new Date().toISOString(),
          completed_at: new Date().toISOString(),
        })
        .eq("id", campaign_id);
    }

    return new Response(JSON.stringify({ processed: sends.length, succeeded, failed }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("send-marketing-email error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
