import Foundation
import Supabase
import Auth

// MARK: - Supabase Configuration

enum SupabaseConfig {
    // Production: floradistro.com
    static let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co")!

    // Anon key - safe for client-side use (RLS protects data)
    // SECURITY: Never use service_role key in client apps
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"
}

// MARK: - UserDefaults Auth Storage (avoids Keychain prompts during development)

final class UserDefaultsAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: keyPrefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: keyPrefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: keyPrefix + key)
    }
}

// MARK: - Supabase Service Coordinator
// Refactored following Apple engineering standards
// File size: ~100 lines (under Apple's 300 line "excellent" threshold)
//
// This coordinator provides a single entry point to all Supabase services
// Each service is focused on a specific domain for maintainability

@MainActor
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    // Service instances
    private(set) lazy var creations = CreationService(client: client)
    private(set) lazy var catalogs = CatalogService(client: client)
    private(set) lazy var products = ProductSchemaService(client: client)
    private(set) lazy var chat = ChatService(client: client)
    private(set) lazy var storeLocation = StoreLocationService(client: client)
    private(set) lazy var orders = OrderService(client: client)
    private(set) lazy var customers = CustomerService(client: client)

    private init() {
        // Using anon key - RLS policies enforce security
        // Using UserDefaults storage to avoid Keychain password prompts during development
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    storage: UserDefaultsAuthLocalStorage(),
                    flowType: .implicit,
                    autoRefreshToken: true
                )
            )
        )
    }

    // MARK: - Convenience Methods (delegate to services)

    // Creations
    func fetchCreations(type: CreationType? = nil, status: CreationStatus? = nil, search: String? = nil, limit: Int = 100) async throws -> [Creation] {
        try await creations.fetchCreations(type: type, status: status, search: search, limit: limit)
    }

    func fetchCreation(id: UUID) async throws -> Creation {
        try await creations.fetchCreation(id: id)
    }

    func createCreation(_ creation: CreationInsert) async throws -> Creation {
        try await creations.createCreation(creation)
    }

    func updateCreation(id: UUID, update: CreationUpdate) async throws -> Creation {
        try await creations.updateCreation(id: id, update: update)
    }

    func deleteCreation(id: UUID) async throws {
        try await creations.deleteCreation(id: id)
    }

    // Collections
    func fetchCollections(limit: Int = 100) async throws -> [CreationCollection] {
        try await creations.fetchCollections(limit: limit)
    }

    func fetchCollection(id: UUID) async throws -> CreationCollection {
        try await creations.fetchCollection(id: id)
    }

    func createCollection(_ collection: CollectionInsert) async throws -> CreationCollection {
        try await creations.createCollection(collection)
    }

    func updateCollection(id: UUID, update: CollectionUpdate) async throws -> CreationCollection {
        try await creations.updateCollection(id: id, update: update)
    }

    func deleteCollection(id: UUID) async throws {
        try await creations.deleteCollection(id: id)
    }

    // Collection Items
    func fetchCollectionItems(collectionId: UUID) async throws -> [CreationCollectionItem] {
        try await creations.fetchCollectionItems(collectionId: collectionId)
    }

    func addToCollection(_ item: CollectionItemInsert) async throws -> CreationCollectionItem {
        try await creations.addToCollection(item)
    }

    func removeFromCollection(itemId: UUID) async throws {
        try await creations.removeFromCollection(itemId: itemId)
    }

    func updateCollectionItemPosition(itemId: UUID, position: Int) async throws {
        try await creations.updateCollectionItemPosition(itemId: itemId, position: position)
    }

    func fetchCollectionWithCreations(id: UUID) async throws -> CollectionWithItems {
        try await creations.fetchCollectionWithCreations(id: id)
    }

    // Stats
    func fetchCreationStats() async throws -> (total: Int, byType: [CreationType: Int], byStatus: [CreationStatus: Int]) {
        try await creations.fetchCreationStats()
    }

    // Catalogs
    func fetchCatalogs(storeId: UUID? = nil) async throws -> [Catalog] {
        try await catalogs.fetchCatalogs(storeId: storeId ?? UUID())
    }

    func fetchCatalog(id: UUID) async throws -> Catalog {
        try await catalogs.fetchCatalog(id: id)
    }

    func createCatalog(_ catalog: CatalogInsert) async throws -> Catalog {
        try await catalogs.createCatalog(catalog)
    }

    func deleteCatalog(id: UUID) async throws {
        try await catalogs.deleteCatalog(id: id)
    }

    // Categories
    func fetchCategories(storeId: UUID? = nil, catalogId: UUID? = nil) async throws -> [Category] {
        try await catalogs.fetchCategories(storeId: storeId, catalogId: catalogId)
    }

    func fetchCategory(id: UUID) async throws -> Category {
        try await catalogs.fetchCategory(id: id)
    }

    func createCategory(_ category: CategoryInsert) async throws -> Category {
        try await catalogs.createCategory(category)
    }

    func deleteCategory(id: UUID) async throws {
        try await catalogs.deleteCategory(id: id)
    }

    func assignCategoriesToCatalog(storeId: UUID, catalogId: UUID, onlyOrphans: Bool = false) async throws -> Int {
        try await catalogs.assignCategoriesToCatalog(storeId: storeId, catalogId: catalogId, onlyOrphans: onlyOrphans)
    }

    // Products
    func fetchProducts(storeId: UUID, categoryId: UUID? = nil, search: String? = nil) async throws -> [Product] {
        try await products.fetchProducts(storeId: storeId, categoryId: categoryId, search: search)
    }

    func fetchProduct(id: UUID) async throws -> Product {
        try await products.fetchProduct(id: id)
    }

    func updateProduct(id: UUID, update: ProductUpdate) async throws -> Product {
        try await products.updateProduct(id: id, update: update)
    }

    func deleteProduct(id: UUID) async throws {
        try await products.deleteProduct(id: id)
    }

    // Field Schemas
    func fetchFieldSchemas(catalogId: UUID) async throws -> [FieldSchema] {
        try await products.fetchFieldSchemas(catalogId: catalogId)
    }

    func fetchFieldSchemasForCategory(categoryId: UUID) async throws -> [FieldSchema] {
        try await products.fetchFieldSchemasForCategory(categoryId: categoryId)
    }

    func fetchAvailableFieldSchemas(catalogId: UUID, categoryName: String?) async throws -> [FieldSchema] {
        try await products.fetchAvailableFieldSchemas(catalogId: catalogId, categoryName: categoryName)
    }

    func createFieldSchema(name: String, description: String?, icon: String?, fields: [FieldDefinition], catalogId: UUID?, applicableCategories: [String]?) async throws -> FieldSchema {
        try await products.createFieldSchema(name: name, description: description, icon: icon, fields: fields, catalogId: catalogId, applicableCategories: applicableCategories)
    }

    func updateFieldSchema(schemaId: UUID, name: String, description: String?, icon: String?, fields: [FieldDefinition]) async throws {
        try await products.updateFieldSchema(schemaId: schemaId, name: name, description: description, icon: icon, fields: fields)
    }

    func deleteFieldSchema(schemaId: UUID) async throws {
        try await products.deleteFieldSchema(schemaId: schemaId)
    }

    // Pricing Schemas
    func fetchPricingSchemas(catalogId: UUID) async throws -> [PricingSchema] {
        try await products.fetchPricingSchemas(catalogId: catalogId)
    }

    func fetchPricingSchemasForCategory(categoryId: UUID) async throws -> [PricingSchema] {
        try await products.fetchPricingSchemasForCategory(categoryId: categoryId)
    }

    func fetchAvailablePricingSchemas(catalogId: UUID, categoryName: String?) async throws -> [PricingSchema] {
        try await products.fetchAvailablePricingSchemas(catalogId: catalogId, categoryName: categoryName)
    }

    func createPricingSchema(name: String, description: String?, tiers: [PricingTier], catalogId: UUID?, applicableCategories: [String]?) async throws -> PricingSchema {
        try await products.createPricingSchema(name: name, description: description, tiers: tiers, catalogId: catalogId, applicableCategories: applicableCategories)
    }

    func updatePricingSchema(schemaId: UUID, name: String, description: String?, tiers: [PricingTier]) async throws {
        try await products.updatePricingSchema(schemaId: schemaId, name: name, description: description, tiers: tiers)
    }

    func deletePricingSchema(schemaId: UUID) async throws {
        try await products.deletePricingSchema(schemaId: schemaId)
    }

    // Schema Assignments
    func assignFieldSchemaToCategory(categoryId: UUID, fieldSchemaId: UUID) async throws {
        try await products.assignFieldSchemaToCategory(categoryId: categoryId, fieldSchemaId: fieldSchemaId)
    }

    func removeFieldSchemaFromCategory(categoryId: UUID, fieldSchemaId: UUID) async throws {
        try await products.removeFieldSchemaFromCategory(categoryId: categoryId, fieldSchemaId: fieldSchemaId)
    }

    func assignPricingSchemaToCategory(categoryId: UUID, pricingSchemaId: UUID) async throws {
        try await products.assignPricingSchemaToCategory(categoryId: categoryId, pricingSchemaId: pricingSchemaId)
    }

    func removePricingSchemaFromCategory(categoryId: UUID, pricingSchemaId: UUID) async throws {
        try await products.removePricingSchemaFromCategory(categoryId: categoryId, pricingSchemaId: pricingSchemaId)
    }

    // Stores & Locations
    func fetchStores(limit: Int = 100) async throws -> [Store] {
        try await storeLocation.fetchStores(limit: limit)
    }

    func fetchStore(id: UUID) async throws -> Store {
        try await storeLocation.fetchStore(id: id)
    }

    func createStore(_ store: StoreInsert) async throws -> Store {
        try await storeLocation.createStore(store)
    }

    func fetchLocations(storeId: UUID) async throws -> [Location] {
        try await storeLocation.fetchLocations(storeId: storeId)
    }

    // Chat
    func fetchConversations(storeId: UUID, chatType: String? = nil) async throws -> [Conversation] {
        try await chat.fetchConversations(storeId: storeId, chatType: chatType)
    }

    func fetchConversation(id: UUID) async throws -> Conversation {
        try await chat.fetchConversation(id: id)
    }

    func fetchConversationsByLocation(locationId: UUID) async throws -> [Conversation] {
        try await chat.fetchConversationsByLocation(locationId: locationId)
    }

    func fetchAllConversationsForStoreLocations(storeId: UUID, fetchLocations: @escaping (UUID) async throws -> [Location]) async throws -> [Conversation] {
        try await chat.fetchAllConversationsForStoreLocations(storeId: storeId, fetchLocations: fetchLocations)
    }

    func createConversation(_ conversation: ConversationInsert) async throws -> Conversation {
        try await chat.createConversation(conversation)
    }

    func getOrCreateTeamConversation(storeId: UUID, chatType: String, title: String) async throws -> Conversation {
        try await chat.getOrCreateTeamConversation(storeId: storeId, chatType: chatType, title: title)
    }

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [ChatMessage] {
        try await chat.fetchMessages(conversationId: conversationId, limit: limit, before: before)
    }

    func sendMessage(_ message: ChatMessageInsert) async throws -> ChatMessage {
        try await chat.sendMessage(message)
    }

    func fetchParticipants(conversationId: UUID) async throws -> [ChatParticipant] {
        try await chat.fetchParticipants(conversationId: conversationId)
    }

    func updateTypingStatus(conversationId: UUID, userId: UUID, isTyping: Bool) async throws {
        try await chat.updateTypingStatus(conversationId: conversationId, userId: userId, isTyping: isTyping)
    }

    func markMessagesRead(conversationId: UUID, userId: UUID, lastMessageId: UUID) async throws {
        try await chat.markMessagesRead(conversationId: conversationId, userId: userId, lastMessageId: lastMessageId)
    }

    func messagesChannel(conversationId: UUID) -> RealtimeChannelV2 {
        chat.messagesChannel(conversationId: conversationId)
    }

    // Browser Sessions
    func fetchBrowserSessions(storeId: UUID, limit: Int = 100) async throws -> [BrowserSession] {
        try await storeLocation.fetchBrowserSessions(storeId: storeId, limit: limit)
    }

    func fetchBrowserSession(id: UUID) async throws -> BrowserSession? {
        try await storeLocation.fetchBrowserSession(id: id)
    }

    func fetchActiveBrowserSessions(storeId: UUID) async throws -> [BrowserSession] {
        try await storeLocation.fetchActiveBrowserSessions(storeId: storeId)
    }

    func updateBrowserSessionStatus(id: UUID, status: String) async throws {
        try await storeLocation.updateBrowserSessionStatus(id: id, status: status)
    }

    func createBrowserSession(storeId: UUID, name: String) async throws -> BrowserSession {
        try await storeLocation.createBrowserSession(storeId: storeId, name: name)
    }

    func deleteBrowserSession(id: UUID) async throws {
        try await storeLocation.deleteBrowserSession(id: id)
    }

    func closeBrowserSession(id: UUID) async throws {
        try await storeLocation.closeBrowserSession(id: id)
    }

    // MARK: - Orders

    func fetchOrders(storeId: UUID, status: String? = nil, limit: Int = 100) async throws -> [Order] {
        try await orders.fetchOrders(storeId: storeId, status: status, limit: limit)
    }

    func fetchOrder(id: UUID) async throws -> Order {
        try await orders.fetchOrder(id: id)
    }

    func fetchOrdersByLocation(locationId: UUID, limit: Int = 50) async throws -> [Order] {
        try await orders.fetchOrdersByLocation(locationId: locationId, limit: limit)
    }

    func fetchOrdersByStatus(storeId: UUID, status: String, limit: Int = 50) async throws -> [Order] {
        try await orders.fetchOrdersByStatus(storeId: storeId, status: status, limit: limit)
    }

    func fetchRecentOrders(storeId: UUID, limit: Int = 20) async throws -> [Order] {
        try await orders.fetchRecentOrders(storeId: storeId, limit: limit)
    }

    func updateOrderStatus(id: UUID, status: String) async throws {
        try await orders.updateOrderStatus(id: id, status: status)
    }

    func updateOrderFulfillmentStatus(id: UUID, fulfillmentStatus: String) async throws {
        try await orders.updateOrderFulfillmentStatus(id: id, fulfillmentStatus: fulfillmentStatus)
    }

    func fetchOrderCounts(storeId: UUID) async throws -> [String: Int] {
        try await orders.fetchOrderCounts(storeId: storeId)
    }

    func fetchOrderItems(orderId: UUID) async throws -> [OrderItem] {
        try await orders.fetchOrderItems(orderId: orderId)
    }

    func fetchOrderStatusHistory(orderId: UUID) async throws -> [OrderStatusHistory] {
        try await orders.fetchOrderStatusHistory(orderId: orderId)
    }

    func fetchOrderWithDetails(orderId: UUID, locationId: UUID? = nil) async throws -> OrderWithDetails {
        try await orders.fetchOrderWithDetails(orderId: orderId, locationId: locationId)
    }

    func updateOrderStatusWithHistory(id: UUID, fromStatus: String?, toStatus: String, note: String?) async throws {
        try await orders.updateOrderStatusWithHistory(id: id, fromStatus: fromStatus, toStatus: toStatus, note: note)
    }

    func updateItemFulfillment(itemId: UUID, status: String, fulfilledQty: Decimal?) async throws {
        try await orders.updateItemFulfillment(itemId: itemId, status: status, fulfilledQty: fulfilledQty)
    }

    func fetchHeadlessCustomer(customerId: UUID) async throws -> HeadlessCustomer? {
        try await orders.fetchHeadlessCustomer(customerId: customerId)
    }

    func fetchStaffMember(userId: UUID) async throws -> StaffMember? {
        try await orders.fetchStaffMember(userId: userId)
    }

    func fetchStaffMembers(userIds: [UUID]) async throws -> [UUID: StaffMember] {
        try await orders.fetchStaffMembers(userIds: userIds)
    }

    // MARK: - Customers

    func fetchCustomers(storeId: UUID, limit: Int = 100, offset: Int = 0) async throws -> [Customer] {
        try await customers.fetchCustomers(storeId: storeId, limit: limit, offset: offset)
    }

    func fetchCustomer(id: UUID) async throws -> Customer {
        try await customers.fetchCustomer(id: id)
    }

    func searchCustomers(storeId: UUID, query: String, limit: Int = 50) async throws -> [Customer] {
        try await customers.searchCustomers(storeId: storeId, query: query, limit: limit)
    }

    func fetchCustomersByTier(storeId: UUID, tier: String, limit: Int = 100) async throws -> [Customer] {
        try await customers.fetchCustomersByTier(storeId: storeId, tier: tier, limit: limit)
    }

    func fetchVIPCustomers(storeId: UUID, minLTV: Decimal = 1000, limit: Int = 50) async throws -> [Customer] {
        try await customers.fetchVIPCustomers(storeId: storeId, minLTV: minLTV, limit: limit)
    }

    func fetchRecentCustomers(storeId: UUID, days: Int = 30, limit: Int = 50) async throws -> [Customer] {
        try await customers.fetchRecentCustomers(storeId: storeId, days: days, limit: limit)
    }

    func fetchCustomerNotes(customerId: UUID, limit: Int = 50) async throws -> [CustomerNote] {
        try await customers.fetchCustomerNotes(customerId: customerId, limit: limit)
    }

    func createCustomerNote(customerId: UUID, note: String, noteType: String = "general", isCustomerVisible: Bool = false) async throws -> CustomerNote {
        try await customers.createCustomerNote(customerId: customerId, note: note, noteType: noteType, isCustomerVisible: isCustomerVisible)
    }

    func fetchCustomerLoyalty(customerId: UUID, storeId: UUID) async throws -> CustomerLoyalty? {
        try await customers.fetchCustomerLoyalty(customerId: customerId, storeId: storeId)
    }

    func fetchCustomerStats(storeId: UUID) async throws -> CustomerStats {
        try await customers.fetchCustomerStats(storeId: storeId)
    }
}
