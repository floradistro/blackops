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
// Premium monochromatic design - Apple-like simplicity

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
        // Ignore iconColor - use monochromatic styling
        self.iconColor = nil
        self._isExpanded = isExpanded
        self.count = count
        self.isLoading = isLoading
        self.realtimeConnected = realtimeConnected
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.4))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(DesignSystem.Animation.fast, value: isExpanded)
                .frame(width: 12)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.85))

            // Realtime connection indicator - subtle dot instead of antenna
            if realtimeConnected {
                Circle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 4, height: 4)
                    .transition(.opacity)
            }

            Spacer(minLength: 4)

            LoadingCountBadge(
                count: count,
                isLoading: isLoading
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
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
// Premium monochromatic headers - clean Apple aesthetic

enum SidebarGroup: String {
    case workspace = "Workspace"
    case content = "Content"
    case operations = "Operations"
    case infrastructure = "Infrastructure"
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
            HStack(spacing: 6) {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 12)

                // Title - uppercase, letter-spaced for premium feel
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.primary.opacity(0.45))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.02))
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
