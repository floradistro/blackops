import SwiftUI

struct SidebarCRMSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // CRM Header
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    store.sidebarCRMExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: store.sidebarCRMExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "megaphone")
                        .font(.system(size: 13))
                        .foregroundStyle(.pink)

                    Text("CRM")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if store.isLoadingCampaigns {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        let totalCount = store.emailCampaigns.count + store.metaCampaigns.count
                        if totalCount > 0 {
                            Text("\(totalCount)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // CRM Content
            if store.sidebarCRMExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    // Meta Integration
                    if !store.metaIntegrations.isEmpty {
                        ForEach(store.metaIntegrations) { integration in
                            MetaIntegrationRow(integration: integration, store: store)
                        }
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)
                    }

                    // Email Campaigns
                    EmailCampaignsSubsection(store: store)

                    // Meta Campaigns
                    MetaCampaignsSubsection(store: store)

                    // SMS Campaigns (if any)
                    if !store.smsCampaigns.isEmpty {
                        SMSCampaignsSubsection(store: store)
                    }
                }
            }
        }
        .task {
            if store.emailCampaigns.isEmpty && store.metaCampaigns.isEmpty && store.selectedStore != nil {
                await store.loadAllCampaigns()
            }
        }
        .onChange(of: store.selectedStore?.id) { _, _ in
            Task {
                await store.loadAllCampaigns()
            }
        }
    }
}

// MARK: - Email Campaigns Subsection

struct EmailCampaignsSubsection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    store.sidebarEmailCampaignsExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: store.sidebarEmailCampaignsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "envelope.badge")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)

                    Text("Email Campaigns")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(store.emailCampaigns.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.sidebarEmailCampaignsExpanded {
                if store.emailCampaigns.isEmpty {
                    Text("No campaigns")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 40)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                } else {
                    ForEach(store.emailCampaigns) { campaign in
                        EmailCampaignRow(campaign: campaign, store: store)
                    }
                }
            }
        }
    }
}

// MARK: - Meta Campaigns Subsection

struct MetaCampaignsSubsection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    store.sidebarMetaCampaignsExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: store.sidebarMetaCampaignsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "megaphone")
                        .font(.system(size: 12))
                        .foregroundStyle(.pink)

                    Text("Meta Campaigns")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(store.metaCampaigns.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.sidebarMetaCampaignsExpanded {
                if store.metaCampaigns.isEmpty {
                    Text("No campaigns")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 40)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                } else {
                    ForEach(store.metaCampaigns) { campaign in
                        MetaCampaignRow(campaign: campaign, store: store)
                    }
                }
            }
        }
    }
}

// MARK: - SMS Campaigns Subsection

struct SMSCampaignsSubsection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    store.sidebarSMSCampaignsExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: store.sidebarSMSCampaignsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "message")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)

                    Text("SMS Campaigns")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(store.smsCampaigns.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.sidebarSMSCampaignsExpanded {
                ForEach(store.smsCampaigns) { campaign in
                    SMSCampaignRow(campaign: campaign, store: store)
                }
            }
        }
    }
}

// MARK: - Row Components

struct EmailCampaignRow: View {
    let campaign: EmailCampaign
    @ObservedObject var store: EditorStore

    var body: some View {
        Button(action: {
            store.selectEmailCampaign(campaign)
        }) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "envelope")
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(campaign.status.rawValue.capitalized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(statusColor)

                        if campaign.totalSent > 0 {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)

                            Text("\(campaign.totalSent) sent")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.leading, 40)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                store.selectedEmailCampaign?.id == campaign.id ?
                    Color.accentColor.opacity(0.15) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var statusColor: Color {
        switch campaign.status {
        case .draft: return .gray
        case .scheduled: return .orange
        case .sending: return .blue
        case .sent: return .green
        case .paused: return .yellow
        case .cancelled: return .red
        case .testing: return .purple
        }
    }
}

struct MetaCampaignRow: View {
    let campaign: MetaCampaign
    @ObservedObject var store: EditorStore

    var body: some View {
        Button(action: {
            store.selectMetaCampaign(campaign)
        }) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.pink)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let status = campaign.status {
                            Text(status)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        if campaign.impressions > 0 {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)

                            Text("\(campaign.impressions) imp")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.leading, 40)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                store.selectedMetaCampaign?.id == campaign.id ?
                    Color.accentColor.opacity(0.15) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MetaIntegrationRow: View {
    let integration: MetaIntegration
    @ObservedObject var store: EditorStore

    var body: some View {
        Button(action: {
            store.selectMetaIntegration(integration)
        }) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(integration.businessName ?? "Meta Integration")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(integration.status.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(statusColor)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                store.selectedMetaIntegration?.id == integration.id ?
                    Color.accentColor.opacity(0.15) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var statusColor: Color {
        switch integration.status {
        case .active: return .green
        case .disconnected: return .gray
        case .expired: return .orange
        case .error: return .red
        }
    }
}

struct SMSCampaignRow: View {
    let campaign: SMSCampaign
    @ObservedObject var store: EditorStore

    var body: some View {
        Button(action: {
            // SMS campaigns feature - coming soon
            print("SMS Campaign selected: \(campaign.name)")
        }) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "message.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(campaign.status.rawValue.capitalized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)

                        if campaign.totalSent > 0 {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)

                            Text("\(campaign.totalSent) sent")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.leading, 40)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
