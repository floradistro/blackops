import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export async function handleWebSearch(sb: SupabaseClient, args: Record<string, unknown>, _storeId?: string) {
  const query = args.query as string;
  const numResults = (args.num_results as number) || 5;

  // Read from platform_secrets table first, fall back to env var
  const { data: secret } = await sb.from("platform_secrets").select("value").eq("key", "exa_api_key").single();
  const exaApiKey = secret?.value || Deno.env.get("EXA_API_KEY");

  if (!exaApiKey) {
    return { success: false, error: "Exa API key not configured. Add 'exa_api_key' to platform_secrets table." };
  }

  if (!query) {
    return { success: false, error: "Query parameter is required" };
  }

  try {
    const response = await fetch("https://api.exa.ai/search", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": exaApiKey
      },
      body: JSON.stringify({
        query,
        numResults,
        useAutoprompt: true,
        type: "auto"
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      return { success: false, error: `Exa API error: ${response.status} - ${errorText}` };
    }

    const data = await response.json();
    return {
      success: true,
      data: {
        query,
        results: data.results || [],
        autopromptString: data.autopromptString
      }
    };
  } catch (err) {
    return { success: false, error: `Web search failed: ${err}` };
  }
}

export async function handleTelemetry(sb: SupabaseClient, args: Record<string, unknown>, storeId?: string) {
  const sid = storeId as string;
  const hoursBack = (args.hours_back as number) || 24;
  const limit = Math.min((args.limit as number) || 50, 200);

  switch (args.action) {
    // ---- conversation_detail: Full conversation with messages + audit entries ----
    case "conversation_detail": {
      const convId = args.conversation_id as string;
      if (!convId) return { success: false, error: "conversation_id is required" };

      const [convResult, msgResult, auditResult] = await Promise.all([
        sb.from("ai_conversations").select("*").eq("id", convId).eq("store_id", sid).single(),
        sb.from("ai_messages").select("*").eq("conversation_id", convId).order("created_at", { ascending: true }),
        sb.from("audit_logs").select("id, action, severity, duration_ms, status_code, error_message, resource_id, input_tokens, output_tokens, model, created_at")
          .eq("conversation_id", convId).order("created_at", { ascending: true }).limit(200)
      ]);
      if (convResult.error) return { success: false, error: convResult.error.message };
      return {
        success: true,
        data: {
          conversation: convResult.data,
          messages: msgResult.data || [],
          audit_entries: auditResult.data || [],
          message_count: msgResult.data?.length || 0,
          audit_count: auditResult.data?.length || 0
        }
      };
    }

    // ---- conversations: List recent conversations ----
    case "conversations": {
      const convLimit = Math.min((args.limit as number) || 20, 100);
      let q = sb.from("ai_conversations")
        .select("*")
        .eq("store_id", sid)
        .gte("created_at", new Date(Date.now() - hoursBack * 3600_000).toISOString())
        .order("created_at", { ascending: false })
        .limit(convLimit);
      if (args.agent_id) q = q.eq("agent_id", args.agent_id as string);
      const { data, error } = await q;
      return error ? { success: false, error: error.message } : { success: true, data: { count: data?.length || 0, conversations: data } };
    }

    // ---- agent_performance: Agent-level analytics via RPC ----
    case "agent_performance": {
      const agentId = args.agent_id as string;
      if (!agentId) return { success: false, error: "agent_id is required" };
      const days = (args.days as number) || 7;
      const { data, error } = await sb.rpc("get_agent_analytics", { p_agent_id: agentId, p_days: days });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- tool_analytics: Per-tool performance metrics via RPC ----
    case "tool_analytics": {
      const { data, error } = await sb.rpc("get_tool_analytics", {
        p_store_id: sid || null,
        p_hours_back: hoursBack,
        p_tool_name: (args.tool_name as string) || null
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- tool_timeline: Time-bucketed tool metrics via RPC ----
    case "tool_timeline": {
      const bucketMinutes = (args.bucket_minutes as number) || 15;
      const { data, error } = await sb.rpc("get_tool_timeline", {
        p_store_id: sid || null,
        p_hours_back: hoursBack,
        p_bucket_minutes: bucketMinutes,
        p_tool_name: (args.tool_name as string) || null
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- trace: Full trace reconstruction via RPC ----
    case "trace": {
      const traceId = args.trace_id as string;
      if (!traceId) return { success: false, error: "trace_id is required" };
      const { data, error } = await sb.rpc("get_trace", { p_trace_id: traceId });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- span_detail: Individual span deep-dive via RPC ----
    case "span_detail": {
      const spanId = args.span_id as string;
      if (!spanId) return { success: false, error: "span_id is required" };
      const { data, error } = await sb.rpc("get_tool_trace_detail", { p_span_id: spanId });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- error_patterns: Error correlation + burst detection via RPC ----
    case "error_patterns": {
      const { data, error } = await sb.rpc("get_tool_error_patterns", {
        p_store_id: sid || null,
        p_hours_back: hoursBack
      });
      return error ? { success: false, error: error.message } : { success: true, data };
    }

    // ---- token_usage: Token consumption by model/day ----
    case "token_usage": {
      const cutoff = new Date(Date.now() - hoursBack * 3600_000).toISOString();
      // Build base query — if agent_id is provided, get conversation IDs first
      let conversationFilter: string[] | null = null;
      if (args.agent_id) {
        const { data: convs } = await sb.from("ai_conversations")
          .select("id").eq("agent_id", args.agent_id as string).eq("store_id", sid);
        conversationFilter = convs?.map(c => c.id) || [];
      }

      let q = sb.from("audit_logs")
        .select("model, input_tokens, output_tokens, total_cost, created_at")
        .eq("store_id", sid)
        .gte("created_at", cutoff)
        .not("input_tokens", "is", null);
      if (conversationFilter !== null) {
        if (conversationFilter.length === 0) return { success: true, data: { rows: [], summary: { total_input: 0, total_output: 0, total_cost: 0 } } };
        q = q.in("conversation_id", conversationFilter);
      }
      const { data, error } = await q.order("created_at", { ascending: false }).limit(1000);
      if (error) return { success: false, error: error.message };

      // Aggregate in-memory by model + day
      const buckets: Record<string, { model: string; day: string; requests: number; input_tokens: number; output_tokens: number; total_cost: number }> = {};
      for (const row of data || []) {
        const day = (row.created_at as string).substring(0, 10);
        const model = row.model || "unknown";
        const key = `${model}|${day}`;
        if (!buckets[key]) buckets[key] = { model, day, requests: 0, input_tokens: 0, output_tokens: 0, total_cost: 0 };
        buckets[key].requests++;
        buckets[key].input_tokens += row.input_tokens || 0;
        buckets[key].output_tokens += row.output_tokens || 0;
        buckets[key].total_cost += parseFloat(row.total_cost || "0");
      }
      const rows = Object.values(buckets).sort((a, b) => b.day.localeCompare(a.day) || b.total_cost - a.total_cost);
      const summary = rows.reduce((acc, r) => ({
        total_input: acc.total_input + r.input_tokens,
        total_output: acc.total_output + r.output_tokens,
        total_cost: acc.total_cost + r.total_cost,
        total_requests: acc.total_requests + r.requests
      }), { total_input: 0, total_output: 0, total_cost: 0, total_requests: 0 });
      return { success: true, data: { rows, summary, hours_back: hoursBack } };
    }

    // ---- sources: List all telemetry sources with counts ----
    case "sources": {
      const cutoff = new Date(Date.now() - hoursBack * 3600_000).toISOString();
      const { data, error } = await sb.from("audit_logs")
        .select("source, severity, created_at")
        .eq("store_id", sid)
        .gte("created_at", cutoff)
        .not("source", "is", null)
        .limit(1000);
      if (error) return { success: false, error: error.message };

      // Aggregate by source
      const sourceMap: Record<string, { source: string; count: number; errors: number; last_seen: string }> = {};
      for (const row of data || []) {
        const src = row.source as string;
        if (!sourceMap[src]) sourceMap[src] = { source: src, count: 0, errors: 0, last_seen: row.created_at as string };
        sourceMap[src].count++;
        if (row.severity === "error") sourceMap[src].errors++;
        if ((row.created_at as string) > sourceMap[src].last_seen) sourceMap[src].last_seen = row.created_at as string;
      }
      const sources = Object.values(sourceMap).sort((a, b) => b.count - a.count);
      return { success: true, data: { sources, total_entries: data?.length || 0, hours_back: hoursBack } };
    }

    default:
      return { success: false, error: `Unknown telemetry action: ${args.action}. Available: conversation_detail, conversations, agent_performance, tool_analytics, tool_timeline, trace, span_detail, error_patterns, token_usage, sources. For activity logs and inventory changes, use the audit_trail tool instead.` };
  }
}
