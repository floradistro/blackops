import SwiftUI

// MARK: - Sidebar Resend Section
// Following Apple engineering standards

struct SidebarResendSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedChannels: Set<String> = ["transactional", "failed"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.sidebarEmailsExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: store.sidebarEmailsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.blue)

                    Text("Emails")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(store.emails.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if store.sidebarEmailsExpanded {
                // Failed Emails Channel (always show if any failures)
                if !store.failedEmails.isEmpty {
                    EmailChannelGroup(
                        title: "Failed",
                        icon: "exclamationmark.triangle.fill",
                        emails: store.failedEmails,
                        color: .red,
                        isExpanded: expandedChannels.contains("failed"),
                        onToggle: { toggleChannel("failed") },
                        store: store
                    )
                }

                // Transactional Channel
                EmailChannelGroup(
                    title: "Transactional",
                    icon: "receipt.fill",
                    emails: store.transactionalEmails,
                    color: .blue,
                    isExpanded: expandedChannels.contains("transactional"),
                    onToggle: { toggleChannel("transactional") },
                    store: store
                )

                // Marketing Channel
                EmailChannelGroup(
                    title: "Marketing",
                    icon: "megaphone.fill",
                    emails: store.marketingEmails,
                    color: .purple,
                    isExpanded: expandedChannels.contains("marketing"),
                    onToggle: { toggleChannel("marketing") },
                    store: store
                )

                // Empty state
                if store.emails.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.xxs) {
                            Text("No emails yet")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
        }
    }

    private func toggleChannel(_ channel: String) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedChannels.contains(channel) {
                expandedChannels.remove(channel)
            } else {
                expandedChannels.insert(channel)
            }
        }
    }
}

// MARK: - Email Channel Group

struct EmailChannelGroup: View {
    let title: String
    let icon: String
    let emails: [ResendEmail]
    let color: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: EditorStore

    var body: some View {
        // Channel header
        Button(action: onToggle) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)

                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text("\(emails.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())

        // Email items
        if isExpanded {
            ForEach(emails) { email in
                EmailTreeItem(
                    email: email,
                    isSelected: false,
                    isActive: store.selectedEmail?.id == email.id,
                    indentLevel: 1,
                    onSelect: { store.openEmail(email) }
                )
            }
        }
    }
}

// MARK: - Email Tree Item

struct EmailTreeItem: View {
    let email: ResendEmail
    let isSelected: Bool
    let isActive: Bool
    let indentLevel: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Status indicator
                Circle()
                    .fill(email.statusColor)
                    .frame(width: 6, height: 6)

                // Email icon
                Image(systemName: email.hasError ? "exclamationmark.triangle.fill" : "envelope")
                    .font(.system(size: 11))
                    .foregroundStyle(email.hasError ? .red : .secondary)
                    .frame(width: 16)

                // Subject
                VStack(alignment: .leading, spacing: 2) {
                    Text(email.displaySubject)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(email.displayTo)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)

                        Text(email.displayDate)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Order badge if linked to order
                if email.orderId != nil {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.leading, CGFloat(indentLevel) * 20 + DesignSystem.Spacing.md)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs + 2)
            .background(
                isActive ?
                    Color.accentColor.opacity(0.15) : Color.clear
            )
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
