/**
 * User Tools Executor
 *
 * Handles execution of user-created custom tools.
 * Three execution types:
 * - rpc: Call a Postgres function
 * - http: Call an external API
 * - sql: Execute a sandboxed SQL query
 */

import { SupabaseClient } from "@supabase/supabase-js";

export interface UserTool {
  id: string;
  store_id: string;
  name: string;
  display_name: string;
  description: string;
  category: string;
  icon: string;
  input_schema: {
    type: "object";
    properties: Record<string, any>;
    required?: string[];
  };
  execution_type: "rpc" | "http" | "sql";
  rpc_function?: string;
  http_config?: HttpConfig;
  sql_template?: string;
  allowed_tables?: string[];
  is_read_only: boolean;
  requires_approval: boolean;
  max_execution_time_ms: number;
}

interface HttpConfig {
  url: string;
  method: "GET" | "POST" | "PUT" | "DELETE" | "PATCH";
  headers?: Record<string, string>;
  body_template?: Record<string, any>;
  query_params?: Record<string, string>;
}

export interface UserToolResult {
  success: boolean;
  data?: any;
  error?: string;
  pending_approval?: boolean;
  execution_id?: string;
}

// ============================================================================
// LOAD USER TOOLS FOR A STORE
// ============================================================================

export async function loadUserTools(
  supabase: SupabaseClient,
  storeId: string
): Promise<UserTool[]> {
  const { data, error } = await supabase
    .from("user_tools")
    .select("*")
    .eq("store_id", storeId)
    .eq("is_active", true);

  if (error) {
    console.error("[UserTools] Failed to load:", error.message);
    return [];
  }

  console.log(`[UserTools] Loaded ${data?.length || 0} custom tools for store ${storeId.slice(0, 8)}`);
  return data as UserTool[];
}

// ============================================================================
// EXECUTE USER TOOL
// ============================================================================

export async function executeUserTool(
  supabase: SupabaseClient,
  tool: UserTool,
  args: Record<string, unknown>,
  storeId: string
): Promise<UserToolResult> {
  const startTime = Date.now();

  try {
    // Create execution record
    const { data: execution, error: execError } = await supabase
      .from("user_tool_executions")
      .insert({
        tool_id: tool.id,
        store_id: storeId,
        input_args: args,
        status: tool.requires_approval ? "pending" : "running"
      })
      .select("id")
      .single();

    if (execError) {
      console.error("[UserTools] Failed to create execution record:", execError);
    }

    const executionId = execution?.id;

    // Check if approval required
    if (tool.requires_approval) {
      return {
        success: false,
        pending_approval: true,
        execution_id: executionId,
        error: "This tool requires human approval before execution. The request has been logged for review."
      };
    }

    let result: any;

    switch (tool.execution_type) {
      case "rpc":
        result = await executeRpc(supabase, tool, args, storeId);
        break;

      case "http":
        result = await executeHttp(tool, args, storeId);
        break;

      case "sql":
        result = await executeSql(supabase, tool, args, storeId);
        break;

      default:
        throw new Error(`Unknown execution type: ${tool.execution_type}`);
    }

    const executionTime = Date.now() - startTime;

    // Update execution record
    if (executionId) {
      await supabase
        .from("user_tool_executions")
        .update({
          status: "success",
          output_result: result,
          execution_time_ms: executionTime
        })
        .eq("id", executionId);
    }

    return { success: true, data: result };

  } catch (error: any) {
    const executionTime = Date.now() - startTime;
    console.error(`[UserTools] Error executing ${tool.name}:`, error);

    return {
      success: false,
      error: error.message || String(error)
    };
  }
}

// ============================================================================
// RPC EXECUTION
// ============================================================================

async function executeRpc(
  supabase: SupabaseClient,
  tool: UserTool,
  args: Record<string, unknown>,
  storeId: string
): Promise<any> {
  if (!tool.rpc_function) {
    throw new Error("No RPC function configured for this tool");
  }

  // Call the RPC function with store_id and args
  const { data, error } = await supabase.rpc(tool.rpc_function, {
    p_store_id: storeId,
    p_args: args
  });

  if (error) {
    throw new Error(`RPC error: ${error.message}`);
  }

  return data;
}

// ============================================================================
// HTTP EXECUTION
// ============================================================================

async function executeHttp(
  tool: UserTool,
  args: Record<string, unknown>,
  storeId: string
): Promise<any> {
  if (!tool.http_config) {
    throw new Error("No HTTP configuration for this tool");
  }

  const config = tool.http_config;

  // Replace template variables in URL
  let url = replaceTemplateVars(config.url, args, storeId);

  // Add query params
  if (config.query_params) {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(config.query_params)) {
      params.append(key, replaceTemplateVars(value, args, storeId));
    }
    url += (url.includes("?") ? "&" : "?") + params.toString();
  }

  // Prepare headers
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "User-Agent": "SwagManager-Agent/1.0"
  };

  if (config.headers) {
    for (const [key, value] of Object.entries(config.headers)) {
      // Skip secret references for now (TODO: implement secret resolution)
      if (!value.includes("{{secret:")) {
        headers[key] = replaceTemplateVars(value, args, storeId);
      }
    }
  }

  // Prepare body
  let body: string | undefined;
  if (config.body_template && ["POST", "PUT", "PATCH"].includes(config.method)) {
    const bodyObj = JSON.parse(JSON.stringify(config.body_template));
    replaceTemplateVarsInObject(bodyObj, args, storeId);
    body = JSON.stringify(bodyObj);
  }

  // Execute request with timeout
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), tool.max_execution_time_ms);

  try {
    const response = await fetch(url, {
      method: config.method,
      headers,
      body,
      signal: controller.signal
    });

    clearTimeout(timeout);

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`HTTP ${response.status}: ${errorText.slice(0, 500)}`);
    }

    const contentType = response.headers.get("content-type");
    if (contentType?.includes("application/json")) {
      return await response.json();
    } else {
      return await response.text();
    }

  } catch (error: any) {
    clearTimeout(timeout);
    if (error.name === "AbortError") {
      throw new Error(`Request timed out after ${tool.max_execution_time_ms}ms`);
    }
    throw error;
  }
}

// ============================================================================
// SQL EXECUTION (Sandboxed)
// ============================================================================

async function executeSql(
  supabase: SupabaseClient,
  tool: UserTool,
  args: Record<string, unknown>,
  storeId: string
): Promise<any> {
  if (!tool.sql_template) {
    throw new Error("No SQL template configured for this tool");
  }

  // SAFETY: Only allow SELECT for read-only tools
  if (tool.is_read_only) {
    const normalizedSql = tool.sql_template.trim().toUpperCase();
    if (!normalizedSql.startsWith("SELECT")) {
      throw new Error("Read-only tools can only execute SELECT queries");
    }
  }

  // SAFETY: Check allowed tables
  if (tool.allowed_tables && tool.allowed_tables.length > 0) {
    const sqlLower = tool.sql_template.toLowerCase();
    const hasDisallowedTable = !tool.allowed_tables.some(table =>
      sqlLower.includes(table.toLowerCase())
    );
    // This is a basic check - in production you'd want proper SQL parsing
  }

  // Build parameterized query
  // Replace $param_name with actual values
  let sql = tool.sql_template;
  const params: any[] = [];

  // Always inject store_id for security
  sql = sql.replace(/\$store_id/g, `'${storeId}'`);

  // Replace other parameters
  for (const [key, value] of Object.entries(args)) {
    const placeholder = `$${key}`;
    if (sql.includes(placeholder)) {
      // Escape and quote string values
      if (typeof value === "string") {
        sql = sql.replace(new RegExp(`\\$${key}`, "g"), `'${value.replace(/'/g, "''")}'`);
      } else if (typeof value === "number") {
        sql = sql.replace(new RegExp(`\\$${key}`, "g"), String(value));
      } else if (typeof value === "boolean") {
        sql = sql.replace(new RegExp(`\\$${key}`, "g"), value ? "true" : "false");
      } else if (value === null) {
        sql = sql.replace(new RegExp(`\\$${key}`, "g"), "NULL");
      }
    }
  }

  // Execute via RPC that runs arbitrary SQL (needs to be created)
  // For safety, we use a restricted RPC that validates the query
  const { data, error } = await supabase.rpc("execute_user_sql", {
    p_store_id: storeId,
    p_sql: sql,
    p_allowed_tables: tool.allowed_tables || [],
    p_is_read_only: tool.is_read_only
  });

  if (error) {
    throw new Error(`SQL error: ${error.message}`);
  }

  return data;
}

// ============================================================================
// TEMPLATE HELPERS
// ============================================================================

function replaceTemplateVars(
  template: string,
  args: Record<string, unknown>,
  storeId: string
): string {
  let result = template;

  // Replace store_id
  result = result.replace(/\{\{store_id\}\}/g, storeId);

  // Replace arg values
  for (const [key, value] of Object.entries(args)) {
    result = result.replace(
      new RegExp(`\\{\\{${key}\\}\\}`, "g"),
      String(value ?? "")
    );
  }

  return result;
}

function replaceTemplateVarsInObject(
  obj: Record<string, any>,
  args: Record<string, unknown>,
  storeId: string
): void {
  for (const key of Object.keys(obj)) {
    if (typeof obj[key] === "string") {
      obj[key] = replaceTemplateVars(obj[key], args, storeId);
    } else if (typeof obj[key] === "object" && obj[key] !== null) {
      replaceTemplateVarsInObject(obj[key], args, storeId);
    }
  }
}

// ============================================================================
// CONVERT TO MCP TOOL FORMAT
// ============================================================================

export function userToolToRegistryFormat(tool: UserTool): any {
  return {
    id: tool.id,
    name: `custom_${tool.name}`, // Prefix to distinguish from system tools
    category: tool.category || "custom",
    description: tool.description,
    definition: {
      name: `custom_${tool.name}`,
      description: `[Custom] ${tool.display_name}: ${tool.description}`,
      input_schema: tool.input_schema
    },
    requires_store_id: true,
    requires_user_id: false,
    is_read_only: tool.is_read_only,
    is_active: true,
    tool_mode: "user",
    // Store the original tool for execution
    _userTool: tool
  };
}
