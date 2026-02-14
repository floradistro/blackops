import SwiftUI

// MARK: - Template Category

enum TemplateCategory: String, CaseIterable, Identifiable {
    case automation
    case integration
    case ai
    case notification
    case data
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automation: return "Automation"
        case .integration: return "Integration"
        case .ai: return "AI & Agents"
        case .notification: return "Notifications"
        case .data: return "Data Processing"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .automation: return "gearshape.2.fill"
        case .integration: return "link.circle.fill"
        case .ai: return "brain.fill"
        case .notification: return "bell.badge.fill"
        case .data: return "doc.viewfinder.fill"
        case .custom: return "star.fill"
        }
    }
}

// MARK: - Preview Step

struct PreviewStep {
    let type: String
    let label: String
}

// MARK: - Gallery Template (Display Model)

struct GalleryTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: TemplateCategory
    let stepCount: Int
    let estimatedSetupTime: String
    let popularity: Int
    let icon: String
    let previewSteps: [PreviewStep]
}

// MARK: - Workflow Template Gallery

struct WorkflowTemplateGallery: View {
    @Environment(\.workflowService) private var service

    let storeId: UUID?
    let onClone: (Workflow) -> Void
    let onDismiss: () -> Void

    @State private var templates: [GalleryTemplate] = []
    @State private var searchText = ""
    @State private var selectedCategory: TemplateCategory?
    @State private var isLoading = false
    @State private var cloningId: String?

    private var filteredTemplates: [GalleryTemplate] {
        var list = templates
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: DS.Spacing.lg)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            categoryFilter
            Divider().foregroundStyle(DS.Colors.divider)
            content
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 500, idealHeight: 640)
        .background(.ultraThickMaterial)
        .task {
            await loadTemplates()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "square.grid.2x2.fill")
                .font(DS.Typography.title3)
                .foregroundStyle(DS.Colors.accent)

            Text("Template Gallery")
                .font(DS.Typography.title3)
                .foregroundStyle(DS.Colors.textPrimary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.footnote)
                    .frame(width: 160)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(DS.Colors.border, lineWidth: 0.5)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                categoryPill(label: "All", icon: "square.grid.2x2", isSelected: selectedCategory == nil) {
                    withAnimation(DS.Animation.fast) { selectedCategory = nil }
                }

                ForEach(TemplateCategory.allCases) { cat in
                    categoryPill(label: cat.label, icon: cat.icon, isSelected: selectedCategory == cat) {
                        withAnimation(DS.Animation.fast) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private func categoryPill(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.caption2)
                Text(label)
                    .font(DS.Typography.caption1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .foregroundStyle(isSelected ? .white : DS.Colors.textSecondary)
            .background(
                isSelected ? AnyShapeStyle(DS.Colors.accent) : AnyShapeStyle(DS.Colors.surfaceHover),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : DS.Colors.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Spacer()
        } else if filteredTemplates.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                    ForEach(filteredTemplates) { template in
                        TemplateCard(
                            template: template,
                            isCloning: cloningId == template.id,
                            onUse: { cloneTemplate(template) }
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(DS.Colors.textQuaternary)
            Text("No templates found")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.textSecondary)
            Text(searchText.isEmpty ? "Templates will appear here once available." : "Try a different search or category.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
            Spacer()
        }
    }

    // MARK: - Actions

    private func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }

        let serverTemplates = await service.listTemplates(storeId: storeId)
        templates = serverTemplates.map { mapToGalleryTemplate($0) }
    }

    private func cloneTemplate(_ template: GalleryTemplate) {
        guard cloningId == nil else { return }
        cloningId = template.id

        Task {
            if let workflow = await service.cloneTemplate(
                templateId: template.id,
                name: template.name,
                storeId: storeId
            ) {
                onClone(workflow)
            }
            cloningId = nil
        }
    }

    // MARK: - Mapping

    private func mapToGalleryTemplate(_ workflow: Workflow) -> GalleryTemplate {
        let category = inferCategory(from: workflow)
        let steps = inferPreviewSteps(from: workflow)

        return GalleryTemplate(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description ?? "Pre-built workflow template",
            category: category,
            stepCount: steps.count > 0 ? steps.count : 3,
            estimatedSetupTime: estimateSetupTime(stepCount: steps.count),
            popularity: workflow.runCount ?? 0,
            icon: workflow.icon ?? category.icon,
            previewSteps: steps
        )
    }

    private func inferCategory(from workflow: Workflow) -> TemplateCategory {
        let text = "\(workflow.name) \(workflow.description ?? "")".lowercased()

        if text.contains("agent") || text.contains("ai") || text.contains("llm") || text.contains("gpt") {
            return .ai
        }
        if text.contains("notify") || text.contains("notification") || text.contains("alert") || text.contains("email") || text.contains("slack") {
            return .notification
        }
        if text.contains("webhook") || text.contains("api") || text.contains("integrat") || text.contains("sync") {
            return .integration
        }
        if text.contains("data") || text.contains("transform") || text.contains("etl") || text.contains("process") || text.contains("report") {
            return .data
        }
        if text.contains("automat") || text.contains("schedule") || text.contains("cron") || text.contains("inventory") || text.contains("order") {
            return .automation
        }
        return .custom
    }

    private func inferPreviewSteps(from workflow: Workflow) -> [PreviewStep] {
        // Without graph data on the template, infer basic steps from trigger type
        var steps: [PreviewStep] = []

        switch workflow.triggerType {
        case "webhook":
            steps.append(PreviewStep(type: "webhook_out", label: "Webhook"))
        case "schedule", "cron":
            steps.append(PreviewStep(type: "delay", label: "Schedule"))
        case "event":
            steps.append(PreviewStep(type: "condition", label: "Event"))
        default:
            steps.append(PreviewStep(type: "tool", label: "Start"))
        }

        // Add generic middle steps based on category inference
        let category = inferCategory(from: workflow)
        switch category {
        case .ai:
            steps.append(PreviewStep(type: "agent", label: "Agent"))
            steps.append(PreviewStep(type: "tool", label: "Action"))
        case .notification:
            steps.append(PreviewStep(type: "condition", label: "Check"))
            steps.append(PreviewStep(type: "tool", label: "Notify"))
        case .integration:
            steps.append(PreviewStep(type: "tool", label: "Fetch"))
            steps.append(PreviewStep(type: "transform", label: "Map"))
        case .data:
            steps.append(PreviewStep(type: "transform", label: "Transform"))
            steps.append(PreviewStep(type: "tool", label: "Store"))
        case .automation:
            steps.append(PreviewStep(type: "condition", label: "Check"))
            steps.append(PreviewStep(type: "tool", label: "Execute"))
        case .custom:
            steps.append(PreviewStep(type: "tool", label: "Step"))
        }

        return steps
    }

    private func estimateSetupTime(stepCount: Int) -> String {
        if stepCount <= 2 { return "1 min" }
        if stepCount <= 4 { return "2 min" }
        if stepCount <= 6 { return "3 min" }
        return "5 min"
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: GalleryTemplate
    let isCloning: Bool
    let onUse: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Icon + Name
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: template.icon)
                    .font(DS.Typography.headline)
                    .foregroundStyle(categoryColor)
                    .frame(width: 28, height: 28)

                Text(template.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            // Description
            Text(template.description)
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Mini DAG Preview
            MiniDAGPreview(steps: template.previewSteps)
                .frame(height: 80)
                .frame(maxWidth: .infinity)

            // Footer: metadata + button
            HStack(spacing: DS.Spacing.sm) {
                // Step count
                Label("\(template.stepCount) steps", systemImage: "square.stack.3d.up")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)

                // Setup time
                Label(template.estimatedSetupTime, systemImage: "clock")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)

                // Popularity
                if template.popularity > 0 {
                    Label("\(template.popularity)", systemImage: "arrow.down.circle")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                // Use button
                Button(action: onUse) {
                    if isCloning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                    } else {
                        Text("Use Template")
                            .font(DS.Typography.buttonSmall)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.accent)
                .controlSize(.small)
                .disabled(isCloning)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(
                    isHovered ? DS.Colors.accent.opacity(0.4) : DS.Colors.border,
                    lineWidth: isHovered ? 1 : 0.5
                )
        }
        .shadow(
            color: Color.black.opacity(isHovered ? 0.15 : 0.08),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(DS.Animation.fast, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var categoryColor: Color {
        switch template.category {
        case .automation: return DS.Colors.orange
        case .integration: return DS.Colors.green
        case .ai: return DS.Colors.cyan
        case .notification: return DS.Colors.yellow
        case .data: return DS.Colors.purple
        case .custom: return DS.Colors.accent
        }
    }
}

// MARK: - Mini DAG Preview (Canvas Renderer)

private struct MiniDAGPreview: View {
    let steps: [PreviewStep]

    var body: some View {
        Canvas { context, size in
            let count = min(steps.count, 5)
            guard count > 0 else { return }

            let centerX = size.width / 2
            let dotRadius: CGFloat = 6
            let verticalPadding: CGFloat = 10
            let availableHeight = size.height - (verticalPadding * 2)
            let spacing = count > 1 ? availableHeight / CGFloat(count - 1) : 0

            for i in 0..<count {
                let y = count > 1
                    ? verticalPadding + CGFloat(i) * spacing
                    : size.height / 2
                let center = CGPoint(x: centerX, y: y)

                // Draw connecting line to next step
                if i < count - 1 {
                    let nextY = verticalPadding + CGFloat(i + 1) * spacing
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: centerX, y: y + dotRadius + 1))
                    linePath.addLine(to: CGPoint(x: centerX, y: nextY - dotRadius - 1))
                    context.stroke(
                        linePath,
                        with: .color(Color.white.opacity(0.15)),
                        lineWidth: 1
                    )
                }

                // Draw dot
                let dotRect = CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                let color = stepColor(for: steps[i].type)
                context.fill(Circle().path(in: dotRect), with: .color(color))

                // Draw label
                let labelText = Text(steps[i].label)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(Color.white.opacity(0.5))
                context.draw(
                    context.resolve(labelText),
                    at: CGPoint(x: centerX + dotRadius + 24, y: y),
                    anchor: .leading
                )
            }
        }
    }

    private func stepColor(for type: String) -> Color {
        switch type {
        case "tool": return DS.Colors.orange
        case "condition": return DS.Colors.accent
        case "agent": return DS.Colors.cyan
        case "code": return DS.Colors.purple
        case "delay": return DS.Colors.yellow
        case "webhook_out": return DS.Colors.green
        case "transform": return DS.Colors.cyan
        default: return DS.Colors.textTertiary
        }
    }
}
