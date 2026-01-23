import SwiftUI

// MARK: - Tree Section Components
// Optimized for performance with smooth Apple-style animations

// MARK: - Animation Constants

enum TreeAnimations {
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.9, blendDuration: 0)
    static let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.95, blendDuration: 0)
    static let chevron = Animation.spring(response: 0.2, dampingFraction: 0.85, blendDuration: 0)
}

// MARK: - Tree Item Button Style

struct TreeItemButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(
                        configuration.isPressed ? 0.08 :
                        isHovered ? 0.04 : 0
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Loading Count Badge

struct LoadingCountBadge: View {
    let count: Int
    let isLoading: Bool
    @State private var dotPhase = 0

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.primary.opacity(dotPhase == index ? 0.5 : 0.2))
                            .frame(width: 3, height: 3)
                    }
                }
                .onAppear {
                    startAnimation()
                }
            } else if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(TreeAnimations.quickSpring, value: count)
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            if !isLoading {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

// MARK: - Tree Section Header
// Premium monochromatic design with smooth animations

struct TreeSectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color?
    @Binding var isExpanded: Bool
    let count: Int
    let isLoading: Bool
    let realtimeConnected: Bool

    @State private var isHovered = false

    init(title: String, icon: String? = nil, iconColor: Color? = nil, isExpanded: Binding<Bool>, count: Int, isLoading: Bool = false, realtimeConnected: Bool = false) {
        self.title = title
        self.icon = icon
        self.iconColor = nil // Monochromatic
        self._isExpanded = isExpanded
        self.count = count
        self.isLoading = isLoading
        self.realtimeConnected = realtimeConnected
    }

    var body: some View {
        HStack(spacing: 6) {
            // Animated chevron with spring
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.4))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .symbolEffect(.pulse, options: .repeating, isActive: isLoading)
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.85))

            // Realtime pulse indicator
            if realtimeConnected {
                Circle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 4, height: 4)
                    .modifier(PulseModifier())
            }

            Spacer(minLength: 4)

            LoadingCountBadge(count: count, isLoading: isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(isHovered ? 0.04 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(TreeAnimations.smoothSpring) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .animation(TreeAnimations.chevron, value: isExpanded)
        .animation(TreeAnimations.quickSpring, value: realtimeConnected)
    }
}

// MARK: - Pulse Animation Modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Section Group Header

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

    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(TreeAnimations.smoothSpring) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.25))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 10)

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.5 : 0.35))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.98)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .animation(TreeAnimations.chevron, value: isCollapsed)
    }
}

// MARK: - Visual Effect Blur

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

// MARK: - Skeleton Loading View

struct SkeletonView: View {
    let width: CGFloat
    let height: CGFloat

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.primary.opacity(0.06))
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.primary.opacity(0.08),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: shimmerOffset * geometry.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: height / 2))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.5
                }
            }
    }
}

// MARK: - Skeleton Tree Item

struct SkeletonTreeItem: View {
    var body: some View {
        HStack(spacing: 6) {
            SkeletonView(width: 14, height: 14)
            SkeletonView(width: CGFloat.random(in: 60...100), height: 10)
            Spacer()
            SkeletonView(width: 20, height: 10)
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
    }
}
