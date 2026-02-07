import SwiftUI

// MARK: - Open Tab Item
// Represents items that can be opened in tabs (Safari/Xcode style)

enum OpenTabItem: Identifiable, Hashable {
    case conversation(Conversation)
    case category(Category)
    case location(Location)
    case queue(Location)
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
        case .conversation(let c): return "conversation-\(c.id)"
        case .category(let c): return "category-\(c.id)"
        case .location(let l): return "location-\(l.id)"
        case .queue(let l): return "queue-\(l.id)"
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
        case .conversation(let c): return c.title ?? "Chat"
        case .category(let c): return c.name
        case .location(let l): return l.name
        case .queue(let l): return "\(l.name) Queue"
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
        case .conversation: return "bubble.left.and.bubble.right"
        case .category: return "folder"
        case .location: return "mappin.and.ellipse"
        case .queue: return "person.3.sequence"
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
        case .conversation: return .green
        case .category: return .orange
        case .location: return .indigo
        case .queue: return .mint
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
