//
//  BrowserSession.swift
//  SwagManager
//
//  Browser session model for AI-controlled browser instances
//

import Foundation
import SwiftUI

struct BrowserSession: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var creationId: UUID?
    var storeId: UUID?
    var name: String?
    var currentUrl: String?
    var viewportWidth: Int?
    var viewportHeight: Int?
    var userAgent: String?
    var cookies: AnyCodable?
    var localStorage: AnyCodable?
    var sessionStorage: AnyCodable?
    var screenshotUrl: String?
    var screenshotAt: Date?
    var interactiveElements: AnyCodable?
    var pageTitle: String?
    var browserWsEndpoint: String?
    var browserService: String?
    var status: String?  // active, paused, closed, error
    var errorMessage: String?
    var lastActivity: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case creationId = "creation_id"
        case storeId = "store_id"
        case name
        case currentUrl = "current_url"
        case viewportWidth = "viewport_width"
        case viewportHeight = "viewport_height"
        case userAgent = "user_agent"
        case cookies
        case localStorage = "local_storage"
        case sessionStorage = "session_storage"
        case screenshotUrl = "screenshot_url"
        case screenshotAt = "screenshot_at"
        case interactiveElements = "interactive_elements"
        case pageTitle = "page_title"
        case browserWsEndpoint = "browser_ws_endpoint"
        case browserService = "browser_service"
        case status
        case errorMessage = "error_message"
        case lastActivity = "last_activity"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let title = pageTitle, !title.isEmpty {
            return title
        }
        if let url = currentUrl {
            // Extract domain from URL
            if let urlObj = URL(string: url), let host = urlObj.host {
                return host
            }
        }
        return "Browser Session"
    }

    var isActive: Bool {
        status == "active"
    }

    var isPaused: Bool {
        status == "paused"
    }

    var isClosed: Bool {
        status == "closed"
    }

    var hasError: Bool {
        status == "error"
    }

    var statusIcon: String {
        switch status {
        case "active": return "●"
        case "paused": return "◐"
        case "closed": return "○"
        case "error": return "⚠"
        default: return "○"
        }
    }

    var isSecure: Bool {
        if let url = currentUrl, let urlObj = URL(string: url) {
            return urlObj.scheme == "https"
        }
        return false
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BrowserSession, rhs: BrowserSession) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Open Tab Item
// Represents items that can be opened in tabs (Safari/Xcode style)

enum OpenTabItem: Identifiable, Hashable {
    case creation(Creation)
    case product(Product)
    case conversation(Conversation)
    case category(Category)
    case browserSession(BrowserSession)
    case order(Order)
    case location(Location)
    case queue(Location)
    case customer(Customer)
    case email(ResendEmail)
    case thread(EmailThread)
    case cart(UUID)
    case emailCampaign(EmailCampaign)
    case metaCampaign(MetaCampaign)
    case metaIntegration(MetaIntegration)
    case aiAgent(AIAgent)
    case aiChat

    var id: String {
        switch self {
        case .creation(let c): return "creation-\(c.id)"
        case .product(let p): return "product-\(p.id)"
        case .conversation(let c): return "conversation-\(c.id)"
        case .category(let c): return "category-\(c.id)"
        case .browserSession(let s): return "browser-\(s.id)"
        case .order(let o): return "order-\(o.id)"
        case .location(let l): return "location-\(l.id)"
        case .queue(let l): return "queue-\(l.id)"
        case .customer(let c): return "customer-\(c.id)"
        case .email(let e): return "email-\(e.id)"
        case .thread(let t): return "thread-\(t.id)"
        case .cart(let id): return "cart-\(id)"
        case .emailCampaign(let c): return "email-campaign-\(c.id)"
        case .metaCampaign(let c): return "meta-campaign-\(c.id)"
        case .metaIntegration(let i): return "meta-integration-\(i.id)"
        case .aiAgent(let a): return "agent-\(a.id)"
        case .aiChat: return "ai-chat"
        }
    }

    var title: String {
        switch self {
        case .creation(let c): return c.name
        case .product(let p): return p.name
        case .conversation(let c): return c.title ?? "Chat"
        case .category(let c): return c.name
        case .browserSession(let s): return s.displayName
        case .order(let o): return o.orderNumber
        case .location(let l): return l.name
        case .queue(let l): return "\(l.name) Queue"
        case .customer(let c): return c.displayName
        case .email(let e): return e.subject
        case .thread(let t): return t.displaySubject
        case .cart: return "Cart"
        case .emailCampaign(let c): return c.name
        case .metaCampaign(let c): return c.name
        case .metaIntegration(let i): return i.businessName ?? "Meta"
        case .aiAgent(let a): return a.name ?? "Agent"
        case .aiChat: return "AI Chat"
        }
    }

    var icon: String {
        switch self {
        case .creation: return "wand.and.stars"
        case .product: return "cube.box"
        case .conversation: return "bubble.left.and.bubble.right"
        case .category: return "folder"
        case .browserSession: return "globe"
        case .order: return "bag"
        case .location: return "mappin.and.ellipse"
        case .queue: return "person.3.sequence"
        case .customer: return "person"
        case .email: return "envelope"
        case .thread: return "tray"
        case .cart: return "cart"
        case .emailCampaign: return "paperplane"
        case .metaCampaign: return "megaphone"
        case .metaIntegration: return "link"
        case .aiAgent: return "cpu"
        case .aiChat: return "bubble.left.and.bubble.right"
        }
    }

    // Alias for title (used by some components)
    var name: String { title }

    var iconColor: Color {
        switch self {
        case .creation: return .purple
        case .product: return .blue
        case .conversation: return .green
        case .category: return .orange
        case .browserSession: return .cyan
        case .order: return .pink
        case .location: return .indigo
        case .queue: return .mint
        case .customer: return .teal
        case .email: return .blue
        case .thread: return .cyan
        case .cart: return .orange
        case .emailCampaign: return .green
        case .metaCampaign: return .blue
        case .metaIntegration: return .purple
        case .aiAgent: return .cyan
        case .aiChat: return .green
        }
    }
}
