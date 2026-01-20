import SwiftUI

// MARK: - Floating Context Bar
// Ultra-minimal, Apple/Anthropic-style context switcher
// Almost invisible until interacted with

struct FloatingContextBar: View {
    @ObservedObject var store: EditorStore
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Scrollable tab area
            if !store.openTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(store.openTabs) { tab in
                            ContextPill(
                                tab: tab,
                                isActive: store.activeTab?.id == tab.id,
                                onSelect: { store.switchToTab(tab) },
                                onClose: { store.closeTab(tab) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .scrollClipDisabled(false)
                .frame(maxWidth: 500) // Reasonable max before scrolling kicks in
            }

            // Subtle separator when we have tabs
            if !store.openTabs.isEmpty {
                capsuleDivider
            }

            // Quick actions
            quickActions
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(isHovering ? 0.95 : 0.7)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isHovering ? 0.12 : 0.06), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.openTabs.count)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 2) {
            GhostButton(icon: "plus", size: 11) {
                // Show menu of what to create
            }
            .help("New...")
        }
    }

    private var capsuleDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 8)
    }
}

// MARK: - Context Pill

struct ContextPill: View {
    let tab: OpenTabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Text(tab.name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)

                // Close button (on hover)
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? Color.white.opacity(0.15) : (isHovering ? Color.white.opacity(0.08) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Ghost Button (Ultra-minimal)

struct GhostButton: View {
    let icon: String
    var size: CGFloat = 12
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovering ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

