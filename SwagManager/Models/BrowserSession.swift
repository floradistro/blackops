//
//  BrowserSession.swift
//  SwagManager
//
//  Browser session model for AI-controlled browser instances
//

import Foundation

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
