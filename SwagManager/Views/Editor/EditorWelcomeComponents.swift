import SwiftUI

// MARK: - Editor Welcome & Small Panel Components

// MARK: - Welcome View (2030 Dark AI Aesthetic)

struct WelcomeView: View {
    @ObservedObject var store: EditorStore
    @State private var appeared = false
    @State private var breathe: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0
    @State private var orbRotation: Double = 0
    @Environment(\.contentZoom) private var zoom

    private var contextualGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Late night"
        }
    }


    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Deep void background with noise texture feel
                Color.black.opacity(0.3)

                // Floating ambient orbs
                floatingOrbs

                // Main content
                VStack(spacing: 0) {
                    Spacer()

                    // Central AI presence
                    aiPresenceCore
                        .padding(.bottom, 48 * zoom)


                    // Ghost action buttons
                    actionRow
                        .padding(.bottom, 48 * zoom)

                    Spacer()
                }
                .frame(maxWidth: 600 * zoom)
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathe = 1
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                glowIntensity = 1
            }
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
        }
    }


    // MARK: - Floating Orbs

    private var floatingOrbs: some View {
        ZStack {
            // Single subtle white glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.03 + glowIntensity * 0.02),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 350
                    )
                )
                .frame(width: 700, height: 700)
                .offset(x: breathe * 10, y: -30)
                .blur(radius: 100)
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - AI Presence Core

    private var aiPresenceCore: some View {
        VStack(spacing: 24 * zoom) {
            // The orb with store logo
            ZStack {
                // Outer breathing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 140 * zoom, height: 140 * zoom)
                    .scaleEffect(1.0 + breathe * 0.08)
                    .opacity(0.6 - breathe * 0.3)

                // Second breathing ring (offset phase)
                Circle()
                    .stroke(
                        Color.white.opacity(0.05),
                        lineWidth: 1
                    )
                    .frame(width: 160 * zoom, height: 160 * zoom)
                    .scaleEffect(1.0 + (1.0 - breathe) * 0.06)
                    .opacity(0.4 - (1.0 - breathe) * 0.2)

                // Glow behind logo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60 * zoom
                        )
                    )
                    .frame(width: 120 * zoom, height: 120 * zoom)

                // Rotating accent arc
                Circle()
                    .trim(from: 0, to: 0.2)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: 130 * zoom, height: 130 * zoom)
                    .rotationEffect(.degrees(orbRotation))

                // Store logo or fallback
                if let logoUrl = store.selectedStore?.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64 * zoom, height: 64 * zoom)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        case .failure(_):
                            fallbackIcon
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 64 * zoom, height: 64 * zoom)
                        @unknown default:
                            fallbackIcon
                        }
                    }
                } else {
                    fallbackIcon
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.5)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: appeared)

            // Text - minimal
            VStack(spacing: 6 * zoom) {
                Text(contextualGreeting)
                    .font(.system(size: 38 * zoom, weight: .ultraLight, design: .default))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.8).delay(0.4), value: appeared)
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 64 * zoom, height: 64 * zoom)
            Image(systemName: "sparkle")
                .font(.system(size: 24 * zoom, weight: .light))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }


    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 12 * zoom) {
            GhostButton(label: "Create", shortcut: "⌘N") {
                store.showNewCreationSheet = true
            }
            GhostButton(label: "Chat", shortcut: "⌘K") {
                // Open AI chat
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)
    }

}

// MARK: - Ghost Button

private struct GhostButton: View {
    let label: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.contentZoom) private var zoom

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * zoom) {
                Text(label)
                    .font(.system(size: 13 * zoom, weight: .regular))
                    .tracking(0.5)

                Text(shortcut)
                    .font(.system(size: 10 * zoom, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .foregroundStyle(Color.white.opacity(isHovering ? 0.9 : 0.6))
            .padding(.horizontal, 20 * zoom)
            .padding(.vertical, 12 * zoom)
            .background(
                RoundedRectangle(cornerRadius: 8 * zoom)
                    .fill(Color.white.opacity(isHovering ? 0.1 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8 * zoom)
                    .stroke(Color.white.opacity(isHovering ? 0.2 : 0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Quick Action Button (Legacy support)

struct QuickActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void
    @Environment(\.contentZoom) private var zoom

    @State private var isHovering = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10 * zoom) {
                Image(systemName: icon)
                    .font(.system(size: 22 * zoom, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(label)
                    .font(.system(size: 12 * zoom, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(shortcut)
                    .font(.system(size: 10 * zoom))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24 * zoom)
            .background(isHovering ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10 * zoom))
            .overlay(
                RoundedRectangle(cornerRadius: 10 * zoom)
                    .stroke(isHovering ? DesignSystem.Colors.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Code Editor Panel

struct CodeEditorPanel: View {
    @Binding var code: String
    let onSave: () -> Void
    @Environment(\.contentZoom) private var zoom

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("React Code")
                    .font(.system(size: 14 * zoom, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(code.count) characters")
                    .font(.system(size: 11 * zoom))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(16 * zoom)
            .background(DesignSystem.Colors.surfaceTertiary)

            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(height: 1)

            // Editor with zoom-scaled font
            TextEditor(text: $code)
                .font(.system(size: 13 * zoom, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Colors.surfaceElevated)
        }
    }
}

// MARK: - Empty Editor State

struct EmptyEditorView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Selection")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Select a creation from the sidebar")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
