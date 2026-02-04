/**
 * Consolidated Tool Executor
 *
 * Following Anthropic's best practices for tool design:
 * - "More tools don't always lead to better outcomes"
 * - "Claude Code uses about a dozen tools"
 * - "Consolidate multi-step operations into single tool calls"
 *
 * 39 tools → 12 consolidated tools:
 *
 * 1. inventory      - manage inventory (adjust, set, transfer, bulk operations)
 * 2. inventory_query - query inventory (summary, velocity, by_location, in_stock)
 * 3. inventory_audit - audit workflow (start, count, complete, summary)
 * 4. collections    - manage collections (find, create, get_theme, set_theme, set_icon)
 * 5. customers      - manage customers (find, create, update)
 * 6. products       - manage products (find, create, update, pricing)
 * 7. analytics      - analytics & data (summary, by_location, detailed, discover, employee)
 * 8. locations      - find/list locations
 * 9. orders         - manage orders (find, get, create)
 * 10. suppliers     - find suppliers
 * 11. email         - unified email (send, send_template, list, get, templates)
 * 12. documents     - document generation
 * 13. alerts        - system alerts
 * 14. audit_trail   - audit logs
 */
import { SupabaseClient } from "@supabase/supabase-js";
export interface ToolResult {
    success: boolean;
    data?: unknown;
    error?: string;
}
export interface ExecutionContext {
    source: "claude_code" | "swag_manager" | "api" | "edge_function" | "test";
    userId?: string;
    requestId?: string;
    parentId?: string;
    agentId?: string;
    agentName?: string;
}
export declare function executeTool(supabase: SupabaseClient, toolName: string, args: Record<string, unknown>, storeId?: string, context?: ExecutionContext): Promise<ToolResult>;
export declare function getImplementedTools(): string[];
