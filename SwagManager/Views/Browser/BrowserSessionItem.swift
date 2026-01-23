//
//  BrowserSessionItem.swift
//  SwagManager
//
//  Sidebar item for browser sessions
//

import SwiftUI

struct BrowserSessionItem: View {
    let session: BrowserSession
    let isSelected: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                // Status indicator circle
                Circle()
                    .fill(statusOpacity)
                    .frame(width: 5, height: 5)

                VStack(alignment: .leading, spacing: 2) {
                    // Title/URL
                    Text(session.displayName)
                        .font(.system(size: 10.5, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.75))
                        .lineLimit(1)

                    // Shortened URL with better formatting
                    if let url = session.currentUrl, !url.isEmpty {
                        HStack(spacing: 3) {
                            if session.isSecure {
                                Image(systemName: "lock")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Color.primary.opacity(0.35))
                            }
                            Text(shortenUrl(url))
                                .font(.system(size: 9))
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Right side: close button or timestamp
                if isHovering && session.isActive {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .frame(width: 14, height: 14)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close session")
                } else if let lastActivity = session.lastActivity {
                    Text(timeAgo(lastActivity))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.primary.opacity(0.08) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var statusOpacity: Color {
        switch session.status {
        case "active": return Color.primary.opacity(0.5)
        case "paused": return Color.primary.opacity(0.35)
        case "closed": return Color.primary.opacity(0.2)
        case "error": return Color.primary.opacity(0.6)
        default: return Color.primary.opacity(0.2)
        }
    }

    private func shortenUrl(_ url: String) -> String {
        guard let urlObj = URL(string: url) else { return url }
        var result = urlObj.host ?? url
        if let path = urlObj.path as String?, !path.isEmpty && path != "/" {
            result += path
        }
        if result.count > 40 {
            return String(result.prefix(37)) + "..."
        }
        return result
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}

// MARK: - Browser Sessions Section Header

struct BrowserSessionsSectionHeader: View {
    @Binding var isExpanded: Bool
    let count: Int
    let isLoading: Bool
    let onNewSession: () -> Void

    init(isExpanded: Binding<Bool>, count: Int, isLoading: Bool = false, onNewSession: @escaping () -> Void) {
        self._isExpanded = isExpanded
        self.count = count
        self.isLoading = isLoading
        self.onNewSession = onNewSession
    }

    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.spring) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(DesignSystem.Animation.fast, value: isExpanded)
                    .frame(width: 12)

                Image(systemName: "safari")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Text("Browser Sessions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.85))

                Spacer()

                LoadingCountBadge(
                    count: count,
                    isLoading: isLoading
                )

                Button(action: onNewSession) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New browser session")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        BrowserSessionsSectionHeader(
            isExpanded: .constant(true),
            count: 3,
            onNewSession: {}
        )

        BrowserSessionItem(
            session: BrowserSession(
                id: UUID(),
                creationId: nil,
                storeId: UUID(),
                name: "Google Search",
                currentUrl: "https://www.google.com/search?q=test",
                viewportWidth: 1280,
                viewportHeight: 800,
                userAgent: nil,
                cookies: nil,
                localStorage: nil,
                sessionStorage: nil,
                screenshotUrl: nil,
                screenshotAt: nil,
                interactiveElements: nil,
                pageTitle: "Google",
                browserWsEndpoint: nil,
                browserService: "browserless",
                status: "active",
                errorMessage: nil,
                lastActivity: Date(),
                createdAt: Date(),
                updatedAt: Date()
            ),
            isSelected: true,
            onTap: {},
            onClose: {}
        )

        BrowserSessionItem(
            session: BrowserSession(
                id: UUID(),
                creationId: nil,
                storeId: UUID(),
                name: nil,
                currentUrl: "https://example.com",
                viewportWidth: 1280,
                viewportHeight: 800,
                userAgent: nil,
                cookies: nil,
                localStorage: nil,
                sessionStorage: nil,
                screenshotUrl: nil,
                screenshotAt: nil,
                interactiveElements: nil,
                pageTitle: "Example Domain",
                browserWsEndpoint: nil,
                browserService: "browserless",
                status: "closed",
                errorMessage: nil,
                lastActivity: Date().addingTimeInterval(-3600),
                createdAt: Date(),
                updatedAt: Date()
            ),
            isSelected: false,
            onTap: {},
            onClose: {}
        )
    }
    .background(Color(white: 0.1).opacity(0.3))
    .frame(width: 260)
}
