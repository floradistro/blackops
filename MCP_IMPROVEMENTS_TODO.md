# MCP Management System - Theme & Data Improvements

## Issues to Fix:

### 1. Theme Mismatch
Current MCP views use generic SwiftUI styling. Need to match SwagManager's visual theme:
- Use `VisualEffectBackground` with `.sidebar` and `.underWindowBackground` materials
- Remove generic `Color.primary.opacity()` backgrounds
- Match button styles, padding, and spacing from existing views
- Use `DesignSystem.Spacing` constants consistently
- Match card/panel styling from other detail views

### 2. Data Not Wired Up
Current implementation uses placeholder data. Real data available:

**lisa_tool_execution_log table** (3,560 executions, 116 tools):
- `tool_name` - which MCP server was called
- `execution_time_ms` - response time
- `result_status` - 'success' or 'error'
- `error_message` - error details if failed
- `created_at` - timestamp
- `store_id` - scoped to store

**RLS Policies**: Already configured for user access based on store_id

### 3. Functions Not Implemented
- `MCPEditor.save()` - needs raw HTTP POST to ai_tool_registry
- `MCPTestRunner.executeRPC()` - works but needs better param handling
- `MCPTestRunner.executeEdgeFunction()` - placeholder only
- `MCPMonitor.loadStats()` - partially implemented, needs real aggregation

## Implementation Steps:

### Phase 1: Fix Data Layer
1. Update `MCPMonitor` to query real execution data:
   ```swift
   - Query lisa_tool_execution_log with time filters
   - Calculate real success rates
   - Get actual execution times
   - Aggregate by tool_name
   ```

2. Fix column names in `RawExecution` model:
   - `execution_time_ms` (not `duration_ms`)
   - `result_status` (not `success`)
   - Add proper success calculation: `result_status == "success"`

3. Map tool_name to category via ai_tool_registry JOIN

### Phase 2: Apply Theme
1. Replace all `Color.primary.opacity(0.05)` with `VisualEffectBackground`
2. Use proper corner radii (4-8px, not variable)
3. Match existing card styling from CustomerDetailPanel, OrderDetailPanel
4. Use consistent icon sizes and weights
5. Match spacing/padding from sidebar sections

### Phase 3: Implement Missing Functions
1. `MCPEditor.save()`: Use URLSession to POST JSON directly to Supabase REST API
2. `MCPTestRunner.executeEdgeFunction()`: Call tools-gateway with proper body format
3. Add proper error handling and user feedback

### Phase 4: Add Missing Features
1. Batch testing (run multiple tools at once)
2. Export test results to JSON/CSV
3. Schedule automated health checks
4. Alert on error rate thresholds
5. Favorite/pin frequently used servers

## Quick Wins (Do These First):
- [ ] Fix MCPMonitor data source (20 min)
- [ ] Apply VisualEffectBackground to all views (15 min)
- [ ] Match card padding/spacing (10 min)
- [ ] Add real success rate calculation (5 min)
- [ ] Fix tab bar styling to match app theme (10 min)

## Database Queries Needed:

```sql
-- Success rate by tool
SELECT
  tool_name,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE result_status = 'success') as successes,
  ROUND(100.0 * COUNT(*) FILTER (WHERE result_status = 'success') / COUNT(*), 1) as success_rate,
  AVG(execution_time_ms) as avg_time_ms
FROM lisa_tool_execution_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY tool_name
ORDER BY total DESC;

-- Recent executions
SELECT tool_name, result_status, execution_time_ms, error_message, created_at
FROM lisa_tool_execution_log
ORDER BY created_at DESC
LIMIT 50;

-- Error log
SELECT tool_name, error_code, error_message, created_at
FROM lisa_tool_execution_log
WHERE result_status = 'error'
ORDER BY created_at DESC
LIMIT 20;
```
