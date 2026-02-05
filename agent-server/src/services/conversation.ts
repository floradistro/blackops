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

// ============================================================================
// TYPES
// ============================================================================

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

// ============================================================================
// CONVERSATION CRUD
// ============================================================================

/**
 * Create a new conversation
 */
export async function createConversation(
  supabase: SupabaseClient,
  params: {
    storeId?: string;
    userId?: string;
    agentId?: string;
    title?: string;
  }
): Promise<Conversation> {
  const { data, error } = await supabase
    .from("ai_conversations")
    .insert({
      store_id: params.storeId || null,
      user_id: params.userId || null,
      agent_id: params.agentId || null,
      title: params.title || null,
      metadata: {}
    })
    .select()
    .single();

  if (error) throw new Error(`Failed to create conversation: ${error.message}`);
  return data;
}

/**
 * Get conversation by ID
 */
export async function getConversation(
  supabase: SupabaseClient,
  conversationId: string
): Promise<Conversation | null> {
  const { data, error } = await supabase
    .from("ai_conversations")
    .select()
    .eq("id", conversationId)
    .single();

  if (error) {
    if (error.code === "PGRST116") return null; // Not found
    throw new Error(`Failed to get conversation: ${error.message}`);
  }
  return data;
}

/**
 * Update conversation title (auto-generated from first message)
 */
export async function updateConversationTitle(
  supabase: SupabaseClient,
  conversationId: string,
  title: string
): Promise<void> {
  const { error } = await supabase
    .from("ai_conversations")
    .update({ title })
    .eq("id", conversationId);

  if (error) throw new Error(`Failed to update conversation title: ${error.message}`);
}

/**
 * List recent conversations for a store
 */
export async function listConversations(
  supabase: SupabaseClient,
  storeId: string,
  limit = 20
): Promise<Conversation[]> {
  const { data, error } = await supabase
    .from("ai_conversations")
    .select()
    .eq("store_id", storeId)
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) throw new Error(`Failed to list conversations: ${error.message}`);
  return data || [];
}

// ============================================================================
// MESSAGE STORAGE
// ============================================================================

/**
 * Save a message to the conversation
 * Content is stored as JSONB - the exact format needed for Anthropic API
 */
export async function saveMessage(
  supabase: SupabaseClient,
  params: {
    conversationId: string;
    role: "user" | "assistant";
    content: Anthropic.ContentBlock[] | Anthropic.ContentBlockParam[] | string;
    tokenCount?: number;
  }
): Promise<ConversationMessage> {
  // Normalize string content to array format
  const contentArray = typeof params.content === "string"
    ? [{ type: "text" as const, text: params.content }]
    : params.content;

  // Extract tool info for denormalization
  const toolUseBlocks = contentArray.filter(
    (block): block is Anthropic.ToolUseBlock =>
      typeof block === "object" && "type" in block && block.type === "tool_use"
  );
  const isToolUse = toolUseBlocks.length > 0;
  const toolNames = isToolUse ? toolUseBlocks.map(b => b.name) : null;

  const { data, error } = await supabase
    .from("ai_messages")
    .insert({
      conversation_id: params.conversationId,
      role: params.role,
      content: contentArray,
      is_tool_use: isToolUse,
      tool_names: toolNames,
      token_count: params.tokenCount || null
    })
    .select()
    .single();

  if (error) throw new Error(`Failed to save message: ${error.message}`);
  return data;
}

/**
 * Load all messages for a conversation in chronological order
 * Returns format ready for Anthropic Messages API
 */
export async function loadMessages(
  supabase: SupabaseClient,
  conversationId: string
): Promise<Anthropic.MessageParam[]> {
  const { data, error } = await supabase
    .from("ai_messages")
    .select("role, content")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });

  if (error) throw new Error(`Failed to load messages: ${error.message}`);

  // Convert to Anthropic MessageParam format
  return (data || []).map(msg => ({
    role: msg.role as "user" | "assistant",
    content: msg.content as Anthropic.ContentBlockParam[]
  }));
}

/**
 * Load all messages with timestamps for UI restoration
 * Returns full records (not just Anthropic API format)
 */
export async function loadMessagesWithTimestamps(
  supabase: SupabaseClient,
  conversationId: string
): Promise<{ role: string; content: unknown[]; created_at: string }[]> {
  const { data, error } = await supabase
    .from("ai_messages")
    .select("role, content, created_at")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });

  if (error) throw new Error(`Failed to load messages: ${error.message}`);
  return data || [];
}

/**
 * Get message count for a conversation
 */
export async function getMessageCount(
  supabase: SupabaseClient,
  conversationId: string
): Promise<number> {
  const { count, error } = await supabase
    .from("ai_messages")
    .select("*", { count: "exact", head: true })
    .eq("conversation_id", conversationId);

  if (error) throw new Error(`Failed to count messages: ${error.message}`);
  return count || 0;
}

// ============================================================================
// CONVERSATION CONTEXT MANAGEMENT
// ============================================================================

/**
 * Build messages array for Anthropic API
 * Loads history and appends new user message
 */
export async function buildMessagesForQuery(
  supabase: SupabaseClient,
  conversationId: string,
  newPrompt: string
): Promise<Anthropic.MessageParam[]> {
  // Load existing history
  const history = await loadMessages(supabase, conversationId);

  // Append new user message
  const messages: Anthropic.MessageParam[] = [
    ...history,
    { role: "user", content: newPrompt }
  ];

  return messages;
}

/**
 * Save the complete assistant turn (including any tool calls and their results)
 * This preserves the exact format needed for multi-turn tool use
 */
export async function saveAssistantTurn(
  supabase: SupabaseClient,
  conversationId: string,
  content: Anthropic.ContentBlock[],
  tokenCount?: number
): Promise<void> {
  await saveMessage(supabase, {
    conversationId,
    role: "assistant",
    content,
    tokenCount
  });
}

/**
 * Save tool results as a user message
 * Per Anthropic API: tool results go in user messages with tool_result content blocks
 */
export async function saveToolResults(
  supabase: SupabaseClient,
  conversationId: string,
  toolResults: Anthropic.ToolResultBlockParam[]
): Promise<void> {
  await saveMessage(supabase, {
    conversationId,
    role: "user",
    content: toolResults
  });
}

/**
 * Generate a title from the first user message
 */
export function generateTitle(firstMessage: string): string {
  // Take first 50 chars, clean up
  let title = firstMessage.slice(0, 50).trim();
  if (firstMessage.length > 50) title += "...";
  return title;
}
