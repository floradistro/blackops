import SwiftUI
import AppKit

// MARK: - Visual Effect Background (NSVisualEffectView)

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// MARK: - Window Vibrancy

struct WindowVibrancy: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = _WiringView()
        DispatchQueue.main.async { v.wireWindow() }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class _WiringView: NSView {
        private static var configured = Set<ObjectIdentifier>()

        func wireWindow() {
            guard let window = self.window else { return }
            let key = ObjectIdentifier(window)
            guard !Self.configured.contains(key) else { return }
            Self.configured.insert(key)

            window.titlebarAppearsTransparent = true

            guard let hostingView = window.contentView,
                  !(hostingView is NSVisualEffectView) else { return }

            let effectView = NSVisualEffectView()
            effectView.material = .sidebar
            effectView.blendingMode = .behindWindow
            effectView.state = .active

            window.contentView = effectView
            effectView.addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            ])
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat

    init(
        padding: CGFloat = DesignSystem.Spacing.lg,
        cornerRadius: CGFloat = DesignSystem.Radius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
    }
}

// MARK: - Glass Section

struct GlassSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(DesignSystem.font(DesignSystem.IconSize.small))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.font(14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }
}

// MARK: - Glass Toolbar

struct GlassToolbar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 0.5)
            }
    }
}

// MARK: - Glass List Item

struct GlassListItem<Content: View>: View {
    let isSelected: Bool
    let content: Content
    let action: () -> Void

    init(
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : .clear)
                        .background(isSelected ? .ultraThinMaterial : .bar, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Glass Panel

struct GlassPanel<Content: View, HeaderActions: View>: View {
    let title: String
    let showHeader: Bool
    let headerActions: () -> HeaderActions
    let content: () -> Content

    init(
        _ title: String,
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
                        .font(DesignSystem.Typography.callout)
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

extension GlassPanel where HeaderActions == EmptyView {
    init(
        _ title: String,
        showHeader: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showHeader = showHeader
        self.headerActions = { EmptyView() }
        self.content = content
    }
}

// MARK: - Search Field

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: (() -> Void)?

    init(_ placeholder: String = "Search", text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(DesignSystem.font(DesignSystem.IconSize.small))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.footnote)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Typography.caption1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(DesignSystem.Typography.headline)
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(DesignSystem.Typography.footnote)
    }
}

// MARK: - Loading Count Badge

struct LoadingCountBadge: View {
    let count: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            if count > 0 {
                Text("\(count)")
                    .font(DesignSystem.font(10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulsing() -> some View {
        modifier(PulseModifier())
    }
}
