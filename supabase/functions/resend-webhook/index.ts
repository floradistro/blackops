// resend-webhook/index.ts
// Handles Resend delivery webhook events (sent, delivered, opened, clicked, bounced, complained)
// Updates email_sends status/timestamps, inserts into email_events
// Verifies Svix webhook signature for security

import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_WEBHOOK_SECRET = Deno.env.get("RESEND_WEBHOOK_SECRET") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, svix-id, svix-timestamp, svix-signature",
};

// Map Resend event types to our event_type enum
const EVENT_MAP: Record<string, string> = {
  "email.sent": "sent",
  "email.delivered": "delivered",
  "email.opened": "opened",
  "email.clicked": "clicked",
  "email.bounced": "bounced",
  "email.complained": "complained",
};

// Map event types to email_sends status
const STATUS_MAP: Record<string, string> = {
  sent: "sent",
  delivered: "delivered",
  bounced: "bounced",
};

// Map event types to email_sends timestamp columns
const TIMESTAMP_MAP: Record<string, string> = {
  sent: "sent_at",
  delivered: "delivered_at",
  opened: "opened_at",
  clicked: "clicked_at",
  bounced: "bounced_at",
  complained: "complained_at",
};

// --- Svix signature verification ---
function base64Decode(str: string): Uint8Array {
  const binary = atob(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

async function verifyWebhook(
  payload: string,
  headers: Record<string, string>
): Promise<boolean> {
  if (!RESEND_WEBHOOK_SECRET) return true; // Skip if not configured (graceful degradation)

  const svixId = headers["svix-id"];
  const svixTimestamp = headers["svix-timestamp"];
  const svixSignature = headers["svix-signature"];

  if (!svixId || !svixTimestamp || !svixSignature) return false;

  // Check timestamp is within 5 minutes
  const now = Math.floor(Date.now() / 1000);
  const ts = parseInt(svixTimestamp, 10);
  if (Math.abs(now - ts) > 300) return false;

  // Compute expected signature
  const toSign = `${svixId}.${svixTimestamp}.${payload}`;
  const secretBytes = base64Decode(RESEND_WEBHOOK_SECRET.replace("whsec_", ""));
  const key = await crypto.subtle.importKey(
    "raw",
    secretBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signatureBytes = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(toSign));
  const expected = base64Encode(new Uint8Array(signatureBytes));

  // Svix sends multiple signatures separated by space, check if any match
  const signatures = svixSignature.split(" ");
  return signatures.some((sig) => {
    const sigValue = sig.replace(/^v1,/, "");
    return sigValue === expected;
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    // Read raw body for signature verification
    const rawBody = await req.text();

    // Verify Svix webhook signature
    const svixHeaders: Record<string, string> = {
      "svix-id": req.headers.get("svix-id") || "",
      "svix-timestamp": req.headers.get("svix-timestamp") || "",
      "svix-signature": req.headers.get("svix-signature") || "",
    };

    const isValid = await verifyWebhook(rawBody, svixHeaders);
    if (!isValid) {
      console.warn("resend-webhook: Invalid signature");
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = JSON.parse(rawBody);
    const eventType = body.type as string;
    const eventData = body.data || {};
    const resendEmailId = eventData.email_id as string;

    const mappedEvent = EVENT_MAP[eventType];
    if (!mappedEvent) {
      return new Response(JSON.stringify({ ok: true, skipped: eventType }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!resendEmailId) {
      return new Response(JSON.stringify({ ok: true, skipped: "no email_id" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Find the email_send by resend_email_id
    const { data: emailSend } = await supabase
      .from("email_sends")
      .select("id, store_id, status")
      .eq("resend_email_id", resendEmailId)
      .limit(1)
      .single();

    if (!emailSend) {
      // Could be a marketing send
      const { data: mktSend } = await supabase
        .from("marketing_sends")
        .select("id, store_id, campaign_id, status")
        .eq("resend_email_id", resendEmailId)
        .limit(1)
        .single();

      if (mktSend) {
        const mktUpdates: Record<string, unknown> = {};
        if (mappedEvent === "delivered") mktUpdates.delivered_at = new Date().toISOString();
        if (mappedEvent === "opened") mktUpdates.opened_at = new Date().toISOString();
        if (mappedEvent === "clicked") {
          // Atomic click count increment (prevents race condition)
          await supabase.rpc("increment_click_count", {
            p_send_id: mktSend.id,
            p_url: eventData.click?.url || null,
          });
        }
        if (mappedEvent === "bounced") mktUpdates.bounced_at = new Date().toISOString();
        if (mappedEvent === "complained") mktUpdates.complained_at = new Date().toISOString();

        // Status escalation (only upgrade, never downgrade)
        const statusOrder = ["pending", "sending", "sent", "delivered", "opened", "clicked", "bounced", "complained"];
        const currentIdx = statusOrder.indexOf(mktSend.status);
        const newIdx = statusOrder.indexOf(mappedEvent);
        if (newIdx > currentIdx || mappedEvent === "bounced" || mappedEvent === "complained") {
          mktUpdates.status = mappedEvent;
        }

        if (Object.keys(mktUpdates).length > 0) {
          await supabase.from("marketing_sends").update(mktUpdates).eq("id", mktSend.id);
        }

        return new Response(JSON.stringify({ ok: true, type: "marketing", event: mappedEvent }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      console.warn(`resend-webhook: email ${resendEmailId} not found in email_sends or marketing_sends`);
      return new Response(JSON.stringify({ ok: true, skipped: "email not found" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Insert into email_events
    const { error: eventError } = await supabase.from("email_events").insert({
      email_send_id: emailSend.id,
      store_id: emailSend.store_id,
      event_type: mappedEvent,
      resend_event_id: body.id || null,
      user_agent: eventData.click?.userAgent || eventData.open?.userAgent || null,
      ip_address: eventData.click?.ipAddress || eventData.open?.ipAddress || null,
      link_url: eventData.click?.url || null,
      raw_event_data: body,
    });

    if (eventError) {
      console.error("email_events insert error:", eventError.message);
    }

    // Update email_sends — status + timestamp
    const updates: Record<string, unknown> = {};

    // Only escalate status
    const newStatus = STATUS_MAP[mappedEvent];
    if (newStatus) {
      const statusPriority: Record<string, number> = { pending: 0, sent: 1, delivered: 2, bounced: 3 };
      if ((statusPriority[newStatus] || 0) > (statusPriority[emailSend.status] || 0)) {
        updates.status = newStatus;
      }
    }

    // Set timestamp — use COALESCE pattern for opens/clicks (only first occurrence)
    const tsColumn = TIMESTAMP_MAP[mappedEvent];
    if (tsColumn) {
      if (mappedEvent === "opened" || mappedEvent === "clicked") {
        const { data: current } = await supabase
          .from("email_sends")
          .select(tsColumn)
          .eq("id", emailSend.id)
          .single();
        if (current && !(current as any)[tsColumn]) {
          updates[tsColumn] = new Date().toISOString();
        }
      } else {
        updates[tsColumn] = new Date().toISOString();
      }
    }

    // Store bounce reason
    if (mappedEvent === "bounced" && eventData.bounce) {
      updates.error_message = eventData.bounce.message || "Bounced";
    }

    if (Object.keys(updates).length > 0) {
      await supabase.from("email_sends").update(updates).eq("id", emailSend.id);
    }

    return new Response(JSON.stringify({ ok: true, event: mappedEvent, email_send_id: emailSend.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("resend-webhook error:", err);
    // Return 200 to prevent Resend from retrying on our errors
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
