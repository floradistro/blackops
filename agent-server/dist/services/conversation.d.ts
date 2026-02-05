/**
 * Conversation Service
 *
 * Handles persistent conversation storage following Anthropic best practices.
 * The Messages API is stateless - we must send full conversation history with each request.
 *
 * References:
 * - https://docs.anthropic.com/en/api/messages
 * - https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use
 */
import { SupabaseClient } from "@supabase/supabase-js";
import Anthropic from "@anthropic-ai/sdk";
export interface Conversation {
    id: string;
    store_id: string | null;
    user_id: string | null;
    agent_id: string | null;
    title: string | null;
    created_at: string;
    updated_at: string;
    metadata: Record<string, unknown>;
}
export interface ConversationMessage {
    id: string;
    conversation_id: string;
    role: "user" | "assistant";
    content: Anthropic.ContentBlock[] | Anthropic.ContentBlockParam[];
    created_at: string;
    is_tool_use: boolean;
    tool_names: string[] | null;
    token_count: number | null;
}
/**
 * Create a new conversation
 */
export declare function createConversation(supabase: SupabaseClient, params: {
    storeId?: string;
    userId?: string;
    agentId?: string;
    title?: string;
}): Promise<Conversation>;
/**
 * Get conversation by ID
 */
export declare function getConversation(supabase: SupabaseClient, conversationId: string): Promise<Conversation | null>;
/**
 * Update conversation title (auto-generated from first message)
 */
export declare function updateConversationTitle(supabase: SupabaseClient, conversationId: string, title: string): Promise<void>;
/**
 * List recent conversations for a store
 */
export declare function listConversations(supabase: SupabaseClient, storeId: string, limit?: number): Promise<Conversation[]>;
/**
 * Save a message to the conversation
 * Content is stored as JSONB - the exact format needed for Anthropic API
 */
export declare function saveMessage(supabase: SupabaseClient, params: {
    conversationId: string;
    role: "user" | "assistant";
    content: Anthropic.ContentBlock[] | Anthropic.ContentBlockParam[] | string;
    tokenCount?: number;
}): Promise<ConversationMessage>;
/**
 * Load all messages for a conversation in chronological order
 * Returns format ready for Anthropic Messages API
 */
export declare function loadMessages(supabase: SupabaseClient, conversationId: string): Promise<Anthropic.MessageParam[]>;
/**
 * Load all messages with timestamps for UI restoration
 * Returns full records (not just Anthropic API format)
 */
export declare function loadMessagesWithTimestamps(supabase: SupabaseClient, conversationId: string): Promise<{
    role: string;
    content: unknown[];
    created_at: string;
}[]>;
/**
 * Get message count for a conversation
 */
export declare function getMessageCount(supabase: SupabaseClient, conversationId: string): Promise<number>;
/**
 * Build messages array for Anthropic API
 * Loads history and appends new user message
 */
export declare function buildMessagesForQuery(supabase: SupabaseClient, conversationId: string, newPrompt: string): Promise<Anthropic.MessageParam[]>;
/**
 * Save the complete assistant turn (including any tool calls and their results)
 * This preserves the exact format needed for multi-turn tool use
 */
export declare function saveAssistantTurn(supabase: SupabaseClient, conversationId: string, content: Anthropic.ContentBlock[], tokenCount?: number): Promise<void>;
/**
 * Save tool results as a user message
 * Per Anthropic API: tool results go in user messages with tool_result content blocks
 */
export declare function saveToolResults(supabase: SupabaseClient, conversationId: string, toolResults: Anthropic.ToolResultBlockParam[]): Promise<void>;
/**
 * Generate a title from the first user message
 */
export declare function generateTitle(firstMessage: string): string;
