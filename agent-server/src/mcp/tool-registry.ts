/**
 * Dynamic Tool Registry
 *
 * Loads tools from Supabase ai_tool_registry and creates MCP tools
 * that execute LOCALLY via direct Supabase queries.
 *
 * Following Anthropic SDK best practices - tools run in-process.
 */

import { tool, createSdkMcpServer } from "@anthropic-ai/claude-code";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { z, ZodTypeAny } from "zod";
import { McpToolResult } from "../types.js";
import { executeTool, getImplementedTools } from "../tools/executor.js";
import { loadUserTools, executeUserTool, userToolToRegistryFormat, UserTool } from "../tools/user-tools.js";

// ============================================================================
// TYPES
// ============================================================================

export interface ToolRegistryEntry {
  id: string;
  name: string;
  category: string;
  description: string | null;
  definition: {
    name: string;
    description: string;
    input_schema: {
      type: "object";
      properties: Record<string, any>;
      required?: string[];
    };
  };
  rpc_function: string | null;
  edge_function: string | null;
  requires_store_id: boolean;
  requires_user_id: boolean;
  is_read_only: boolean;
  is_active: boolean;
  tool_mode: string;
}

export interface ToolMetadata {
  id: string;
  name: string;
  description: string;
  category: string;
}

// Matches what we send to Swift client
export interface ClientToolMetadata {
  id: string;
  name: string;
  description: string;
  category: string;
}

// ============================================================================
// TOOL REGISTRY LOADER
// ============================================================================

let cachedTools: ToolRegistryEntry[] | null = null;
let cacheTimestamp = 0;
const CACHE_TTL = 60000; // 1 minute cache

export function invalidateToolCache() {
  cachedTools = null;
  cacheTimestamp = 0;
}

export async function loadToolRegistry(
  supabaseUrl: string,
  supabaseKey: string,
  forceRefresh = false
): Promise<ToolRegistryEntry[]> {
  // Return cached if fresh (unless force refresh)
  if (!forceRefresh && cachedTools && Date.now() - cacheTimestamp < CACHE_TTL) {
    return cachedTools;
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data, error } = await supabase
    .from("ai_tool_registry")
    .select("*")
    .eq("is_active", true)
    .order("category", { ascending: true });

  if (error) {
    console.error("[ToolRegistry] Failed to load tools:", error.message);
    return cachedTools || [];
  }

  cachedTools = data as ToolRegistryEntry[];
  cacheTimestamp = Date.now();

  const implementedTools = getImplementedTools();
  const implementedCount = cachedTools.filter(t => implementedTools.includes(t.name)).length;

  console.log(`[ToolRegistry] Loaded ${cachedTools.length} tools from registry (${implementedCount} implemented locally)`);
  return cachedTools;
}

export function getToolMetadata(tools: ToolRegistryEntry[]): ClientToolMetadata[] {
  return tools.map(t => ({
    id: t.name,
    name: t.definition?.name || t.name,
    description: t.description || t.definition?.description || "",
    category: t.category
  }));
}

// ============================================================================
// USER TOOLS LOADER
// ============================================================================

/**
 * Load user-created custom tools for a specific store and merge with system tools
 */
export async function loadToolsWithUserTools(
  supabaseUrl: string,
  supabaseKey: string,
  storeId: string,
  forceRefresh = false
): Promise<ToolRegistryEntry[]> {
  const supabase = createClient(supabaseUrl, supabaseKey);

  // Load system tools
  const systemTools = await loadToolRegistry(supabaseUrl, supabaseKey, forceRefresh);

  // Load user tools for this store
  const userTools = await loadUserTools(supabase, storeId);

  // Convert user tools to registry format and merge
  const userToolEntries = userTools.map(ut => userToolToRegistryFormat(ut));

  console.log(`[ToolRegistry] Merged ${systemTools.length} system + ${userToolEntries.length} user tools for store ${storeId.slice(0, 8)}`);

  return [...systemTools, ...userToolEntries];
}

// ============================================================================
// DYNAMIC MCP SERVER FACTORY
// ============================================================================

/**
 * Creates an MCP server with all tools loaded from the registry.
 * Tools execute LOCALLY via direct Supabase queries (Anthropic SDK best practice).
 * User tools are executed via the user-tools executor.
 */
export function createDynamicToolsServer(
  supabaseUrl: string,
  supabaseKey: string,
  tools: ToolRegistryEntry[],
  storeId?: string,
  userId?: string,
  sessionId?: string,  // Trace ID - links all tool calls in this conversation
  agentId?: string,    // AI Agent UUID for telemetry
  agentName?: string   // AI Agent name for telemetry
) {
  const supabase = createClient(supabaseUrl, supabaseKey);
  const traceId = sessionId || crypto.randomUUID();  // One trace per agent session

  // Convert registry entries to MCP tools
  const mcpTools = tools.map(entry => {
    // Build Zod schema from JSON schema
    const schema = buildZodSchema(entry.definition?.input_schema || { type: "object", properties: {} });

    return tool(
      entry.name,
      entry.description || entry.definition?.description || `Execute ${entry.name}`,
      schema,
      async (args: Record<string, unknown>): Promise<McpToolResult> => {
        // Check if this is a user tool (has _userTool property)
        const userTool = (entry as any)._userTool as UserTool | undefined;

        if (userTool && storeId) {
          // Execute via user tool executor
          const result = await executeUserTool(supabase, userTool, args, storeId);

          if (result.pending_approval) {
            return {
              content: [{
                type: "text",
                text: JSON.stringify({
                  pending_approval: true,
                  execution_id: result.execution_id,
                  message: result.error
                })
              }]
            };
          }

          if (!result.success) {
            return errorResult(result.error || "User tool execution failed");
          }

          return successResult(result.data);
        }

        // Execute system tool via standard handler
        return executeToolLocally(supabase, entry, args, storeId, userId, traceId, agentId, agentName);
      }
    );
  });

  return createSdkMcpServer({
    name: "swagmanager",
    version: "2.0.0",
    tools: mcpTools
  });
}

// ============================================================================
// LOCAL TOOL EXECUTION (Anthropic SDK best practice)
// ============================================================================

async function executeToolLocally(
  supabase: SupabaseClient,
  toolEntry: ToolRegistryEntry,
  args: Record<string, unknown>,
  storeId?: string,
  userId?: string,
  traceId?: string,
  agentId?: string,
  agentName?: string
): Promise<McpToolResult> {
  try {
    // Inject store_id and user_id if required
    if (toolEntry.requires_store_id && storeId && !args.store_id) {
      args.store_id = storeId;
    }
    if (toolEntry.requires_user_id && userId && !args.user_id) {
      args.user_id = userId;
    }

    // Execute tool via local handler with telemetry context
    const result = await executeTool(supabase, toolEntry.name, args, storeId, {
      source: "swag_manager",
      userId: userId,
      requestId: traceId,  // Links all tool calls in this conversation
      agentId: agentId,
      agentName: agentName
    });

    if (!result.success) {
      console.error(`[Tool Error] ${toolEntry.name}:`, result.error);
      return errorResult(result.error || "Tool execution failed");
    }

    return successResult(result.data);
  } catch (err) {
    console.error(`[Tool Exception] ${toolEntry.name}:`, err);
    return errorResult(`Tool execution error: ${err}`);
  }
}

// ============================================================================
// SCHEMA CONVERSION
// ============================================================================

/**
 * Convert JSON Schema to Zod schema for tool validation
 */
function buildZodSchema(jsonSchema: any): Record<string, ZodTypeAny> {
  const properties = jsonSchema?.properties || {};
  const required = new Set(jsonSchema?.required || []);

  const zodSchema: Record<string, ZodTypeAny> = {};

  for (const [key, prop] of Object.entries(properties) as [string, any][]) {
    let zodType: ZodTypeAny;

    switch (prop.type) {
      case "string":
        if (prop.enum) {
          zodType = z.enum(prop.enum as [string, ...string[]]);
        } else {
          zodType = z.string();
        }
        break;
      case "integer":
      case "number":
        zodType = z.number();
        break;
      case "boolean":
        zodType = z.boolean();
        break;
      case "array":
        zodType = z.array(z.any());
        break;
      case "object":
        zodType = z.record(z.any());
        break;
      default:
        zodType = z.any();
    }

    // Add description
    if (prop.description) {
      zodType = zodType.describe(prop.description);
    }

    // Make optional if not required
    if (!required.has(key)) {
      zodType = zodType.optional();
    }

    zodSchema[key] = zodType;
  }

  return zodSchema;
}

// ============================================================================
// HELPERS
// ============================================================================

function successResult(data: unknown): McpToolResult {
  return {
    content: [{
      type: "text",
      text: typeof data === "string" ? data : JSON.stringify(data, null, 2)
    }]
  };
}

function errorResult(message: string): McpToolResult {
  return {
    content: [{
      type: "text",
      text: JSON.stringify({ error: message })
    }],
    isError: true
  };
}
