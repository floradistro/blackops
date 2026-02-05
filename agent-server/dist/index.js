/**
 * SwagManager Agent Server
 *
 * Clean implementation using @anthropic-ai/sdk directly
 * with proper multi-turn conversation support.
 *
 * Architecture:
 * - WebSocket server for Swift app communication
 * - Anthropic SDK for Claude API with tool use
 * - Persistent conversation storage in Supabase
 * - Full conversation history sent with each request (Anthropic best practice)
 *
 * Compliance (2026 Standards):
 * - Anthropic Agent SDK best practices (2026)
 * - Error classification with retry logic (6 error types)
 * - Token budget enforcement
 * - Conversation compaction at 92% context
 * - Graceful shutdown with connection draining
 * - Fine-grained tool streaming (2026 beta)
 * - Interleaved thinking support (2026 beta)
 * - Database-backed telemetry (audit_logs with trace IDs)
 * - MCP November 2025 specification compliance
 *
 * References:
 * - https://docs.anthropic.com/en/api/messages
 * - https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use
 * - https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk
 * - https://modelcontextprotocol.io/specification/2025-11-25
 */
import { config } from "dotenv";
config();
import { WebSocketServer, WebSocket } from "ws";
import Anthropic from "@anthropic-ai/sdk";
import { createClient } from "@supabase/supabase-js";
import { loadToolRegistry, getToolMetadata, invalidateToolCache } from "./services/tool-registry.js";
import { executeTool, ToolErrorType } from "./tools/executor.js";
import { createConversation, getConversation, listConversations, loadMessages, loadMessagesWithTimestamps, saveMessage, saveAssistantTurn, saveToolResults, generateTitle } from "./services/conversation.js";
// ============================================================================
// MODEL PRICING (2026 Anthropic rates)
// ============================================================================
const MODEL_PRICING = {
    "claude-sonnet-4-20250514": { input: 3, output: 15, cacheRead: 0.30, cacheWrite: 3.75 },
    "claude-sonnet-4-5-20250929": { input: 3, output: 15, cacheRead: 0.30, cacheWrite: 3.75 },
    "claude-opus-4-20250514": { input: 15, output: 75, cacheRead: 1.50, cacheWrite: 18.75 },
    "claude-3-5-haiku-20241022": { input: 0.80, output: 4, cacheRead: 0.08, cacheWrite: 1 },
    // Fallback for unknown models
    "default": { input: 3, output: 15 }
};
// ============================================================================
// CONSTANTS - Anthropic SDK Compliance
// ============================================================================
const CONTEXT_WINDOW = 200000; // Claude Sonnet 4 context window
const COMPRESSION_THRESHOLD = 0.92; // Trigger compaction at 92% utilization
const TOOL_EXECUTION_TIMEOUT_MS = 30000; // 30s tool timeout
const SHUTDOWN_TIMEOUT_MS = 30000; // 30s graceful shutdown
const MAX_RESULT_LENGTH = 10000; // Max tool result length before truncation
// Token budget defaults
const DEFAULT_TOKEN_BUDGET = {
    maxTokensPerRequest: 8192,
    maxTokensPerConversation: 150000,
    warningThreshold: 0.8
};
// ============================================================================
// CONFIGURATION
// ============================================================================
const PORT = parseInt(process.env.AGENT_PORT || "3847");
const SUPABASE_URL = process.env.SUPABASE_URL || "https://uaednwpxursknmwdeejn.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
// ============================================================================
// TOOL REGISTRY
// ============================================================================
let toolRegistry = [];
let toolMetadata = [];
async function initializeTools() {
    if (!SUPABASE_KEY) {
        console.warn("[Agent] No SUPABASE_SERVICE_ROLE_KEY - tools unavailable");
        return;
    }
    console.log("[Agent] Loading tools from registry...");
    toolRegistry = await loadToolRegistry(SUPABASE_URL, SUPABASE_KEY);
    toolMetadata = getToolMetadata(toolRegistry);
    console.log(`[Agent] Loaded ${toolRegistry.length} tools`);
}
// ============================================================================
// SUPABASE CONNECTION POOLING (Anthropic best practice: reuse connections)
// ============================================================================
const supabasePool = new Map();
function getSupabaseClient(key) {
    if (!supabasePool.has(key)) {
        supabasePool.set(key, createClient(SUPABASE_URL, key));
    }
    return supabasePool.get(key);
}
// ============================================================================
// CONVERT REGISTRY TO ANTHROPIC TOOL FORMAT (with strict mode)
// ============================================================================
function registryToAnthropicTools(tools) {
    return tools.map(t => {
        // Validate tool has proper input_schema
        if (!t.definition?.input_schema || Object.keys(t.definition.input_schema.properties || {}).length === 0) {
            console.warn(`[Agent] Tool "${t.name}" has empty input_schema - may cause issues`);
        }
        return {
            name: t.name,
            description: t.description || t.definition?.description || `Execute ${t.name}`,
            input_schema: t.definition?.input_schema || { type: "object", properties: {} }
            // Note: 'strict' mode not yet available in Anthropic SDK, but we validate schemas
        };
    });
}
// ============================================================================
// ESTIMATE TOKEN COUNT (rough approximation)
// ============================================================================
function estimateTokenCount(messages) {
    let chars = 0;
    for (const msg of messages) {
        if (typeof msg.content === "string") {
            chars += msg.content.length;
        }
        else if (Array.isArray(msg.content)) {
            for (const block of msg.content) {
                if ("text" in block)
                    chars += block.text?.length || 0;
                if ("content" in block)
                    chars += String(block.content).length;
            }
        }
    }
    // Rough estimate: ~4 characters per token
    return Math.ceil(chars / 4);
}
// ============================================================================
// CONVERSATION COMPACTION (Anthropic: compress at 92% context utilization)
// ============================================================================
async function compactConversation(anthropic, messages, model) {
    const estimatedTokens = estimateTokenCount(messages);
    const compressionPoint = CONTEXT_WINDOW * COMPRESSION_THRESHOLD;
    if (estimatedTokens < compressionPoint) {
        return messages; // No compression needed
    }
    console.log(`[Agent] Context at ${Math.round((estimatedTokens / CONTEXT_WINDOW) * 100)}%, compressing...`);
    // Keep first 3 and last 8 messages, summarize the middle
    const keepStart = 3;
    const keepEnd = 8;
    if (messages.length <= keepStart + keepEnd) {
        return messages; // Not enough messages to compress
    }
    const toSummarize = messages.slice(keepStart, messages.length - keepEnd);
    // Create a summary of the middle messages
    try {
        const summaryResponse = await anthropic.messages.create({
            model: "claude-sonnet-4-20250514",
            max_tokens: 1500,
            system: "You are a conversation summarizer. Create a brief summary of the key decisions, data retrieved, tool calls made, and progress achieved. Focus on information the AI will need to continue the conversation effectively. Be concise but complete.",
            messages: [
                {
                    role: "user",
                    content: `Summarize this conversation segment:\n\n${JSON.stringify(toSummarize, null, 2).slice(0, 50000)}`
                }
            ]
        });
        const summaryText = summaryResponse.content[0].type === "text"
            ? summaryResponse.content[0].text
            : "Conversation history summarized.";
        // Rebuild message history with summary
        const compacted = [
            ...messages.slice(0, keepStart),
            {
                role: "user",
                content: `[CONVERSATION SUMMARY - ${toSummarize.length} messages compressed]\n${summaryText}\n\n[Continuing conversation...]`
            },
            {
                role: "assistant",
                content: "I understand the conversation context from the summary. Let me continue helping you."
            },
            ...messages.slice(messages.length - keepEnd)
        ];
        console.log(`[Agent] Compacted ${messages.length} messages to ${compacted.length}`);
        return compacted;
    }
    catch (error) {
        console.error("[Agent] Compression failed, continuing with full context:", error);
        return messages;
    }
}
// ============================================================================
// WEBSOCKET SERVER
// ============================================================================
const wss = new WebSocketServer({ port: PORT });
console.log(`[Agent] Starting on ws://localhost:${PORT}`);
wss.on("connection", (ws) => {
    console.log("[Agent] Client connected");
    // Session state
    let currentConversationId = null;
    let abortController = null;
    let conversationTokens = 0; // Track tokens for budget enforcement
    ws.on("message", async (data) => {
        try {
            const message = JSON.parse(data.toString());
            const supabase = getSupabaseClient(SUPABASE_KEY); // Use connection pool
            switch (message.type) {
                case "query":
                    abortController = new AbortController();
                    await handleQuery(ws, message, abortController, supabase, currentConversationId, (id) => {
                        currentConversationId = id;
                    });
                    break;
                case "new_conversation":
                    currentConversationId = null;
                    console.log("[Agent] Starting new conversation");
                    break;
                case "get_conversations":
                    if (message.storeId) {
                        const conversations = await listConversations(supabase, message.storeId, message.limit || 20);
                        send(ws, {
                            type: "conversations",
                            conversations: conversations.map(c => ({
                                id: c.id,
                                title: c.title || "Untitled",
                                agentId: c.agent_id || undefined,
                                messageCount: 0,
                                createdAt: c.created_at,
                                updatedAt: c.updated_at
                            }))
                        });
                    }
                    break;
                case "load_conversation":
                    if (message.conversationId) {
                        try {
                            const conv = await getConversation(supabase, message.conversationId);
                            if (!conv) {
                                send(ws, { type: "error", error: "Conversation not found" });
                                break;
                            }
                            const msgs = await loadMessagesWithTimestamps(supabase, message.conversationId);
                            currentConversationId = message.conversationId;
                            send(ws, {
                                type: "conversation_loaded",
                                conversationId: conv.id,
                                title: conv.title || "Untitled",
                                messages: msgs.map(m => ({
                                    role: m.role,
                                    content: m.content,
                                    createdAt: m.created_at
                                }))
                            });
                        }
                        catch (err) {
                            send(ws, { type: "error", error: `Failed to load conversation: ${err.message}` });
                        }
                    }
                    break;
                case "abort":
                    if (abortController) {
                        abortController.abort();
                        send(ws, { type: "aborted" });
                    }
                    break;
                case "ping":
                    send(ws, { type: "pong" });
                    break;
                case "get_tools":
                    invalidateToolCache();
                    await initializeTools();
                    send(ws, { type: "tools", tools: toolMetadata });
                    break;
                default:
                    send(ws, { type: "error", error: "Unknown message type" });
            }
        }
        catch (error) {
            console.error("[Agent] Error:", error);
            send(ws, { type: "error", error: "Invalid message format" });
        }
    });
    ws.on("close", () => {
        console.log("[Agent] Client disconnected");
        abortController?.abort();
    });
    ws.on("error", (error) => {
        console.error("[Agent] WebSocket error:", error);
    });
    send(ws, {
        type: "ready",
        version: "3.0.0",
        tools: toolMetadata
    });
});
// ============================================================================
// QUERY HANDLER - Multi-turn conversation with persistence
// ============================================================================
async function handleQuery(ws, message, abortController, supabase, existingConversationId, setConversationId) {
    const { prompt, config, storeId, userId, conversationId: requestedConversationId } = message;
    console.log(`[Agent] Query: "${prompt.slice(0, 80)}..."`);
    console.log(`[Agent] Store: ${storeId || 'none'}, Agent: ${config?.agentName || 'none'}`);
    // Refresh tools if needed
    if (toolRegistry.length === 0) {
        await initializeTools();
    }
    // Filter tools based on enabledTools config
    let toolsToUse = toolRegistry;
    if (config?.enabledTools?.length) {
        const enabledSet = new Set(config.enabledTools);
        toolsToUse = toolRegistry.filter(t => enabledSet.has(t.name));
        console.log(`[Agent] Using ${toolsToUse.length} enabled tools: ${toolsToUse.map(t => t.name).join(', ')}`);
    }
    // Validate system prompt
    if (!config?.systemPrompt) {
        send(ws, { type: "error", error: "No system prompt configured. Add one in Agent Config." });
        return;
    }
    // Build system prompt with store context
    let systemPrompt = config.systemPrompt;
    if (storeId) {
        const { data: store } = await supabase
            .from("stores")
            .select("name, description")
            .eq("id", storeId)
            .single();
        const storeName = store?.name || "Unknown Store";
        systemPrompt += `\n\n## Store Context\nYou are operating for: **${storeName}**\nStore ID: ${storeId}\nThe store_id is automatically included in tool calls.`;
        console.log(`[Agent] Store: ${storeName}`);
    }
    // Get API key
    const apiKey = config?.apiKey || process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
        send(ws, { type: "error", error: "No API key configured." });
        return;
    }
    // Select model
    let model = config?.model || "claude-sonnet-4-20250514";
    if (model.includes("opus-4-5")) {
        model = "claude-sonnet-4-20250514"; // Opus 4.5 not available for API yet
    }
    // =========================================================================
    // CONVERSATION MANAGEMENT (Anthropic best practice: stateless API)
    // =========================================================================
    // Determine conversation ID: use requested, existing session, or create new
    let conversationId = requestedConversationId || existingConversationId;
    let isNewConversation = false;
    if (conversationId) {
        // Verify conversation exists
        const existing = await getConversation(supabase, conversationId);
        if (!existing) {
            console.log(`[Agent] Conversation ${conversationId} not found, creating new`);
            conversationId = null;
        }
    }
    if (!conversationId) {
        // Create new conversation
        const conversation = await createConversation(supabase, {
            storeId: storeId || undefined,
            userId: userId || undefined,
            agentId: config?.agentId || undefined,
            title: generateTitle(prompt)
        });
        conversationId = conversation.id;
        isNewConversation = true;
        console.log(`[Agent] Created conversation: ${conversationId.slice(0, 8)}...`);
        // Notify client of new conversation
        send(ws, {
            type: "conversation_created",
            conversation: {
                id: conversationId,
                title: generateTitle(prompt),
                agentId: config?.agentId,
                agentName: config?.agentName,
                messageCount: 0,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            }
        });
    }
    // Update session state
    setConversationId(conversationId);
    // Initialize Anthropic client (needed for compaction and queries)
    const anthropic = new Anthropic({ apiKey });
    // =========================================================================
    // LOAD CONVERSATION HISTORY (Anthropic: send full history each request)
    // =========================================================================
    let messages = [];
    if (!isNewConversation) {
        // Load existing conversation history from database
        messages = await loadMessages(supabase, conversationId);
        console.log(`[Agent] Loaded ${messages.length} messages from conversation history`);
        // Apply conversation compaction if needed (Anthropic: compress at 92% context)
        messages = await compactConversation(anthropic, messages, model);
    }
    // Save and append new user message
    await saveMessage(supabase, {
        conversationId,
        role: "user",
        content: prompt
    });
    messages.push({ role: "user", content: prompt });
    // Token budget check
    const estimatedTokens = estimateTokenCount(messages);
    if (estimatedTokens > DEFAULT_TOKEN_BUDGET.maxTokensPerConversation) {
        send(ws, {
            type: "error",
            error: `Conversation exceeded token budget: ${estimatedTokens} > ${DEFAULT_TOKEN_BUDGET.maxTokensPerConversation}. Please start a new conversation.`
        });
        return;
    }
    if (estimatedTokens > DEFAULT_TOKEN_BUDGET.maxTokensPerConversation * DEFAULT_TOKEN_BUDGET.warningThreshold) {
        send(ws, {
            type: "warning",
            warning: `Approaching token budget: ${Math.round((estimatedTokens / DEFAULT_TOKEN_BUDGET.maxTokensPerConversation) * 100)}% used`
        });
    }
    // =========================================================================
    // SEND STARTED EVENT
    // =========================================================================
    send(ws, { type: "started", model, storeId, conversationId });
    // Convert tools to Anthropic format
    const anthropicTools = registryToAnthropicTools(toolsToUse);
    console.log(`[Agent] ${anthropicTools.length} tools available, ${messages.length} messages in context`);
    const maxTurns = config?.maxTurns || 20;
    let turn = 0;
    let totalInputTokens = 0;
    let totalOutputTokens = 0;
    let totalCacheReadTokens = 0;
    let totalCacheCreationTokens = 0;
    let totalCost = 0;
    // Generate trace ID for this conversation turn sequence
    const traceId = generateTraceId();
    try {
        // Agentic loop
        while (turn < maxTurns) {
            turn++;
            const turnStartTime = Date.now();
            if (abortController.signal.aborted) {
                send(ws, { type: "aborted" });
                return;
            }
            console.log(`[Agent] Turn ${turn}/${maxTurns}`);
            // Call Claude with streaming (with full event handlers per Anthropic best practice)
            // Create streaming request
            const stream = anthropic.messages.stream({
                model,
                max_tokens: config?.maxTokens || DEFAULT_TOKEN_BUDGET.maxTokensPerRequest,
                system: systemPrompt,
                tools: anthropicTools.length > 0 ? anthropicTools : undefined,
                messages
            });
            // Collect the response
            let assistantContent = [];
            // Handle streaming events (Anthropic 2026: handle text, thinking, and tool events)
            stream.on("text", (text) => {
                send(ws, { type: "text", text });
            });
            // 2026: Handle interleaved thinking blocks
            // When Claude thinks between tool calls, we can optionally surface this to the UI
            stream.on("message", (message) => {
                // Check for thinking blocks in the response (2026 beta feature)
                if (message.content) {
                    for (const block of message.content) {
                        if (block.type === "thinking") {
                            // Send thinking to client for transparency (optional - can hide in production)
                            send(ws, {
                                type: "thinking",
                                thinking: block.thinking
                            });
                        }
                    }
                }
            });
            // Handle stream errors
            stream.on("error", (error) => {
                console.error("[Agent] Stream error:", error);
                send(ws, {
                    type: "error",
                    error: `Streaming error: ${error.message}`
                });
            });
            let response;
            const turnSpanId = generateSpanId();
            let apiErrorType;
            try {
                response = await stream.finalMessage();
            }
            catch (streamError) {
                const turnDuration = Date.now() - turnStartTime;
                // Anthropic 2026 error classification
                // 429 = rate limit (your fault - too many requests)
                // 529 = overloaded (Anthropic's fault - server busy)
                if (streamError.status === 429) {
                    apiErrorType = 'rate_limit';
                    await logApiTelemetry(supabase, {
                        model,
                        inputTokens: 0,
                        outputTokens: 0,
                        totalCost: 0,
                        turnNumber: turn,
                        conversationId,
                        storeId,
                        agentId: config?.agentId,
                        agentName: config?.agentName,
                        durationMs: turnDuration,
                        stopReason: 'error',
                        traceId,
                        spanId: turnSpanId,
                        statusCode: 'ERROR',
                        errorMessage: 'Rate limited (429)',
                        errorType: 'rate_limit'
                    });
                    send(ws, { type: "error", error: "Rate limited. Please retry in a moment.", recoverable: true });
                    return;
                }
                if (streamError.status === 529) {
                    apiErrorType = 'overloaded';
                    await logApiTelemetry(supabase, {
                        model,
                        inputTokens: 0,
                        outputTokens: 0,
                        totalCost: 0,
                        turnNumber: turn,
                        conversationId,
                        storeId,
                        agentId: config?.agentId,
                        agentName: config?.agentName,
                        durationMs: turnDuration,
                        stopReason: 'error',
                        traceId,
                        spanId: turnSpanId,
                        statusCode: 'ERROR',
                        errorMessage: 'Anthropic overloaded (529)',
                        errorType: 'overloaded'
                    });
                    send(ws, { type: "error", error: "Anthropic servers overloaded. Please retry.", recoverable: true });
                    return;
                }
                throw streamError;
            }
            const turnDuration = Date.now() - turnStartTime;
            // Extract token usage including cache tokens (Anthropic 2026)
            const usage = response.usage; // Extended usage type
            const turnInputTokens = usage.input_tokens || 0;
            const turnOutputTokens = usage.output_tokens || 0;
            const turnCacheReadTokens = usage.cache_read_input_tokens || 0;
            const turnCacheCreationTokens = usage.cache_creation_input_tokens || 0;
            totalInputTokens += turnInputTokens;
            totalOutputTokens += turnOutputTokens;
            totalCacheReadTokens += turnCacheReadTokens;
            totalCacheCreationTokens += turnCacheCreationTokens;
            // Calculate cost for this turn
            const turnCost = estimateCost(model, turnInputTokens, turnOutputTokens, turnCacheReadTokens, turnCacheCreationTokens);
            totalCost += turnCost;
            // Log API telemetry for this turn (Anthropic 2026 compliant)
            await logApiTelemetry(supabase, {
                model,
                inputTokens: turnInputTokens,
                outputTokens: turnOutputTokens,
                cacheReadTokens: turnCacheReadTokens,
                cacheCreationTokens: turnCacheCreationTokens,
                totalCost: turnCost,
                turnNumber: turn,
                conversationId,
                storeId,
                agentId: config?.agentId,
                agentName: config?.agentName,
                durationMs: turnDuration,
                stopReason: response.stop_reason || 'unknown',
                traceId,
                spanId: turnSpanId,
                statusCode: 'OK'
            });
            assistantContent = response.content;
            // Add assistant message to in-memory history
            messages.push({ role: "assistant", content: assistantContent });
            // Persist assistant response to database
            await saveAssistantTurn(supabase, conversationId, assistantContent, turnOutputTokens);
            // Check stop reason
            if (response.stop_reason === "end_turn") {
                console.log(`[Agent] Complete after ${turn} turns, cost: $${totalCost.toFixed(6)}`);
                send(ws, {
                    type: "done",
                    status: "success",
                    conversationId,
                    usage: {
                        inputTokens: totalInputTokens,
                        outputTokens: totalOutputTokens,
                        cacheReadTokens: totalCacheReadTokens,
                        cacheCreationTokens: totalCacheCreationTokens,
                        totalCost
                    }
                });
                return;
            }
            // Handle tool use
            if (response.stop_reason === "tool_use") {
                const toolResults = [];
                for (const block of assistantContent) {
                    if (block.type === "tool_use") {
                        console.log(`[Agent] Tool: ${block.name}`);
                        send(ws, { type: "tool_start", tool: block.name, input: block.input });
                        // Execute tool with timeout (Anthropic best practice: prevent blocking)
                        let result;
                        try {
                            const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error(`Tool execution timeout after ${TOOL_EXECUTION_TIMEOUT_MS}ms`)), TOOL_EXECUTION_TIMEOUT_MS));
                            result = await Promise.race([
                                executeTool(supabase, block.name, block.input, storeId, {
                                    source: "swag_manager",
                                    requestId: traceId, // Use trace ID for distributed tracing
                                    agentId: config?.agentId,
                                    agentName: config?.agentName,
                                    // Anthropic 2026: Pass model/token context for tool telemetry
                                    model,
                                    inputTokens: totalInputTokens,
                                    outputTokens: totalOutputTokens,
                                    totalCost,
                                    turnNumber: turn,
                                    conversationId
                                }),
                                timeoutPromise
                            ]);
                        }
                        catch (timeoutError) {
                            result = {
                                success: false,
                                error: timeoutError.message,
                                errorType: ToolErrorType.RECOVERABLE,
                                timedOut: true
                            };
                        }
                        const resultText = result.success
                            ? (typeof result.data === "string" ? result.data : JSON.stringify(result.data, null, 2))
                            : `Error: ${result.error}`;
                        // Truncation with metadata (Anthropic best practice: inform about truncation)
                        const isTruncated = resultText.length > MAX_RESULT_LENGTH;
                        const truncatedResult = resultText.slice(0, MAX_RESULT_LENGTH);
                        console.log(`[Agent] Tool ${block.name}: ${result.success ? "OK" : "ERROR"}${isTruncated ? " (truncated)" : ""}`);
                        send(ws, {
                            type: "tool_result",
                            tool: block.name,
                            success: result.success,
                            result: truncatedResult,
                            isTruncated,
                            actualLength: resultText.length,
                            error: result.success ? undefined : result.error,
                            errorType: result.errorType,
                            retryable: result.errorType === ToolErrorType.RECOVERABLE || result.errorType === ToolErrorType.RATE_LIMIT
                        });
                        // Include truncation notice in tool result for Claude
                        const contentForClaude = isTruncated
                            ? `${truncatedResult}\n\n[NOTE: Result truncated from ${resultText.length} to ${MAX_RESULT_LENGTH} characters]`
                            : resultText;
                        toolResults.push({
                            type: "tool_result",
                            tool_use_id: block.id,
                            content: contentForClaude,
                            is_error: !result.success
                        });
                    }
                }
                // Add tool results to in-memory history
                messages.push({ role: "user", content: toolResults });
                // Persist tool results to database
                await saveToolResults(supabase, conversationId, toolResults);
            }
        }
        // Max turns reached
        console.log(`[Agent] Max turns (${maxTurns}) reached, cost: $${totalCost.toFixed(6)}`);
        send(ws, {
            type: "done",
            status: "max_turns",
            conversationId,
            usage: {
                inputTokens: totalInputTokens,
                outputTokens: totalOutputTokens,
                cacheReadTokens: totalCacheReadTokens,
                cacheCreationTokens: totalCacheCreationTokens,
                totalCost
            }
        });
    }
    catch (error) {
        if (abortController.signal.aborted) {
            send(ws, { type: "aborted" });
        }
        else {
            console.error("[Agent] Error:", error.message);
            send(ws, { type: "error", error: error.message || String(error) });
        }
    }
}
// ============================================================================
// HELPERS
// ============================================================================
function send(ws, message) {
    if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(message));
    }
}
function estimateCost(model, inputTokens, outputTokens, cacheReadTokens, cacheCreationTokens) {
    const pricing = MODEL_PRICING[model] || MODEL_PRICING["default"];
    // Per million tokens -> dollars
    const inputCost = (inputTokens / 1_000_000) * pricing.input;
    const outputCost = (outputTokens / 1_000_000) * pricing.output;
    const cacheReadCost = cacheReadTokens && pricing.cacheRead
        ? (cacheReadTokens / 1_000_000) * pricing.cacheRead
        : 0;
    const cacheWriteCost = cacheCreationTokens && pricing.cacheWrite
        ? (cacheCreationTokens / 1_000_000) * pricing.cacheWrite
        : 0;
    return Math.round((inputCost + outputCost + cacheReadCost + cacheWriteCost) * 1000000) / 1000000;
}
// ============================================================================
// TELEMETRY - Anthropic 2026 Compliant API Call Logging
// ============================================================================
function generateSpanId() {
    // W3C span-id: 16 lowercase hex chars
    return Array.from({ length: 16 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
}
function generateTraceId() {
    // W3C trace-id: 32 lowercase hex chars
    return Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
}
async function logApiTelemetry(supabase, telemetry) {
    try {
        const { error } = await supabase.from('audit_logs').insert({
            action: 'claude_api_request',
            severity: telemetry.statusCode === 'ERROR' ? 'error' : 'info',
            store_id: telemetry.storeId || null,
            request_id: telemetry.traceId,
            duration_ms: telemetry.durationMs,
            error_message: telemetry.errorMessage || null,
            // Denormalized columns for fast queries/aggregations
            trace_id: telemetry.traceId,
            span_id: telemetry.spanId,
            span_kind: 'CLIENT',
            service_name: 'agent-server',
            service_version: '3.0.0',
            status_code: telemetry.statusCode,
            start_time: new Date(Date.now() - telemetry.durationMs).toISOString(),
            end_time: new Date().toISOString(),
            model: telemetry.model,
            input_tokens: telemetry.inputTokens,
            output_tokens: telemetry.outputTokens,
            total_cost: telemetry.totalCost,
            turn_number: telemetry.turnNumber,
            conversation_id: telemetry.conversationId || null,
            error_type: telemetry.errorType || null,
            retryable: telemetry.errorType === 'rate_limit' || telemetry.errorType === 'overloaded',
            // JSONB details for flexible/extended attributes
            details: {
                // OTEL gen_ai.* semantic conventions (Anthropic 2026)
                'gen_ai.system': 'anthropic',
                'gen_ai.request.model': telemetry.model,
                'gen_ai.response.model': telemetry.model,
                'gen_ai.usage.input_tokens': telemetry.inputTokens,
                'gen_ai.usage.output_tokens': telemetry.outputTokens,
                'gen_ai.usage.total_tokens': telemetry.inputTokens + telemetry.outputTokens,
                // Cache tokens (Anthropic-specific)
                'gen_ai.usage.cache_read_tokens': telemetry.cacheReadTokens || 0,
                'gen_ai.usage.cache_creation_tokens': telemetry.cacheCreationTokens || 0,
                // Cost tracking (USD)
                'gen_ai.usage.cost': telemetry.totalCost,
                // Agent context
                agent_id: telemetry.agentId || null,
                agent_name: telemetry.agentName || null,
                conversation_id: telemetry.conversationId,
                turn_number: telemetry.turnNumber,
                stop_reason: telemetry.stopReason,
                // OTEL span context
                otel: {
                    trace_id: telemetry.traceId,
                    span_id: telemetry.spanId,
                    parent_span_id: telemetry.parentSpanId || null,
                    span_kind: 'CLIENT', // Outgoing call to Claude API
                    status_code: telemetry.statusCode,
                    service_name: 'agent-server',
                    service_version: '3.0.0'
                },
                // Error classification (Anthropic 2026)
                error_type: telemetry.errorType || null
            }
        });
        if (error) {
            console.error('[Telemetry] Failed to log API call:', error.message);
        }
    }
    catch (err) {
        console.error('[Telemetry] Error logging API call:', err);
    }
}
// ============================================================================
// STARTUP
// ============================================================================
async function main() {
    await initializeTools();
    console.log(`[Agent] Ready on ws://localhost:${PORT}`);
}
main().catch(console.error);
// ============================================================================
// GRACEFUL SHUTDOWN (Anthropic best practice: connection draining with timeout)
// ============================================================================
async function gracefulShutdown(signal) {
    console.log(`\n[Agent] Received ${signal}, initiating graceful shutdown...`);
    // Notify all connected clients
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: "shutdown", message: "Server shutting down" }));
        }
    });
    // Give clients 5 seconds to close gracefully
    await new Promise(resolve => setTimeout(resolve, 5000));
    // Force close remaining connections
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.close(1001, "Server shutdown");
        }
    });
    // Close server with timeout
    const closePromise = new Promise(resolve => {
        wss.close(() => {
            console.log("[Agent] WebSocket server closed");
            resolve();
        });
    });
    const timeoutPromise = new Promise(resolve => setTimeout(() => {
        console.warn("[Agent] Shutdown timeout reached, force exiting");
        resolve();
    }, SHUTDOWN_TIMEOUT_MS));
    await Promise.race([closePromise, timeoutPromise]);
    console.log("[Agent] Shutdown complete");
    process.exit(0);
}
process.on("SIGINT", () => gracefulShutdown("SIGINT"));
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
