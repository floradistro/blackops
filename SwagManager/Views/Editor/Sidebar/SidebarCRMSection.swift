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
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(store.sidebarCRMExpanded ? 90 : 0))
                        .frame(width: 16)

                    Image(systemName: "megaphone")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.pink)

                    Text("CRM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    if store.isLoadingCampaigns {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        let totalCount = store.emailCampaigns.count + store.metaCampaigns.count
                        if totalCount > 0 {
                            Text("(\(totalCount))")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
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
                HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.TreeSpacing.chevronSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(store.sidebarEmailCampaignsExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "envelope.badge")
                        .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                        .foregroundColor(DesignSystem.Colors.blue)

                    Text("Email Campaigns")
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

                    Text("(\(store.emailCampaigns.count))")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(height: DesignSystem.TreeSpacing.itemHeight)
                .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + DesignSystem.TreeSpacing.indentPerLevel)
                .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.sidebarEmailCampaignsExpanded {
                if store.emailCampaigns.isEmpty {
                    Text("No campaigns")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
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
                HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.TreeSpacing.chevronSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(store.sidebarMetaCampaignsExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "megaphone")
                        .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                        .foregroundColor(DesignSystem.Colors.pink)

                    Text("Meta Campaigns")
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

                    Text("(\(store.metaCampaigns.count))")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(height: DesignSystem.TreeSpacing.itemHeight)
                .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + DesignSystem.TreeSpacing.indentPerLevel)
                .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.sidebarMetaCampaignsExpanded {
                if store.metaCampaigns.isEmpty {
                    Text("No campaigns")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
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
                HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.TreeSpacing.chevronSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(store.sidebarSMSCampaignsExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "message")
                        .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                        .foregroundColor(DesignSystem.Colors.green)

                    Text("SMS Campaigns")
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

                    Text("(\(store.smsCampaigns.count))")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(height: DesignSystem.TreeSpacing.itemHeight)
                .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + DesignSystem.TreeSpacing.indentPerLevel)
                .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
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
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: "envelope")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundColor(statusColor)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DesignSystem.TreeSpacing.elementSpacing) {
                        Text(campaign.status.rawValue.capitalized)
                            .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize, weight: .medium))
                            .foregroundColor(statusColor)

                        if campaign.totalSent > 0 {
                            Text("•")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(campaign.totalSent) sent")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)
            }
            .frame(height: DesignSystem.TreeSpacing.itemHeight)
            .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + DesignSystem.TreeSpacing.indentPerLevel * 2)
            .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .background(
                store.selectedEmailCampaign?.id == campaign.id ?
                    DesignSystem.Colors.selectionActive : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var statusColor: Color {
        switch campaign.status {
        case .draft: return DesignSystem.Colors.textTertiary
        case .scheduled: return DesignSystem.Colors.orange
        case .sending: return DesignSystem.Colors.blue
        case .sent: return DesignSystem.Colors.green
        case .paused: return DesignSystem.Colors.yellow
        case .cancelled: return DesignSystem.Colors.red
        case .testing: return DesignSystem.Colors.purple
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
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundColor(DesignSystem.Colors.pink)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DesignSystem.TreeSpacing.elementSpacing) {
                        if let status = campaign.status {
                            Text(status)
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        if campaign.impressions > 0 {
                            Text("•")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(campaign.impressions) imp")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)
            }
            .frame(height: DesignSystem.TreeSpacing.itemHeight)
            .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + DesignSystem.TreeSpacing.indentPerLevel * 2)
            .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .background(
                store.selectedMetaCampaign?.id == campaign.id ?
                    DesignSystem.Colors.selectionActive : Color.clear
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
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(integration.businessName ?? "Meta Integration")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    Text(integration.status.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(statusColor)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                store.selectedMetaIntegration?.id == integration.id ?
                    DesignSystem.Colors.selectionActive : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var statusColor: Color {
        switch integration.status {
        case .active: return DesignSystem.Colors.green
        case .disconnected: return DesignSystem.Colors.textTertiary
        case .expired: return DesignSystem.Colors.orange
        case .error: return DesignSystem.Colors.red
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
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: "message.fill")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundColor(DesignSystem.Colors.green)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DesignSystem.TreeSpacing.elementSpacing) {
                        Text(campaign.status.rawValue.capitalized)
                            .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        if campaign.totalSent > 0 {
                            Text("•")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(campaign.totalSent) sent")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)
            }
            .frame(height: DesignSystem.TreeSpacing.itemHeight)
            .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + DesignSystem.TreeSpacing.indentPerLevel * 2)
            .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
