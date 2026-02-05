import SwiftUI
import AppKit

// MARK: - Request Models for Edge Functions

private struct ToolsGatewayRequest: Encodable {
    let operation: String
    let parameters: EmailToolParameters
    let store_id: String
}

private struct EmailToolParameters: Encodable {
    let action: String
    var domain_id: String?
    var domain: String?
    var inbound_subdomain: String?
    var address: String?
    var display_name: String?
    var mailbox_type: String?
    var ai_enabled: Bool?
}

// MARK: - Email Domain Settings View
// Manage email domains and addresses for the store

struct EmailDomainSettingsView: View {
    var store: EditorStore
    @State private var domains: [StoreEmailDomain] = []
    @State private var addresses: [StoreEmailAddress] = []
    @State private var connectedAccounts: [EmailAccount] = []
    @State private var isLoading = true
    @State private var showAddDomain = false
    @State private var showAddAddress = false
    @State private var selectedDomain: StoreEmailDomain?
    @State private var error: String?
    @State private var isConnectingGmail = false
    @State private var syncingAccountId: UUID?

    var body: some View {
        List {
            // Connected Accounts Section (Gmail, Outlook, etc.)
            Section {
                if connectedAccounts.isEmpty && !isLoading {
                    Button {
                        Task { await connectGmail() }
                    } label: {
                        HStack {
                            Image(systemName: "envelope.badge.person.crop")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect Gmail")
                                    .font(.headline)
                                Text("Read and send emails directly from your Gmail account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isConnectingGmail {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(connectedAccounts) { account in
                        ConnectedAccountRow(
                            account: account,
                            isSyncing: syncingAccountId == account.id
                        ) {
                            Task { await syncAccount(account) }
                        } onDisconnect: {
                            Task { await disconnectAccount(account) }
                        }
                    }

                    Button {
                        Task { await connectGmail() }
                    } label: {
                        Label("Connect Another Account", systemImage: "plus")
                    }
                }
            } header: {
                Text("Connected Accounts")
            } footer: {
                Text("Connect your email accounts to manage all messages in one place.")
            }

            // Domains Section (Resend fallback)
            Section {
                if domains.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Email Domains",
                        systemImage: "envelope.badge.shield.half.filled",
                        description: Text("Add a domain to start receiving emails")
                    )
                } else {
                    ForEach(domains) { domain in
                        DomainRow(domain: domain) {
                            selectedDomain = domain
                        } onVerify: {
                            Task { await verifyDomain(domain) }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Email Domains")
                    Spacer()
                    Button {
                        showAddDomain = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            }

            // Addresses Section
            Section {
                if addresses.isEmpty && !isLoading {
                    Text("No addresses configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(addresses) { address in
                        AddressRow(address: address)
                    }
                }
            } header: {
                HStack {
                    Text("Email Addresses")
                    Spacer()
                    Button {
                        showAddAddress = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(domains.isEmpty)
                }
            }

            // DNS Records Section (for selected domain)
            if let domain = selectedDomain, let records = domain.dnsRecords, !records.isEmpty {
                Section("DNS Records for \(domain.fullInboundDomain)") {
                    ForEach(records) { record in
                        DNSRecordRow(record: record)
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Email Settings")
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showAddDomain) {
            AddDomainSheet(store: store) { newDomain in
                domains.append(newDomain)
                selectedDomain = newDomain
            }
        }
        .sheet(isPresented: $showAddAddress) {
            AddAddressSheet(store: store, domains: domains) { newAddress in
                addresses.append(newAddress)
            }
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        guard let storeId = store.selectedStore?.id else { return }

        // Load connected accounts
        do {
            let fetchedAccounts: [EmailAccount] = try await store.supabase.client
                .from("store_email_accounts")
                .select("id, store_id, email_address, display_name, provider, is_active, last_sync_at, sync_error, sync_enabled, ai_enabled, created_at, updated_at")
                .eq("store_id", value: storeId)
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.connectedAccounts = fetchedAccounts
            }
        } catch {
            print("Failed to load accounts: \(error)")
        }

        // Load domains
        do {
            let fetchedDomains: [StoreEmailDomain] = try await store.supabase.client
                .from("store_email_domains")
                .select()
                .eq("store_id", value: storeId)
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.domains = fetchedDomains
                if selectedDomain == nil, let first = fetchedDomains.first {
                    selectedDomain = first
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load domains: \(error.localizedDescription)"
            }
        }

        // Load addresses
        do {
            let fetchedAddresses: [StoreEmailAddress] = try await store.supabase.client
                .from("store_email_addresses")
                .select("*, domain:store_email_domains(id, domain, inbound_subdomain, status)")
                .eq("store_id", value: storeId)
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.addresses = fetchedAddresses
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load addresses: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Gmail Connection

    private func connectGmail() async {
        guard let storeId = store.selectedStore?.id else { return }

        isConnectingGmail = true
        defer { isConnectingGmail = false }

        do {
            // Make direct HTTP request to edge function
            let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/gmail-oauth")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: String] = [
                "action": "start",
                "store_id": storeId.uuidString,
                "redirect_uri": "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/gmail-oauth"
            ]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(OAuthStartResponse.self, from: data)

            // Open auth URL in browser
            if let authUrl = URL(string: result.authUrl) {
                await MainActor.run {
                    NSWorkspace.shared.open(authUrl)
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to start Gmail connection: \(error.localizedDescription)"
            }
        }
    }

    private func syncAccount(_ account: EmailAccount) async {
        syncingAccountId = account.id

        defer {
            Task { @MainActor in
                syncingAccountId = nil
            }
        }

        do {
            // Make direct HTTP request with proper auth
            let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/gmail-sync")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

            let body = ["action": "sync", "account_id": account.id.uuidString]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "GmailSync", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }

            // Reload data after successful sync
            await loadData()

            // Also refresh inbox if it's being viewed
            await store.loadInboxThreads()
        } catch {
            await MainActor.run {
                self.error = "Sync failed: \(error.localizedDescription)"
            }
        }
    }

    private func disconnectAccount(_ account: EmailAccount) async {
        guard let storeId = store.selectedStore?.id else { return }

        do {
            struct DisconnectRequest: Encodable {
                let action: String
                let account_id: String
                let store_id: String
            }

            try await store.supabase.client
                .functions
                .invoke("gmail-sync", options: .init(body: DisconnectRequest(
                    action: "disconnect",
                    account_id: account.id.uuidString,
                    store_id: storeId.uuidString
                )))

            await MainActor.run {
                connectedAccounts.removeAll { $0.id == account.id }
            }
        } catch {
            await MainActor.run {
                self.error = "Disconnect failed: \(error.localizedDescription)"
            }
        }
    }

    private func verifyDomain(_ domain: StoreEmailDomain) async {
        guard let resendId = domain.resendDomainId else { return }

        do {
            // Call Resend verify API via edge function
            let request = ToolsGatewayRequest(
                operation: "email",
                parameters: EmailToolParameters(
                    action: "domains_verify",
                    domain_id: domain.id.uuidString
                ),
                store_id: store.selectedStore?.id.uuidString ?? ""
            )
            try await store.supabase.client
                .functions
                .invoke("tools-gateway", options: .init(body: request))

            // Reload data
            await loadData()
        } catch {
            await MainActor.run {
                self.error = "Verification failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Domain Row

struct DomainRow: View {
    let domain: StoreEmailDomain
    let onSelect: () -> Void
    let onVerify: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: domain.statusIcon)
                    .foregroundStyle(domain.statusColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(domain.fullInboundDomain)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(domain.statusLabel)
                            .font(.caption)
                            .foregroundStyle(domain.statusColor)

                        if domain.receivingEnabled {
                            Label("Receiving", systemImage: "envelope.arrow.triangle.branch")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        if domain.sendingVerified {
                            Label("Sending", systemImage: "paperplane.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                if domain.status != "verified" {
                    Button("Verify") {
                        onVerify()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Address Row

struct AddressRow: View {
    let address: StoreEmailAddress

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: address.mailboxIcon)
                .foregroundStyle(address.mailboxColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(address.fullEmail ?? address.address)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(address.mailboxType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(address.mailboxColor.opacity(0.15))
                        .foregroundStyle(address.mailboxColor)
                        .clipShape(Capsule())

                    if address.aiEnabled {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }

                    if !address.isActive {
                        Text("Inactive")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let displayName = address.displayName {
                Text(displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - DNS Record Row

struct DNSRecordRow: View {
    let record: DNSRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: record.statusIcon)
                    .foregroundStyle(record.statusColor)

                Text(record.record)
                    .font(.headline)

                Spacer()

                Text(record.type)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack {
                Text("Name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.name)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }

            HStack {
                Text("Value:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.displayValue)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }

            if let priority = record.priority {
                HStack {
                    Text("Priority:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(priority)")
                        .font(.caption.monospaced())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Domain Sheet

struct AddDomainSheet: View {
    var store: EditorStore
    let onAdd: (StoreEmailDomain) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var domain = ""
    @State private var subdomain = "in"
    @State private var isAdding = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Domain", text: $domain, prompt: Text("example.com"))
                        .textContentType(.URL)
                        .autocorrectionDisabled()

                    TextField("Inbound Subdomain", text: $subdomain, prompt: Text("in"))
                        .autocorrectionDisabled()
                } header: {
                    Text("Domain Configuration")
                } footer: {
                    Text("Emails will be received at addresses like support@\(subdomain.isEmpty ? "in" : subdomain).\(domain.isEmpty ? "example.com" : domain)")
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Email Domain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addDomain() }
                    }
                    .disabled(domain.isEmpty || isAdding)
                }
            }
            .overlay {
                if isAdding {
                    ProgressView("Adding domain...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func addDomain() async {
        isAdding = true
        error = nil

        guard let storeId = store.selectedStore?.id else {
            error = "No store selected"
            isAdding = false
            return
        }

        do {
            // Insert domain directly into database
            let subdomainValue = subdomain.isEmpty ? "in" : subdomain

            let newDomain = StoreEmailDomain(
                id: UUID(),
                storeId: storeId,
                domain: domain,
                inboundSubdomain: subdomainValue,
                resendDomainId: nil,
                status: "pending",
                receivingEnabled: true,
                sendingVerified: false,
                dnsRecords: nil,
                verifiedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await store.supabase.client
                .from("store_email_domains")
                .insert(newDomain)
                .execute()

            await MainActor.run {
                onAdd(newDomain)
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isAdding = false
            }
        }
    }
}

// MARK: - Add Address Sheet

struct AddAddressSheet: View {
    var store: EditorStore
    let domains: [StoreEmailDomain]
    let onAdd: (StoreEmailAddress) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDomainId: UUID?
    @State private var address = ""
    @State private var displayName = ""
    @State private var mailboxType = "general"
    @State private var aiEnabled = true
    @State private var isAdding = false
    @State private var error: String?

    let mailboxTypes = ["support", "orders", "returns", "info", "general", "custom"]

    var selectedDomain: StoreEmailDomain? {
        domains.first { $0.id == selectedDomainId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Domain", selection: $selectedDomainId) {
                        Text("Select Domain").tag(nil as UUID?)
                        ForEach(domains) { domain in
                            Text(domain.fullInboundDomain).tag(domain.id as UUID?)
                        }
                    }

                    TextField("Address", text: $address, prompt: Text("support"))
                        .autocorrectionDisabled()

                    TextField("Display Name", text: $displayName, prompt: Text("Company Support"))
                } header: {
                    Text("Email Address")
                } footer: {
                    if let domain = selectedDomain {
                        Text("Full address: \(address.isEmpty ? "address" : address)@\(domain.fullInboundDomain)")
                    }
                }

                Section("Settings") {
                    Picker("Mailbox Type", selection: $mailboxType) {
                        ForEach(mailboxTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }

                    Toggle("AI Enabled", isOn: $aiEnabled)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Email Address")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addAddress() }
                    }
                    .disabled(selectedDomainId == nil || address.isEmpty || isAdding)
                }
            }
            .onAppear {
                if selectedDomainId == nil, let first = domains.first {
                    selectedDomainId = first.id
                }
            }
        }
    }

    private func addAddress() async {
        guard let domainId = selectedDomainId,
              let storeId = store.selectedStore?.id else { return }

        isAdding = true
        error = nil

        do {
            let domain = selectedDomain

            let newAddress = StoreEmailAddress(
                id: UUID(),
                storeId: storeId,
                domainId: domainId,
                address: address.lowercased(),
                displayName: displayName.isEmpty ? nil : displayName,
                mailboxType: mailboxType,
                aiEnabled: aiEnabled,
                aiAutoReply: false,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
                domain: domain.map { StoreEmailDomainRef(
                    id: $0.id,
                    domain: $0.domain,
                    inboundSubdomain: $0.inboundSubdomain,
                    status: $0.status
                )}
            )

            // Insert the address (without the domain ref for the insert)
            struct AddressInsert: Encodable {
                let id: UUID
                let store_id: UUID
                let domain_id: UUID
                let address: String
                let display_name: String?
                let mailbox_type: String
                let ai_enabled: Bool
                let ai_auto_reply: Bool
                let is_active: Bool
            }

            try await store.supabase.client
                .from("store_email_addresses")
                .insert(AddressInsert(
                    id: newAddress.id,
                    store_id: storeId,
                    domain_id: domainId,
                    address: address.lowercased(),
                    display_name: displayName.isEmpty ? nil : displayName,
                    mailbox_type: mailboxType,
                    ai_enabled: aiEnabled,
                    ai_auto_reply: false,
                    is_active: true
                ))
                .execute()

            await MainActor.run {
                onAdd(newAddress)
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isAdding = false
            }
        }
    }
}

// MARK: - Connected Account Row

struct ConnectedAccountRow: View {
    let account: EmailAccount
    let isSyncing: Bool
    let onSync: () -> Void
    let onDisconnect: () -> Void

    @State private var showDisconnectAlert = false

    var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            Image(systemName: account.providerIcon)
                .font(.title2)
                .foregroundStyle(account.statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.emailAddress)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(account.providerName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Circle()
                        .fill(account.statusColor)
                        .frame(width: 6, height: 6)

                    Text(account.isActive ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if account.aiEnabled {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }

                if isSyncing {
                    Text("Syncing...")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text(account.lastSyncText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Actions
            if isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    onSync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Sync emails")
            }

            Button {
                showDisconnectAlert = true
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Disconnect account")
            .disabled(isSyncing)
        }
        .padding(.vertical, 4)
        .alert("Disconnect Account", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                onDisconnect()
            }
        } message: {
            Text("Are you sure you want to disconnect \(account.emailAddress)? You can reconnect it later.")
        }
    }
}
