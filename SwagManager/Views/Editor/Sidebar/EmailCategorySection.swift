import SwiftUI

// MARK: - Email Category Section
// Reusable component for displaying email categories with subcategories
// Following Apple engineering standards

struct EmailCategorySection: View {
    let group: EmailCategory.Group
    let emails: [ResendEmail]
    @Binding var expandedGroups: Set<EmailCategory.Group>
    @Binding var expandedCategories: Set<EmailCategory>
    @ObservedObject var store: EditorStore

    private var isExpanded: Bool {
        expandedGroups.contains(group)
    }

    private var subcategories: [EmailCategory] {
        group.categories.filter { category in
            !emails.filter(category: category).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            groupHeader

            // Subcategories
            if isExpanded {
                ForEach(subcategories, id: \.self) { category in
                    subcategorySection(category: category)
                }

                // Empty state
                if subcategories.isEmpty {
                    emptyState
                }
            }
        }
    }

    // MARK: - Group Header

    private var groupHeader: some View {
        Button(action: toggleGroup) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)

                // Group icon
                Image(systemName: group.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(group.color)
                    .frame(width: 14)

                // Group name
                Text(group.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                // Email count badge
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
    }

    // MARK: - Subcategory Section

    private func subcategorySection(category: EmailCategory) -> some View {
        let categoryEmails = emails.filter(category: category)
        let isCategoryExpanded = expandedCategories.contains(category)

        return VStack(alignment: .leading, spacing: 0) {
            // Subcategory header
            Button(action: { toggleCategory(category) }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.6))
                        .rotationEffect(.degrees(isCategoryExpanded ? 90 : 0))
                        .frame(width: 8)

                    // Category icon
                    Image(systemName: category.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(category.color.opacity(0.8))
                        .frame(width: 12)

                    // Category name
                    Text(category.displayName)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    // Count
                    Text("\(categoryEmails.count)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.surfaceElevated.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    Spacer()
                }
                .padding(.leading, 34)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Email items
            if isCategoryExpanded {
                ForEach(categoryEmails) { email in
                    EmailTreeItem(
                        email: email,
                        isSelected: false,
                        isActive: store.selectedEmail?.id == email.id,
                        indentLevel: 2,
                        onSelect: { store.openEmail(email) }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text("No emails")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.quaternary)
            }
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Actions

    private func toggleGroup() {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedGroups.contains(group) {
                expandedGroups.remove(group)
            } else {
                expandedGroups.insert(group)
            }
        }
    }

    private func toggleCategory(_ category: EmailCategory) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }
}
