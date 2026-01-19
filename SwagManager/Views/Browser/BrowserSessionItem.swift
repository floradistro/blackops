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
            HStack(spacing: 8) {
                // Status indicator circle
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 3) {
                    // Title/URL
                    Text(session.displayName)
                        .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                        .lineLimit(1)

                    // Shortened URL with better formatting
                    if let url = session.currentUrl, !url.isEmpty {
                        HStack(spacing: 3) {
                            if session.isSecure {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Theme.green.opacity(0.6))
                            }
                            Text(shortenUrl(url))
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.textTertiary)
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
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 16, height: 16)
                            .background(
                                Circle()
                                    .fill(Theme.bgHover)
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close session")
                } else if let lastActivity = session.lastActivity {
                    Text(timeAgo(lastActivity))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.selectionActive : (isHovering ? Theme.bgHover : Color.clear))
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

    private var statusColor: Color {
        switch session.status {
        case "active": return Theme.green
        case "paused": return Theme.yellow
        case "closed": return Theme.textTertiary
        case "error": return Theme.red
        default: return Theme.textTertiary
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
    let onNewSession: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(Theme.spring) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(Theme.animationFast, value: isExpanded)
                    .frame(width: 12)

                Text("BROWSER SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.5)

                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                Button(action: onNewSession) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(isHovering ? Theme.bgHover : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New browser session")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
    .background(Theme.bgSecondary)
    .frame(width: 260)
}
