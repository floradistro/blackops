# How to Test MCP Servers Fix

## What I Fixed

1. **Database is correct** - Verified that `rpc_function`, `edge_function`, and `tool_mode` columns exist and have data
2. **PostgREST API is correct** - Verified the REST API returns these columns properly
3. **Code is updated** - EditorStore now logs the raw JSON to show if columns are present

## Testing Steps in Xcode

1. **Clean Build**
   - In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

2. **Rebuild**
   - Product → Build (Cmd+B)

3. **Run**
   - Product → Run (Cmd+R)

4. **Check Console Logs**
   - When app loads, look for these log lines in Xcode console:
     ```
     [EditorStore] 🔍 First server raw JSON keys: ...
     [EditorStore] 🔍 rpc_function = ...
     [EditorStore] 🔍 edge_function = ...
     [EditorStore] 🔍 tool_mode = ...
     ```

5. **Test an MCP Server**
   - Click on "locations_list" in the MCP Servers sidebar
   - Click "Execute Test"
   - Should work now (edge_function = "tools-gateway")

## What to Look For

✅ **SUCCESS**: Console shows `rpc_function = alerts_query` or `edge_function = tools-gateway`
❌ **FAILURE**: Console shows `rpc_function = NULL` and `edge_function = NULL`

## If Still Failing

Send me the console output lines that start with `[EditorStore] 🔍`
