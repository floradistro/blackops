/**
 * SwagManager Agent Server
 *
 * Production-quality local agent using Claude Agent SDK
 * Tools are loaded dynamically from Supabase ai_tool_registry
 *
 * Architecture:
 * - WebSocket server for Swift app communication
 * - Claude Agent SDK for agentic loop with tool execution
 * - Tools execute via tools-gateway edge function
 */

// Load environment variables from .env file
import { config } from "dotenv";
config();

import { WebSocketServer, WebSocket } from "ws";
import { query } from "@anthropic-ai/claude-code";
import { loadToolRegistry, createDynamicToolsServer, getToolMetadata, ToolRegistryEntry, ClientToolMetadata, invalidateToolCache } from "./mcp/tool-registry.js";
import { AgentConfig, ClientMessage, ServerMessage } from "./types.js";

// ============================================================================
// CONFIGURATION
// ============================================================================

const PORT = parseInt(process.env.AGENT_PORT || "3847");
const SUPABASE_URL = process.env.SUPABASE_URL || "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

// ============================================================================
// TOOL REGISTRY (loaded at startup)
// ============================================================================

let toolRegistry: ToolRegistryEntry[] = [];
let toolMetadata: ClientToolMetadata[] = [];

async function initializeTools() {
  if (!SUPABASE_KEY) {
    console.warn("[Agent Server] No SUPABASE_SERVICE_ROLE_KEY - tools will not be available");
    return;
  }

  console.log("[Agent Server] Loading tools from registry...");
  toolRegistry = await loadToolRegistry(SUPABASE_URL, SUPABASE_KEY);
  toolMetadata = getToolMetadata(toolRegistry);
  console.log(`[Agent Server] Loaded ${toolRegistry.length} tools in ${new Set(toolRegistry.map(t => t.category)).size} categories`);
}

// ============================================================================
// NO DEFAULT SYSTEM PROMPT - All settings come from Agent Config
// ============================================================================

// ============================================================================
// WEBSOCKET SERVER
// ============================================================================

const wss = new WebSocketServer({ port: PORT });

console.log(`[Agent Server] Starting on ws://localhost:${PORT}`);

wss.on("connection", (ws: WebSocket) => {
  console.log("[Agent Server] Client connected");

  let abortController: AbortController | null = null;

  ws.on("message", async (data: Buffer) => {
    try {
      const message: ClientMessage = JSON.parse(data.toString());

      switch (message.type) {
        case "query":
          abortController = new AbortController();
          handleQuery(ws, message, abortController);
          break;

        case "abort":
          if (abortController) {
            abortController.abort();
            send(ws, { type: "aborted" });
          }
          break;

        case "ping":
          send(ws, { type: "pong" });
          break;

        case "get_tools":
          // Force refresh tools from registry (invalidate cache) and send back
          invalidateToolCache();
          await initializeTools();
          send(ws, {
            type: "tools",
            tools: toolMetadata
          });
          break;

        default:
          send(ws, { type: "error", error: `Unknown message type` });
      }
    } catch (error) {
      console.error("[Agent Server] Error:", error);
      send(ws, { type: "error", error: "Invalid message format" });
    }
  });

  ws.on("close", () => {
    console.log("[Agent Server] Client disconnected");
    abortController?.abort();
  });

  ws.on("error", (error) => {
    console.error("[Agent Server] WebSocket error:", error);
  });

  // Send ready message with available tools
  send(ws, {
    type: "ready",
    version: "2.0.0",
    tools: toolMetadata
  });
});

// ============================================================================
// QUERY HANDLER
// ============================================================================

async function handleQuery(
  ws: WebSocket,
  message: ClientMessage & { type: "query" },
  abortController: AbortController
) {
  const { prompt, config, storeId, attachedPaths } = message;

  console.log(`[Agent Server] Query: "${prompt.slice(0, 80)}..."`);
  console.log(`[Agent Server] Agent info: id=${config?.agentId || 'none'}, name=${config?.agentName || 'none'}`);
  console.log(`[Agent Server] Config received:`, JSON.stringify({
    model: config?.model,
    agentId: config?.agentId,
    agentName: config?.agentName,
    enabledTools: config?.enabledTools,
    enabledToolsType: config?.enabledTools === undefined ? 'undefined' : config?.enabledTools === null ? 'null' : `array(${config?.enabledTools?.length})`,
    systemPromptLength: config?.systemPrompt?.length || 0
  }));

  // Refresh tools if stale
  if (toolRegistry.length === 0) {
    await initializeTools();
  }

  // Filter tools based on enabledTools config:
  // - undefined/null: Use ALL tools (default - no restriction)
  // - empty array []: Use NO tools (explicit restriction)
  // - array with items: Use only those specific tools
  let toolsToUse = toolRegistry;

  if (config?.enabledTools !== undefined && config?.enabledTools !== null) {
    // enabledTools is explicitly set (could be empty or have items)
    if (config.enabledTools.length === 0) {
      // Explicitly set to empty = NO tools allowed
      toolsToUse = [];
      console.log(`[Agent Server] Tools explicitly disabled (empty enabledTools array)`);
    } else {
      // Filter to only the specified tools
      const enabledSet = new Set(config.enabledTools);
      toolsToUse = toolRegistry.filter(t => enabledSet.has(t.name));
      console.log(`[Agent Server] Filtered to ${toolsToUse.length} enabled tools (from ${toolRegistry.length})`);
      if (toolsToUse.length === 0) {
        console.warn(`[Agent Server] Warning: No tools matched the filter! enabledTools: ${config.enabledTools.slice(0, 5).join(', ')}...`);
      }
    }
  } else {
    // enabledTools not set = use all tools (default)
    console.log(`[Agent Server] Using all ${toolRegistry.length} tools (enabledTools not configured)`);
  }

  // System prompt comes ONLY from agent config - no defaults
  if (!config?.systemPrompt) {
    send(ws, { type: "error", error: "No system prompt configured for this agent. Please add a system prompt in the Agent Config panel." });
    return;
  }
  let systemPrompt = config.systemPrompt;
  if (storeId) {
    systemPrompt += `\n\nStore Context: You are operating for store_id: ${storeId}. This will be automatically included in tool calls.`;
  }

  // Create MCP server with filtered tools
  // Generate session ID for tracing - links all tool calls in this conversation
  const sessionId = crypto.randomUUID();
  const toolsServer = createDynamicToolsServer(
    SUPABASE_URL,
    SUPABASE_KEY,
    toolsToUse,
    storeId,
    undefined,  // userId
    sessionId,  // traceId for telemetry
    config?.agentId,   // AI Agent UUID for telemetry
    config?.agentName  // AI Agent name for telemetry
  );

  // Build allowedTools list - MCP tools are prefixed with mcp__swagmanager__
  // This restricts the agent to ONLY our MCP tools (no built-in Bash, Read, Write, etc.)
  const allowedTools = toolsToUse.map(t => `mcp__swagmanager__${t.name}`);
  console.log(`[Agent Server] allowedTools: ${allowedTools.join(', ')}`);

  // Validate model - Claude Code SDK requires specific models for tool use
  // Haiku models don't support complex tool use, fall back to Sonnet
  const SUPPORTED_MODELS = [
    "claude-sonnet-4-20250514",
    "claude-opus-4-20250514",
    "claude-3-5-sonnet-20241022",
    "claude-3-opus-20240229"
  ];

  let modelToUse = config?.model || "claude-sonnet-4-20250514";

  // If model is Haiku or not in supported list, fall back to Sonnet
  if (!SUPPORTED_MODELS.includes(modelToUse) || modelToUse.includes("haiku")) {
    console.log(`[Agent Server] Model "${modelToUse}" not supported for tool use, falling back to claude-sonnet-4-20250514`);
    modelToUse = "claude-sonnet-4-20250514";
  }

  console.log(`[Agent Server] Model from config: "${config?.model}", using: "${modelToUse}"`);
  console.log(`[Agent Server] API key from config: ${config?.apiKey ? config.apiKey.slice(0, 20) + '...' : 'none'}`);
  console.log(`[Agent Server] API key from env: ${process.env.ANTHROPIC_API_KEY ? process.env.ANTHROPIC_API_KEY.slice(0, 20) + '...' : 'none'}`);

  // Use API key from agent config if provided, otherwise fall back to env var
  if (config?.apiKey) {
    process.env.ANTHROPIC_API_KEY = config.apiKey;
    console.log(`[Agent Server] Using API key from agent config`);
  } else if (!process.env.ANTHROPIC_API_KEY) {
    send(ws, { type: "error", error: "No Anthropic API key configured. Add one in the Agent Config panel or set ANTHROPIC_API_KEY in .env" });
    return;
  } else {
    console.log(`[Agent Server] Using API key from environment`);
  }

  send(ws, { type: "started", model: modelToUse, storeId });

  // Send debug info
  send(ws, {
    type: "debug",
    level: "info",
    message: "Query started",
    data: {
      promptLength: prompt.length,
      model: modelToUse,
      storeId: storeId || "none",
      toolCount: toolsToUse.length,
      totalToolsAvailable: toolRegistry.length,
      enabledToolsFilter: config?.enabledTools?.length ?? "none"
    }
  });

  try {
    let toolName: string | null = null;

    // Run agent with SDK
    // Use allowedTools to restrict agent to ONLY our MCP tools (no built-in Bash, Read, Write, etc.)
    const response = query({
      prompt,
      options: {
        model: modelToUse,
        maxTurns: config?.maxTurns || 50,
        customSystemPrompt: systemPrompt,
        permissionMode: config?.permissionMode || "bypassPermissions",
        abortController,
        includePartialMessages: true,
        allowedTools: allowedTools.length > 0 ? allowedTools : undefined,
        mcpServers: {
          swagmanager: toolsServer
        }
      }
    });

    // Process SDK events
    for await (const event of response) {
      const eventType = event.type;
      const subtype = (event as any).subtype;

      // Log all events for debugging
      if (eventType !== "stream_event") {
        console.log(`[Event] type=${eventType}, subtype=${subtype || 'none'}`);
      }

      switch (eventType) {
        case "system":
          if (subtype === "init") {
            const toolCount = (event as any).tools?.length || 0;
            console.log(`[Init] model: ${(event as any).model}, tools: ${toolCount}`);
            send(ws, {
              type: "debug",
              level: "info",
              message: `Agent initialized with ${toolCount} tools`
            });
          }
          break;

        case "stream_event":
          const streamEvent = (event as any).event;
          if (streamEvent?.type === "content_block_delta") {
            const delta = streamEvent.delta;
            if (delta?.type === "text_delta" && delta.text) {
              send(ws, { type: "text", text: delta.text });
            }
          } else if (streamEvent?.type === "content_block_start") {
            const block = streamEvent.content_block;
            if (block?.type === "tool_use") {
              toolName = block.name;
              console.log(`[Tool Start] ${block.name}`);
              send(ws, {
                type: "tool_start",
                tool: block.name,
                input: {}
              });
            }
          }
          break;

        case "assistant":
          const assistantEvent = event as any;
          if (assistantEvent.message?.content) {
            for (const block of assistantEvent.message.content) {
              if (block.type === "tool_use" && toolName !== block.name) {
                toolName = block.name;
                send(ws, {
                  type: "tool_start",
                  tool: block.name,
                  input: block.input || {}
                });
              }
            }
          }
          break;

        case "user":
          const userEvent = event as any;
          if (userEvent.message?.content) {
            for (const block of userEvent.message.content) {
              if (block.type === "tool_result") {
                const isError = block.is_error || false;
                let resultText = "";
                if (Array.isArray(block.content)) {
                  resultText = block.content.map((c: any) => c.text || "").join("");
                } else if (typeof block.content === "string") {
                  resultText = block.content;
                }

                console.log(`[Tool Result] ${toolName}: ${isError ? "ERROR" : "OK"}${isError ? ` - ${resultText.slice(0, 200)}` : ""}`);
                send(ws, {
                  type: "tool_result",
                  tool: toolName || "unknown",
                  success: !isError,
                  result: resultText.slice(0, 2000),
                  error: isError ? resultText : undefined
                });

                toolName = null;
              }
            }
          }
          break;

        case "result":
          const resultEvent = event as any;
          console.log(`[Done] ${resultEvent.subtype}, turns: ${resultEvent.num_turns}, cost: $${resultEvent.total_cost_usd?.toFixed(4)}`);
          send(ws, {
            type: "done",
            status: resultEvent.subtype || "success",
            usage: {
              inputTokens: resultEvent.usage?.input_tokens || 0,
              outputTokens: resultEvent.usage?.output_tokens || 0,
              totalCost: resultEvent.total_cost_usd || 0
            }
          });
          break;
      }
    }

  } catch (error: any) {
    if (abortController.signal.aborted) {
      send(ws, { type: "aborted" });
    } else if (error.message?.includes("process exited with code 1")) {
      // Ignore this error - it happens after successful completion
      // This is a known issue with the Claude Code SDK cleanup
      console.log("[Agent Server] Process cleanup (benign)");
    } else {
      console.error("[Agent Server] Query error:", error);
      send(ws, {
        type: "error",
        error: error.message || String(error)
      });
    }
  }
}

// ============================================================================
// HELPERS
// ============================================================================

function send(ws: WebSocket, message: ServerMessage) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

// ============================================================================
// STARTUP
// ============================================================================

async function main() {
  await initializeTools();
  console.log(`[Agent Server] Ready on ws://localhost:${PORT}`);
}

main().catch(console.error);

// Graceful shutdown
process.on("SIGINT", () => {
  console.log("\n[Agent Server] Shutting down...");
  wss.close(() => {
    console.log("[Agent Server] Closed");
    process.exit(0);
  });
});
