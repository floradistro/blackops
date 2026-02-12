// agent-chat/lib/auth.ts — Authentication and CORS utilities

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS: use ALLOWED_ORIGINS env var (comma-separated) or fall back to wildcard for local dev
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") || "*").split(",").map((s: string) => s.trim());

export function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowedOrigin = ALLOWED_ORIGINS.includes("*") ? "*" : (ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]);
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

export interface AuthResult {
  isServiceRole: boolean;
  user: { id: string; email?: string } | null;
  supabase: SupabaseClient;
}

/** Verify auth token — returns service-role flag + user (if JWT) + service-role client */
export async function verifyAuth(token: string): Promise<{ result?: AuthResult; error?: Response; req?: Request }> {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const isServiceRole = token === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (isServiceRole) {
    return { result: { isServiceRole: true, user: null, supabase } };
  }

  // Validate user JWT
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return { error: undefined }; // caller handles 401
  }
  return { result: { isServiceRole: false, user, supabase } };
}

/** Check rate limit via RPC — returns null if OK, or {retry_after} if exceeded */
export async function checkRateLimit(
  supabase: SupabaseClient,
  userId: string,
  windowSeconds = 60,
  maxRequests = 20
): Promise<{ allowed: boolean; retry_after_seconds: number } | null> {
  const { data: rl } = await supabase.rpc("check_rate_limit", {
    p_user_id: userId, p_window_seconds: windowSeconds, p_max_requests: maxRequests
  });
  if (rl?.[0] && !rl[0].allowed) {
    return { allowed: false, retry_after_seconds: rl[0].retry_after_seconds };
  }
  return null;
}
