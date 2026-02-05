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
