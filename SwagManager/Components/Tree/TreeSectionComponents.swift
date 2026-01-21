import SwiftUI

// MARK: - Tree Section Components
// Extracted from TreeItems.swift following Apple engineering standards
// Contains: TreeItemButtonStyle, TreeSectionHeader, LoadingCountBadge, SectionGroupHeader
// File size: ~200 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Tree Item Button Style

struct TreeItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? DesignSystem.Colors.surfaceActive : Color.clear
            )
    }
}

// MARK: - Loading Count Badge
// Native iOS spinner for sidebar section counts

struct LoadingCountBadge: View {
    let count: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                // Native iOS spinner (hide count while loading)
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else if count > 0 {
                // Count in simple parentheses format
                Text("(\(count))")
                    .font(DesignSystem.Typography.sidebarItemCount)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Tree Section Header

struct TreeSectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color?
    @Binding var isExpanded: Bool
    let count: Int
    let isLoading: Bool
    let realtimeConnected: Bool

    init(title: String, icon: String? = nil, iconColor: Color? = nil, isExpanded: Binding<Bool>, count: Int, isLoading: Bool = false, realtimeConnected: Bool = false) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self._isExpanded = isExpanded
        self.count = count
        self.isLoading = isLoading
        self.realtimeConnected = realtimeConnected
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(DesignSystem.Animation.fast, value: isExpanded)
                .frame(width: 16)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor ?? .secondary)
            }

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            // Realtime connection indicator
            if realtimeConnected {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.green)
                    .transition(.opacity)
            }

            Spacer(minLength: 4)

            LoadingCountBadge(
                count: count,
                isLoading: isLoading
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DesignSystem.Animation.fast) {
                isExpanded.toggle()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: realtimeConnected)
    }
}

// MARK: - Section Group Header
// Floating glass headers matching native macOS style (Finder, Mail, etc.)
// These pin to the top when scrolling, providing persistent navigation context

enum SidebarGroup: String {
    case workspace = "Workspace"
    case content = "Content"
    case operations = "Operations"
    case infrastructure = "Infrastructure"

    var color: Color {
        switch self {
        case .workspace: return .green
        case .content: return .blue
        case .operations: return .orange
        case .infrastructure: return .purple
        }
    }
}

struct SectionGroupHeader: View {
    let title: String
    let group: SidebarGroup
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.fast) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 16)

                // Title
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(DesignSystem.Colors.surfaceSecondary.opacity(0.5))
    }
}

// MARK: - Visual Effect Blur
// Native macOS blur effect for glass morphism

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
