import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface GmailMessage {
  id: string;
  threadId: string;
  labelIds?: string[];
  snippet?: string;
  payload: {
    headers?: Array<{ name: string; value: string }>;
    mimeType?: string;
    body?: { data?: string; size?: number };
    parts?: Array<{
      mimeType?: string;
      body?: { data?: string; size?: number };
      parts?: Array<{ mimeType?: string; body?: { data?: string } }>;
    }>;
  };
  internalDate: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    const body = await req.json();
    const { action, account_id, store_id, max_results = 20 } = body;

    // Sync emails for a specific account
    if (action === "sync") {
      if (!account_id) {
        return new Response(
          JSON.stringify({ error: "account_id required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Get account with tokens
      const { data: account, error: accountError } = await supabase
        .from("store_email_accounts")
        .select("*")
        .eq("id", account_id)
        .single();

      if (accountError || !account) {
        return new Response(
          JSON.stringify({ error: "Account not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Check if token needs refresh
      if (new Date(account.token_expires_at) < new Date()) {
        // Call refresh endpoint
        const refreshResponse = await fetch(`${SUPABASE_URL}/functions/v1/gmail-oauth`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}` },
          body: JSON.stringify({ action: "refresh", account_id }),
        });

        if (!refreshResponse.ok) {
          return new Response(
            JSON.stringify({ error: "Token refresh failed" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // Re-fetch account with new token
        const { data: refreshedAccount } = await supabase
          .from("store_email_accounts")
          .select("*")
          .eq("id", account_id)
          .single();

        if (refreshedAccount) {
          account.access_token = refreshedAccount.access_token;
        }
      }

      // Fetch messages from Gmail
      const messagesUrl = new URL("https://gmail.googleapis.com/gmail/v1/users/me/messages");
      messagesUrl.searchParams.set("maxResults", max_results.toString());
      messagesUrl.searchParams.set("labelIds", "INBOX");

      const messagesResponse = await fetch(messagesUrl.toString(), {
        headers: { Authorization: `Bearer ${account.access_token}` },
      });

      if (!messagesResponse.ok) {
        const error = await messagesResponse.text();
        console.error("Gmail API error:", error);
        return new Response(
          JSON.stringify({ error: "Gmail API error", details: error }),
          { status: messagesResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const messagesData = await messagesResponse.json();
      const messageIds = messagesData.messages || [];

      // Fetch full message details
      const emails = [];
      for (const { id } of messageIds.slice(0, max_results)) {
        const msgResponse = await fetch(
          `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}?format=full`,
          { headers: { Authorization: `Bearer ${account.access_token}` } }
        );

        if (msgResponse.ok) {
          const message: GmailMessage = await msgResponse.json();
          const email = parseGmailMessage(message, account);
          emails.push(email);
        }
      }

      // Upsert emails into database
      for (const email of emails) {
        // First, find or create thread
        let threadId: string;

        const { data: existingThread } = await supabase
          .from("email_threads")
          .select("id")
          .eq("store_id", account.store_id)
          .eq("external_thread_id", email.gmail_thread_id)
          .single();

        if (existingThread) {
          threadId = existingThread.id;
        } else {
          const { data: newThread, error: threadError } = await supabase
            .from("email_threads")
            .insert({
              store_id: account.store_id,
              external_thread_id: email.gmail_thread_id,
              subject: email.subject,
              status: "open",
              mailbox: determineMailbox(email.to_email, account.email_address),
              priority: "normal",
            })
            .select()
            .single();

          if (threadError) {
            console.error("Thread create error:", threadError);
            continue;
          }
          threadId = newThread.id;
        }

        // Insert email
        const { error: emailError } = await supabase
          .from("email_inbox")
          .upsert({
            store_id: account.store_id,
            thread_id: threadId,
            message_id: email.message_id,
            external_id: email.gmail_id,
            from_email: email.from_email,
            from_name: email.from_name,
            to_email: email.to_email,
            subject: email.subject,
            body_text: email.body_text,
            body_html: email.body_html,
            direction: email.is_inbound ? "inbound" : "outbound",
            is_inbound: email.is_inbound,
            is_read: !email.is_unread,
            received_at: email.received_at,
            source: "gmail",
          }, {
            onConflict: "external_id",
          });

        if (emailError) {
          console.error("Email upsert error:", emailError);
        }
      }

      // Update last sync time
      await supabase
        .from("store_email_accounts")
        .update({ last_sync_at: new Date().toISOString(), sync_error: null })
        .eq("id", account_id);

      return new Response(
        JSON.stringify({ success: true, synced: emails.length }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // List connected accounts for a store
    if (action === "list_accounts") {
      const { data: accounts, error } = await supabase
        .from("store_email_accounts")
        .select("id, email_address, display_name, provider, is_active, last_sync_at, sync_error, created_at")
        .eq("store_id", store_id)
        .order("created_at", { ascending: false });

      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ accounts }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Disconnect account
    if (action === "disconnect") {
      const { error } = await supabase
        .from("store_email_accounts")
        .delete()
        .eq("id", account_id)
        .eq("store_id", store_id);

      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Invalid action" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Gmail sync error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function decodeBase64Url(data: string): string {
  try {
    // Convert URL-safe base64 to standard base64
    const base64 = data.replace(/-/g, "+").replace(/_/g, "/");
    // Decode base64 to bytes
    const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    // Decode UTF-8 bytes to string
    return new TextDecoder("utf-8").decode(bytes);
  } catch (e) {
    console.error("Base64 decode error:", e);
    return "";
  }
}

function parseGmailMessage(message: GmailMessage, account: any) {
  const headers = message.payload?.headers || [];
  const getHeader = (name: string) => headers.find(h => h.name.toLowerCase() === name.toLowerCase())?.value || "";

  const from = getHeader("From");
  const to = getHeader("To");
  const subject = getHeader("Subject");
  const messageId = getHeader("Message-ID");

  // Parse from email and name
  const fromMatch = from.match(/^(?:"?([^"]*)"?\s)?<?([^>]+)>?$/);
  const fromName = fromMatch?.[1]?.trim() || "";
  const fromEmail = fromMatch?.[2]?.trim() || from;

  // Determine if inbound
  const isInbound = fromEmail.toLowerCase() !== account.email_address.toLowerCase();

  // Get body - handle various email structures
  let bodyText = "";
  let bodyHtml = "";

  const extractBody = (payload: any, depth = 0) => {
    if (depth > 10) return; // Prevent infinite recursion

    if (!payload) return;

    // Direct body data
    if (payload.body?.data && payload.body.data.length > 0) {
      const decoded = decodeBase64Url(payload.body.data);
      if (payload.mimeType === "text/plain" && !bodyText) {
        bodyText = decoded;
      } else if (payload.mimeType === "text/html" && !bodyHtml) {
        bodyHtml = decoded;
      }
    }

    // Multipart - recurse into parts
    if (payload.parts && Array.isArray(payload.parts)) {
      for (const part of payload.parts) {
        extractBody(part, depth + 1);
      }
    }
  };

  extractBody(message.payload);

  // If no text but have HTML, create text from HTML
  if (!bodyText && bodyHtml) {
    bodyText = bodyHtml.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim().substring(0, 500);
  }

  // Use snippet as fallback
  if (!bodyText && !bodyHtml && message.snippet) {
    bodyText = message.snippet;
  }

  return {
    gmail_id: message.id,
    gmail_thread_id: message.threadId,
    message_id: messageId,
    from_email: fromEmail,
    from_name: fromName,
    to_email: to,
    subject: subject || "(No Subject)",
    body_text: bodyText,
    body_html: bodyHtml,
    is_inbound: isInbound,
    is_unread: message.labelIds?.includes("UNREAD") || false,
    received_at: new Date(parseInt(message.internalDate)).toISOString(),
  };
}

function determineMailbox(toEmail: string, accountEmail: string): string {
  const localPart = toEmail.split("@")[0].toLowerCase();

  if (localPart.includes("support")) return "support";
  if (localPart.includes("order")) return "orders";
  if (localPart.includes("return")) return "returns";
  if (localPart.includes("info")) return "info";

  return "general";
}
