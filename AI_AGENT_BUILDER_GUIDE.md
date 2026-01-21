# AI Agent Builder Guide for SwagManager

## Overview

You already have **all the infrastructure** needed to build sophisticated AI agents using your MCP servers. This guide shows you how to leverage your existing capabilities to create autonomous agents that can execute workflows, handle customer requests, and automate operations.

---

## Why Build AI Agents?

### 1. **Automated Workflows**
- Customer service agent that answers questions using your product catalog MCP tools
- Inventory management agent that monitors stock and triggers reorders
- Marketing agent that creates campaigns based on sales data
- Order fulfillment agent that processes orders and updates customers

### 2. **24/7 Operations**
- Agents work continuously without downtime
- Handle multiple tasks simultaneously across locations
- Scale instantly based on demand

### 3. **Consistency & Compliance**
- Agents follow exact procedures every time
- All actions logged in `lisa_tool_execution_log`
- Audit trail via `wilson_tool_executions`

### 4. **Cost Reduction**
- Automate repetitive tasks (data entry, reports, notifications)
- Reduce human error
- Free staff for higher-value work

---

## Your Current Architecture (Already Built!)

### Backend Infrastructure ✅

**MCP Tool Registry:**
```
ai_tool_registry - 300+ tools organized by category
  ├── category (crm, inventory, orders, analytics, etc.)
  ├── rpc_function (database function name)
  ├── edge_function (Supabase Edge Function)
  ├── tool_mode (ops, admin, customer, etc.)
  └── definition (JSON schema for parameters)
```

**Agent Configuration:**
```
agents - Agent definitions
  ├── name, description, system_prompt
  ├── enabled_tools[] (specific tools this agent can use)
  ├── enabled_categories[] (tool categories like "crm", "inventory")
  ├── personality (tone, verbosity, proactivity)
  └── knowledge_sources (RAG data sources)

ai_agent_config - Store-level agent settings
  ├── store_id, system_prompt, model
  ├── max_tool_calls, max_tokens
  └── version control
```

**Conversation & Execution Tracking:**
```
wilson_conversations - Agent conversation history
  ├── messages (full conversation context)
  ├── tool_call_count, total_turns, loop_depth
  ├── cost tracking (input_tokens, output_tokens)
  └── status monitoring

wilson_tool_executions - Detailed tool execution logs
  ├── tool_name, input, output, status
  ├── execution_time_ms, error tracking
  └── parallel execution support

lisa_tool_execution_log - System-wide tool execution audit
  ├── result_status, execution_time_ms
  └── error_message
```

### Frontend UI ✅

**Already Built Components:**
- `MCPMonitoringView` - Real-time tool execution monitoring
- `MCPDeveloperView` - Test tools manually
- `ChatStore` - Conversation management
- `EditorStore+MCPServers` - MCP server management
- Tree components for all major entities

---

## How to Build Agents (3 Approaches)

### Approach 1: **Conversation-Based Agents (Easiest)**

**Best for:** Customer service, interactive assistants, Q&A

**How it works:**
1. User sends message in `TeamChatView`
2. Backend AI processes message
3. AI decides which MCP tools to call
4. Results returned to conversation

**Implementation:**

```swift
// SwagManager/Stores/AgentStore.swift
@MainActor
class AgentStore: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var activeConversations: [WilsonConversation] = []

    private let supabase = SupabaseService.shared

    // Load configured agents
    func loadAgents() async throws {
        let response = try await supabase.client
            .from("agents")
            .select("*")
            .execute()

        let decoder = JSONDecoder.supabaseDecoder
        agents = try decoder.decode([Agent].self, from: response.data)
    }

    // Start a conversation with an agent
    func startConversation(
        agentId: UUID,
        initialMessage: String,
        storeId: UUID? = nil
    ) async throws -> WilsonConversation {
        // Create wilson_conversation
        let conv = WilsonConversationInsert(
            storeId: storeId,
            userId: try await supabase.client.auth.user().id,
            messages: [["role": "user", "content": initialMessage]],
            status: "active"
        )

        let response = try await supabase.client
            .from("wilson_conversations")
            .insert(conv)
            .select()
            .single()
            .execute()

        let conversation = try JSONDecoder.supabaseDecoder
            .decode(WilsonConversation.self, from: response.data)

        // Trigger agent processing via Edge Function
        await processAgentTurn(conversationId: conversation.id, agentId: agentId)

        return conversation
    }

    // Agent processes the conversation and calls tools
    private func processAgentTurn(
        conversationId: UUID,
        agentId: UUID
    ) async {
        // Call your existing edge function to run the agent
        // Agent will:
        // 1. Read conversation messages
        // 2. Load agent config (enabled_tools, system_prompt)
        // 3. Call Claude API with available tools
        // 4. Execute tool calls via MCP
        // 5. Append results to conversation
        // 6. Continue until task complete

        do {
            let _ = try await supabase.client.functions.invoke(
                "agent-conversation-turn",
                options: FunctionInvokeOptions(
                    body: [
                        "conversation_id": conversationId.uuidString,
                        "agent_id": agentId.uuidString
                    ]
                )
            )
        } catch {
            NSLog("[AgentStore] Error processing turn: \(error)")
        }
    }
}

// Models
struct Agent: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let systemPrompt: String?
    let enabledTools: [String]
    let enabledCategories: [String]
    let maxTokensPerResponse: Int?
    let personality: Personality?

    struct Personality: Codable {
        let tone: String
        let verbosity: String
        let proactivity: String
    }
}

struct WilsonConversation: Codable, Identifiable {
    let id: UUID
    let storeId: UUID?
    let userId: UUID
    let title: String?
    let messages: [[String: Any]]
    let toolCallCount: Int
    let status: String
    let createdAt: Date
}
```

**UI Component:**

```swift
// SwagManager/Views/Agents/AgentChatView.swift
struct AgentChatView: View {
    @StateObject private var store = AgentStore()
    @State private var selectedAgent: Agent?
    @State private var messageText = ""

    var body: some View {
        HSplitView {
            // Agent Selector
            List(store.agents) { agent in
                AgentRow(agent: agent)
                    .onTapGesture {
                        selectedAgent = agent
                    }
            }
            .frame(minWidth: 250)

            // Chat Interface
            if let agent = selectedAgent {
                VStack {
                    // Messages
                    ScrollView {
                        // Show conversation messages
                    }

                    // Input
                    HStack {
                        TextField("Message...", text: $messageText)
                        Button("Send") {
                            Task {
                                try? await store.startConversation(
                                    agentId: agent.id,
                                    initialMessage: messageText
                                )
                                messageText = ""
                            }
                        }
                    }
                }
            }
        }
        .task {
            try? await store.loadAgents()
        }
    }
}
```

---

### Approach 2: **Background Task Agents (Most Powerful)**

**Best for:** Scheduled tasks, monitoring, automation

**How it works:**
1. Agent runs on schedule or triggered by event
2. Executes workflow using multiple MCP tools
3. Logs all actions, handles errors
4. Reports results

**Example: Inventory Monitor Agent**

```typescript
// supabase/functions/agent-inventory-monitor/index.ts
import { createClient } from '@supabase/supabase-js'

interface AgentContext {
  agent_id: string
  store_id: string
  enabled_tools: string[]
}

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { agent_id, store_id } = await req.json()

  // 1. Load agent configuration
  const { data: agent } = await supabase
    .from('agents')
    .select('*')
    .eq('id', agent_id)
    .single()

  // 2. Get low stock items using MCP tool
  const { data: lowStock } = await supabase.rpc(
    'inventory_query', // Your existing MCP tool
    {
      store_id,
      filters: { stock_level: 'low' }
    }
  )

  // 3. For each low stock item, create reorder
  for (const item of lowStock) {
    // Log tool execution
    await supabase.from('wilson_tool_executions').insert({
      conversation_id: null, // Background task, no conversation
      tool_name: 'purchase_order_create',
      tool_id: crypto.randomUUID(),
      input: {
        product_id: item.product_id,
        quantity: item.reorder_quantity,
        supplier_id: item.preferred_supplier_id
      },
      status: 'started'
    })

    // Call MCP tool to create PO
    const { data: po, error } = await supabase.rpc(
      'purchase_order_create',
      {
        store_id,
        product_id: item.product_id,
        quantity: item.reorder_quantity,
        supplier_id: item.preferred_supplier_id
      }
    )

    if (error) {
      // Log error
      await supabase.from('wilson_tool_executions').insert({
        tool_name: 'purchase_order_create',
        status: 'error',
        error_message: error.message
      })
      continue
    }

    // 4. Send notification via MCP
    await supabase.rpc('notification_send', {
      store_id,
      title: `Reorder Created: ${item.product_name}`,
      message: `PO #${po.id} created for ${item.product_name}`,
      type: 'inventory'
    })
  }

  return new Response(
    JSON.stringify({
      success: true,
      items_processed: lowStock.length
    }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
```

**Schedule it:**
```sql
-- Use pg_cron or Supabase scheduled functions
SELECT cron.schedule(
  'inventory-agent-hourly',
  '0 * * * *', -- Every hour
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/agent-inventory-monitor',
    body := '{"agent_id": "....", "store_id": "..."}'::jsonb
  );
  $$
);
```

---

### Approach 3: **UI-Embedded Agents (Most Integrated)**

**Best for:** Real-time assistance within existing UI

**How it works:**
1. User performs action in UI (e.g., views order)
2. Agent watches context, offers suggestions
3. User can accept/reject agent actions
4. Agent executes via MCP tools

**Example: Smart Order Assistant**

```swift
// SwagManager/Stores/OrderAgentStore.swift
@MainActor
class OrderAgentStore: ObservableObject {
    @Published var suggestions: [AgentSuggestion] = []
    @Published var isProcessing = false

    private let supabase = SupabaseService.shared

    // Analyze order and generate suggestions
    func analyzeOrder(_ order: Order) async {
        isProcessing = true
        defer { isProcessing = false }

        suggestions = []

        // Check if customer has wallet pass
        let hasWalletPass = await checkCustomerWalletPass(order.customerId)
        if !hasWalletPass {
            suggestions.append(AgentSuggestion(
                type: .walletPass,
                title: "Create Wallet Pass",
                description: "Customer doesn't have a wallet pass yet",
                action: { [weak self] in
                    await self?.createWalletPass(order.customerId)
                }
            ))
        }

        // Check if order qualifies for loyalty reward
        let loyaltyPoints = await calculateLoyaltyPoints(order)
        if loyaltyPoints > 0 {
            suggestions.append(AgentSuggestion(
                type: .loyalty,
                title: "Award \(loyaltyPoints) Points",
                description: "Order qualifies for loyalty rewards",
                action: { [weak self] in
                    await self?.awardLoyaltyPoints(order.customerId, loyaltyPoints)
                }
            ))
        }

        // Suggest related products
        let recommendations = await getProductRecommendations(order)
        if !recommendations.isEmpty {
            suggestions.append(AgentSuggestion(
                type: .upsell,
                title: "Suggest Add-ons",
                description: "\(recommendations.count) related products",
                products: recommendations,
                action: { [weak self] in
                    await self?.sendUpsellEmail(order.customerId, recommendations)
                }
            ))
        }
    }

    private func createWalletPass(_ customerId: UUID) async {
        do {
            let _ = try await supabase.client.rpc(
                "wallet_pass_create",
                params: [
                    "customer_id": customerId.uuidString,
                    "template": "loyalty-card"
                ]
            ).execute()

            // Log success
            await logToolExecution(
                toolName: "wallet_pass_create",
                status: "success",
                customerId: customerId
            )
        } catch {
            NSLog("[OrderAgent] Error creating wallet pass: \(error)")
        }
    }

    private func awardLoyaltyPoints(_ customerId: UUID, _ points: Int) async {
        // Use your loyalty MCP tool
        try? await supabase.client.rpc(
            "loyalty_award_points",
            params: [
                "customer_id": customerId.uuidString,
                "points": points,
                "reason": "Order completion"
            ]
        ).execute()
    }
}

struct AgentSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    var products: [Product]? = nil
    let action: () async -> Void

    enum SuggestionType {
        case walletPass, loyalty, upsell, followUp
    }
}
```

**UI Integration:**

```swift
// In OrderDetailPanel.swift
struct OrderDetailPanel: View {
    let order: Order
    @StateObject private var agentStore = OrderAgentStore()

    var body: some View {
        VStack {
            // Existing order details...

            // Agent suggestions
            if !agentStore.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Suggestions")
                        .font(.headline)

                    ForEach(agentStore.suggestions) { suggestion in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(suggestion.title)
                                    .fontWeight(.medium)
                                Text(suggestion.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Apply") {
                                Task {
                                    await suggestion.action()
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .task {
            await agentStore.analyzeOrder(order)
        }
    }
}
```

---

## Database Setup

All tables already exist! Just add a few agents:

```sql
-- Create a customer service agent
INSERT INTO agents (
  name,
  description,
  system_prompt,
  enabled_categories,
  personality
) VALUES (
  'Customer Service Agent',
  'Answers customer questions about orders, products, and policies',
  'You are a helpful customer service representative. Use the available tools to look up order information, product details, and help customers with their questions. Be friendly and concise.',
  ARRAY['crm', 'orders', 'products', 'inventory'],
  '{"tone": "friendly", "verbosity": "concise", "proactivity": "high"}'::jsonb
);

-- Create an inventory monitoring agent
INSERT INTO agents (
  name,
  description,
  system_prompt,
  enabled_categories,
  personality
) VALUES (
  'Inventory Monitor',
  'Monitors stock levels and creates reorder alerts',
  'You monitor inventory levels across all locations. When stock falls below reorder points, you create purchase orders and notify managers.',
  ARRAY['inventory', 'purchasing', 'notifications'],
  '{"tone": "professional", "verbosity": "detailed", "proactivity": "very-high"}'::jsonb
);

-- Create a marketing automation agent
INSERT INTO agents (
  name,
  description,
  system_prompt,
  enabled_categories,
  personality
) VALUES (
  'Marketing Assistant',
  'Creates targeted email campaigns based on customer behavior',
  'You analyze customer purchase history and behavior to create personalized marketing campaigns. You can segment customers, design emails, and schedule sends.',
  ARRAY['crm', 'email', 'analytics'],
  '{"tone": "creative", "verbosity": "moderate", "proactivity": "moderate"}'::jsonb
);
```

---

## Edge Function: Universal Agent Executor

Create one edge function that can run any agent:

```typescript
// supabase/functions/agent-execute/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk@0.27.0'

interface ToolDefinition {
  name: string
  description: string
  input_schema: any
}

serve(async (req) => {
  try {
    const { agent_id, conversation_id, user_message } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const anthropic = new Anthropic({
      apiKey: Deno.env.get('ANTHROPIC_API_KEY')!
    })

    // 1. Load agent configuration
    const { data: agent } = await supabase
      .from('agents')
      .select('*')
      .eq('id', agent_id)
      .single()

    if (!agent) {
      throw new Error('Agent not found')
    }

    // 2. Load available tools from ai_tool_registry
    let toolsQuery = supabase
      .from('ai_tool_registry')
      .select('name, definition, rpc_function, edge_function')
      .eq('is_active', true)

    // Filter by agent's enabled categories/tools
    if (agent.enabled_categories.length > 0) {
      toolsQuery = toolsQuery.in('category', agent.enabled_categories)
    }
    if (agent.enabled_tools.length > 0) {
      toolsQuery = toolsQuery.in('name', agent.enabled_tools)
    }

    const { data: tools } = await toolsQuery

    // Convert to Claude tool format
    const claudeTools = tools.map(t => ({
      name: t.name,
      description: t.definition.description,
      input_schema: t.definition.input_schema
    }))

    // 3. Load conversation history
    const { data: conversation } = await supabase
      .from('wilson_conversations')
      .select('messages')
      .eq('id', conversation_id)
      .single()

    let messages = conversation?.messages || []

    // Add new user message
    if (user_message) {
      messages.push({
        role: 'user',
        content: user_message
      })
    }

    // 4. Call Claude with tools
    let continueLoop = true
    let turnCount = 0
    const maxTurns = agent.max_turns_per_conversation || 10

    while (continueLoop && turnCount < maxTurns) {
      turnCount++

      const response = await anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: agent.max_tokens_per_response || 4096,
        system: agent.system_prompt,
        messages: messages,
        tools: claudeTools
      })

      // Add assistant message
      messages.push({
        role: 'assistant',
        content: response.content
      })

      // Check if Claude wants to use tools
      const toolUses = response.content.filter(c => c.type === 'tool_use')

      if (toolUses.length === 0) {
        // No more tools to call, we're done
        continueLoop = false
        break
      }

      // 5. Execute tool calls
      const toolResults = []

      for (const toolUse of toolUses) {
        const toolDef = tools.find(t => t.name === toolUse.name)
        if (!toolDef) continue

        // Log tool execution start
        const execId = crypto.randomUUID()
        const startTime = Date.now()

        await supabase.from('wilson_tool_executions').insert({
          id: execId,
          conversation_id: conversation_id,
          tool_name: toolUse.name,
          tool_id: toolUse.id,
          input: toolUse.input,
          status: 'started',
          turn_number: turnCount
        })

        try {
          let result

          // Execute via RPC or Edge Function
          if (toolDef.rpc_function) {
            const { data } = await supabase.rpc(
              toolDef.rpc_function,
              toolUse.input
            )
            result = data
          } else if (toolDef.edge_function) {
            const { data } = await supabase.functions.invoke(
              toolDef.edge_function,
              { body: toolUse.input }
            )
            result = data
          }

          const executionTime = Date.now() - startTime

          // Log success
          await supabase
            .from('wilson_tool_executions')
            .update({
              output: result,
              status: 'success',
              execution_time_ms: executionTime,
              completed_at: new Date().toISOString()
            })
            .eq('id', execId)

          toolResults.push({
            type: 'tool_result',
            tool_use_id: toolUse.id,
            content: JSON.stringify(result)
          })

        } catch (error) {
          // Log error
          await supabase
            .from('wilson_tool_executions')
            .update({
              status: 'error',
              error_message: error.message,
              completed_at: new Date().toISOString()
            })
            .eq('id', execId)

          toolResults.push({
            type: 'tool_result',
            tool_use_id: toolUse.id,
            content: `Error: ${error.message}`,
            is_error: true
          })
        }
      }

      // Add tool results to messages
      messages.push({
        role: 'user',
        content: toolResults
      })

      // Continue loop to let Claude process results
    }

    // 6. Update conversation
    await supabase
      .from('wilson_conversations')
      .update({
        messages: messages,
        tool_call_count: supabase.rpc('increment', { field: 'tool_call_count' }),
        total_turns: turnCount,
        updated_at: new Date().toISOString()
      })
      .eq('id', conversation_id)

    // 7. Return final response
    const lastMessage = messages[messages.length - 1]
    const textContent = lastMessage.content
      .filter(c => c.type === 'text')
      .map(c => c.text)
      .join('\n')

    return new Response(
      JSON.stringify({
        success: true,
        response: textContent,
        turns: turnCount,
        conversation_id: conversation_id
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## Integration with Existing UI

Your UI already has all the pieces:

### 1. **Add Agent Section to Sidebar**

```swift
// In EditorSidebarView.swift
Section {
    NavigationLink(
        destination: AgentManagementView(store: store),
        tag: OpenTabItem.agentManagement,
        selection: $store.activeTab
    ) {
        Label("AI Agents", systemImage: "brain")
    }
}
```

### 2. **Agent Management View**

```swift
struct AgentManagementView: View {
    @StateObject private var agentStore = AgentStore()

    var body: some View {
        HSplitView {
            // List of agents
            List {
                ForEach(agentStore.agents) { agent in
                    AgentRowView(agent: agent)
                        .onTapGesture {
                            agentStore.selectedAgent = agent
                        }
                }
            }
            .frame(minWidth: 250)

            // Agent detail/config
            if let agent = agentStore.selectedAgent {
                AgentDetailView(agent: agent, store: agentStore)
            }
        }
        .task {
            await agentStore.loadAgents()
        }
    }
}
```

### 3. **Monitor Agent Activity**

Extend your existing `MCPMonitoringView` to show agent activity:

```swift
// Add to MCPMonitoringView.swift
Section("Agent Activity") {
    ForEach(monitor.recentAgentExecutions) { exec in
        HStack {
            Image(systemName: "brain")
                .foregroundColor(.purple)

            VStack(alignment: .leading) {
                Text(exec.agentName)
                    .fontWeight(.medium)
                Text("\(exec.toolsUsed) tools")
                    .font(.caption)
            }

            Spacer()

            Text(exec.timestamp.formatted(.relative(presentation: .named)))
                .font(.caption)
        }
    }
}
```

---

## Testing Your Agents

### 1. **Test Individual Tools First**

Use your existing `MCPDeveloperView`:
- Test each tool the agent will use
- Verify parameters and responses
- Check execution logs in `lisa_tool_execution_log`

### 2. **Test Agent in Isolation**

```swift
// Create test agent conversation
Task {
    let conv = try await agentStore.startConversation(
        agentId: customerServiceAgentId,
        initialMessage: "What's the status of order #12345?"
    )

    // Monitor wilson_tool_executions to see what tools it calls
}
```

### 3. **Monitor Real-Time**

Watch `MCPMonitoringView` while agent runs to see:
- Which tools are called
- Execution times
- Errors
- Success rates

---

## Best Practices

### 1. **Start Small**
- Begin with 1-2 simple agents (customer service, notifications)
- Add more agents as you verify stability

### 2. **Use Categories for Safety**
```swift
// Customer-facing agent: read-only access
enabledCategories: ["crm", "orders", "products"]
enabledTools: [] // All tools in those categories

// Admin agent: full access
enabledCategories: ["inventory", "purchasing", "admin"]
```

### 3. **Monitor Costs**
```sql
-- Check agent usage costs
SELECT
  agent_id,
  SUM(input_tokens) as total_input,
  SUM(output_tokens) as total_output,
  SUM(total_cost_usd) as total_cost
FROM wilson_conversations
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY agent_id;
```

### 4. **Set Limits**
```swift
// In agent config
maxToolCalls: 25 // Prevent infinite loops
maxTokensPerResponse: 4096 // Control costs
maxTurnsPerConversation: 50 // Prevent runaway conversations
```

### 5. **Audit Everything**
All tool executions are automatically logged in:
- `wilson_tool_executions` (detailed, per-conversation)
- `lisa_tool_execution_log` (system-wide audit)

---

## Quick Start Checklist

1. ✅ **Database** - Already set up!
2. ✅ **MCP Tools** - Already registered in `ai_tool_registry`
3. ✅ **Monitoring** - Already built (`MCPMonitoringView`)
4. ⬜ **Create agents** - Add rows to `agents` table
5. ⬜ **Build AgentStore** - Swift class to manage agents
6. ⬜ **Add UI** - Agent management view in sidebar
7. ⬜ **Deploy edge function** - `agent-execute` function
8. ⬜ **Test** - Run first agent conversation

---

## Example Use Cases

### Use Case 1: Automated Customer Support
**Agent:** Customer Service Agent
**Triggers:** New message in `lisa_conversations`
**Tools Used:** `customer_query`, `order_query`, `product_query`
**UI:** Chat interface in TeamChatView

### Use Case 2: Inventory Management
**Agent:** Inventory Monitor
**Triggers:** Scheduled (hourly)
**Tools Used:** `inventory_query`, `purchase_order_create`, `notification_send`
**UI:** Background task, results in MCPMonitoringView

### Use Case 3: Smart Order Processing
**Agent:** Order Assistant
**Triggers:** Order created/viewed
**Tools Used:** `wallet_pass_create`, `loyalty_award`, `email_send`
**UI:** Suggestions panel in OrderDetailPanel

### Use Case 4: Marketing Automation
**Agent:** Marketing Assistant
**Triggers:** Daily/Weekly
**Tools Used:** `customer_segment`, `email_campaign_create`, `email_send`
**UI:** Campaign dashboard with agent suggestions

---

## Next Steps

1. **Choose your first agent** - Customer service is easiest
2. **Add agent to database** - Insert into `agents` table
3. **Build AgentStore.swift** - Copy code from Approach 1 above
4. **Deploy edge function** - Copy `agent-execute` code
5. **Add UI** - Agent chat view in sidebar
6. **Test & iterate** - Monitor in MCPMonitoringView

Your infrastructure is ready. You just need to connect the pieces!

---

## Questions?

- Database schema: Check `agents`, `ai_agent_config`, `wilson_conversations`
- MCP tools: View in `ai_tool_registry` or use `MCPDeveloperView`
- Monitoring: Use existing `MCPMonitoringView`
- Logs: Query `lisa_tool_execution_log` and `wilson_tool_executions`
