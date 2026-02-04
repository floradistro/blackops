#!/usr/bin/env npx tsx
/**
 * SwagManager MCP Server for Claude Code CLI
 * Uses the official MCP SDK for proper protocol handling
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { createClient } from "@supabase/supabase-js";
import { executeTool, getImplementedTools } from "./tools/executor.js";
// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const STORE_ID = process.env.STORE_ID || "";
if (!SUPABASE_KEY) {
    console.error("Error: SUPABASE_SERVICE_ROLE_KEY environment variable required");
    process.exit(1);
}
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
// Session ID for tracing - one per MCP server session (i.e., one Claude Code conversation)
const SESSION_ID = crypto.randomUUID();
let toolDefinitions = [];
async function loadToolDefinitions() {
    try {
        const { data, error } = await supabase
            .from("ai_tool_registry")
            .select("name, description, definition")
            .eq("is_active", true);
        if (error) {
            console.error("Failed to load tools from registry:", error.message);
            return [];
        }
        return (data || []).map(t => ({
            name: t.name,
            description: t.description || t.definition?.description || `Execute ${t.name}`,
            inputSchema: t.definition?.input_schema || { type: "object", properties: {} }
        }));
    }
    catch (err) {
        console.error("Error loading tool definitions:", err);
        return [];
    }
}
// Create MCP server
const server = new Server({
    name: "swagmanager",
    version: "2.0.0",
}, {
    capabilities: {
        tools: {},
    },
});
// Handle tools/list
server.setRequestHandler(ListToolsRequestSchema, async () => {
    // Load tools if not cached
    if (toolDefinitions.length === 0) {
        toolDefinitions = await loadToolDefinitions();
        console.error(`[MCP] Loaded ${toolDefinitions.length} tools`);
    }
    return {
        tools: toolDefinitions.map(t => ({
            name: t.name,
            description: t.description,
            inputSchema: t.inputSchema,
        })),
    };
});
// Handle tools/call
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const toolName = request.params.name;
    const toolArgs = (request.params.arguments || {});
    console.error(`[MCP] Executing tool: ${toolName}`);
    // Check if tool is implemented
    const implementedTools = getImplementedTools();
    if (!implementedTools.includes(toolName)) {
        return {
            content: [
                {
                    type: "text",
                    text: JSON.stringify({ error: `Tool "${toolName}" not implemented` }),
                },
            ],
            isError: true,
        };
    }
    // Execute tool with telemetry context
    // SESSION_ID links all tool calls in this Claude Code conversation
    const result = await executeTool(supabase, toolName, toolArgs, STORE_ID || undefined, {
        source: "claude_code",
        requestId: SESSION_ID
    });
    if (result.success) {
        return {
            content: [
                {
                    type: "text",
                    text: typeof result.data === "string"
                        ? result.data
                        : JSON.stringify(result.data, null, 2),
                },
            ],
        };
    }
    else {
        return {
            content: [
                {
                    type: "text",
                    text: JSON.stringify({ error: result.error }),
                },
            ],
            isError: true,
        };
    }
});
// Main
async function main() {
    console.error("[MCP] SwagManager MCP Server starting...");
    console.error(`[MCP] Supabase URL: ${SUPABASE_URL}`);
    console.error(`[MCP] Store ID: ${STORE_ID || "(not set)"}`);
    // Pre-load tools
    toolDefinitions = await loadToolDefinitions();
    console.error(`[MCP] Pre-loaded ${toolDefinitions.length} tools`);
    // Connect via stdio
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("[MCP] Server connected and ready");
}
main().catch((err) => {
    console.error("[MCP] Fatal error:", err);
    process.exit(1);
});
