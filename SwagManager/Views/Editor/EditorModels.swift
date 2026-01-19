import SwiftUI

// MARK: - Editor Models & Types
// Extracted from EditorView.swift following Apple engineering standards
// Contains: EditorTab enum, OpenTabItem enum with associated logic
// File size: ~125 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Editor Tab Enum

enum EditorTab: String, CaseIterable {
    case preview = "Preview"
    case code = "Code"
    case details = "Details"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .preview: return "play.display"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .details: return "info.circle"
        case .settings: return "gear"
        }
    }

    var terminalLabel: String {
        switch self {
        case .preview: return "▶"
        case .code: return "</>"
        case .details: return "ℹ"
        case .settings: return "⚙"
        }
    }
}

// MARK: - Open Tab Model (Safari/Xcode style tabs)

enum OpenTabItem: Identifiable, Hashable {
    case creation(Creation)
    case product(Product)
    case conversation(Conversation)
    case category(Category)
    case browserSession(BrowserSession)

    var id: String {
        switch self {
        case .creation(let c): return "creation-\(c.id)"
        case .product(let p): return "product-\(p.id)"
        case .conversation(let c): return "conversation-\(c.id)"
        case .category(let c): return "category-\(c.id)"
        case .browserSession(let s): return "browser-\(s.id)"
        }
    }

    var name: String {
        switch self {
        case .creation(let c): return c.name
        case .product(let p): return p.name
        case .conversation(let c): return c.displayTitle
        case .category(let c): return c.name
        case .browserSession(let s): return s.displayName
        }
    }

    var icon: String {
        switch self {
        case .creation(let c):
            switch c.creationType {
            case .app: return "app.badge"
            case .display: return "display"
            case .email: return "envelope"
            case .landing: return "globe"
            case .dashboard: return "chart.bar.xaxis"
            case .artifact: return "cube"
            case .store: return "storefront"
            }
        case .product: return "leaf"
        case .conversation(let c): return c.chatTypeIcon
        case .category: return "folder"
        case .browserSession: return "globe"
        }
    }

    var iconColor: Color {
        switch self {
        case .creation(let c): return c.creationType.color
        case .product: return .green
        case .conversation: return .blue
        case .category: return .orange
        case .browserSession: return .cyan
        }
    }

    var isCreation: Bool {
        if case .creation = self { return true }
        return false
    }

    var isBrowserSession: Bool {
        if case .browserSession = self { return true }
        return false
    }

    // Terminal-style icon
    var terminalIcon: String {
        switch self {
        case .creation(let c): return c.creationType.terminalIcon
        case .product: return "•"
        case .conversation: return "◈"
        case .category: return "▢"
        case .browserSession: return "◎"
        }
    }

    // Terminal-style color
    var terminalColor: Color {
        switch self {
        case .creation(let c): return c.creationType.terminalColor
        case .product: return .green
        case .conversation: return .purple
        case .category: return .yellow
        case .browserSession: return .cyan
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OpenTabItem, rhs: OpenTabItem) -> Bool {
        lhs.id == rhs.id
    }
}
