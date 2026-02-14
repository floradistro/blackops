import SwiftUI

// MARK: - Workflow Version Panel
// Right panel: version history with rollback support

struct WorkflowVersionPanel: View {
    let workflowId: String
    let storeId: UUID?
    let onDismiss: () -> Void

    @Environment(\.workflowService) private var service

    @State private var versions: [WorkflowVersion] = []
    @State private var isLoading = true
    @State private var rollingBackVersion: Int?
    @State private var compareMode = false
    @State private var selectedVersionIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Inline controls
            HStack(spacing: DS.Spacing.sm) {
                Text("\(versions.count) versions")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)

                Spacer()

                if versions.count >= 2 {
                    Button {
                        compareMode.toggle()
                        if !compareMode { selectedVersionIds.removeAll() }
                    } label: {
                        Image(systemName: compareMode ? "arrow.left.arrow.right.square.fill" : "arrow.left.arrow.right.square")
                            .font(DesignSystem.font(10, weight: .medium))
                            .foregroundStyle(compareMode ? DS.Colors.accent : DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(9, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            // Compare hint
            if compareMode && selectedVersionIds.count < 2 {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "hand.point.up.fill")
                        .font(DesignSystem.font(9))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Select \(2 - selectedVersionIds.count) version\(selectedVersionIds.count == 1 ? "" : "s") to compare")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.accent.opacity(0.08))
            }

            // Comparison view
            if compareMode && selectedVersionIds.count == 2 {
                comparisonView
                Divider().opacity(0.3)
            }

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(0.7)
                Spacer()
            } else if versions.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Versions", systemImage: "clock.badge.checkmark.fill")
                } description: {
                    Text("Publish the workflow to create a version snapshot.")
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xs) {
                        ForEach(versions) { version in
                            versionRow(version)
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
        }
        .background(DS.Colors.surfaceTertiary)
        .task {
            versions = await service.getVersions(workflowId: workflowId, storeId: storeId)
            isLoading = false
        }
    }

    private func versionRow(_ version: WorkflowVersion) -> some View {
        let isSelected = selectedVersionIds.contains(version.id)

        return HStack(spacing: DS.Spacing.sm) {
            // Selection indicator in compare mode
            if compareMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DesignSystem.font(12))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textQuaternary)
            }

            // Version badge
            Text("v\(version.version)")
                .font(DS.Typography.monoLabel)
                .foregroundStyle(isSelected && compareMode ? DS.Colors.accent : DS.Colors.accent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if let log = version.changelog, !log.isEmpty {
                    Text(log)
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(2)
                }

                HStack(spacing: DS.Spacing.xs) {
                    Text(version.publishedAt.prefix(10))
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)

                    if let by = version.publishedBy {
                        Text(by)
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textQuaternary)
                    }
                }
            }

            Spacer()

            // Rollback (not for latest, hidden in compare mode)
            if !compareMode, version.version != versions.first?.version {
                Button {
                    rollback(to: version.version)
                } label: {
                    if rollingBackVersion == version.version {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(DesignSystem.font(10))
                            .foregroundStyle(DS.Colors.warning)
                    }
                }
                .buttonStyle(.plain)
                .help("Rollback to v\(version.version)")
                .disabled(rollingBackVersion != nil)
            }
        }
        .padding(DS.Spacing.sm)
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(isSelected && compareMode ? DS.Colors.accent : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard compareMode else { return }
            if isSelected {
                selectedVersionIds.remove(version.id)
            } else if selectedVersionIds.count < 2 {
                selectedVersionIds.insert(version.id)
            }
        }
    }

    // MARK: - Comparison View

    private var comparisonView: some View {
        let selected = versions.filter { selectedVersionIds.contains($0.id) }
            .sorted { $0.version < $1.version }
        let older = selected.first
        let newer = selected.count > 1 ? selected[1] : nil

        return VStack(spacing: DS.Spacing.sm) {
            // Header
            HStack {
                Text("COMPARISON")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)
                Spacer()
                Button {
                    selectedVersionIds.removeAll()
                } label: {
                    Text("Clear")
                        .font(DS.Typography.buttonSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if let older, let newer {
                // Side-by-side metadata
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    // Older version
                    versionMetadataCard(version: older, label: "OLDER")

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(DesignSystem.font(12, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                        .padding(.top, DS.Spacing.lg)

                    // Newer version
                    versionMetadataCard(version: newer, label: "NEWER")
                }

                // Diff placeholder
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(DesignSystem.font(10))
                        .foregroundStyle(DS.Colors.textQuaternary)
                    Text("Full graph diff coming soon")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.sm)
                .glassBackground(cornerRadius: DS.Radius.sm)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceElevated.opacity(0.3))
    }

    private func versionMetadataCard(version: WorkflowVersion, label: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textQuaternary)

            Text("v\(version.version)")
                .font(DS.Typography.monoLabel)
                .foregroundStyle(DS.Colors.accent)

            if let log = version.changelog, !log.isEmpty {
                Text(log)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(3)
            } else {
                Text("No changelog")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textQuaternary)
                    .italic()
            }

            Text(String(version.publishedAt.prefix(10)))
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textQuaternary)

            if let by = version.publishedBy {
                Text(by)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm)
        .glassBackground(cornerRadius: DS.Radius.sm)
    }

    private func rollback(to version: Int) {
        rollingBackVersion = version
        Task {
            let success = await service.rollback(workflowId: workflowId, version: version, storeId: storeId)
            if success {
                versions = await service.getVersions(workflowId: workflowId, storeId: storeId)
            }
            rollingBackVersion = nil
        }
    }
}
