// agent-chat/index.ts
// Production-ready Claude Agent endpoint with streaming and tool execution
// Follows Anthropic SDK best practices

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@0.30.1";

// Types
interface AgentConfig {
  id: string;
  name: string;
  system_prompt: string;
  model: string;
  max_tokens: number;
  max_tool_calls: number;
  temperature: number;
  enabled_tools: string[];
  can_query: boolean;
  can_send: boolean;
  can_modify: boolean;
}

interface ToolDefinition {
  name: string;
  description: string;
  input_schema: {
    type: "object";
    properties: Record<string, unknown>;
    required?: string[];
  };
}

interface StreamEvent {
  type: "text" | "tool_start" | "tool_result" | "error" | "done" | "usage";
  text?: string;
  name?: string;
  args?: Record<string, unknown>;
  result?: unknown;
  success?: boolean;
  error?: string;
  usage?: {
    input_tokens: number;
    output_tokens: number;
  };
}

// Initialize Anthropic client
const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY")!,
});

// Core tool definitions that map to actual RPC functions
const TOOL_DEFINITIONS: ToolDefinition[] = [
  // Inventory Tools
  {
    name: "inventory_summary",
    description: "Get inventory summary grouped by category, location, or product. Shows total quantities and product counts.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        group_by: {
          type: "string",
          enum: ["category", "location", "product"],
          description: "How to group results"
        },
        location_id: { type: "string", description: "Filter by location UUID" },
        include_zero_stock: { type: "boolean", description: "Include zero stock items" }
      },
      required: ["store_id"]
    }
  },
  {
    name: "inventory_adjust",
    description: "Adjust inventory quantity for a product at a location. Use for corrections, shrinkage, or found stock.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        product_id: { type: "string", description: "Product UUID" },
        location_id: { type: "string", description: "Location UUID" },
        quantity_change: { type: "integer", description: "Amount to add (positive) or remove (negative)" },
        reason: { type: "string", description: "Reason for adjustment" }
      },
      required: ["store_id", "product_id", "location_id", "quantity_change", "reason"]
    }
  },
  {
    name: "inventory_transfer",
    description: "Transfer inventory between locations.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        product_id: { type: "string", description: "Product UUID" },
        from_location_id: { type: "string", description: "Source location UUID" },
        to_location_id: { type: "string", description: "Destination location UUID" },
        quantity: { type: "integer", description: "Amount to transfer" }
      },
      required: ["store_id", "product_id", "from_location_id", "to_location_id", "quantity"]
    }
  },

  // Order Tools
  {
    name: "orders_list",
    description: "List orders with optional filters. Returns recent orders by default.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        status: {
          type: "string",
          enum: ["pending", "processing", "shipped", "delivered", "cancelled"],
          description: "Filter by status"
        },
        customer_id: { type: "string", description: "Filter by customer UUID" },
        location_id: { type: "string", description: "Filter by location UUID" },
        limit: { type: "integer", description: "Max results (default 20)" },
        offset: { type: "integer", description: "Pagination offset" }
      },
      required: ["store_id"]
    }
  },
  {
    name: "order_details",
    description: "Get full details of a specific order including items, customer, and status history.",
    input_schema: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "Order UUID" }
      },
      required: ["order_id"]
    }
  },

  // Customer Tools
  {
    name: "customers_search",
    description: "Search customers by name, email, or phone.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        query: { type: "string", description: "Search query (name, email, or phone)" },
        limit: { type: "integer", description: "Max results (default 20)" }
      },
      required: ["store_id", "query"]
    }
  },
  {
    name: "customer_details",
    description: "Get customer profile including order history and loyalty points.",
    input_schema: {
      type: "object",
      properties: {
        customer_id: { type: "string", description: "Customer UUID" }
      },
      required: ["customer_id"]
    }
  },
  {
    name: "customer_loyalty_adjust",
    description: "Add or subtract loyalty points for a customer.",
    input_schema: {
      type: "object",
      properties: {
        customer_id: { type: "string", description: "Customer UUID" },
        points: { type: "integer", description: "Points to add (positive) or subtract (negative)" },
        reason: { type: "string", description: "Reason for adjustment" }
      },
      required: ["customer_id", "points", "reason"]
    }
  },

  // Product Tools
  {
    name: "products_search",
    description: "Search products by name, SKU, or category.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        query: { type: "string", description: "Search query" },
        category_id: { type: "string", description: "Filter by category UUID" },
        in_stock_only: { type: "boolean", description: "Only show in-stock products" },
        limit: { type: "integer", description: "Max results (default 20)" }
      },
      required: ["store_id"]
    }
  },
  {
    name: "product_details",
    description: "Get full product details including variants, pricing, and inventory.",
    input_schema: {
      type: "object",
      properties: {
        product_id: { type: "string", description: "Product UUID" }
      },
      required: ["product_id"]
    }
  },

  // Analytics Tools
  {
    name: "analytics_sales",
    description: "Get sales analytics for a time period.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        start_date: { type: "string", description: "Start date (YYYY-MM-DD)" },
        end_date: { type: "string", description: "End date (YYYY-MM-DD)" },
        group_by: {
          type: "string",
          enum: ["day", "week", "month"],
          description: "Time grouping"
        },
        location_id: { type: "string", description: "Filter by location" }
      },
      required: ["store_id", "start_date", "end_date"]
    }
  },
  {
    name: "analytics_inventory",
    description: "Get inventory analytics including velocity and low stock alerts.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        location_id: { type: "string", description: "Filter by location" }
      },
      required: ["store_id"]
    }
  },

  // Location Tools
  {
    name: "locations_list",
    description: "List all locations for a store.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" }
      },
      required: ["store_id"]
    }
  }
];

// Map tool names to RPC function names
const TOOL_TO_RPC: Record<string, string> = {
  // Inventory
  "inventory_summary": "inventory_summary_by_location",
  "inventory_adjust": "adjust_inventory_ai",
  "inventory_transfer": "transfer_inventory_ai",

  // Orders - use direct table queries
  "orders_list": "__direct_query__",
  "order_details": "__direct_query__",

  // Customers - use direct table queries
  "customers_search": "__direct_query__",
  "customer_details": "__direct_query__",
  "customer_loyalty_adjust": "adjust_customer_loyalty_points",

  // Products - use direct table queries
  "products_search": "__direct_query__",
  "product_details": "__direct_query__",

  // Analytics
  "analytics_sales": "analytics_query",
  "analytics_inventory": "get_inventory_velocity",

  // Locations
  "locations_list": "__direct_query__"
};

// Execute a tool call with telemetry logging
async function executeTool(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>,
  traceId?: string,
  storeId?: string
): Promise<{ success: boolean; data?: unknown; error?: string }> {
  const startTime = Date.now();
  let result: { success: boolean; data?: unknown; error?: string };

  try {
    const rpcName = TOOL_TO_RPC[toolName];

    if (!rpcName) {
      result = { success: false, error: `Unknown tool: ${toolName}` };
    } else if (rpcName === "__direct_query__") {
      result = await executeDirectQuery(supabase, toolName, args);
    } else {
      const { data, error } = await supabase.rpc(rpcName, args);
      result = error ? { success: false, error: error.message } : { success: true, data };
    }
  } catch (err) {
    result = { success: false, error: String(err) };
  }

  // Log to audit_logs for unified telemetry
  const durationMs = Date.now() - startTime;
  try {
    await supabase.from("audit_logs").insert({
      action: `tool.${toolName}`,
      severity: result.success ? "info" : "error",
      store_id: storeId || args.store_id || null,
      resource_type: "mcp_tool",
      resource_id: toolName,
      request_id: traceId || null,
      details: {
        source: "edge_function",
        args: args,
        result: result.success ? result.data : null
      },
      error_message: result.error || null,
      duration_ms: durationMs
    });
  } catch {
    // Don't fail tool call if logging fails
  }

  return result;
}

// Execute direct table queries for tools that don't have RPC functions
async function executeDirectQuery(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>
): Promise<{ success: boolean; data?: unknown; error?: string }> {
  try {
    switch (toolName) {
      case "orders_list": {
        let query = supabase
          .from("orders")
          .select(`
            id, order_number, status, total, created_at,
            customer:customers(id, full_name, email),
            location:locations(id, name)
          `)
          .eq("store_id", args.store_id as string)
          .order("created_at", { ascending: false })
          .limit((args.limit as number) || 20);

        if (args.status) query = query.eq("status", args.status);
        if (args.customer_id) query = query.eq("customer_id", args.customer_id);
        if (args.location_id) query = query.eq("location_id", args.location_id);
        if (args.offset) query = query.range(args.offset as number, (args.offset as number) + ((args.limit as number) || 20) - 1);

        const { data, error } = await query;
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "order_details": {
        const { data, error } = await supabase
          .from("orders")
          .select(`
            *,
            customer:customers(*),
            location:locations(id, name),
            items:order_items(*, product:products(id, name, sku))
          `)
          .eq("id", args.order_id as string)
          .single();

        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "customers_search": {
        const query = args.query as string;
        const { data, error } = await supabase
          .from("customers")
          .select("id, full_name, email, phone, loyalty_points, created_at")
          .eq("store_id", args.store_id as string)
          .or(`full_name.ilike.%${query}%,email.ilike.%${query}%,phone.ilike.%${query}%`)
          .limit((args.limit as number) || 20);

        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "customer_details": {
        const { data, error } = await supabase
          .from("customers")
          .select(`
            *,
            orders:orders(id, order_number, total, status, created_at)
          `)
          .eq("id", args.customer_id as string)
          .single();

        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "products_search": {
        let query = supabase
          .from("products")
          .select("id, name, sku, price, category_id, status")
          .eq("store_id", args.store_id as string)
          .limit((args.limit as number) || 20);

        if (args.query) {
          const q = args.query as string;
          query = query.or(`name.ilike.%${q}%,sku.ilike.%${q}%`);
        }
        if (args.category_id) query = query.eq("category_id", args.category_id);

        const { data, error } = await query;
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "product_details": {
        const { data, error } = await supabase
          .from("products")
          .select(`
            *,
            variants:product_variants(*),
            inventory:inventory(location_id, quantity)
          `)
          .eq("id", args.product_id as string)
          .single();

        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "locations_list": {
        const { data, error } = await supabase
          .from("locations")
          .select("id, name, address, is_active")
          .eq("store_id", args.store_id as string)
          .eq("is_active", true);

        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      default:
        return { success: false, error: `No direct query handler for: ${toolName}` };
    }
  } catch (err) {
    return { success: false, error: String(err) };
  }
}

// Load agent configuration
async function loadAgentConfig(
  supabase: SupabaseClient,
  agentId: string
): Promise<AgentConfig | null> {
  const { data, error } = await supabase
    .from("ai_agent_config")
    .select("*")
    .eq("id", agentId)
    .single();

  if (error || !data) return null;
  return data as AgentConfig;
}

// Get tools for agent based on capabilities
function getToolsForAgent(agent: AgentConfig): ToolDefinition[] {
  // Filter tools based on agent capabilities
  const readOnlyTools = ["inventory_summary", "orders_list", "order_details",
    "customers_search", "customer_details", "products_search", "product_details",
    "analytics_sales", "analytics_inventory", "locations_list"];

  const writeTools = ["inventory_adjust", "inventory_transfer", "customer_loyalty_adjust"];

  let allowedTools = [...readOnlyTools];

  if (agent.can_modify) {
    allowedTools = [...allowedTools, ...writeTools];
  }

  // If agent has specific enabled_tools, use those
  if (agent.enabled_tools && agent.enabled_tools.length > 0) {
    allowedTools = allowedTools.filter(t => agent.enabled_tools.includes(t));
  }

  return TOOL_DEFINITIONS.filter(t => allowedTools.includes(t.name));
}

// Log execution trace
async function logExecution(
  supabase: SupabaseClient,
  agentId: string,
  storeId: string,
  userMessage: string,
  finalResponse: string,
  success: boolean,
  turnCount: number,
  toolCalls: number,
  inputTokens: number,
  outputTokens: number,
  error?: string
): Promise<void> {
  try {
    await supabase.from("agent_execution_traces").insert({
      agent_id: agentId,
      store_id: storeId,
      user_message: userMessage,
      final_response: finalResponse,
      success,
      turn_count: turnCount,
      tool_calls: toolCalls,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      error,
      duration_ms: 0  // Could track actual duration
    });
  } catch {
    // Don't fail the request if logging fails
    console.error("Failed to log execution trace");
  }
}

// Main handler
serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const { agentId, storeId, message, conversationHistory } = await req.json();

    if (!agentId || !message) {
      return new Response(
        JSON.stringify({ error: "agentId and message are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client with service role for tool execution
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Load agent config
    const agent = await loadAgentConfig(supabase, agentId);
    if (!agent) {
      return new Response(
        JSON.stringify({ error: "Agent not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get tools for this agent
    const tools = getToolsForAgent(agent);

    // Generate trace ID for this conversation - links all tool calls
    const traceId = crypto.randomUUID();

    // Build system prompt with store context
    let systemPrompt = agent.system_prompt || "You are a helpful assistant.";
    if (storeId) {
      systemPrompt += `\n\nYou are operating for store_id: ${storeId}. Always include this in tool calls that require it.`;
    }
    if (!agent.can_modify) {
      systemPrompt += "\n\nIMPORTANT: You have read-only access. Do not attempt to modify any data.";
    }

    // Build messages array
    const messages: Anthropic.MessageParam[] = [
      ...(conversationHistory || []),
      { role: "user", content: message }
    ];

    // Set up SSE stream
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: StreamEvent) => {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
        };

        let turnCount = 0;
        let toolCallCount = 0;
        let totalInputTokens = 0;
        let totalOutputTokens = 0;
        let finalResponse = "";
        let continueLoop = true;

        try {
          while (continueLoop && turnCount < (agent.max_tool_calls || 10)) {
            turnCount++;

            // Call Claude with streaming
            const response = await anthropic.messages.create({
              model: agent.model || "claude-sonnet-4-20250514",
              max_tokens: agent.max_tokens || 4096,
              system: systemPrompt,
              tools: tools.map(t => ({
                name: t.name,
                description: t.description,
                input_schema: t.input_schema
              })),
              messages,
              stream: true
            });

            let currentText = "";
            const toolUseBlocks: Array<{ id: string; name: string; input: Record<string, unknown> }> = [];
            let currentToolUse: { id: string; name: string; input: string } | null = null;

            // Process stream
            for await (const event of response) {
              if (event.type === "content_block_start") {
                if (event.content_block.type === "tool_use") {
                  currentToolUse = {
                    id: event.content_block.id,
                    name: event.content_block.name,
                    input: ""
                  };
                  send({ type: "tool_start", name: event.content_block.name });
                }
              } else if (event.type === "content_block_delta") {
                if (event.delta.type === "text_delta") {
                  currentText += event.delta.text;
                  send({ type: "text", text: event.delta.text });
                } else if (event.delta.type === "input_json_delta" && currentToolUse) {
                  currentToolUse.input += event.delta.partial_json;
                }
              } else if (event.type === "content_block_stop") {
                if (currentToolUse) {
                  try {
                    const input = JSON.parse(currentToolUse.input);
                    toolUseBlocks.push({
                      id: currentToolUse.id,
                      name: currentToolUse.name,
                      input
                    });
                  } catch {
                    // Invalid JSON, skip this tool use
                  }
                  currentToolUse = null;
                }
              } else if (event.type === "message_delta") {
                if (event.usage) {
                  totalOutputTokens += event.usage.output_tokens;
                }
              } else if (event.type === "message_start") {
                if (event.message.usage) {
                  totalInputTokens += event.message.usage.input_tokens;
                }
              }
            }

            // If no tool calls, we're done
            if (toolUseBlocks.length === 0) {
              finalResponse = currentText;
              continueLoop = false;
              break;
            }

            // Execute tool calls
            const toolResults: Anthropic.MessageParam["content"] = [];

            for (const toolUse of toolUseBlocks) {
              toolCallCount++;

              // Inject store_id if not provided
              const args = { ...toolUse.input };
              if (!args.store_id && storeId) {
                args.store_id = storeId;
              }

              const result = await executeTool(supabase, toolUse.name, args, traceId, storeId);

              send({
                type: "tool_result",
                name: toolUse.name,
                success: result.success,
                result: result.success ? result.data : result.error
              });

              toolResults.push({
                type: "tool_result",
                tool_use_id: toolUse.id,
                content: JSON.stringify(result.success ? result.data : { error: result.error })
              });
            }

            // Add assistant message with tool use and tool results
            messages.push({
              role: "assistant",
              content: [
                ...(currentText ? [{ type: "text" as const, text: currentText }] : []),
                ...toolUseBlocks.map(t => ({
                  type: "tool_use" as const,
                  id: t.id,
                  name: t.name,
                  input: t.input
                }))
              ]
            });

            messages.push({
              role: "user",
              content: toolResults
            });
          }

          // Send final usage
          send({
            type: "usage",
            usage: {
              input_tokens: totalInputTokens,
              output_tokens: totalOutputTokens
            }
          });

          send({ type: "done" });

          // Log execution
          await logExecution(
            supabase,
            agentId,
            storeId,
            message,
            finalResponse,
            true,
            turnCount,
            toolCallCount,
            totalInputTokens,
            totalOutputTokens
          );

        } catch (err) {
          send({ type: "error", error: String(err) });

          // Log failed execution
          await logExecution(
            supabase,
            agentId,
            storeId,
            message,
            "",
            false,
            turnCount,
            toolCallCount,
            totalInputTokens,
            totalOutputTokens,
            String(err)
          );
        }

        controller.close();
      }
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "*",
      },
    });

  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
