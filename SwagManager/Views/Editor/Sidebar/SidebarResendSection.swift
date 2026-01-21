import SwiftUI

// MARK: - Sidebar Resend Section
// Following Apple engineering standards

struct SidebarResendSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedGroups: Set<EmailCategory.Group> = [] // Start collapsed

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            sectionHeader

            // Expanded Content
            if store.sidebarEmailsExpanded {
                // Failed emails (priority section - always at top if any exist)
                if !store.failedEmails.isEmpty {
                    failedEmailsSection
                }

                // Show categorized emails if categories exist
                if !visibleGroups.isEmpty {
                    ForEach(visibleGroups, id: \.self) { group in
                        categoryGroupSection(group: group)
                    }
                }

                // Show uncategorized emails (fallback for emails without category field)
                let uncategorizedCount = store.emailCategoryCounts["uncategorized"] ?? 0
                if uncategorizedCount > 0 {
                    uncategorizedEmailsSection(count: uncategorizedCount)
                }

                // Empty state
                if store.emailTotalCount == 0 && !store.isLoadingEmails {
                    emptyState
                }

                // Loading state (initial count load)
                if store.isLoadingEmails && store.emailTotalCount == 0 {
                    loadingState
                }
            }
        }
        .onAppear {
            // Load counts immediately when sidebar loads
            if store.emailTotalCount == 0 {
                Task {
                    await store.loadEmailCounts()
                }
            }
        }
        .onChange(of: store.sidebarEmailsExpanded) { _, isExpanded in
            // Also load when user expands the section
            if isExpanded && store.emailTotalCount == 0 {
                Task {
                    await store.loadEmailCounts()
                }
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.spring) {
                store.sidebarEmailsExpanded.toggle()
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(store.sidebarEmailsExpanded ? 90 : 0))
                    .frame(width: 16)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.blue)

                Text("Emails")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                // Show total count with loading animation
                LoadingCountBadge(
                    count: store.emailTotalCount,
                    isLoading: store.isLoadingEmails
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Failed Emails Section

    private var failedEmailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { toggleGroup(.system) }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(expandedGroups.contains(.system) ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.red)
                        .frame(width: 14)

                    Text("Failed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.red)

                    Spacer()

                    Text("(\(store.failedEmails.count))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.red.opacity(0.8))
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedGroups.contains(.system) {
                ForEach(store.failedEmails) { email in
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

    // MARK: - Category Group Section (Simplified)

    private func categoryGroupSection(group: EmailCategory.Group) -> some View {
        let groupCount = groupEmailCount(for: group)
        let isExpanded = expandedGroups.contains(group)
        let loadedEmails = store.emails(for: group)
        let isLoaded = !loadedEmails.isEmpty || groupCount == 0

        return VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button(action: {
                toggleGroup(group)
                // Lazy load emails when expanding
                if !isExpanded && groupCount > 0 {
                    Task {
                        await store.loadEmailsForGroup(group)
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: group.icon)
                        .font(.system(size: 10))
                        .foregroundColor(group.color)
                        .frame(width: 14)

                    Text(group.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("(\(groupCount))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Show emails when expanded
            if isExpanded {
                if isLoaded {
                    ForEach(loadedEmails) { email in
                        EmailTreeItem(
                            email: email,
                            isSelected: false,
                            isActive: store.selectedEmail?.id == email.id,
                            indentLevel: 1,
                            onSelect: { store.openEmail(email) }
                        )
                    }
                } else {
                    // Loading indicator
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading \(groupCount) emails...")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    // Get count for a group from category counts
    private func groupEmailCount(for group: EmailCategory.Group) -> Int {
        group.categories.reduce(0) { total, category in
            total + (store.emailCategoryCounts[category.rawValue] ?? 0)
        }
    }

    // Get count of failed emails (loaded on demand)
    private var failedEmailCount: Int {
        store.failedEmails.count
    }

    // MARK: - Uncategorized Emails Section

    private func uncategorizedEmailsSection(count: Int) -> some View {
        let isExpanded = expandedGroups.contains(.system)
        let loadedEmails = store.emails.filter { $0.category == nil && $0.status.lowercased() != "failed" }
        let isLoaded = !loadedEmails.isEmpty || count == 0

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                toggleGroup(.system)
                // Lazy load uncategorized emails when expanding
                if !isExpanded && count > 0 {
                    Task {
                        await store.loadEmailsForCategory(nil)
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "envelope.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(width: 14)

                    Text("Uncategorized")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("(\(count))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    // Warning badge
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DesignSystem.Colors.orange)
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Show uncategorized emails when expanded
            if isExpanded {
                if isLoaded {
                    ForEach(loadedEmails) { email in
                        EmailTreeItem(
                            email: email,
                            isSelected: false,
                            isActive: store.selectedEmail?.id == email.id,
                            indentLevel: 1,
                            onSelect: { store.openEmail(email) }
                        )
                    }
                } else {
                    // Loading indicator
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading \(count) emails...")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Visible Groups

    private var visibleGroups: [EmailCategory.Group] {
        EmailCategory.Group.allCases.filter { group in
            groupEmailCount(for: group) > 0
        }
    }

    // MARK: - Loading States

    private var loadingState: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignSystem.Spacing.xs) {
                ProgressView()
                Text("Loading emails...")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text("No emails yet")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Actions

    private func toggleGroup(_ group: EmailCategory.Group) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedGroups.contains(group) {
                expandedGroups.remove(group)
            } else {
                expandedGroups.insert(group)
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
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 12)

                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                Text("(\(emails.count))")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.leading, DesignSystem.Spacing.md)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

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
                    .foregroundColor(email.hasError ? DesignSystem.Colors.red : DesignSystem.Colors.textSecondary)
                    .frame(width: 16)

                // Subject
                VStack(alignment: .leading, spacing: 2) {
                    Text(email.displaySubject)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(email.displayTo)
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text(email.displayDate)
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()

                // Order badge if linked to order
                if email.orderId != nil {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DesignSystem.Colors.orange)
                }
            }
            .padding(.leading, 40)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                isActive ?
                    DesignSystem.Colors.selectionActive : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
