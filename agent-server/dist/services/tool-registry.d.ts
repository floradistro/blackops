/**
 * Tool Registry
 *
 * Loads tools from Supabase ai_tool_registry.
 * Used by the agent server to know which tools are available.
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
export interface ClientToolMetadata {
    id: string;
    name: string;
    description: string;
    category: string;
}
export declare function invalidateToolCache(): void;
export declare function loadToolRegistry(supabaseUrl: string, supabaseKey: string, forceRefresh?: boolean): Promise<ToolRegistryEntry[]>;
export declare function getToolMetadata(tools: ToolRegistryEntry[]): ClientToolMetadata[];
