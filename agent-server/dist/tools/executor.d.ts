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
 * 7. analytics      - analytics & intelligence (summary, by_location, detailed, discover, employee, customers, products, inventory_intelligence, marketing, fraud, employee_performance, behavior, full)
 * 8. locations      - find/list locations
 * 9. orders         - manage orders (find, get, create)
 * 10. suppliers     - find suppliers
 * 11. email         - unified email (send, send_template, list, get, templates)
 * 12. documents     - document generation
 * 13. alerts        - system alerts
 * 14. audit_trail   - audit logs
 */
import { SupabaseClient } from "@supabase/supabase-js";
export declare enum ToolErrorType {
    RECOVERABLE = "recoverable",// Retry with same input (transient failure)
    PERMANENT = "permanent",// Don't retry (invalid input, business logic error)
    RATE_LIMIT = "rate_limit",// Exponential backoff needed
    AUTH = "auth",// User permission issue
    VALIDATION = "validation",// Bad input from AI
    NOT_FOUND = "not_found"
}
export interface ToolResult {
    success: boolean;
    data?: unknown;
    error?: string;
    errorType?: ToolErrorType;
    retryable?: boolean;
    timedOut?: boolean;
}
export type SpanKind = "CLIENT" | "SERVER" | "INTERNAL" | "PRODUCER" | "CONSUMER";
export interface ExecutionContext {
    source: "claude_code" | "swag_manager" | "api" | "edge_function" | "test";
    userId?: string;
    traceId?: string;
    spanId?: string;
    parentSpanId?: string;
    traceFlags?: number;
    requestId?: string;
    parentId?: string;
    serviceName?: string;
    serviceVersion?: string;
    agentId?: string;
    agentName?: string;
    conversationId?: string;
    turnNumber?: number;
    model?: string;
    inputTokens?: number;
    outputTokens?: number;
    totalCost?: number;
    costBefore?: number;
    turnCost?: number;
}
export declare function executeTool(supabase: SupabaseClient, toolName: string, args: Record<string, unknown>, storeId?: string, context?: ExecutionContext): Promise<ToolResult>;
export declare function getImplementedTools(): string[];
