// agent-chat/lib/types.ts — Shared type definitions

export interface AgentConfig {
  id: string;
  name: string;
  description: string;
  system_prompt: string;
  model: string;
  max_tokens: number;
  max_tool_calls: number;
  temperature: number;
  enabled_tools: string[];
  can_query: boolean;
  can_send: boolean;
  can_modify: boolean;
  tone: string;
  verbosity: string;
  api_key: string | null;
  store_id: string | null;
  context_config: {
    includeLocations?: boolean;
    locationIds?: string[];
    includeCustomers?: boolean;
    customerSegments?: string[];
    max_history_chars?: number;
    max_tool_result_chars?: number;
    max_message_chars?: number;
  } | null;
}

export interface ToolDef {
  name: string;
  description: string;
  input_schema: Record<string, unknown>;
}

export interface StreamEvent {
  type: "text" | "tool_start" | "tool_result" | "error" | "done" | "usage";
  text?: string;
  name?: string;
  result?: unknown;
  success?: boolean;
  error?: string;
  usage?: { input_tokens: number; output_tokens: number };
  conversationId?: string;
}
