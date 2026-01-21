//
//  ModalComponents.swift
//  SwagManager (macOS)
//
//  Reusable modal/sheet component styles
//  Ported from iOS Whale app
//

import SwiftUI

// MARK: - Modal Section

struct ModalSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
    }
}

// MARK: - Modal Header

struct ModalHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let onClose: () -> Void
    @ViewBuilder let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, onClose: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            ModalCloseButton(action: onClose)
            Spacer()
            VStack(spacing: 2) {
                if let subtitle = subtitle {
                    Text(subtitle.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.5)
                }
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

extension ModalHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, onClose: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
        self.trailing = EmptyView()
    }
}

// MARK: - Modal Close Button

struct ModalCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modal Back Button

struct ModalBackButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modal Action Button

struct ModalActionButton: View {
    enum Style {
        case primary
        case success
        case destructive
        case glass

        var backgroundColor: Color {
            switch self {
            case .primary: return .white
            case .success: return Color(red: 0.2, green: 0.78, blue: 0.35)
            case .destructive: return Color(red: 0.95, green: 0.3, blue: 0.3)
            case .glass: return .white.opacity(0.15)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return .black
            case .success, .destructive, .glass: return .white
            }
        }
    }

    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var style: Style = .primary
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isEnabled: Bool = true, isLoading: Bool = false, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.style = style
        self.action = action
    }

    var body: some View {
        Button {
            guard isEnabled && !isLoading else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style.foregroundColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? style.backgroundColor : style.backgroundColor.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}
