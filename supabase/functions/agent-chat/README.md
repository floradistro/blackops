# Agent Chat Edge Function

Production-ready Claude Agent endpoint with streaming and tool execution.
Follows Anthropic SDK best practices.

## Deployment

```bash
# Set required secrets (do this once)
supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-your-key-here

# Deploy the function
supabase functions deploy agent-chat
```

## Usage

### Request

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agentId": "a97de4f5-e98c-4b3b-aec9-19ca88602084",
    "storeId": "cd2e1122-d511-4edb-be5d-98ef274b4baf",
    "message": "Show me inventory summary",
    "conversationHistory": []
  }' \
  https://uaednwpxursknmwdeejn.supabase.co/functions/v1/agent-chat
```

### Response (SSE Stream)

```
data: {"type":"text","text":"Let me check "}
data: {"type":"text","text":"the inventory..."}
data: {"type":"tool_start","name":"inventory_summary"}
data: {"type":"tool_result","name":"inventory_summary","success":true,"result":{...}}
data: {"type":"text","text":"Here's your inventory summary..."}
data: {"type":"usage","usage":{"input_tokens":150,"output_tokens":320}}
data: {"type":"done"}
```

## Architecture

```
SwiftUI App (AIChatPane)
    │
    │ POST + SSE Stream
    ▼
agent-chat Edge Function
    │
    ├─► Load agent from ai_agent_config
    ├─► Load tools based on agent.enabled_tools
    ├─► Call Claude API with streaming
    ├─► Execute tools via Supabase RPC
    ├─► Log to agent_execution_traces
    └─► Stream events back to client
```

## Available Tools

The function includes these tools that map to actual database operations:

### Inventory
- `inventory_summary` - Get inventory grouped by category/location/product
- `inventory_adjust` - Adjust inventory quantities
- `inventory_transfer` - Transfer between locations

### Orders
- `orders_list` - List orders with filters
- `order_details` - Get full order details

### Customers
- `customers_search` - Search by name/email/phone
- `customer_details` - Get customer profile
- `customer_loyalty_adjust` - Adjust loyalty points

### Products
- `products_search` - Search products
- `product_details` - Get product details

### Analytics
- `analytics_sales` - Sales analytics
- `analytics_inventory` - Inventory analytics

### Locations
- `locations_list` - List store locations

## Adding New Tools

1. Add tool definition to `TOOL_DEFINITIONS` array
2. Add mapping in `TOOL_TO_RPC` (or use `__direct_query__`)
3. If using direct query, add handler in `executeDirectQuery()`

## Environment Variables

Required in Supabase:
- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `SUPABASE_URL` - Auto-provided
- `SUPABASE_SERVICE_ROLE_KEY` - Auto-provided
