import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag Data Formats
// Using plain text with prefixes to avoid Info.plist requirements

enum DragItemType: String {
    case mcpServer = "mcpserver:"
    case product = "product:"
    case customer = "customer:"
    case location = "location:"

    static func encode(_ type: DragItemType, uuid: UUID) -> String {
        return type.rawValue + uuid.uuidString
    }

    static func decode(_ string: String) -> (type: DragItemType, uuid: UUID)? {
        for type in [DragItemType.mcpServer, .product, .customer, .location] {
            if string.hasPrefix(type.rawValue) {
                let uuidString = String(string.dropFirst(type.rawValue.count))
                if let uuid = UUID(uuidString: uuidString) {
                    return (type, uuid)
                }
            }
        }
        return nil
    }
}

// MARK: - Draggable Tool Row

struct DraggableToolRow: View {
    let tool: MCPServer
    @State private var isHovered = false
    @EnvironmentObject private var editorStore: EditorStore

    private var builderStore: AgentBuilderStore? {
        editorStore.agentBuilderStore
    }

    var body: some View {
        Button {
            builderStore?.addTool(tool)
        } label: {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: toolIcon)
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundStyle(isHovered ? .primary : .secondary)

                Text(tool.name)
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                    .lineLimit(1)

                Spacer()

                if isHovered {
                    Image(systemName: "plus.circle")
                        .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: DesignSystem.TreeSpacing.itemHeight)
        .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? DesignSystem.Colors.surfaceHover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(tool.description ?? "Click to add this tool to your agent")
    }

    private var toolIcon: String {
        if tool.isReadOnly == true {
            return "eye.fill"
        } else {
            return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Draggable Context Row

struct DraggableContextRow: View {
    let type: AgentContextType
    let title: String
    let count: Int?
    let icon: String
    @State private var isHovered = false
    @EnvironmentObject private var editorStore: EditorStore

    private var builderStore: AgentBuilderStore? {
        editorStore.agentBuilderStore
    }

    var body: some View {
        Button {
            builderStore?.addContext(type)
        } label: {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundStyle(contextColor)

                Text(title)
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                    .lineLimit(1)

                Spacer()

                if let count = count {
                    Text("\(count)")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundStyle(.tertiary)
                }

                if isHovered {
                    Image(systemName: "plus.circle")
                        .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: DesignSystem.TreeSpacing.itemHeight)
        .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? DesignSystem.Colors.surfaceHover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help("Click to add this data as context for your agent")
    }

    private var contextColor: Color {
        switch type {
        case .products, .productCategory: return .blue
        case .location: return .green
        case .customers, .customerSegment: return .purple
        }
    }
}

// MARK: - Draggable Template Row

struct DraggableTemplateRow: View {
    let template: PromptTemplate
    @State private var isHovered = false
    @EnvironmentObject private var editorStore: EditorStore

    private var builderStore: AgentBuilderStore? {
        editorStore.agentBuilderStore
    }

    var body: some View {
        Button {
            builderStore?.appendToSystemPrompt(template)
        } label: {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundStyle(.orange)

                Text(template.name)
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                    .lineLimit(1)

                Spacer()

                if isHovered {
                    Image(systemName: "plus.circle")
                        .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: DesignSystem.TreeSpacing.itemHeight)
        .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? DesignSystem.Colors.surfaceHover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(template.description ?? "Click to add this template to your system prompt")
    }
}

// MARK: - Tool Card (in canvas)

struct ToolCard: View {
    let tool: MCPServer
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(categoryColor)

                Spacer()

                if isHovered {
                    Button {
                        withAnimation(DesignSystem.Animation.spring) {
                            onRemove()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove tool")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let description = tool.description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Capabilities badge
            HStack(spacing: 4) {
                if tool.isReadOnly == true {
                    Badge(text: "Read", color: .blue)
                } else {
                    Badge(text: "Write", color: .orange)
                }

                Badge(text: tool.category, color: .gray)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.surfaceTertiary)
                .shadow(
                    color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .strokeBorder(
                    isHovered ? DesignSystem.Colors.border : DesignSystem.Colors.borderSubtle,
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.fast, value: isHovered)
    }

    private var categoryColor: Color {
        switch tool.category.lowercased() {
        case "crm": return .purple
        case "orders": return .blue
        case "products": return .green
        case "inventory": return .orange
        case "email": return .pink
        default: return .gray
        }
    }
}

// MARK: - Context Data Card

struct ContextDataCard: View {
    let context: AgentContextData
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: context.icon)
                .font(.system(size: 20))
                .foregroundStyle(context.color)
                .frame(width: 32, height: 32)
                .background(context.color.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.title)
                    .font(.system(size: 13, weight: .medium))

                Text(context.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovered {
                Button {
                    withAnimation(DesignSystem.Animation.spring) {
                        onRemove()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove context")
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.surfaceTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isHovered ? DesignSystem.Colors.border : DesignSystem.Colors.borderSubtle,
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(DesignSystem.Animation.fast, value: isHovered)
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Drag Item Models

enum AgentDragItem: Codable {
    case tool(MCPServer)
    case context(AgentContextType)
    case template(PromptTemplate)

    var encoded: String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func decode(_ string: String) -> AgentDragItem? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AgentDragItem.self, from: data)
    }
}

enum AgentContextType: Codable {
    case products
    case productCategory(String)
    case location(StoreLocation)
    case customers
    case customerSegment(String)
}

// MARK: - Drop Delegates

struct ToolDropDelegate: DropDelegate {
    let builderStore: AgentBuilderStore

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let string = String(data: data, encoding: .utf8),
                  let dragItem = AgentDragItem.decode(string) else {
                return
            }

            DispatchQueue.main.async {
                switch dragItem {
                case .tool(let tool):
                    withAnimation(DesignSystem.Animation.spring) {
                        builderStore.addTool(tool)
                    }
                default:
                    break
                }
            }
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback when dragging over drop zone
    }

    func dropExited(info: DropInfo) {
        // Reset visual feedback
    }
}

struct ContextDropDelegate: DropDelegate {
    let builderStore: AgentBuilderStore

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let string = String(data: data, encoding: .utf8),
                  let dragItem = AgentDragItem.decode(string) else {
                return
            }

            DispatchQueue.main.async {
                switch dragItem {
                case .context(let type):
                    withAnimation(DesignSystem.Animation.spring) {
                        builderStore.addContext(type)
                    }
                default:
                    break
                }
            }
        }

        return true
    }
}

struct PromptDropDelegate: DropDelegate {
    let builderStore: AgentBuilderStore
    let dropAction: (PromptTemplate) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let string = String(data: data, encoding: .utf8),
                  let dragItem = AgentDragItem.decode(string) else {
                return
            }

            DispatchQueue.main.async {
                switch dragItem {
                case .template(let template):
                    withAnimation(DesignSystem.Animation.spring) {
                        dropAction(template)
                    }
                default:
                    break
                }
            }
        }

        return true
    }
}
