import SwiftUI

// MARK: - Workflow DLQ Panel
// Right panel: failed runs with retry/dismiss actions

struct WorkflowDLQPanel: View {
    let storeId: UUID?
    let onDismiss: () -> Void

    @Environment(\.workflowService) private var service

    @State private var entries: [DLQEntry] = []
    @State private var isLoading = true
    @State private var processingId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Inline controls
            HStack(spacing: DS.Spacing.sm) {
                let pending = entries.filter { $0.status == "pending" }.count
                Text("\(pending) pending")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(pending > 0 ? DS.Colors.error : DS.Colors.textQuaternary)

                Spacer()

                Button {
                    Task {
                        isLoading = true
                        entries = await service.getDLQ(storeId: storeId)
                        isLoading = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(DesignSystem.font(10, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(9, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(0.7)
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Failed Entries", systemImage: "checkmark.diamond.fill")
                } description: {
                    Text("All workflow runs completed successfully.")
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xs) {
                        ForEach(entries) { entry in
                            dlqRow(entry)
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
        }
        .background(DS.Colors.surfaceTertiary)
        .task {
            entries = await service.getDLQ(storeId: storeId)
            isLoading = false
        }
    }

    private func dlqRow(_ entry: DLQEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(DesignSystem.font(10))
                    .foregroundStyle(DS.Colors.error)

                Text(entry.stepKey)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                Text(entry.status.uppercased())
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(entry.status == "pending" ? DS.Colors.error : DS.Colors.textTertiary)
            }

            Text(entry.error)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(3)

            HStack(spacing: DS.Spacing.xs) {
                Text(entry.createdAt.prefix(19))
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)

                if let retries = entry.retryCount, retries > 0 {
                    Text("\(retries) retries")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.warning)
                }
            }

            if entry.status == "pending" {
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        retryEntry(entry)
                    } label: {
                        HStack(spacing: DS.Spacing.xxs) {
                            if processingId == entry.id {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(DesignSystem.font(9))
                            }
                            Text("Retry")
                                .font(DS.Typography.buttonSmall)
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Colors.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .foregroundStyle(DS.Colors.warning)
                    }
                    .buttonStyle(.plain)
                    .disabled(processingId != nil)

                    Button {
                        dismissEntry(entry)
                    } label: {
                        Text("Dismiss")
                            .font(DS.Typography.buttonSmall)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(processingId != nil)
                }
            }
        }
        .padding(DS.Spacing.sm)
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }

    private func retryEntry(_ entry: DLQEntry) {
        processingId = entry.id
        Task {
            if await service.retryDLQ(dlqId: entry.id, storeId: storeId) {
                entries.removeAll { $0.id == entry.id }
            }
            processingId = nil
        }
    }

    private func dismissEntry(_ entry: DLQEntry) {
        processingId = entry.id
        Task {
            if await service.dismissDLQ(dlqId: entry.id, storeId: storeId) {
                entries.removeAll { $0.id == entry.id }
            }
            processingId = nil
        }
    }
}
