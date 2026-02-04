/**
 * User Tools Executor
 *
 * Handles execution of user-created custom tools.
 * Three execution types:
 * - rpc: Call a Postgres function
 * - http: Call an external API
 * - sql: Execute a sandboxed SQL query
 */
import { SupabaseClient } from "@supabase/supabase-js";
export interface UserTool {
    id: string;
    store_id: string;
    name: string;
    display_name: string;
    description: string;
    category: string;
    icon: string;
    input_schema: {
        type: "object";
        properties: Record<string, any>;
        required?: string[];
    };
    execution_type: "rpc" | "http" | "sql";
    rpc_function?: string;
    http_config?: HttpConfig;
    sql_template?: string;
    allowed_tables?: string[];
    is_read_only: boolean;
    requires_approval: boolean;
    max_execution_time_ms: number;
}
interface HttpConfig {
    url: string;
    method: "GET" | "POST" | "PUT" | "DELETE" | "PATCH";
    headers?: Record<string, string>;
    body_template?: Record<string, any>;
    query_params?: Record<string, string>;
}
export interface UserToolResult {
    success: boolean;
    data?: any;
    error?: string;
    pending_approval?: boolean;
    execution_id?: string;
}
export declare function loadUserTools(supabase: SupabaseClient, storeId: string): Promise<UserTool[]>;
export declare function executeUserTool(supabase: SupabaseClient, tool: UserTool, args: Record<string, unknown>, storeId: string): Promise<UserToolResult>;
export declare function userToolToRegistryFormat(tool: UserTool): any;
export {};
