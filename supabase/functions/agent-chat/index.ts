// agent-chat/index.ts
// Production agent endpoint with SSE streaming
// Tools loaded from ai_tool_registry — same as MCP server

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@0.74.0";

// ── Module imports ──
import type { AgentConfig, ToolDef, StreamEvent } from "./lib/types.ts";
import { summarizeResult, withTimeout, sanitizeError } from "./lib/utils.ts";
import { handleInventory, handleInventoryQuery, handleInventoryAudit } from "./handlers/inventory.ts";
import { handlePurchaseOrders, handleTransfers } from "./handlers/supply-chain.ts";
import { handleProducts, handleCollections } from "./handlers/catalog.ts";
import { handleCustomers, handleOrders } from "./handlers/crm.ts";
import { handleAnalytics } from "./handlers/analytics.ts";
import { handleLocations, handleSuppliers, handleAlerts, handleAuditTrail } from "./handlers/operations.ts";
import { handleEmail, handleDocuments } from "./handlers/comms.ts";
import { handleWebSearch, handleTelemetry } from "./handlers/platform.ts";

// ============================================================================
// TOOL REGISTRY (loaded from database)
// ============================================================================

let cachedTools: ToolDef[] = [];
let cacheTime = 0;

async function loadTools(supabase: SupabaseClient): Promise<ToolDef[]> {
  if (cachedTools.length > 0 && Date.now() - cacheTime < 60_000) return cachedTools;

  const { data, error } = await supabase
    .from("ai_tool_registry")
    .select("name, description, definition")
    .eq("is_active", true)
    .neq("tool_mode", "code");

  if (error || !data) return cachedTools;

  cachedTools = data.map((t: any) => ({
    name: t.name,
    description: t.description || t.definition?.description || t.name,
    input_schema: t.definition?.input_schema || { type: "object", properties: {} }
  }));
  cacheTime = Date.now();
  return cachedTools;
}

function getToolsForAgent(agent: AgentConfig, allTools: ToolDef[]): ToolDef[] {
  if (agent.enabled_tools?.length > 0) {
    return allTools.filter(t => agent.enabled_tools.includes(t.name));
  }
  return allTools;
}

// ============================================================================
// TOOL EXECUTOR — dispatches to handler modules
// ============================================================================

const TOOL_TIMEOUT_MS = 30_000;

async function executeTool(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>,
  storeId?: string,
  traceId?: string,
  userId?: string | null,
  userEmail?: string | null,
  source?: string,
  conversationId?: string
): Promise<{ success: boolean; data?: unknown; error?: string }> {
  const startTime = Date.now();
  const action = args.action as string | undefined;
  let result: { success: boolean; data?: unknown; error?: string };

  // Validate store_id for all store-scoped tools
  const storeRequired = toolName !== "web_search";
  if (storeRequired && (!storeId || !/^[0-9a-fA-F]{8}-/.test(storeId))) {
    return { success: false, error: `store_id is required for ${toolName}. Ensure a store is selected.` };
  }

  try {
    const toolPromise = (async () => {
      switch (toolName) {
        case "inventory": return handleInventory(supabase, args, storeId);
        case "inventory_query": return handleInventoryQuery(supabase, args, storeId);
        case "inventory_audit": return handleInventoryAudit(supabase, args, storeId);
        case "purchase_orders": return handlePurchaseOrders(supabase, args, storeId);
        case "transfers": return handleTransfers(supabase, args, storeId);
        case "products": return handleProducts(supabase, args, storeId);
        case "collections": return handleCollections(supabase, args, storeId);
        case "customers": return handleCustomers(supabase, args, storeId);
        case "orders": return handleOrders(supabase, args, storeId);
        case "analytics": return handleAnalytics(supabase, args, storeId);
        case "locations": return handleLocations(supabase, args, storeId);
        case "suppliers": return handleSuppliers(supabase, args, storeId);
        case "email": return handleEmail(supabase, args, storeId);
        case "documents": return handleDocuments(supabase, args, storeId);
        case "alerts": return handleAlerts(supabase, args, storeId);
        case "audit_trail": return handleAuditTrail(supabase, args, storeId);
        case "web_search": return handleWebSearch(supabase, args, storeId);
        case "telemetry": return handleTelemetry(supabase, args, storeId);
        default: return { success: false, error: `Unknown tool: ${toolName}` };
      }
    })();

    result = await withTimeout(toolPromise, TOOL_TIMEOUT_MS, toolName);
  } catch (err) {
    result = { success: false, error: sanitizeError(err) };
  }

  // Log to audit_logs with result summary
  try {
    const details: Record<string, unknown> = { source: source || "edge_function", args };
    if (result.success && result.data) {
      details.result_summary = summarizeResult(toolName, action, result.data);
    }
    await supabase.from("audit_logs").insert({
      action: `tool.${toolName}${action ? `.${action}` : ""}`,
      severity: result.success ? "info" : "error",
      store_id: storeId || null,
      resource_type: "mcp_tool",
      resource_id: toolName,
      request_id: traceId || null,
      conversation_id: conversationId || null,
      source: source || "edge_function",
      details,
      error_message: result.error || null,
      duration_ms: Date.now() - startTime,
      user_id: userId || null,
      user_email: userEmail || null
    });
  } catch (err) { console.error("[audit]", err); }

  return result;
}

// ============================================================================
// AGENT LOADER
// ============================================================================

async function loadAgentConfig(supabase: SupabaseClient, agentId: string): Promise<AgentConfig | null> {
  const { data, error } = await supabase.from("ai_agent_config").select("*").eq("id", agentId).single();
  if (error || !data) return null;
  return data as AgentConfig;
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

const defaultAnthropicKey = Deno.env.get("ANTHROPIC_API_KEY")!;

function getAnthropicClient(agent: AgentConfig): Anthropic {
  const key = agent.api_key || defaultAnthropicKey;
  return new Anthropic({ apiKey: key });
}

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") || "*").split(",").map((s: string) => s.trim());

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowedOrigin = ALLOWED_ORIGINS.includes("*") ? "*" : (ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]);
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: getCorsHeaders(req) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
    });
  }

  try {
    // ── Auth gate: require valid JWT or service-role key ──
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing authorization" }),
        { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
    }

    const token = authHeader.substring(7);

    // Create service-role client for data operations
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Check if token is a service-role key (new sb_secret_* format OR legacy JWT)
    let user: { id: string; email?: string } | null = null;
    const isServiceRole =
      token === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
      token === (Deno.env.get("SERVICE_ROLE_JWT") || "");

    if (!isServiceRole) {
      // Validate user JWT
      const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(token);
      if (authError || !authUser) {
        return new Response(JSON.stringify({ error: "Invalid or expired token" }),
          { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
      }
      user = authUser;
    }

    // ── Rate limiting (skip for service-role) ──
    if (user) {
      const { data: rl } = await supabase.rpc("check_rate_limit", {
        p_user_id: user.id, p_window_seconds: 60, p_max_requests: 20
      });
      if (rl?.[0] && !rl[0].allowed) {
        return new Response(JSON.stringify({ error: "Rate limit exceeded" }), {
          status: 429,
          headers: { "Retry-After": String(rl[0].retry_after_seconds), "Content-Type": "application/json", ...getCorsHeaders(req) },
        });
      }
    }

    const body = await req.json();

    // ── Direct tool execution mode ──
    // POST { mode: "tool", tool_name, args, store_id }
    // Returns JSON { success, data, error } — no agent loop, no SSE
    if (body.mode === "tool") {
      const { tool_name, args, store_id } = body;
      if (!tool_name) {
        return new Response(JSON.stringify({ error: "tool_name required" }),
          { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
      }
      const toolArgs = (args || {}) as Record<string, unknown>;
      const result = await executeTool(
        supabase, tool_name, toolArgs, store_id || undefined,
        undefined, user?.id || body.userId || null, user?.email || body.userEmail || null, "mcp"
      );
      return new Response(JSON.stringify(result), {
        status: result.success ? 200 : 500,
        headers: { "Content-Type": "application/json", ...getCorsHeaders(req) },
      });
    }

    const { agentId, message, conversationHistory, source, conversationId } = body;
    let storeId: string | undefined = body.storeId;

    if (!agentId || !message) {
      return new Response(JSON.stringify({ error: "agentId and message required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
    }

    // Verify user has access to the requested store (skip for service_role)
    if (storeId && !isServiceRole) {
      const userClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: `Bearer ${token}` } } }
      );
      const { data: storeAccess, error: storeErr } = await userClient
        .from("stores").select("id").eq("id", storeId).limit(1);
      if (storeErr || !storeAccess?.length) {
        return new Response(JSON.stringify({ error: "Access denied to store" }),
          { status: 403, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
      }
    }

    const userId: string = user?.id || body.userId || "";
    const userEmail: string | null = user?.email || body.userEmail || null;

    const agent = await loadAgentConfig(supabase, agentId);
    if (!agent) {
      return new Response(JSON.stringify({ error: "Agent not found" }),
        { status: 404, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
    }

    const allTools = await loadTools(supabase);
    const tools = getToolsForAgent(agent, allTools);
    const traceId = crypto.randomUUID();

    // Resolve or create conversation
    let activeConversationId: string;
    if (conversationId) {
      activeConversationId = conversationId;
    } else {
      let conv = await supabase.from("ai_conversations").insert({
        store_id: storeId || null, user_id: userId || null, agent_id: agentId,
        title: message.substring(0, 100),
        metadata: { agentName: agent.name, source: source || "whale_chat" }
      }).select("id").single();
      if (conv.error && userId) {
        conv = await supabase.from("ai_conversations").insert({
          store_id: storeId || null, agent_id: agentId,
          title: message.substring(0, 100),
          metadata: { agentName: agent.name, source: source || "whale_chat", userId, userEmail }
        }).select("id").single();
      }
      activeConversationId = conv.data?.id || crypto.randomUUID();
    }

    // Build system prompt
    let systemPrompt = agent.system_prompt || "You are a helpful assistant.";
    if (storeId) systemPrompt += `\n\nYou are operating for store_id: ${storeId}. Always include this in tool calls that require it.`;
    if (!agent.can_modify) systemPrompt += "\n\nIMPORTANT: You have read-only access. Do not attempt to modify any data.";
    if (agent.tone && agent.tone !== "professional") systemPrompt += `\n\nTone: Respond in a ${agent.tone} tone.`;
    if (agent.verbosity === "concise") systemPrompt += "\n\nBe concise — short answers, minimal explanation.";
    else if (agent.verbosity === "verbose") systemPrompt += "\n\nBe thorough — provide detailed answers with full context.";

    if (agent.context_config) {
      const ctx = agent.context_config;
      if (ctx.includeLocations && ctx.locationIds?.length) systemPrompt += `\n\nFocus on these locations: ${ctx.locationIds.join(", ")}`;
      if (ctx.includeCustomers && ctx.customerSegments?.length) systemPrompt += `\n\nFocus on these customer segments: ${ctx.customerSegments.join(", ")}`;
    }

    const anthropic = getAnthropicClient(agent);

    // Token budget management — lightweight safety net (server handles compaction)
    const ctxCfg = agent.context_config;
    const MAX_HISTORY_CHARS = ctxCfg?.max_history_chars || 400_000;
    const MAX_TOOL_RESULT_CHARS = ctxCfg?.max_tool_result_chars || 40_000;
    const MAX_MESSAGE_CHARS = ctxCfg?.max_message_chars || 20_000;

    function compactHistory(history: Anthropic.MessageParam[]): Anthropic.MessageParam[] {
      if (!history?.length) return [];
      let totalChars = 0;
      const compacted: Anthropic.MessageParam[] = [];
      for (let i = history.length - 1; i >= 0; i--) {
        const msg = history[i];
        let content = msg.content;
        if (typeof content === "string") {
          if (content.length > MAX_MESSAGE_CHARS) content = content.substring(0, MAX_MESSAGE_CHARS) + "\n...[truncated]";
        } else if (Array.isArray(content)) {
          content = content.map((block: any) => {
            if (block.type === "text" && block.text?.length > MAX_MESSAGE_CHARS) {
              return { ...block, text: block.text.substring(0, MAX_MESSAGE_CHARS) + "\n...[truncated]" };
            }
            if (block.type === "tool_result" && typeof block.content === "string" && block.content.length > MAX_TOOL_RESULT_CHARS) {
              return { ...block, content: block.content.substring(0, MAX_TOOL_RESULT_CHARS) + "\n...[truncated]" };
            }
            return block;
          });
        }
        const msgChars = JSON.stringify(content).length;
        if (totalChars + msgChars > MAX_HISTORY_CHARS) break;
        totalChars += msgChars;
        compacted.unshift({ ...msg, content });
      }
      while (compacted.length > 0 && compacted[0].role !== "user") compacted.shift();
      return compacted;
    }

    const messages: Anthropic.MessageParam[] = [
      ...compactHistory(conversationHistory || []),
      { role: "user", content: message }
    ];

    // Insert user message + audit
    try { await supabase.from("ai_messages").insert({ conversation_id: activeConversationId, role: "user", content: [{ type: "text", text: message }] }); } catch (err) { console.error("[audit]", err); }
    try {
      await supabase.from("audit_logs").insert({
        action: "chat.user_message", severity: "info", store_id: storeId || null,
        resource_type: "chat_message", resource_id: agentId, request_id: traceId,
        conversation_id: activeConversationId, user_id: userId || null, user_email: userEmail || null,
        source: source || "whale_chat",
        details: { message_preview: message.substring(0, 200), agent_id: agentId, model: agent.model, conversation_id: activeConversationId, history_length: conversationHistory?.length || 0 }
      });
    } catch (err) { console.error("[audit]", err); }

    // SSE stream
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: StreamEvent) => {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
        };

        let turnCount = 0, toolCallCount = 0, totalIn = 0, totalOut = 0;
        let finalResponse = "", continueLoop = true;
        const chatStartTime = Date.now();
        let allTextResponses: string[] = [];
        let allToolNames: string[] = [];

        try {
          while (continueLoop && turnCount < (agent.max_tool_calls || 10)) {
            turnCount++;

            const response = await anthropic.beta.messages.create({
              model: agent.model || "claude-sonnet-4-20250514",
              max_tokens: agent.max_tokens || 4096,
              temperature: agent.temperature ?? 0.7,
              system: systemPrompt,
              tools: tools.map(t => ({ name: t.name, description: t.description, input_schema: t.input_schema })),
              messages,
              stream: true,
              betas: ["compact-2026-01-12", "context-management-2025-06-27"],
              context_management: {
                edits: [
                  { type: "compact_20260112", trigger: { type: "input_tokens", value: 150_000 } },
                  { type: "clear_tool_uses_20250919", trigger: { type: "input_tokens", value: 100_000 },
                    keep: { type: "tool_uses", value: 5 } },
                ],
              },
            } as any);

            let currentText = "";
            const toolUseBlocks: Array<{ id: string; name: string; input: Record<string, unknown> }> = [];
            let currentToolUse: { id: string; name: string; input: string } | null = null;

            for await (const event of response) {
              if (event.type === "content_block_start" && event.content_block.type === "tool_use") {
                currentToolUse = { id: event.content_block.id, name: event.content_block.name, input: "" };
                send({ type: "tool_start", name: event.content_block.name });
              } else if (event.type === "content_block_delta") {
                if (event.delta.type === "text_delta") {
                  currentText += event.delta.text;
                  send({ type: "text", text: event.delta.text });
                } else if (event.delta.type === "input_json_delta" && currentToolUse) {
                  currentToolUse.input += event.delta.partial_json;
                }
              } else if (event.type === "content_block_stop" && currentToolUse) {
                try {
                  const rawInput = currentToolUse.input.trim() || "{}";
                  toolUseBlocks.push({ id: currentToolUse.id, name: currentToolUse.name, input: JSON.parse(rawInput) });
                } catch (err) { console.error("[json-parse]", err); }
                currentToolUse = null;
              } else if (event.type === "content_block_start" && (event as any).content_block?.type === "compaction") {
                console.log("[compaction] Server compacted conversation history");
              } else if (event.type === "message_delta" && event.usage) {
                totalOut += event.usage.output_tokens;
              } else if (event.type === "message_start" && event.message.usage) {
                totalIn += event.message.usage.input_tokens;
              }
            }

            if (currentText) allTextResponses.push(currentText);

            if (toolUseBlocks.length === 0) {
              finalResponse = currentText;
              continueLoop = false;
              break;
            }

            // Execute tool calls
            const toolResults: Anthropic.MessageParam["content"] = [];
            for (const tu of toolUseBlocks) {
              toolCallCount++;
              allToolNames.push(tu.name);
              const toolArgs = { ...tu.input };
              if (!toolArgs.store_id && storeId) toolArgs.store_id = storeId;

              const result = await executeTool(supabase, tu.name, toolArgs, storeId, traceId, userId, userEmail, source, activeConversationId);
              send({ type: "tool_result", name: tu.name, success: result.success, result: result.success ? result.data : result.error });
              let resultJson = JSON.stringify(result.success ? result.data : { error: result.error });
              if (resultJson.length > MAX_TOOL_RESULT_CHARS) {
                resultJson = resultJson.substring(0, MAX_TOOL_RESULT_CHARS) + '..."truncated"}';
              }
              toolResults.push({ type: "tool_result", tool_use_id: tu.id, content: resultJson });
            }

            messages.push({
              role: "assistant",
              content: [
                ...(currentText ? [{ type: "text" as const, text: currentText }] : []),
                ...toolUseBlocks.map(t => ({ type: "tool_use" as const, id: t.id, name: t.name, input: t.input }))
              ]
            });
            messages.push({ role: "user", content: toolResults });
          }

          send({ type: "usage", usage: { input_tokens: totalIn, output_tokens: totalOut } });

          const fullResponse = allTextResponses.join("\n\n") || finalResponse;
          const usedToolNames = [...new Set(allToolNames)];
          try {
            await supabase.from("ai_messages").insert({
              conversation_id: activeConversationId, role: "assistant",
              content: [{ type: "text", text: fullResponse }],
              is_tool_use: toolCallCount > 0,
              tool_names: usedToolNames.length > 0 ? usedToolNames : null,
              token_count: totalIn + totalOut
            });
          } catch (err) { console.error("[audit]", err); }

          try {
            await supabase.from("ai_conversations").update({
              metadata: { agentName: agent.name, source: source || "whale_chat", model: agent.model,
                lastTurnTokens: totalIn + totalOut, lastToolCalls: toolCallCount, lastDurationMs: Date.now() - chatStartTime }
            }).eq("id", activeConversationId);
          } catch (err) { console.error("[audit]", err); }

          try {
            await supabase.from("audit_logs").insert({
              action: "chat.assistant_response", severity: "info", store_id: storeId || null,
              resource_type: "chat_message", resource_id: agentId, request_id: traceId,
              conversation_id: activeConversationId, duration_ms: Date.now() - chatStartTime,
              user_id: userId || null, user_email: userEmail || null, source: source || "whale_chat",
              input_tokens: totalIn, output_tokens: totalOut, model: agent.model || "claude-sonnet-4-20250514",
              details: { response_preview: fullResponse.substring(0, 500), agent_id: agentId, model: agent.model,
                turn_count: turnCount, tool_calls: toolCallCount, tool_names: usedToolNames, conversation_id: activeConversationId }
            });
          } catch (err) { console.error("[audit]", err); }

          send({ type: "done", conversationId: activeConversationId });

        } catch (err) {
          send({ type: "error", error: sanitizeError(err) });
        }

        controller.close();
      }
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        ...getCorsHeaders(req),
      },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: sanitizeError(err) }),
      { status: 500, headers: { "Content-Type": "application/json", ...getCorsHeaders(req) } });
  }
});
