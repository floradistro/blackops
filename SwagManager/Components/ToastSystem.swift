import SwiftUI

// MARK: - Toast System
// Slide-down toast notifications with auto-dismiss

enum ToastType {
    case success
    case error
    case info
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
@MainActor
final class ToastManager {
    static let shared = ToastManager()

    var currentToast: ToastMessage?

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, type: ToastType = .info, duration: TimeInterval = 3.0) {
        dismissTask?.cancel()
        currentToast = ToastMessage(message: message, type: type, duration: duration)

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                currentToast = nil
            }
        }
    }

    func success(_ message: String) {
        show(message, type: .success)
    }

    func error(_ message: String) {
        show(message, type: .error)
    }

    func dismiss() {
        dismissTask?.cancel()
        currentToast = nil
    }
}

// MARK: - Toast Overlay

struct ToastOverlay: View {
    @State private var toast = ToastManager.shared

    var body: some View {
        VStack {
            if let message = toast.currentToast {
                ToastView(toast: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { toast.dismiss() }
            }
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast.currentToast)
        .allowsHitTesting(toast.currentToast != nil)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage

    private var icon: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.type {
        case .success: return DesignSystem.Colors.success
        case .error: return DesignSystem.Colors.error
        case .info: return DesignSystem.Colors.accent
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.IconSize.small))
                .foregroundStyle(iconColor)

            Text(toast.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.top, DesignSystem.Spacing.sm)
    }
}
