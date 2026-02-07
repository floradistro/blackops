import SwiftUI
import SwiftData

// MARK: - Section Content Views
// Clean, minimal list views for each section

// MARK: - Emails Section
// Uses EditorStore for data that doesn't have a service method yet

struct EmailsListView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID  // For future use when service methods are added

    var body: some View {
        List {
            if !store.emails.isEmpty {
                Section("Recent Emails") {
                    ForEach(store.emails) { email in
                        NavigationLink(value: SDSidebarItem.emailDetail(email.id)) {
                            EmailListRow(email: email)
                        }
                    }
                }
            }

            if !store.emailCampaigns.isEmpty {
                Section("Campaigns") {
                    ForEach(store.emailCampaigns) { campaign in
                        NavigationLink(value: SDSidebarItem.emailCampaignDetail(campaign.id)) {
                            Text(campaign.name ?? "Campaign")
                                .font(.subheadline)
                        }
                    }
                }
            }

            if store.emails.isEmpty && store.emailCampaigns.isEmpty {
                ContentUnavailableView("No Emails", systemImage: "envelope")
            }
        }
        .listStyle(.inset)
        .navigationTitle("Emails")
    }
}

struct EmailListRow: View {
    let email: ResendEmail

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(email.subject.isEmpty ? "No Subject" : email.subject)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(email.toEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(text: email.statusLabel, color: email.statusColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Agents Section
// Uses EditorStore for data that doesn't have a service method yet

struct AgentsListView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID  // For future use when service methods are added

    var body: some View {
        Group {
            if store.aiAgents.isEmpty {
                ContentUnavailableView("No AI Agents", systemImage: "cpu", description: Text("Create agents to automate tasks"))
            } else {
                List {
                    ForEach(store.aiAgents) { agent in
                        NavigationLink(value: SDSidebarItem.agentDetail(agent.id)) {
                            AgentListRow(agent: agent)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("AI Agents")
    }
}

struct AgentListRow: View {
    let agent: AIAgent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: agent.displayIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.subheadline.weight(.medium))
                if let prompt = agent.systemPrompt {
                    Text(String(prompt.prefix(60)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Circle()
                .fill(agent.isActive ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Team Chat

struct TeamChatPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Team Chat", systemImage: "bubble.left.and.bubble.right", description: Text("Coming soon"))
            .navigationTitle("Team Chat")
    }
}

// MARK: - CRM Views
// Uses EditorStore for data that doesn't have service methods yet

struct CRMEmailCampaignsView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID  // For future use

    var body: some View {
        if store.emailCampaigns.isEmpty {
            ContentUnavailableView("No Email Campaigns", systemImage: "envelope.badge")
        } else {
            List(store.emailCampaigns) { campaign in
                NavigationLink(value: SDSidebarItem.emailCampaignDetail(campaign.id)) {
                    Text(campaign.name ?? "Campaign")
                        .font(.subheadline)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Email Campaigns")
        }
    }
}

struct CRMMetaCampaignsView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID  // For future use

    var body: some View {
        if store.metaCampaigns.isEmpty {
            ContentUnavailableView("No Meta Campaigns", systemImage: "megaphone")
        } else {
            List(store.metaCampaigns) { campaign in
                NavigationLink(value: SDSidebarItem.metaCampaignDetail(campaign.id)) {
                    Text(campaign.name ?? "Campaign")
                        .font(.subheadline)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Meta Campaigns")
        }
    }
}

struct CRMMetaIntegrationsView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID  // For future use

    var body: some View {
        if store.metaIntegrations.isEmpty {
            ContentUnavailableView("No Meta Integrations", systemImage: "link")
        } else {
            List(store.metaIntegrations) { integration in
                NavigationLink(value: SDSidebarItem.metaIntegrationDetail(integration.id)) {
                    Text(integration.businessName ?? "Integration")
                        .font(.subheadline)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Meta Integrations")
        }
    }
}

// MARK: - Locations Section

struct LocationsListView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID

    var body: some View {
        Group {
            if store.locations.isEmpty {
                ContentUnavailableView("No Locations", systemImage: "mappin.and.ellipse", description: Text("Locations will appear here"))
            } else {
                List {
                    ForEach(store.locations) { location in
                        NavigationLink(value: SDSidebarItem.locationDetail(location.id)) {
                            LocationListRow(location: location)
                        }
                        .contextMenu {
                            Button {
                                selection = .queue(location.id)
                            } label: {
                                Label("Open Queue", systemImage: "list.bullet")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadLocations() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

struct LocationListRow: View {
    let location: Location

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(location.isActive == true ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline.weight(.medium))
                if let address = location.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let city = location.city, let state = location.state {
                Text("\(city), \(state)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct LocationDetailWrapper: View {
    let locationId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let location = store.locations.first(where: { $0.id == locationId }) {
            LocationDetailView(location: location)
        } else {
            ContentUnavailableView("Location not found", systemImage: "mappin.slash")
        }
    }
}

struct LocationDetailView: View {
    let location: Location

    var body: some View {
        SettingsContainer {
            SettingsDetailHeader(
                title: location.name,
                subtitle: location.address,
                icon: "mappin.and.ellipse"
            )

            SettingsGroup(header: "Details") {
                if let address = location.address {
                    SettingsRow(label: "Address", value: address)
                }
                if let city = location.city {
                    SettingsRow(label: "City", value: city)
                        .settingsDivider()
                }
                if let state = location.state {
                    SettingsRow(label: "State", value: state)
                        .settingsDivider()
                }
                if let zip = location.zip {
                    SettingsRow(label: "ZIP", value: zip)
                        .settingsDivider()
                }
            }

            SettingsGroup(header: "Contact") {
                if let phone = location.phone {
                    SettingsRow(label: "Phone", value: phone)
                }
                if let email = location.email {
                    SettingsRow(label: "Email", value: email)
                        .settingsDivider()
                }
            }

            SettingsGroup(header: "Status") {
                SettingsRow(label: "Active", value: location.isActive == true ? "Yes" : "No")
            }
        }
        .navigationTitle(location.name)
    }
}

// MARK: - Location Queue View

struct LocationQueueView: View {
    let locationId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let location = store.locations.first(where: { $0.id == locationId }) {
            VStack {
                Text("Queue for \(location.name)")
                    .font(.headline)
                    .padding()

                ContentUnavailableView("Queue View", systemImage: "list.bullet", description: Text("Queue management coming soon"))
            }
            .navigationTitle("\(location.name) Queue")
        } else {
            ContentUnavailableView("Location not found", systemImage: "mappin.slash")
        }
    }
}
