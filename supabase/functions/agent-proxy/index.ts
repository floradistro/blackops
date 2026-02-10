// agent-proxy/index.ts
// Proxies Anthropic API calls from CLI clients
// Server holds ANTHROPIC_API_KEY — clients authenticate via Supabase JWT

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@0.30.1";

// CORS: use ALLOWED_ORIGINS env var (comma-separated) or fall back to wildcard for local dev
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") || "*").split(",").map(s => s.trim());

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowedOrigin = ALLOWED_ORIGINS.includes("*") ? "*" : (ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]);
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: getCorsHeaders(req) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
    });
  }

  // Validate JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
    });
  }

  const token = authHeader.replace("Bearer ", "");

  try {
    // Verify the JWT is valid by creating a user-scoped client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
      });
    }

    // Parse request body
    const body = await req.json();
    const {
      messages,
      system,
      tools,
      model: requestedModel = "claude-sonnet-4-20250514",
      max_tokens: requestedMaxTokens = 4096,
      temperature,
      stream = true,
    } = body;

    if (!messages || !Array.isArray(messages)) {
      return new Response(JSON.stringify({ error: "messages array required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
      });
    }

    // Model allowlist — only permit known Anthropic models
    const ALLOWED_MODELS = [
      "claude-sonnet-4-20250514",
      "claude-haiku-4-5-20251001",
      "claude-opus-4-20250514",
    ];
    const model = ALLOWED_MODELS.includes(requestedModel) ? requestedModel : "claude-sonnet-4-20250514";

    // Cap max_tokens to prevent abuse (16k ceiling)
    const MAX_TOKENS_LIMIT = 16384;
    const max_tokens = Math.min(Math.max(1, Number(requestedMaxTokens) || 4096), MAX_TOKENS_LIMIT);

    // Build Anthropic request
    const apiParams: Record<string, unknown> = {
      model,
      max_tokens,
      messages,
      stream: true, // Always stream from Anthropic
    };
    if (system) apiParams.system = system;
    if (tools?.length) apiParams.tools = tools;
    if (temperature !== undefined) apiParams.temperature = temperature;

    if (!stream) {
      // Non-streaming: collect full response and return JSON
      const response = await anthropic.messages.create({
        ...apiParams,
        stream: false,
      } as any);
      return new Response(JSON.stringify(response), {
        headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
      });
    }

    // Streaming: passthrough SSE from Anthropic
    const encoder = new TextEncoder();
    const readableStream = new ReadableStream({
      async start(controller) {
        try {
          const response = await anthropic.messages.create(apiParams as any);

          for await (const event of response as any) {
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify(event)}\n\n`)
            );
          }

          controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        } catch (err) {
          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify({ type: "error", error: String(err) })}\n\n`
            )
          );
        }
        controller.close();
      },
    });

    return new Response(readableStream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        ...getCorsHeaders(req),
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
    });
  }
});
