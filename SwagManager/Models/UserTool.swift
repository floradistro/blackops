import Foundation

// MARK: - User Tool Model
// Custom tools created by users for AI agent automation

struct UserTool: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID
    var name: String
    var displayName: String
    var description: String
    var category: String
    var icon: String
    var inputSchema: InputSchema?
    var executionType: ExecutionType
    var rpcFunction: String?
    var httpConfig: HTTPConfig?
    var sqlTemplate: String?
    var allowedTables: [String]?
    var isReadOnly: Bool
    var requiresApproval: Bool
    var maxExecutionTimeMs: Int
    var isActive: Bool
    var isTested: Bool
    var testResult: TestResult?
    var metadata: [String: AnyCodable]?
    var tags: [String]?
    var createdBy: UUID?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case name
        case displayName = "display_name"
        case description
        case category
        case icon
        case inputSchema = "input_schema"
        case executionType = "execution_type"
        case rpcFunction = "rpc_function"
        case httpConfig = "http_config"
        case sqlTemplate = "sql_template"
        case allowedTables = "allowed_tables"
        case isReadOnly = "is_read_only"
        case requiresApproval = "requires_approval"
        case maxExecutionTimeMs = "max_execution_time_ms"
        case isActive = "is_active"
        case isTested = "is_tested"
        case testResult = "test_result"
        case metadata
        case tags
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum ExecutionType: String, Codable, CaseIterable {
        case rpc = "rpc"
        case http = "http"
        case sql = "sql"

        var displayName: String {
            switch self {
            case .rpc: return "RPC Function"
            case .http: return "HTTP API"
            case .sql: return "SQL Query"
            }
        }

        var icon: String {
            switch self {
            case .rpc: return "function"
            case .http: return "network"
            case .sql: return "tablecells"
            }
        }

        var description: String {
            switch self {
            case .rpc: return "Call a Postgres function"
            case .http: return "Call an external API"
            case .sql: return "Execute a sandboxed query"
            }
        }
    }

    // Default initializer for creating new tools
    init(
        id: UUID = UUID(),
        storeId: UUID,
        name: String = "",
        displayName: String = "",
        description: String = "",
        category: String = "custom",
        icon: String = "wrench.fill",
        inputSchema: InputSchema? = nil,
        executionType: ExecutionType = .rpc,
        rpcFunction: String? = nil,
        httpConfig: HTTPConfig? = nil,
        sqlTemplate: String? = nil,
        allowedTables: [String]? = nil,
        isReadOnly: Bool = true,
        requiresApproval: Bool = false,
        maxExecutionTimeMs: Int = 5000,
        isActive: Bool = true,
        isTested: Bool = false,
        testResult: TestResult? = nil,
        metadata: [String: AnyCodable]? = nil,
        tags: [String]? = nil,
        createdBy: UUID? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.displayName = displayName
        self.description = description
        self.category = category
        self.icon = icon
        self.inputSchema = inputSchema
        self.executionType = executionType
        self.rpcFunction = rpcFunction
        self.httpConfig = httpConfig
        self.sqlTemplate = sqlTemplate
        self.allowedTables = allowedTables
        self.isReadOnly = isReadOnly
        self.requiresApproval = requiresApproval
        self.maxExecutionTimeMs = maxExecutionTimeMs
        self.isActive = isActive
        self.isTested = isTested
        self.testResult = testResult
        self.metadata = metadata
        self.tags = tags
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Input Schema

struct InputSchema: Codable, Hashable {
    var type: String
    var properties: [String: PropertySchema]?
    var required: [String]?

    init(type: String = "object", properties: [String: PropertySchema]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

struct PropertySchema: Codable, Hashable {
    var type: String
    var description: String?
    var `default`: AnyCodable?
    var `enum`: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case `default`
        case `enum`
    }
}

// MARK: - HTTP Config

struct HTTPConfig: Codable, Hashable {
    var url: String
    var method: HTTPMethod
    var headers: [String: String]?
    var bodyTemplate: [String: AnyCodable]?
    var queryParams: [String: String]?

    // Batch/Bulk processing options
    var batchConfig: BatchConfig?

    // Response handling
    var responseMapping: ResponseMapping?

    enum CodingKeys: String, CodingKey {
        case url
        case method
        case headers
        case bodyTemplate = "body_template"
        case queryParams = "query_params"
        case batchConfig = "batch_config"
        case responseMapping = "response_mapping"
    }

    enum HTTPMethod: String, Codable, CaseIterable {
        case GET, POST, PUT, DELETE, PATCH
    }

    init(
        url: String = "",
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        bodyTemplate: [String: AnyCodable]? = nil,
        queryParams: [String: String]? = nil,
        batchConfig: BatchConfig? = nil,
        responseMapping: ResponseMapping? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.bodyTemplate = bodyTemplate
        self.queryParams = queryParams
        self.batchConfig = batchConfig
        self.responseMapping = responseMapping
    }
}

// MARK: - Batch Config

struct BatchConfig: Codable, Hashable {
    var enabled: Bool
    var maxConcurrent: Int          // Max parallel requests
    var delayBetweenMs: Int         // Delay between batches
    var batchSize: Int              // Items per batch
    var inputArrayPath: String?     // JSONPath to input array (e.g., "images", "urls")
    var outputArrayPath: String?    // JSONPath for collecting results
    var retryOnFailure: Bool
    var continueOnError: Bool       // Continue batch if one item fails

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxConcurrent = "max_concurrent"
        case delayBetweenMs = "delay_between_ms"
        case batchSize = "batch_size"
        case inputArrayPath = "input_array_path"
        case outputArrayPath = "output_array_path"
        case retryOnFailure = "retry_on_failure"
        case continueOnError = "continue_on_error"
    }

    init(
        enabled: Bool = false,
        maxConcurrent: Int = 5,
        delayBetweenMs: Int = 100,
        batchSize: Int = 10,
        inputArrayPath: String? = nil,
        outputArrayPath: String? = nil,
        retryOnFailure: Bool = true,
        continueOnError: Bool = true
    ) {
        self.enabled = enabled
        self.maxConcurrent = maxConcurrent
        self.delayBetweenMs = delayBetweenMs
        self.batchSize = batchSize
        self.inputArrayPath = inputArrayPath
        self.outputArrayPath = outputArrayPath
        self.retryOnFailure = retryOnFailure
        self.continueOnError = continueOnError
    }
}

// MARK: - Response Mapping

struct ResponseMapping: Codable, Hashable {
    var resultPath: String?         // JSONPath to extract result (e.g., "data.url")
    var errorPath: String?          // JSONPath to extract error message
    var successCondition: String?   // JSONPath expression for success check

    enum CodingKeys: String, CodingKey {
        case resultPath = "result_path"
        case errorPath = "error_path"
        case successCondition = "success_condition"
    }
}

// MARK: - API Template

enum APITemplate: String, Codable, CaseIterable, Identifiable {
    case removeBg = "remove_bg"
    case openaiImages = "openai_images"
    case openaiChat = "openai_chat"
    case geminiImages = "gemini_images"
    case geminiChat = "gemini_chat"
    case stability = "stability"
    case replicate = "replicate"
    case resend = "resend"
    case twilio = "twilio"
    case stripe = "stripe"
    case shopify = "shopify"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .removeBg: return "Remove.bg"
        case .openaiImages: return "OpenAI Images"
        case .openaiChat: return "OpenAI Chat"
        case .geminiImages: return "Gemini Images"
        case .geminiChat: return "Gemini Chat"
        case .stability: return "Stability AI"
        case .replicate: return "Replicate"
        case .resend: return "Resend Email"
        case .twilio: return "Twilio SMS"
        case .stripe: return "Stripe"
        case .shopify: return "Shopify"
        case .custom: return "Custom API"
        }
    }

    var icon: String {
        switch self {
        case .removeBg: return "person.crop.rectangle"
        case .openaiImages, .geminiImages, .stability, .replicate: return "photo.artframe"
        case .openaiChat, .geminiChat: return "bubble.left.and.bubble.right"
        case .resend: return "envelope"
        case .twilio: return "message"
        case .stripe: return "creditcard"
        case .shopify: return "bag"
        case .custom: return "network"
        }
    }

    var category: String {
        switch self {
        case .removeBg, .openaiImages, .geminiImages, .stability, .replicate:
            return "images"
        case .openaiChat, .geminiChat:
            return "ai"
        case .resend:
            return "email"
        case .twilio:
            return "messaging"
        case .stripe:
            return "payments"
        case .shopify:
            return "ecommerce"
        case .custom:
            return "custom"
        }
    }

    var description: String {
        switch self {
        case .removeBg: return "Remove backgrounds from images automatically"
        case .openaiImages: return "Generate images with DALL-E 3"
        case .openaiChat: return "Chat completions with GPT-4"
        case .geminiImages: return "Generate images with Google Gemini"
        case .geminiChat: return "Chat with Google Gemini"
        case .stability: return "Generate images with Stable Diffusion"
        case .replicate: return "Run ML models on Replicate"
        case .resend: return "Send transactional emails"
        case .twilio: return "Send SMS messages"
        case .stripe: return "Process payments"
        case .shopify: return "Manage Shopify store"
        case .custom: return "Configure a custom API endpoint"
        }
    }

    var supportsBatch: Bool {
        switch self {
        case .removeBg, .openaiImages, .geminiImages, .stability, .replicate:
            return true
        case .resend, .twilio:
            return true
        default:
            return false
        }
    }

    // Pre-configured HTTP settings for each template
    var defaultConfig: HTTPConfig {
        switch self {
        case .removeBg:
            return HTTPConfig(
                url: "https://api.remove.bg/v1.0/removebg",
                method: .POST,
                headers: [
                    "X-Api-Key": "{{REMOVEBG_API_KEY}}"
                ],
                bodyTemplate: [
                    "image_url": AnyCodable("{{image_url}}"),
                    "size": AnyCodable("auto"),
                    "format": AnyCodable("png")
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 5, delayBetweenMs: 200, batchSize: 10, inputArrayPath: "image_urls"),
                responseMapping: ResponseMapping(resultPath: "data", errorPath: "errors[0].title")
            )

        case .openaiImages:
            return HTTPConfig(
                url: "https://api.openai.com/v1/images/generations",
                method: .POST,
                headers: [
                    "Authorization": "Bearer {{OPENAI_API_KEY}}",
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "model": AnyCodable("dall-e-3"),
                    "prompt": AnyCodable("{{prompt}}"),
                    "n": AnyCodable(1),
                    "size": AnyCodable("1024x1024"),
                    "quality": AnyCodable("standard")
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 3, delayBetweenMs: 500, batchSize: 5, inputArrayPath: "prompts"),
                responseMapping: ResponseMapping(resultPath: "data[0].url", errorPath: "error.message")
            )

        case .openaiChat:
            return HTTPConfig(
                url: "https://api.openai.com/v1/chat/completions",
                method: .POST,
                headers: [
                    "Authorization": "Bearer {{OPENAI_API_KEY}}",
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "model": AnyCodable("gpt-4o"),
                    "messages": AnyCodable([["role": "user", "content": "{{message}}"]]),
                    "max_tokens": AnyCodable(4096)
                ],
                responseMapping: ResponseMapping(resultPath: "choices[0].message.content", errorPath: "error.message")
            )

        case .geminiImages:
            return HTTPConfig(
                url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent",
                method: .POST,
                headers: [
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "contents": AnyCodable([["parts": [["text": "{{prompt}}"]]]]),
                    "generationConfig": AnyCodable(["responseModalities": ["IMAGE", "TEXT"]])
                ],
                queryParams: [
                    "key": "{{GEMINI_API_KEY}}"
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 3, delayBetweenMs: 500, batchSize: 5, inputArrayPath: "prompts"),
                responseMapping: ResponseMapping(resultPath: "candidates[0].content.parts", errorPath: "error.message")
            )

        case .geminiChat:
            return HTTPConfig(
                url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
                method: .POST,
                headers: [
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "contents": AnyCodable([["parts": [["text": "{{message}}"]]]])
                ],
                queryParams: [
                    "key": "{{GEMINI_API_KEY}}"
                ],
                responseMapping: ResponseMapping(resultPath: "candidates[0].content.parts[0].text", errorPath: "error.message")
            )

        case .stability:
            return HTTPConfig(
                url: "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image",
                method: .POST,
                headers: [
                    "Authorization": "Bearer {{STABILITY_API_KEY}}",
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "text_prompts": AnyCodable([["text": "{{prompt}}", "weight": 1]]),
                    "cfg_scale": AnyCodable(7),
                    "height": AnyCodable(1024),
                    "width": AnyCodable(1024),
                    "samples": AnyCodable(1),
                    "steps": AnyCodable(30)
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 2, delayBetweenMs: 1000, batchSize: 5, inputArrayPath: "prompts"),
                responseMapping: ResponseMapping(resultPath: "artifacts[0].base64", errorPath: "message")
            )

        case .replicate:
            return HTTPConfig(
                url: "https://api.replicate.com/v1/predictions",
                method: .POST,
                headers: [
                    "Authorization": "Token {{REPLICATE_API_KEY}}",
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "version": AnyCodable("{{model_version}}"),
                    "input": AnyCodable(["prompt": "{{prompt}}"])
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 5, delayBetweenMs: 200, batchSize: 10, inputArrayPath: "prompts"),
                responseMapping: ResponseMapping(resultPath: "output", errorPath: "error")
            )

        case .resend:
            return HTTPConfig(
                url: "https://api.resend.com/emails",
                method: .POST,
                headers: [
                    "Authorization": "Bearer {{RESEND_API_KEY}}",
                    "Content-Type": "application/json"
                ],
                bodyTemplate: [
                    "from": AnyCodable("{{from_email}}"),
                    "to": AnyCodable("{{to_email}}"),
                    "subject": AnyCodable("{{subject}}"),
                    "html": AnyCodable("{{html_body}}")
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 10, delayBetweenMs: 50, batchSize: 50, inputArrayPath: "recipients"),
                responseMapping: ResponseMapping(resultPath: "id", errorPath: "message")
            )

        case .twilio:
            return HTTPConfig(
                url: "https://api.twilio.com/2010-04-01/Accounts/{{TWILIO_ACCOUNT_SID}}/Messages.json",
                method: .POST,
                headers: [
                    "Authorization": "Basic {{TWILIO_AUTH}}",
                    "Content-Type": "application/x-www-form-urlencoded"
                ],
                bodyTemplate: [
                    "From": AnyCodable("{{from_number}}"),
                    "To": AnyCodable("{{to_number}}"),
                    "Body": AnyCodable("{{message}}")
                ],
                batchConfig: BatchConfig(enabled: false, maxConcurrent: 10, delayBetweenMs: 100, batchSize: 50, inputArrayPath: "recipients"),
                responseMapping: ResponseMapping(resultPath: "sid", errorPath: "message")
            )

        case .stripe:
            return HTTPConfig(
                url: "https://api.stripe.com/v1/payment_intents",
                method: .POST,
                headers: [
                    "Authorization": "Bearer {{STRIPE_SECRET_KEY}}",
                    "Content-Type": "application/x-www-form-urlencoded"
                ],
                bodyTemplate: [
                    "amount": AnyCodable("{{amount}}"),
                    "currency": AnyCodable("{{currency}}"),
                    "payment_method": AnyCodable("{{payment_method}}")
                ],
                responseMapping: ResponseMapping(resultPath: "id", errorPath: "error.message")
            )

        case .shopify:
            return HTTPConfig(
                url: "https://{{shop_domain}}/admin/api/2024-01/products.json",
                method: .GET,
                headers: [
                    "X-Shopify-Access-Token": "{{SHOPIFY_ACCESS_TOKEN}}",
                    "Content-Type": "application/json"
                ],
                responseMapping: ResponseMapping(resultPath: "products", errorPath: "errors")
            )

        case .custom:
            return HTTPConfig(
                url: "",
                method: .GET
            )
        }
    }

    // Required secrets for each template
    var requiredSecrets: [String] {
        switch self {
        case .removeBg: return ["REMOVEBG_API_KEY"]
        case .openaiImages, .openaiChat: return ["OPENAI_API_KEY"]
        case .geminiImages, .geminiChat: return ["GEMINI_API_KEY"]
        case .stability: return ["STABILITY_API_KEY"]
        case .replicate: return ["REPLICATE_API_KEY"]
        case .resend: return ["RESEND_API_KEY"]
        case .twilio: return ["TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN"]
        case .stripe: return ["STRIPE_SECRET_KEY"]
        case .shopify: return ["SHOPIFY_ACCESS_TOKEN"]
        case .custom: return []
        }
    }

    // Default input parameters for each template
    var defaultInputSchema: InputSchema {
        switch self {
        case .removeBg:
            return InputSchema(
                type: "object",
                properties: [
                    "image_url": PropertySchema(type: "string", description: "URL of the image to process"),
                    "image_urls": PropertySchema(type: "array", description: "Array of image URLs for batch processing")
                ],
                required: ["image_url"]
            )

        case .openaiImages:
            return InputSchema(
                type: "object",
                properties: [
                    "prompt": PropertySchema(type: "string", description: "Image generation prompt"),
                    "prompts": PropertySchema(type: "array", description: "Array of prompts for batch generation"),
                    "size": PropertySchema(type: "string", description: "Image size (1024x1024, 1792x1024, 1024x1792)", enum: ["1024x1024", "1792x1024", "1024x1792"]),
                    "quality": PropertySchema(type: "string", description: "Image quality", enum: ["standard", "hd"])
                ],
                required: ["prompt"]
            )

        case .openaiChat:
            return InputSchema(
                type: "object",
                properties: [
                    "message": PropertySchema(type: "string", description: "User message"),
                    "system_prompt": PropertySchema(type: "string", description: "Optional system prompt")
                ],
                required: ["message"]
            )

        case .geminiImages:
            return InputSchema(
                type: "object",
                properties: [
                    "prompt": PropertySchema(type: "string", description: "Image generation prompt"),
                    "prompts": PropertySchema(type: "array", description: "Array of prompts for batch generation")
                ],
                required: ["prompt"]
            )

        case .geminiChat:
            return InputSchema(
                type: "object",
                properties: [
                    "message": PropertySchema(type: "string", description: "User message")
                ],
                required: ["message"]
            )

        case .stability:
            return InputSchema(
                type: "object",
                properties: [
                    "prompt": PropertySchema(type: "string", description: "Image generation prompt"),
                    "prompts": PropertySchema(type: "array", description: "Array of prompts for batch generation"),
                    "negative_prompt": PropertySchema(type: "string", description: "What to avoid in the image")
                ],
                required: ["prompt"]
            )

        case .replicate:
            return InputSchema(
                type: "object",
                properties: [
                    "model_version": PropertySchema(type: "string", description: "Replicate model version ID"),
                    "prompt": PropertySchema(type: "string", description: "Input prompt"),
                    "prompts": PropertySchema(type: "array", description: "Array of prompts for batch processing")
                ],
                required: ["model_version", "prompt"]
            )

        case .resend:
            return InputSchema(
                type: "object",
                properties: [
                    "from_email": PropertySchema(type: "string", description: "Sender email address"),
                    "to_email": PropertySchema(type: "string", description: "Recipient email address"),
                    "recipients": PropertySchema(type: "array", description: "Array of recipient emails for batch sending"),
                    "subject": PropertySchema(type: "string", description: "Email subject"),
                    "html_body": PropertySchema(type: "string", description: "HTML email body")
                ],
                required: ["from_email", "to_email", "subject", "html_body"]
            )

        case .twilio:
            return InputSchema(
                type: "object",
                properties: [
                    "from_number": PropertySchema(type: "string", description: "Twilio phone number"),
                    "to_number": PropertySchema(type: "string", description: "Recipient phone number"),
                    "recipients": PropertySchema(type: "array", description: "Array of phone numbers for batch SMS"),
                    "message": PropertySchema(type: "string", description: "SMS message body")
                ],
                required: ["from_number", "to_number", "message"]
            )

        case .stripe:
            return InputSchema(
                type: "object",
                properties: [
                    "amount": PropertySchema(type: "number", description: "Amount in cents"),
                    "currency": PropertySchema(type: "string", description: "Currency code (usd, eur, etc.)"),
                    "payment_method": PropertySchema(type: "string", description: "Payment method ID")
                ],
                required: ["amount", "currency"]
            )

        case .shopify:
            return InputSchema(
                type: "object",
                properties: [
                    "shop_domain": PropertySchema(type: "string", description: "Your Shopify store domain")
                ],
                required: ["shop_domain"]
            )

        case .custom:
            return InputSchema(type: "object")
        }
    }
}

// MARK: - Test Result

struct TestResult: Codable, Hashable {
    var success: Bool
    var output: AnyCodable?
    var error: String?
    var executionTimeMs: Int?
    var testedAt: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case output
        case error
        case executionTimeMs = "execution_time_ms"
        case testedAt = "tested_at"
    }
}

// MARK: - User Trigger Model

struct UserTrigger: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID
    var toolId: UUID?
    var name: String
    var description: String?
    var triggerType: TriggerType
    var eventTable: String?
    var eventOperation: EventOperation?
    var eventFilter: [String: AnyCodable]?
    var cronExpression: String?
    var timezone: String?
    var conditionSql: String?
    var conditionCheckInterval: Int?
    var toolArgsTemplate: [String: AnyCodable]?
    var isActive: Bool
    var maxRetries: Int
    var retryDelaySeconds: Int
    var retryBackoffMultiplier: Double?
    var timeoutSeconds: Int?
    var maxExecutionsPerHour: Int?
    var cooldownSeconds: Int?
    var metadata: [String: AnyCodable]?
    var tags: [String]?
    var createdBy: UUID?
    let createdAt: Date?
    var updatedAt: Date?
    var lastTriggeredAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case toolId = "tool_id"
        case name
        case description
        case triggerType = "trigger_type"
        case eventTable = "event_table"
        case eventOperation = "event_operation"
        case eventFilter = "event_filter"
        case cronExpression = "cron_expression"
        case timezone
        case conditionSql = "condition_sql"
        case conditionCheckInterval = "condition_check_interval"
        case toolArgsTemplate = "tool_args_template"
        case isActive = "is_active"
        case maxRetries = "max_retries"
        case retryDelaySeconds = "retry_delay_seconds"
        case retryBackoffMultiplier = "retry_backoff_multiplier"
        case timeoutSeconds = "timeout_seconds"
        case maxExecutionsPerHour = "max_executions_per_hour"
        case cooldownSeconds = "cooldown_seconds"
        case metadata
        case tags
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastTriggeredAt = "last_triggered_at"
    }

    enum TriggerType: String, Codable, CaseIterable {
        case event = "event"
        case schedule = "schedule"
        case condition = "condition"

        var displayName: String {
            switch self {
            case .event: return "Database Event"
            case .schedule: return "Scheduled"
            case .condition: return "Condition"
            }
        }

        var icon: String {
            switch self {
            case .event: return "cylinder"
            case .schedule: return "clock"
            case .condition: return "questionmark.circle"
            }
        }
    }

    enum EventOperation: String, Codable, CaseIterable {
        case INSERT, UPDATE, DELETE

        var displayName: String {
            rawValue.capitalized
        }
    }

    init(
        id: UUID = UUID(),
        storeId: UUID,
        toolId: UUID? = nil,
        name: String = "",
        description: String? = nil,
        triggerType: TriggerType = .event,
        eventTable: String? = nil,
        eventOperation: EventOperation? = nil,
        eventFilter: [String: AnyCodable]? = nil,
        cronExpression: String? = nil,
        timezone: String? = "UTC",
        conditionSql: String? = nil,
        conditionCheckInterval: Int? = 300,
        toolArgsTemplate: [String: AnyCodable]? = nil,
        isActive: Bool = true,
        maxRetries: Int = 3,
        retryDelaySeconds: Int = 60,
        retryBackoffMultiplier: Double? = 2.0,
        timeoutSeconds: Int? = 30,
        maxExecutionsPerHour: Int? = 100,
        cooldownSeconds: Int? = 0,
        metadata: [String: AnyCodable]? = nil,
        tags: [String]? = nil,
        createdBy: UUID? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.storeId = storeId
        self.toolId = toolId
        self.name = name
        self.description = description
        self.triggerType = triggerType
        self.eventTable = eventTable
        self.eventOperation = eventOperation
        self.eventFilter = eventFilter
        self.cronExpression = cronExpression
        self.timezone = timezone
        self.conditionSql = conditionSql
        self.conditionCheckInterval = conditionCheckInterval
        self.toolArgsTemplate = toolArgsTemplate
        self.isActive = isActive
        self.maxRetries = maxRetries
        self.retryDelaySeconds = retryDelaySeconds
        self.retryBackoffMultiplier = retryBackoffMultiplier
        self.timeoutSeconds = timeoutSeconds
        self.maxExecutionsPerHour = maxExecutionsPerHour
        self.cooldownSeconds = cooldownSeconds
        self.metadata = metadata
        self.tags = tags
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastTriggeredAt = lastTriggeredAt
    }
}

// NOTE: AnyCodable is defined in SwagManager/Utilities/AnyCodable.swift
