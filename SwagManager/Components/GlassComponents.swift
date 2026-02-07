import SwiftUI
import AppKit

// MARK: - Glass UI Components
// Recreated from deleted UnifiedGlassComponents.swift

// MARK: - Visual Effect Background (NSVisualEffectView wrapper)

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

// MARK: - Common UI Components

struct SectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    init(title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

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
    }
}

// MARK: - Stub Views (for features not yet implemented)

struct POSSettingsViewStub: View {
    @Environment(\.editorStore) private var store
    let locationId: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("POS Settings")
                .font(.title2.bold())
            Text("Register & Printer settings")
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 300)
    }
}

struct LabelPrinterSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Label Printer Settings")
                .font(.title2.bold())
            Text("Configure your label printer")
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 300)
    }
}

// MARK: - Loading Count Badge

struct LoadingCountBadge: View {
    let count: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pulse Modifier (Animation)

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

