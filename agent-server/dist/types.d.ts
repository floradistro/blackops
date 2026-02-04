/**
 * Type definitions for agent server communication
 */
export interface AgentConfig {
    model?: string;
    maxTurns?: number;
    permissionMode?: "default" | "acceptEdits" | "bypassPermissions";
    systemPrompt?: string;
    enabledTools?: string[];
    agentId?: string;
    agentName?: string;
    apiKey?: string;
}
export type ClientMessage = {
    type: "query";
    prompt: string;
    config?: Partial<AgentConfig>;
    storeId?: string;
    attachedPaths?: string[];
} | {
    type: "abort";
} | {
    type: "ping";
} | {
    type: "get_tools";
};
export interface ToolMetadata {
    id: string;
    name: string;
    description: string;
    category: string;
}
export type ServerMessage = {
    type: "ready";
    version: string;
    tools: ToolMetadata[];
} | {
    type: "tools";
    tools: ToolMetadata[];
} | {
    type: "pong";
} | {
    type: "started";
    model: string;
    storeId?: string;
} | {
    type: "text";
    text: string;
} | {
    type: "tool_start";
    tool: string;
    input: Record<string, unknown>;
} | {
    type: "tool_result";
    tool: string;
    success: boolean;
    result?: unknown;
    error?: string;
} | {
    type: "done";
    status: string;
    usage: TokenUsage;
} | {
    type: "error";
    error: string;
} | {
    type: "aborted";
} | {
    type: "debug";
    level: "info" | "warn" | "error";
    message: string;
    data?: Record<string, unknown>;
};
export interface TokenUsage {
    inputTokens: number;
    outputTokens: number;
    totalCost: number;
}
export interface McpToolResult {
    [key: string]: unknown;
    content: Array<{
        type: "text";
        text: string;
    }>;
    isError?: boolean;
}
