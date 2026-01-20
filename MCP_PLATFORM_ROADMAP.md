# MCP Platform Roadmap - SwagManager

## 🎯 Vision
Transform SwagManager into a **production MCP platform** that competes with n8n/Zapier but with:
- Context-aware automation (knows your business)
- Built-in debugging/monitoring
- Marketplace for developers to sell tools
- Simple, not complex

---

## ✅ COMPLETED - Debugging Infrastructure

### **Execution History & Inspector**
Now developers can debug their MCP tools like browser DevTools:

**Features Built:**
1. **ExecutionHistoryView** - Searchable list of all 3,560+ executions
   - Filter by: status (success/failed), time range, tool name
   - Real-time search
   - Click any row → full details

2. **ExecutionDetailView** - Full request/response inspector
   - **Overview Tab**: Status, duration, metadata, errors
   - **Request Tab**: Parameters, HTTP method/URL, headers
   - **Response Tab**: Response body, status code, headers
   - **Timeline Tab**: (Coming soon) Visual execution timeline

3. **Developer Actions**:
   - ✅ "Replay" button - re-run with same params
   - ✅ "Copy as cURL" - get exact curl command
   - ✅ Copy request/response JSON
   - ✅ See execution time breakdown

**Files Created:**
- `SwagManager/Models/ExecutionDetail.swift` - Full execution data model
- `SwagManager/Views/MCP/ExecutionHistoryView.swift` - History list
- `SwagManager/Views/MCP/ExecutionDetailView.swift` - Detail inspector
- Updated `MCPMonitoringView.swift` - Added History tab

**Usage:**
```
Menu > MCP > Monitor MCP Servers
→ Click "History" tab
→ Search/filter executions
→ Click any execution
→ See full request/response
→ Copy as cURL or replay
```

---

## 🚧 NEXT UP - API Platform Features

### **Phase 1: API Authentication** (Week 1)

**Goal:** Let external developers call your 186 MCP tools via API

**Database Schema:**
```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key_prefix TEXT NOT NULL, -- "sk_live_abc"
  key_hash TEXT NOT NULL, -- bcrypt hash
  user_id UUID REFERENCES auth.users(id),
  store_id UUID REFERENCES stores(id),
  name TEXT, -- "Production API", "Staging"
  permissions JSONB DEFAULT '{"tools": "*", "read_only": false}',
  rate_limit INTEGER DEFAULT 1000, -- per hour
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);
CREATE INDEX idx_api_keys_user ON api_keys(user_id);
```

**Implementation:**
1. API Key generation UI in SwagManager
2. Middleware to validate keys on requests
3. Rate limiting per key
4. Usage tracking (link to lisa_tool_execution_log)

**Files to Create:**
- `SwagManager/Models/APIKey.swift`
- `SwagManager/Views/MCP/APIKeyManagementView.swift`
- `supabase/functions/validate-api-key/index.ts`

---

### **Phase 2: Usage Metering** (Week 2)

**Goal:** Track API usage per key for billing

**Database Updates:**
```sql
ALTER TABLE lisa_tool_execution_log
ADD COLUMN api_key_id UUID REFERENCES api_keys(id),
ADD COLUMN billable BOOLEAN DEFAULT true;

CREATE TABLE api_usage_summary (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  api_key_id UUID REFERENCES api_keys(id),
  tool_name TEXT,
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  call_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  total_execution_ms BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(api_key_id, tool_name, period_start)
);
```

**Features:**
- Real-time usage dashboard per API key
- Daily/weekly/monthly rollups
- Cost calculation (if you add pricing)
- Usage alerts (approaching limits)

**Files to Create:**
- `SwagManager/Views/MCP/UsageDashboardView.swift`
- `supabase/functions/rollup-usage/index.ts` (cron job)

---

### **Phase 3: Public API Endpoints** (Week 3)

**Goal:** External developers can call: `POST /api/v1/tools/{tool_name}`

**Edge Function:**
```typescript
// supabase/functions/tools-gateway/index.ts

import { serve } from "std/http/server.ts"
import { createClient } from '@supabase/supabase-js'

serve(async (req) => {
  // 1. Validate API key from header
  const apiKey = req.headers.get('Authorization')?.replace('Bearer ', '')

  // 2. Check rate limits

  // 3. Parse tool name from URL
  const url = new URL(req.url)
  const toolName = url.pathname.split('/').pop()

  // 4. Get tool definition from ai_tool_registry

  // 5. Execute RPC or edge function

  // 6. Log to lisa_tool_execution_log

  // 7. Return result
})
```

**API Documentation Auto-Generation:**
```
GET /api/v1/tools → List all available tools
GET /api/v1/tools/{name} → Get tool definition (OpenAPI spec)
POST /api/v1/tools/{name} → Execute tool
```

**Files to Create:**
- `supabase/functions/tools-gateway/index.ts`
- `supabase/functions/tools-list/index.ts`
- `SwagManager/Views/MCP/APIDocsView.swift` (renders OpenAPI)

---

### **Phase 4: Tool Chaining/Sequences** (Month 2)

**Goal:** Create workflows like n8n but simpler

**Database Schema:**
```sql
CREATE TABLE tool_sequences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  steps JSONB NOT NULL, -- Array of tool calls
  trigger JSONB, -- { type: "webhook", url: "..." } or { type: "schedule", cron: "..." }
  store_id UUID REFERENCES stores(id),
  created_by UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE sequence_executions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sequence_id UUID REFERENCES tool_sequences(id),
  status TEXT, -- "running", "completed", "failed"
  step_results JSONB, -- Results from each step
  error_message TEXT,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```

**Example Sequence:**
```json
{
  "name": "Fulfill Order Workflow",
  "steps": [
    {
      "tool": "validate_inventory",
      "params": { "order_id": "{{trigger.order_id}}" },
      "on_success": "next",
      "on_failure": "abort"
    },
    {
      "tool": "create_shipping_label",
      "params": { "order_id": "{{trigger.order_id}}" },
      "save_output_as": "tracking_number"
    },
    {
      "tool": "update_order_status",
      "params": {
        "order_id": "{{trigger.order_id}}",
        "tracking": "{{steps.1.tracking_number}}"
      }
    },
    {
      "tool": "send_customer_email",
      "params": {
        "template": "order_shipped",
        "tracking": "{{steps.1.tracking_number}}"
      }
    }
  ],
  "trigger": {
    "type": "webhook",
    "event": "order.paid"
  }
}
```

**Visual Builder:**
- Drag & drop tools to create sequence
- Visual flow diagram
- Test sequences with sample data
- See execution history

**Files to Create:**
- `SwagManager/Models/ToolSequence.swift`
- `SwagManager/Views/MCP/SequenceBuilderView.swift`
- `supabase/functions/execute-sequence/index.ts`

---

### **Phase 5: Marketplace** (Month 3)

**Goal:** Let external developers publish tools and earn revenue

**Database Schema:**
```sql
CREATE TABLE marketplace_tools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tool_id UUID REFERENCES ai_tool_registry(id),
  developer_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  pricing_model TEXT, -- "free", "pay_per_use", "subscription"
  price_per_call DECIMAL(10,2),
  monthly_price DECIMAL(10,2),
  is_published BOOLEAN DEFAULT false,
  install_count INTEGER DEFAULT 0,
  rating DECIMAL(3,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tool_installations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  marketplace_tool_id UUID REFERENCES marketplace_tools(id),
  store_id UUID REFERENCES stores(id),
  api_key_id UUID REFERENCES api_keys(id),
  installed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE marketplace_revenue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  marketplace_tool_id UUID REFERENCES marketplace_tools(id),
  developer_id UUID REFERENCES auth.users(id),
  execution_id UUID REFERENCES lisa_tool_execution_log(id),
  amount DECIMAL(10,2), -- Developer's cut (80%)
  platform_fee DECIMAL(10,2), -- Your cut (20%)
  status TEXT, -- "pending", "paid", "failed"
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Revenue Model:**
- Developers keep 80%
- Platform takes 20%
- Stripe Connect for payouts

**Files to Create:**
- `SwagManager/Views/MCP/MarketplaceView.swift`
- `SwagManager/Views/MCP/PublishToolSheet.swift`
- `supabase/functions/marketplace-install/index.ts`

---

## 📊 Success Metrics

### **Phase 1 Success** (API Authentication)
- [ ] 10 external developers have API keys
- [ ] 100+ API calls/day from external sources
- [ ] API documentation published

### **Phase 2 Success** (Usage Metering)
- [ ] Usage dashboard shows real-time metrics
- [ ] Rate limiting prevents abuse
- [ ] First paid customer (if pricing added)

### **Phase 3 Success** (Public API)
- [ ] API listed on RapidAPI or similar
- [ ] 50+ external API consumers
- [ ] $500 MRR from API usage

### **Phase 4 Success** (Sequences)
- [ ] 20+ sequences created by users
- [ ] 100+ sequence executions/day
- [ ] Users report "easier than n8n"

### **Phase 5 Success** (Marketplace)
- [ ] 5 external developers publishing tools
- [ ] 50+ tool installations
- [ ] $2,000 GMV/month

---

## 🎁 Quick Wins (Do These Now)

### **This Week:**
1. ✅ Execution history/inspector (DONE!)
2. [ ] Add "Replay" functionality to test form
3. [ ] Add webhook support (5 hours work)

### **Next Week:**
4. [ ] API key generation UI (3 hours)
5. [ ] Public API endpoint (8 hours)
6. [ ] Write blog post: "Building a Production MCP Platform"

### **Month 1:**
7. [ ] Launch on Product Hunt
8. [ ] Get first external API customer
9. [ ] Add usage-based pricing

---

## 💰 Pricing Model Ideas

### **Free Tier:**
- 1,000 API calls/month
- 5 tool sequences
- Community support

### **Pro Tier ($29/mo):**
- 10,000 API calls/month
- Unlimited sequences
- Email support
- Webhook triggers

### **Business Tier ($99/mo):**
- 100,000 API calls/month
- Custom tools
- Priority support
- SSO/RBAC

### **Enterprise ($499+/mo):**
- Unlimited usage
- White-label
- SLA
- Dedicated support

---

## 🚀 Go-to-Market

### **Positioning:**
"The first production platform for Anthropic MCP servers"

### **Target Audiences:**
1. AI developers using Claude with tools
2. E-commerce companies needing automation
3. Vertical SaaS building industry tools

### **Launch Strategy:**
1. Open source an MCP client library
2. Write technical blog posts
3. Post on HackerNews, Reddit r/MachineLearning
4. Get featured on Anthropic's MCP examples

### **Competitive Advantages:**
- ✅ MCP-native (not retrofitted)
- ✅ Context-aware by default
- ✅ Production debugging built-in
- ✅ Simpler than n8n
- ✅ Cheaper than Zapier

---

## 📝 Next Steps

**Immediate (Today):**
1. Test the execution history viewer
2. Find any bugs in debugging UI
3. Add "Replay" button functionality

**This Week:**
1. Implement API key management
2. Create public API endpoint
3. Write API documentation

**This Month:**
1. Launch beta to 10 developers
2. Get feedback on DX
3. Add webhooks and scheduling
4. Prepare for Product Hunt launch

Want me to start implementing API key management next?
