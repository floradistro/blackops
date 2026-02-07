import SwiftUI

// MARK: - Meta Integration Detail Panel
// Minimal monochromatic theme

struct MetaIntegrationDetailPanel: View {
    let integration: MetaIntegration
    @Environment(\.editorStore) private var store
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Inline toolbar
            PanelToolbar(
                title: integration.businessName ?? "Meta Integration",
                icon: "link.badge.plus",
                subtitle: integration.status.rawValue.capitalized
            ) {
                ToolbarButton(
                    icon: isRefreshing ? "ellipsis" : "arrow.clockwise",
                    action: {
                        Task {
                            isRefreshing = true
                            // Refresh integration if method exists
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            isRefreshing = false
                        }
                    },
                    disabled: isRefreshing
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection

                    Divider()
                        .padding(.vertical, 8)

                    // Integration Details
                    SectionHeader(title: "Details")
                    detailsSection

                    Divider()
                        .padding(.vertical, 8)

                    // Connected Accounts
                    SectionHeader(title: "Connected Accounts")
                    accountsSection

                    Divider()
                        .padding(.vertical, 8)

                    // Status
                    SectionHeader(title: "Status")
                    statusSection

                    Spacer(minLength: 20)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(integration.businessName ?? "Meta Integration")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))

                Text("App ID: \(integration.appId)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }

            Spacer()

            // Status badge - sleek minimal
            IntegrationStatusBadge(status: integration.status)
        }
        .padding(20)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 6) {
            InfoRow(label: "App ID", value: integration.appId)

            if let businessId = integration.businessId {
                InfoRow(label: "Business ID", value: businessId)
            }

            if let businessName = integration.businessName {
                InfoRow(label: "Business", value: businessName)
            }

            InfoRow(label: "Created", value: integration.createdAt.formatted(date: .abbreviated, time: .shortened))
            InfoRow(label: "Updated", value: integration.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        VStack(spacing: 8) {
            if let adAccountId = integration.adAccountId {
                AccountRow(icon: "megaphone", label: "Ad Account", value: adAccountId)
            }

            if let pixelId = integration.pixelId {
                AccountRow(icon: "target", label: "Pixel", value: pixelId)
            }

            if let pageId = integration.pageId {
                AccountRow(icon: "doc.text", label: "Page", value: pageId)
            }

            if let instagramBusinessId = integration.instagramBusinessId {
                AccountRow(icon: "camera", label: "Instagram Business", value: instagramBusinessId)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Status")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                    Text(integration.status.rawValue.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                }

                Spacer()

                Circle()
                    .fill(Color.primary.opacity(statusOpacity))
                    .frame(width: 8, height: 8)
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            if let lastError = integration.lastError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Error")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                    Text(lastError)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var statusOpacity: Double {
        switch integration.status {
        case .active: return 0.7
        case .disconnected: return 0.3
        case .expired: return 0.5
        case .error: return 0.4
        }
    }
}

// MARK: - Supporting Views

struct IntegrationStatusBadge: View {
    let status: MetaIntegrationStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.primary.opacity(statusOpacity))
                .frame(width: 6, height: 6)
            Text(status.rawValue.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }

    private var statusOpacity: Double {
        switch status {
        case .active: return 0.7
        case .disconnected: return 0.3
        case .expired: return 0.5
        case .error: return 0.4
        }
    }
}

struct AccountRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.7))
            }

            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}
