/**
 * SwagManager Agent Server
 *
 * Production-quality local agent using Claude Agent SDK
 * Tools are loaded dynamically from Supabase ai_tool_registry
 *
 * Architecture:
 * - WebSocket server for Swift app communication
 * - Claude Agent SDK for agentic loop with tool execution
 * - Tools execute via tools-gateway edge function
 */
export {};
