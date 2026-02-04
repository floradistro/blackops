/**
 * Dynamic Tool Registry
 *
 * Loads tools from Supabase ai_tool_registry and creates MCP tools
 * that execute LOCALLY via direct Supabase queries.
 *
 * Following Anthropic SDK best practices - tools run in-process.
 */
import { tool, createSdkMcpServer } from "@anthropic-ai/claude-code";
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { executeTool, getImplementedTools } from "../tools/executor.js";
import { loadUserTools, executeUserTool, userToolToRegistryFormat } from "../tools/user-tools.js";
// ============================================================================
// TOOL REGISTRY LOADER
// ============================================================================
let cachedTools = null;
let cacheTimestamp = 0;
const CACHE_TTL = 60000; // 1 minute cache
export function invalidateToolCache() {
    cachedTools = null;
    cacheTimestamp = 0;
}
export async function loadToolRegistry(supabaseUrl, supabaseKey, forceRefresh = false) {
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
    cachedTools = data;
    cacheTimestamp = Date.now();
    const implementedTools = getImplementedTools();
    const implementedCount = cachedTools.filter(t => implementedTools.includes(t.name)).length;
    console.log(`[ToolRegistry] Loaded ${cachedTools.length} tools from registry (${implementedCount} implemented locally)`);
    return cachedTools;
}
export function getToolMetadata(tools) {
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
export async function loadToolsWithUserTools(supabaseUrl, supabaseKey, storeId, forceRefresh = false) {
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
export function createDynamicToolsServer(supabaseUrl, supabaseKey, tools, storeId, userId, sessionId, // Trace ID - links all tool calls in this conversation
agentId, // AI Agent UUID for telemetry
agentName // AI Agent name for telemetry
) {
    const supabase = createClient(supabaseUrl, supabaseKey);
    const traceId = sessionId || crypto.randomUUID(); // One trace per agent session
    // Convert registry entries to MCP tools
    const mcpTools = tools.map(entry => {
        // Build Zod schema from JSON schema
        const schema = buildZodSchema(entry.definition?.input_schema || { type: "object", properties: {} });
        return tool(entry.name, entry.description || entry.definition?.description || `Execute ${entry.name}`, schema, async (args) => {
            // Check if this is a user tool (has _userTool property)
            const userTool = entry._userTool;
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
        });
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
async function executeToolLocally(supabase, toolEntry, args, storeId, userId, traceId, agentId, agentName) {
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
            requestId: traceId, // Links all tool calls in this conversation
            agentId: agentId,
            agentName: agentName
        });
        if (!result.success) {
            console.error(`[Tool Error] ${toolEntry.name}:`, result.error);
            return errorResult(result.error || "Tool execution failed");
        }
        return successResult(result.data);
    }
    catch (err) {
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
function buildZodSchema(jsonSchema) {
    const properties = jsonSchema?.properties || {};
    const required = new Set(jsonSchema?.required || []);
    const zodSchema = {};
    for (const [key, prop] of Object.entries(properties)) {
        let zodType;
        switch (prop.type) {
            case "string":
                if (prop.enum) {
                    zodType = z.enum(prop.enum);
                }
                else {
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
function successResult(data) {
    return {
        content: [{
                type: "text",
                text: typeof data === "string" ? data : JSON.stringify(data, null, 2)
            }]
    };
}
function errorResult(message) {
    return {
        content: [{
                type: "text",
                text: JSON.stringify({ error: message })
            }],
        isError: true
    };
}
