import SwiftUI

// MARK: - Glass UI Components
// Recreated from deleted UnifiedGlassComponents.swift

// MARK: - Glass Panel

struct GlassPanel<Content: View, HeaderActions: View>: View {
    let title: String
    let showHeader: Bool
    let headerActions: () -> HeaderActions
    let content: () -> Content

    init(
        title: String,
        showHeader: Bool = true,
        @ViewBuilder headerActions: @escaping () -> HeaderActions = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showHeader = showHeader
        self.headerActions = headerActions
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHeader {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    headerActions()
                }
                .padding()
                .background(VisualEffectBackground(material: .sidebar))
            }

            ScrollView {
                content()
                    .padding()
            }
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }
}

// Convenience initializer for GlassPanel with no header actions
extension GlassPanel where HeaderActions == EmptyView {
    init(
        title: String,
        showHeader: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showHeader = showHeader
        self.headerActions = { EmptyView() }
        self.content = content
    }
}

// MARK: - Glass Section

struct GlassSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            content()
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}
