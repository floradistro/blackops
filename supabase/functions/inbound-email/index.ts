// inbound-email/index.ts
// Multi-tenant webhook handler for Resend email.received events
// Routes emails to correct store based on domain configuration

import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const RESEND_WEBHOOK_SECRET = Deno.env.get("RESEND_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Extract order numbers from text (e.g., #1234, ORD-1234, order 1234)
function extractOrderNumbers(text: string): string[] {
  const patterns = [
    /#(\d{4,})/g,
    /ORD-(\d+)/gi,
    /order\s*#?\s*(\d{4,})/gi,
  ];

  const numbers: string[] = [];
  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(text)) !== null) {
      numbers.push(match[1]);
    }
  }
  return [...new Set(numbers)];
}

// Verify Svix webhook signature
async function verifyWebhook(
  payload: string,
  headers: Record<string, string>
): Promise<boolean> {
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
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

// Extract email from "Name <email@domain.com>" format
function extractEmail(str: string): string {
  const match = str.match(/<([^>]+)>/);
  return match ? match[1] : str.trim();
}

// Extract name from "Name <email@domain.com>" format
function extractName(str: string): string {
  const match = str.match(/^(.+?)\s*<[^>]+>/);
  return match ? match[1].trim().replace(/^["']|["']$/g, "") : "";
}

// Fallback mailbox resolver for addresses not in store_email_addresses
function resolveMailboxFallback(address: string): string {
  const mailboxMap: Record<string, string> = {
    support: "support",
    help: "support",
    orders: "orders",
    order: "orders",
    returns: "returns",
    return: "returns",
    refund: "returns",
    info: "info",
    contact: "info",
    hello: "info",
  };
  return mailboxMap[address.toLowerCase()] || "general";
}

Deno.serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const rawBody = await req.text();

  // Verify webhook signature
  const svixHeaders: Record<string, string> = {};
  for (const key of ["svix-id", "svix-timestamp", "svix-signature"]) {
    svixHeaders[key] = req.headers.get(key) || "";
  }

  const isValid = await verifyWebhook(rawBody, svixHeaders);
  if (!isValid) {
    console.error("Webhook signature verification failed");
    return new Response(JSON.stringify({ error: "Invalid signature" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const event = JSON.parse(rawBody);

    // Only handle email.received events
    if (event.type !== "email.received") {
      return new Response(JSON.stringify({ ok: true, skipped: event.type }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const emailData = event.data;
    const resendEmailId = emailData.email_id;

    // Fetch full email content from Resend Receiving API
    const emailRes = await fetch(`https://api.resend.com/emails/receiving/${resendEmailId}`, {
      headers: { "Authorization": `Bearer ${RESEND_API_KEY}` },
    });

    if (!emailRes.ok) {
      console.error(`Failed to fetch email ${resendEmailId}: ${emailRes.status}`);
      return new Response(JSON.stringify({ error: "Failed to fetch email content" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    const fullEmail = await emailRes.json();

    const fromEmail = extractEmail(fullEmail.from || emailData.from || "");
    const fromName = extractName(fullEmail.from || emailData.from || "");
    const toAddresses: string[] = fullEmail.to || emailData.to || [];
    const toEmail = toAddresses[0] || "";
    const subject = fullEmail.subject || emailData.subject || "";
    const bodyHtml = fullEmail.html || null;
    const bodyText = fullEmail.text || null;
    const messageId = fullEmail.message_id || emailData.message_id || null;
    const cc = fullEmail.cc || emailData.cc || [];
    const bcc = fullEmail.bcc || emailData.bcc || [];

    // Parse threading headers
    const headers = fullEmail.headers || {};
    const inReplyTo = headers["in-reply-to"] || headers["In-Reply-To"] || null;
    const refsHeader = headers["references"] || headers["References"] || "";
    const refs = refsHeader ? refsHeader.split(/\s+/).filter(Boolean) : [];

    // Attachments metadata
    const attachments = (fullEmail.attachments || emailData.attachments || []).map(
      (a: Record<string, unknown>) => ({
        id: a.id,
        filename: a.filename,
        content_type: a.content_type,
        content_disposition: a.content_disposition,
      })
    );
    const hasAttachments = attachments.length > 0;

    // ============================================
    // MULTI-TENANT ROUTING: Look up store by email address
    // ============================================
    const { data: routingData, error: routingError } = await supabase
      .rpc("get_store_from_email_address", { email_address: toEmail });

    if (routingError) {
      console.error("Routing lookup error:", routingError.message);
    }

    // Extract routing info (may be null if domain not registered)
    const storeRouting = routingData?.[0] || null;
    const storeId = storeRouting?.store_id || null;
    const domainId = storeRouting?.domain_id || null;
    const addressId = storeRouting?.address_id || null;
    const mailboxType = storeRouting?.mailbox_type || resolveMailboxFallback(toEmail.split("@")[0]);
    const aiEnabled = storeRouting?.ai_enabled ?? true;

    // If no store found, log warning but still process (for backwards compatibility)
    if (!storeId) {
      console.warn(`No store found for email address: ${toEmail}`);
    }

    // Match customer by email (scoped to store if known)
    let customerId: string | null = null;
    const customerQuery = supabase
      .from("customers")
      .select("id, store_id")
      .ilike("email", fromEmail)
      .limit(1);

    if (storeId) {
      customerQuery.eq("store_id", storeId);
    }

    const { data: customer } = await customerQuery.maybeSingle();
    if (customer) {
      customerId = customer.id;
      // If we didn't have a store_id from routing, use customer's store
      if (!storeId && customer.store_id) {
        // Note: We don't reassign storeId here as it's const, but we use customer's store below
      }
    }

    const effectiveStoreId = storeId || customer?.store_id || null;

    // Match order by scanning subject + body for order numbers
    let orderId: string | null = null;
    const searchText = `${subject} ${bodyText || ""}`;
    const orderNumbers = extractOrderNumbers(searchText);

    if (orderNumbers.length > 0 && effectiveStoreId) {
      const { data: order } = await supabase
        .from("orders")
        .select("id")
        .eq("store_id", effectiveStoreId)
        .in("order_number", orderNumbers)
        .limit(1)
        .maybeSingle();

      if (order) orderId = order.id;
    }

    // Thread matching: check In-Reply-To against existing messages
    let threadId: string | null = null;

    if (inReplyTo) {
      const { data: existingMsg } = await supabase
        .from("email_inbox")
        .select("thread_id")
        .eq("message_id", inReplyTo)
        .limit(1)
        .maybeSingle();

      if (existingMsg) threadId = existingMsg.thread_id;
    }

    // Also check References if no thread found
    if (!threadId && refs.length > 0) {
      const { data: existingMsg } = await supabase
        .from("email_inbox")
        .select("thread_id")
        .in("message_id", refs)
        .limit(1)
        .maybeSingle();

      if (existingMsg) threadId = existingMsg.thread_id;
    }

    // If no thread found, create one
    if (!threadId) {
      const threadRecord: Record<string, unknown> = {
        subject: subject || "(No Subject)",
        mailbox: mailboxType,
        status: "open",
        priority: "normal",
        customer_id: customerId,
        order_id: orderId,
        last_message_at: new Date().toISOString(),
      };
      if (effectiveStoreId) threadRecord.store_id = effectiveStoreId;

      const { data: newThread, error: threadError } = await supabase
        .from("email_threads")
        .insert(threadRecord)
        .select("id")
        .single();

      if (threadError) {
        console.error("Failed to create thread:", threadError.message);
        return new Response(JSON.stringify({ error: "Failed to create thread" }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }

      threadId = newThread.id;
    } else {
      // Update existing thread: reopen if resolved, update timestamp
      await supabase
        .from("email_threads")
        .update({
          last_message_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          ...(customerId && { customer_id: customerId }),
          ...(orderId && { order_id: orderId }),
        })
        .eq("id", threadId);
    }

    // Insert the inbound message
    const inboxRecord: Record<string, unknown> = {
      thread_id: threadId,
      resend_email_id: resendEmailId,
      direction: "inbound",
      from_email: fromEmail,
      from_name: fromName || null,
      to_email: toEmail,
      subject: subject || null,
      body_html: bodyHtml,
      body_text: bodyText,
      message_id: messageId,
      in_reply_to: inReplyTo,
      references: refs,
      cc,
      bcc,
      has_attachments: hasAttachments,
      attachments: attachments,
      status: "new",
      customer_id: customerId,
      order_id: orderId,
    };
    if (effectiveStoreId) inboxRecord.store_id = effectiveStoreId;

    const { error: inboxError } = await supabase
      .from("email_inbox")
      .insert(inboxRecord);

    if (inboxError) {
      console.error("Failed to insert inbox message:", inboxError.message);
      return new Response(JSON.stringify({ error: "Failed to store message" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(
      `Inbound email stored: thread=${threadId}, store=${effectiveStoreId || "unknown"}, ` +
      `from=${fromEmail}, mailbox=${mailboxType}, ai_enabled=${aiEnabled}, ` +
      `customer=${customerId || "unknown"}, order=${orderId || "none"}`
    );

    // TODO: If ai_enabled, trigger AI draft generation here

    return new Response(JSON.stringify({
      ok: true,
      thread_id: threadId,
      store_id: effectiveStoreId,
      mailbox: mailboxType,
      ai_enabled: aiEnabled,
      customer_matched: !!customerId,
      order_matched: !!orderId,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("inbound-email error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
