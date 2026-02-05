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
export {};
