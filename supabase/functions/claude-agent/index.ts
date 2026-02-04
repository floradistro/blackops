// claude-agent/index.ts
// Full Claude Agent SDK integration with business tools + coding capabilities
// Combines retail management with code/file operations

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@0.30.1";

// ============================================================================
// TYPES
// ============================================================================

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
  type: "text" | "tool_start" | "tool_result" | "error" | "done" | "usage" | "thinking";
  text?: string;
  name?: string;
  args?: Record<string, unknown>;
  result?: unknown;
  success?: boolean;
  error?: string;
  usage?: { input_tokens: number; output_tokens: number };
}

// ============================================================================
// ANTHROPIC CLIENT
// ============================================================================

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY")!,
});

// ============================================================================
// BUSINESS TOOLS - Inventory, Orders, Customers, Analytics
// ============================================================================

const BUSINESS_TOOLS: ToolDefinition[] = [
  // Inventory
  {
    name: "inventory_summary",
    description: "Get inventory summary grouped by category, location, or product. Shows quantities and counts.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string", description: "Store UUID" },
        group_by: { type: "string", enum: ["category", "location", "product"] },
        location_id: { type: "string", description: "Filter by location UUID" },
        include_zero_stock: { type: "boolean" }
      },
      required: ["store_id"]
    }
  },
  {
    name: "inventory_adjust",
    description: "Adjust inventory quantity for a product at a location.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string" },
        product_id: { type: "string" },
        location_id: { type: "string" },
        quantity_change: { type: "integer", description: "Positive to add, negative to remove" },
        reason: { type: "string" }
      },
      required: ["store_id", "product_id", "location_id", "quantity_change", "reason"]
    }
  },

  // Orders
  {
    name: "orders_list",
    description: "List orders with filters. Returns recent orders by default.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string" },
        status: { type: "string", enum: ["pending", "processing", "shipped", "delivered", "cancelled"] },
        customer_id: { type: "string" },
        location_id: { type: "string" },
        limit: { type: "integer" },
        offset: { type: "integer" }
      },
      required: ["store_id"]
    }
  },
  {
    name: "order_details",
    description: "Get full order details including items and customer.",
    input_schema: {
      type: "object",
      properties: { order_id: { type: "string" } },
      required: ["order_id"]
    }
  },
  {
    name: "order_update_status",
    description: "Update order status.",
    input_schema: {
      type: "object",
      properties: {
        order_id: { type: "string" },
        status: { type: "string", enum: ["pending", "processing", "shipped", "delivered", "cancelled"] },
        note: { type: "string" }
      },
      required: ["order_id", "status"]
    }
  },

  // Customers
  {
    name: "customers_search",
    description: "Search customers by name, email, or phone.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string" },
        query: { type: "string" },
        limit: { type: "integer" }
      },
      required: ["store_id", "query"]
    }
  },
  {
    name: "customer_details",
    description: "Get customer profile with order history and loyalty points.",
    input_schema: {
      type: "object",
      properties: { customer_id: { type: "string" } },
      required: ["customer_id"]
    }
  },
  {
    name: "customer_loyalty_adjust",
    description: "Add or subtract loyalty points.",
    input_schema: {
      type: "object",
      properties: {
        customer_id: { type: "string" },
        points: { type: "integer" },
        reason: { type: "string" }
      },
      required: ["customer_id", "points", "reason"]
    }
  },

  // Products
  {
    name: "products_search",
    description: "Search products by name, SKU, or category.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string" },
        query: { type: "string" },
        category_id: { type: "string" },
        in_stock_only: { type: "boolean" },
        limit: { type: "integer" }
      },
      required: ["store_id"]
    }
  },
  {
    name: "product_details",
    description: "Get product details with variants, pricing, and inventory.",
    input_schema: {
      type: "object",
      properties: { product_id: { type: "string" } },
      required: ["product_id"]
    }
  },

  // Analytics
  {
    name: "analytics_sales",
    description: "Get sales analytics for a time period.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string" },
        start_date: { type: "string", description: "YYYY-MM-DD" },
        end_date: { type: "string", description: "YYYY-MM-DD" },
        group_by: { type: "string", enum: ["day", "week", "month"] },
        location_id: { type: "string" }
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
        store_id: { type: "string" },
        location_id: { type: "string" }
      },
      required: ["store_id"]
    }
  },

  // Locations
  {
    name: "locations_list",
    description: "List all locations for a store.",
    input_schema: {
      type: "object",
      properties: { store_id: { type: "string" } },
      required: ["store_id"]
    }
  }
];

// ============================================================================
// CODING TOOLS - File operations, code generation, shell (sandboxed)
// ============================================================================

const CODING_TOOLS: ToolDefinition[] = [
  {
    name: "code_generate",
    description: "Generate code snippet for a specific task. Returns code without executing.",
    input_schema: {
      type: "object",
      properties: {
        language: { type: "string", enum: ["swift", "typescript", "python", "sql", "javascript", "html", "css"] },
        task: { type: "string", description: "What the code should do" },
        context: { type: "string", description: "Additional context like existing code patterns" }
      },
      required: ["language", "task"]
    }
  },
  {
    name: "code_review",
    description: "Review code for bugs, security issues, and improvements.",
    input_schema: {
      type: "object",
      properties: {
        code: { type: "string", description: "The code to review" },
        language: { type: "string" },
        focus: { type: "string", enum: ["bugs", "security", "performance", "style", "all"] }
      },
      required: ["code"]
    }
  },
  {
    name: "code_explain",
    description: "Explain what code does in plain language.",
    input_schema: {
      type: "object",
      properties: {
        code: { type: "string" },
        detail_level: { type: "string", enum: ["brief", "detailed", "line_by_line"] }
      },
      required: ["code"]
    }
  },
  {
    name: "sql_generate",
    description: "Generate SQL query for Supabase/PostgreSQL.",
    input_schema: {
      type: "object",
      properties: {
        task: { type: "string", description: "What data to query or modify" },
        tables: { type: "array", items: { type: "string" }, description: "Available tables" },
        store_id: { type: "string", description: "Store context for RLS" }
      },
      required: ["task"]
    }
  },
  {
    name: "sql_execute",
    description: "Execute a read-only SQL query against the database.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string", description: "SELECT query only" },
        params: { type: "object", description: "Query parameters" }
      },
      required: ["query"]
    }
  },
  {
    name: "creation_generate",
    description: "Generate a React component for the creations system.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Component name" },
        description: { type: "string", description: "What the component should do" },
        style: { type: "string", enum: ["minimal", "modern", "playful", "professional"] },
        includes_data: { type: "boolean", description: "Whether to include live data hooks" }
      },
      required: ["name", "description"]
    }
  },
  {
    name: "creation_save",
    description: "Save a generated React component to the creations table.",
    input_schema: {
      type: "object",
      properties: {
        store_id: { type: "string" },
        name: { type: "string" },
        description: { type: "string" },
        react_code: { type: "string" },
        type: { type: "string", enum: ["menu", "display", "app", "widget", "component"] }
      },
      required: ["store_id", "name", "react_code", "type"]
    }
  }
];

// ============================================================================
// TOOL EXECUTION
// ============================================================================

async function executeTool(
  supabase: SupabaseClient,
  toolName: string,
  args: Record<string, unknown>,
  storeId?: string
): Promise<{ success: boolean; data?: unknown; error?: string }> {
  try {
    // Inject store_id if not provided
    if (!args.store_id && storeId) {
      args.store_id = storeId;
    }

    // ========== BUSINESS TOOLS ==========
    switch (toolName) {
      case "inventory_summary": {
        const { data, error } = await supabase.rpc("inventory_summary_by_location", {
          p_store_id: args.store_id,
          p_location_id: args.location_id || null
        });
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "inventory_adjust": {
        const { data, error } = await supabase.rpc("adjust_inventory_ai", args);
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "orders_list": {
        let query = supabase
          .from("orders")
          .select(`id, order_number, status, total, created_at, customer:customers(id, full_name, email)`)
          .eq("store_id", args.store_id as string)
          .order("created_at", { ascending: false })
          .limit((args.limit as number) || 20);

        if (args.status) query = query.eq("status", args.status);
        if (args.customer_id) query = query.eq("customer_id", args.customer_id);
        if (args.location_id) query = query.eq("location_id", args.location_id);

        const { data, error } = await query;
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "order_details": {
        const { data, error } = await supabase
          .from("orders")
          .select(`*, customer:customers(*), items:order_items(*, product:products(id, name, sku))`)
          .eq("id", args.order_id as string)
          .single();
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "order_update_status": {
        const { error } = await supabase
          .from("orders")
          .update({ status: args.status, updated_at: new Date().toISOString() })
          .eq("id", args.order_id as string);
        if (error) return { success: false, error: error.message };
        return { success: true, data: { updated: true, status: args.status } };
      }

      case "customers_search": {
        const q = args.query as string;
        const { data, error } = await supabase
          .from("customers")
          .select("id, full_name, email, phone, loyalty_points")
          .eq("store_id", args.store_id as string)
          .or(`full_name.ilike.%${q}%,email.ilike.%${q}%,phone.ilike.%${q}%`)
          .limit((args.limit as number) || 20);
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "customer_details": {
        const { data, error } = await supabase
          .from("customers")
          .select(`*, orders:orders(id, order_number, total, status, created_at)`)
          .eq("id", args.customer_id as string)
          .single();
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "customer_loyalty_adjust": {
        const { data, error } = await supabase.rpc("adjust_customer_loyalty_points", {
          p_customer_id: args.customer_id,
          p_points: args.points,
          p_reason: args.reason
        });
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
          .select(`*, inventory:inventory(location_id, quantity)`)
          .eq("id", args.product_id as string)
          .single();
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "analytics_sales": {
        const { data, error } = await supabase.rpc("analytics_query", {
          p_store_id: args.store_id,
          p_start_date: args.start_date,
          p_end_date: args.end_date,
          p_group_by: args.group_by || "day"
        });
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "analytics_inventory": {
        const { data, error } = await supabase.rpc("get_inventory_velocity", {
          p_store_id: args.store_id,
          p_location_id: args.location_id || null
        });
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

      // ========== CODING TOOLS ==========
      case "code_generate":
      case "code_review":
      case "code_explain":
      case "sql_generate":
        // These are handled by Claude itself - just return acknowledgment
        return { success: true, data: { handled_by_model: true, tool: toolName, args } };

      case "sql_execute": {
        const query = (args.query as string).trim().toLowerCase();
        // Only allow SELECT queries for safety
        if (!query.startsWith("select")) {
          return { success: false, error: "Only SELECT queries are allowed" };
        }
        const { data, error } = await supabase.rpc("execute_readonly_query", {
          query_text: args.query
        });
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      case "creation_save": {
        const { data, error } = await supabase
          .from("creations")
          .insert({
            store_id: args.store_id,
            name: args.name,
            description: args.description,
            react_code: args.react_code,
            type: args.type,
            status: "draft"
          })
          .select()
          .single();
        if (error) return { success: false, error: error.message };
        return { success: true, data };
      }

      default:
        return { success: false, error: `Unknown tool: ${toolName}` };
    }
  } catch (err) {
    return { success: false, error: String(err) };
  }
}

// ============================================================================
// AGENT CONFIGURATION
// ============================================================================

async function loadAgentConfig(supabase: SupabaseClient, agentId: string): Promise<AgentConfig | null> {
  const { data, error } = await supabase
    .from("ai_agent_config")
    .select("*")
    .eq("id", agentId)
    .single();

  if (error || !data) return null;
  return data as AgentConfig;
}

function getToolsForAgent(agent: AgentConfig, includeCodeTools: boolean): ToolDefinition[] {
  let tools = [...BUSINESS_TOOLS];

  if (includeCodeTools) {
    tools = [...tools, ...CODING_TOOLS];
  }

  // Filter by agent capabilities
  if (!agent.can_modify) {
    const writeTools = ["inventory_adjust", "order_update_status", "customer_loyalty_adjust", "creation_save"];
    tools = tools.filter(t => !writeTools.includes(t.name));
  }

  // Filter by enabled_tools if specified
  if (agent.enabled_tools && agent.enabled_tools.length > 0) {
    tools = tools.filter(t => agent.enabled_tools.includes(t.name));
  }

  return tools;
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

serve(async (req: Request) => {
  // CORS
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
    const { agentId, storeId, message, conversationHistory, includeCodeTools = true } = await req.json();

    if (!agentId || !message) {
      return new Response(
        JSON.stringify({ error: "agentId and message are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const agent = await loadAgentConfig(supabase, agentId);
    if (!agent) {
      return new Response(
        JSON.stringify({ error: "Agent not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const tools = getToolsForAgent(agent, includeCodeTools);

    // Build system prompt
    let systemPrompt = agent.system_prompt || "You are a helpful assistant.";
    systemPrompt += `\n\nStore context: store_id=${storeId}. Include this in tool calls that require it.`;

    if (includeCodeTools) {
      systemPrompt += `\n\nYou also have coding capabilities:
- Generate code in Swift, TypeScript, Python, SQL, and more
- Review code for bugs and security issues
- Explain code in plain language
- Create React components for the creations system
- Execute read-only SQL queries

When generating code, be concise and production-ready.`;
    }

    if (!agent.can_modify) {
      systemPrompt += "\n\nIMPORTANT: You have read-only access. Do not attempt to modify data.";
    }

    const messages: Anthropic.MessageParam[] = [
      ...(conversationHistory || []),
      { role: "user", content: message }
    ];

    // SSE Stream
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
          while (continueLoop && turnCount < (agent.max_tool_calls || 15)) {
            turnCount++;

            const response = await anthropic.messages.create({
              model: agent.model || "claude-sonnet-4-20250514",
              max_tokens: agent.max_tokens || 8192,
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
                    // Invalid JSON
                  }
                  currentToolUse = null;
                }
              } else if (event.type === "message_delta" && event.usage) {
                totalOutputTokens += event.usage.output_tokens;
              } else if (event.type === "message_start" && event.message.usage) {
                totalInputTokens += event.message.usage.input_tokens;
              }
            }

            if (toolUseBlocks.length === 0) {
              finalResponse = currentText;
              continueLoop = false;
              break;
            }

            // Execute tools
            const toolResults: Anthropic.MessageParam["content"] = [];

            for (const toolUse of toolUseBlocks) {
              toolCallCount++;
              const result = await executeTool(supabase, toolUse.name, toolUse.input, storeId);

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

            messages.push({ role: "user", content: toolResults });
          }

          send({
            type: "usage",
            usage: { input_tokens: totalInputTokens, output_tokens: totalOutputTokens }
          });

          send({ type: "done" });

        } catch (err) {
          send({ type: "error", error: String(err) });
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
