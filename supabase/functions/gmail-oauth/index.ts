import { createClient } from "npm:@supabase/supabase-js@2";

const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID")!;
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Gmail API scopes
const SCOPES = [
  "https://www.googleapis.com/auth/gmail.readonly",
  "https://www.googleapis.com/auth/gmail.send",
  "https://www.googleapis.com/auth/gmail.modify",
  "https://www.googleapis.com/auth/userinfo.email",
].join(" ");

// H3 FIX: Default to restrictive CORS
const GMAIL_ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") || "http://localhost:3000,http://127.0.0.1:3000").split(",").map(s => s.trim());
const corsHeaders = {
  "Access-Control-Allow-Origin": GMAIL_ALLOWED_ORIGINS.includes("*") ? "*" : GMAIL_ALLOWED_ORIGINS[0],
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    if (req.method === "POST") {
      // Auth: only service_role can start OAuth or refresh tokens
      const authHeader = req.headers.get("Authorization");
      if (!authHeader?.startsWith("Bearer ") || authHeader.slice(7) !== SUPABASE_SERVICE_KEY) {
        return new Response(
          JSON.stringify({ error: "Unauthorized" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const body = await req.json();

      // Start OAuth flow - generate auth URL
      if (body.action === "start") {
        const { store_id, redirect_uri } = body;

        if (!store_id) {
          return new Response(
            JSON.stringify({ error: "store_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // Generate random state for CSRF protection
        const state = crypto.randomUUID();

        // Store state in database
        await supabase.from("oauth_states").insert({
          state,
          store_id,
          provider: "gmail",
          redirect_uri: redirect_uri || "swagmanager://oauth/callback",
        });

        // Build Google OAuth URL
        const authUrl = new URL("https://accounts.google.com/o/oauth2/v2/auth");
        authUrl.searchParams.set("client_id", GOOGLE_CLIENT_ID);
        authUrl.searchParams.set("redirect_uri", `${SUPABASE_URL}/functions/v1/gmail-oauth`);
        authUrl.searchParams.set("response_type", "code");
        authUrl.searchParams.set("scope", SCOPES);
        authUrl.searchParams.set("access_type", "offline");
        authUrl.searchParams.set("prompt", "consent");
        authUrl.searchParams.set("state", state);

        return new Response(
          JSON.stringify({ auth_url: authUrl.toString(), state }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Refresh token
      if (body.action === "refresh") {
        const { account_id } = body;

        // Get account
        const { data: account, error: accountError } = await supabase
          .from("store_email_accounts")
          .select("*")
          .eq("id", account_id)
          .single();

        if (accountError || !account?.refresh_token) {
          return new Response(
            JSON.stringify({ error: "Account not found or no refresh token" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // Refresh the token
        const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            client_id: GOOGLE_CLIENT_ID,
            client_secret: GOOGLE_CLIENT_SECRET,
            refresh_token: account.refresh_token,
            grant_type: "refresh_token",
          }),
        });

        const tokens = await tokenResponse.json();

        if (tokens.error) {
          // Mark account as needing re-auth
          await supabase
            .from("store_email_accounts")
            .update({ sync_error: `Token refresh failed: ${tokens.error}`, is_active: false })
            .eq("id", account_id);

          return new Response(
            JSON.stringify({ error: tokens.error }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // Update tokens
        await supabase
          .from("store_email_accounts")
          .update({
            access_token: tokens.access_token,
            token_expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
            sync_error: null,
          })
          .eq("id", account_id);

        return new Response(
          JSON.stringify({ success: true, expires_in: tokens.expires_in }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Handle OAuth callback (GET request from Google)
    if (req.method === "GET" && url.searchParams.get("code")) {
      const code = url.searchParams.get("code");
      const state = url.searchParams.get("state");
      const error = url.searchParams.get("error");

      if (error) {
        return new Response(`OAuth error: ${error}`, { status: 400 });
      }

      if (!state) {
        return new Response("Missing state parameter", { status: 400 });
      }

      // Verify state and get store_id
      const { data: stateData, error: stateError } = await supabase
        .from("oauth_states")
        .select("*")
        .eq("state", state)
        .single();

      if (stateError || !stateData) {
        return new Response("Invalid or expired state", { status: 400 });
      }

      // Delete used state
      await supabase.from("oauth_states").delete().eq("state", state);

      // Check if state is expired
      if (new Date(stateData.expires_at) < new Date()) {
        return new Response("State expired", { status: 400 });
      }

      // Exchange code for tokens
      const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: GOOGLE_CLIENT_ID,
          client_secret: GOOGLE_CLIENT_SECRET,
          code: code!,
          grant_type: "authorization_code",
          redirect_uri: `${SUPABASE_URL}/functions/v1/gmail-oauth`,
        }),
      });

      const tokens = await tokenResponse.json();

      if (tokens.error) {
        return new Response(`Token exchange failed: ${tokens.error}`, { status: 400 });
      }

      // Get user email from Google
      const userInfoResponse = await fetch("https://www.googleapis.com/oauth2/v2/userinfo", {
        headers: { Authorization: `Bearer ${tokens.access_token}` },
      });
      const userInfo = await userInfoResponse.json();

      // Upsert email account
      const { data: account, error: upsertError } = await supabase
        .from("store_email_accounts")
        .upsert({
          store_id: stateData.store_id,
          email_address: userInfo.email,
          display_name: userInfo.name,
          provider: "gmail",
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          token_expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
          is_active: true,
          sync_error: null,
        }, {
          onConflict: "store_id,email_address",
        })
        .select()
        .single();

      if (upsertError) {
        console.error("Upsert error:", upsertError);
        return new Response(`Database error: ${upsertError.message}`, { status: 500 });
      }

      // Redirect back to app
      const redirectUri = stateData.redirect_uri || "swagmanager://oauth/callback";
      // M6 FIX: Sanitize redirect URI to prevent XSS — only allow known schemes
      const allowedSchemes = ["swagmanager://", "http://localhost", "http://127.0.0.1"];
      const safeRedirect = allowedSchemes.some(s => redirectUri.startsWith(s)) ? redirectUri : "swagmanager://oauth/callback";
      const successUrl = `${safeRedirect}?success=true&email=${encodeURIComponent(userInfo.email)}`;

      // Return HTML that redirects (works better for desktop apps)
      return new Response(
        `<!DOCTYPE html>
        <html>
        <head>
          <title>Gmail Connected</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #1a1a1a; color: white; }
            .container { text-align: center; }
            h1 { color: #34C759; }
            p { color: #888; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>✓ Gmail Connected</h1>
            <p>${userInfo.email} has been connected to SwagManager.</p>
            <p>You can close this window.</p>
            <script>
              // Try to redirect to app
              setTimeout(() => {
                window.location.href = "${successUrl}";
              }, 1000);
            </script>
          </div>
        </body>
        </html>`,
        { headers: { "Content-Type": "text/html" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Invalid request" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Gmail OAuth error:", error);
    // M5 FIX: Sanitize error to avoid leaking internal details
    const safeMsg = error instanceof Error ? error.message.replace(/at\s+.*$/gm, "").trim() : "Internal error";
    return new Response(
      JSON.stringify({ error: safeMsg.slice(0, 200) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
