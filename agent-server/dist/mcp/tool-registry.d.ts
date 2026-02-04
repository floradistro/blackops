/**
 * Dynamic Tool Registry
 *
 * Loads tools from Supabase ai_tool_registry and creates MCP tools
 * that execute LOCALLY via direct Supabase queries.
 *
 * Following Anthropic SDK best practices - tools run in-process.
 */
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
export interface ClientToolMetadata {
    id: string;
    name: string;
    description: string;
    category: string;
}
export declare function invalidateToolCache(): void;
export declare function loadToolRegistry(supabaseUrl: string, supabaseKey: string, forceRefresh?: boolean): Promise<ToolRegistryEntry[]>;
export declare function getToolMetadata(tools: ToolRegistryEntry[]): ClientToolMetadata[];
/**
 * Load user-created custom tools for a specific store and merge with system tools
 */
export declare function loadToolsWithUserTools(supabaseUrl: string, supabaseKey: string, storeId: string, forceRefresh?: boolean): Promise<ToolRegistryEntry[]>;
/**
 * Creates an MCP server with all tools loaded from the registry.
 * Tools execute LOCALLY via direct Supabase queries (Anthropic SDK best practice).
 * User tools are executed via the user-tools executor.
 */
export declare function createDynamicToolsServer(supabaseUrl: string, supabaseKey: string, tools: ToolRegistryEntry[], storeId?: string, userId?: string, sessionId?: string, // Trace ID - links all tool calls in this conversation
agentId?: string, // AI Agent UUID for telemetry
agentName?: string): import("@anthropic-ai/claude-code").McpSdkServerConfigWithInstance;
