import SwiftUI

// MARK: - Panel Toolbar
// Unified minimal toolbar for detail panels

struct PanelToolbar<Actions: View>: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    var hasChanges: Bool = false
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
                .symbolEffect(.bounce, value: hasChanges)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
                .lineLimit(1)

            if let subtitle = subtitle {
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.3))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .lineLimit(1)
            }

            if hasChanges {
                Circle()
                    .fill(Color.primary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
                    .modifier(PulseModifier())
            }

            Spacer()

            actions()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasChanges)
    }
}

// Convenience initializer without actions
extension PanelToolbar where Actions == EmptyView {
    init(title: String, icon: String, subtitle: String? = nil, hasChanges: Bool = false) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.hasChanges = hasChanges
        self.actions = { EmptyView() }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    var disabled: Bool = false

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.primary.opacity(disabled ? 0.2 : (isHovering ? 0.8 : 0.5)))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(
                            isPressed ? 0.1 :
                            isHovering && !disabled ? 0.06 : 0
                        ))
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
