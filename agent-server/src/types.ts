/**
 * Type definitions for agent server communication
 *
 * Protocol for Swift app <-> Agent Server communication
 * All conversations are persisted and support multi-turn interactions
 */

// ============================================================================
// AGENT CONFIGURATION
// ============================================================================

export interface AgentConfig {
  model?: string;
  maxTurns?: number;
  maxTokens?: number;
  systemPrompt?: string;
  enabledTools?: string[];
  agentId?: string;
  agentName?: string;
  apiKey?: string;
}

// ============================================================================
// CONVERSATION METADATA
// ============================================================================

export interface ConversationMeta {
  id: string;
  title: string;
  agentId?: string;
  agentName?: string;
  messageCount: number;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// CLIENT -> SERVER MESSAGES
// ============================================================================

export type ClientMessage =
  | {
      type: "query";
      prompt: string;
      config?: Partial<AgentConfig>;
      storeId?: string;
      userId?: string;
      conversationId?: string;  // Omit to create new, include to continue
    }
  | { type: "abort" }
  | { type: "ping" }
  | { type: "get_tools" }
  | { type: "new_conversation" }
  | { type: "get_conversations"; storeId: string; limit?: number }
  | { type: "load_conversation"; conversationId: string };

// ============================================================================
// SERVER -> CLIENT MESSAGES
// ============================================================================

export interface ToolMetadata {
  id: string;
  name: string;
  description: string;
  category: string;
}

export interface TokenUsage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens?: number;      // Anthropic 2026: Prompt cache read tokens
  cacheCreationTokens?: number;  // Anthropic 2026: Prompt cache creation tokens
  totalCost: number;
}

export type ServerMessage =
  | { type: "ready"; version: string; tools: ToolMetadata[] }
  | { type: "tools"; tools: ToolMetadata[] }
  | { type: "pong" }
  | { type: "started"; model: string; conversationId: string; storeId?: string }
  | { type: "text"; text: string }
  | { type: "tool_start"; tool: string; input: Record<string, unknown> }
  | { type: "tool_result"; tool: string; success: boolean; result?: unknown; error?: string }
  | { type: "done"; status: string; conversationId: string; usage: TokenUsage }
  | { type: "error"; error: string }
  | { type: "aborted" }
  | { type: "conversation_created"; conversation: ConversationMeta }
  | { type: "conversations"; conversations: ConversationMeta[] }
  | { type: "conversation_loaded"; conversationId: string; title: string; messages: ConversationMessageData[] };

export interface ConversationMessageData {
  role: "user" | "assistant";
  content: unknown[];  // Anthropic ContentBlock[]
  createdAt: string;
}
