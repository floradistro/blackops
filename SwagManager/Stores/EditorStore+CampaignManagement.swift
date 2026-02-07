import Foundation

extension EditorStore {
    private var campaignService: CampaignService {
        CampaignService.shared
    }

    // MARK: - Load Campaigns

    func loadAllCampaigns() async {
        guard let storeId = selectedStore?.id else { return }

        isLoadingCampaigns = true
        defer { isLoadingCampaigns = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadEmailCampaigns(storeId: storeId) }
            group.addTask { await self.loadMetaCampaigns(storeId: storeId) }
            group.addTask { await self.loadMetaIntegrations(storeId: storeId) }
            group.addTask { await self.loadMarketingCampaigns(storeId: storeId) }
            group.addTask { await self.loadSMSCampaigns(storeId: storeId) }
        }
    }

    func loadEmailCampaigns(storeId: UUID) async {
        do {
            emailCampaigns = try await campaignService.loadEmailCampaigns(storeId: storeId)
        } catch {
            self.error = "Failed to load email campaigns: \(error.localizedDescription)"
        }
    }

    func loadMetaCampaigns(storeId: UUID) async {
        do {
            metaCampaigns = try await campaignService.loadMetaCampaigns(storeId: storeId)
        } catch {
            self.error = "Failed to load meta campaigns: \(error.localizedDescription)"
        }
    }

    func loadMetaIntegrations(storeId: UUID) async {
        do {
            metaIntegrations = try await campaignService.loadMetaIntegrations(storeId: storeId)
        } catch {
            self.error = "Failed to load meta integrations: \(error.localizedDescription)"
        }
    }

    func loadMarketingCampaigns(storeId: UUID) async {
        do {
            marketingCampaigns = try await campaignService.loadMarketingCampaigns(storeId: storeId)
        } catch {
            self.error = "Failed to load marketing campaigns: \(error.localizedDescription)"
        }
    }

    func loadSMSCampaigns(storeId: UUID) async {
        do {
            smsCampaigns = try await campaignService.loadSMSCampaigns(storeId: storeId)
        } catch {
            // SMS campaigns table uses different RLS approach - skip for now
            if error.localizedDescription.contains("app.current_store_id") {
                smsCampaigns = []
            } else {
                self.error = "Failed to load SMS campaigns: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Select Campaigns

    func selectEmailCampaign(_ campaign: EmailCampaign) {
        selectedEmailCampaign = campaign
        openTab(.emailCampaign(campaign))
    }

    func selectMetaCampaign(_ campaign: MetaCampaign) {
        selectedMetaCampaign = campaign
        openTab(.metaCampaign(campaign))
    }

    func selectMetaIntegration(_ integration: MetaIntegration) {
        selectedMetaIntegration = integration
        openTab(.metaIntegration(integration))
    }

    // MARK: - Refresh Campaign

    func refreshEmailCampaign(_ campaign: EmailCampaign) async {
        do {
            let updated = try await campaignService.getEmailCampaign(id: campaign.id)
            if let index = emailCampaigns.firstIndex(where: { $0.id == campaign.id }) {
                emailCampaigns[index] = updated
            }
            if selectedEmailCampaign?.id == campaign.id {
                selectedEmailCampaign = updated
            }
            // Update active tab if showing this campaign
            if let activeTab = activeTab, case .emailCampaign(let c) = activeTab, c.id == campaign.id {
                self.activeTab = .emailCampaign(updated)
                if let tabIndex = openTabs.firstIndex(where: { $0.id == activeTab.id }) {
                    openTabs[tabIndex] = .emailCampaign(updated)
                }
            }
        } catch {
            self.error = "Failed to refresh campaign: \(error.localizedDescription)"
        }
    }

    func refreshMetaCampaign(_ campaign: MetaCampaign) async {
        do {
            let updated = try await campaignService.getMetaCampaign(id: campaign.id)
            if let index = metaCampaigns.firstIndex(where: { $0.id == campaign.id }) {
                metaCampaigns[index] = updated
            }
            if selectedMetaCampaign?.id == campaign.id {
                selectedMetaCampaign = updated
            }
            // Update active tab if showing this campaign
            if let activeTab = activeTab, case .metaCampaign(let c) = activeTab, c.id == campaign.id {
                self.activeTab = .metaCampaign(updated)
                if let tabIndex = openTabs.firstIndex(where: { $0.id == activeTab.id }) {
                    openTabs[tabIndex] = .metaCampaign(updated)
                }
            }
        } catch {
            self.error = "Failed to refresh campaign: \(error.localizedDescription)"
        }
    }
}
