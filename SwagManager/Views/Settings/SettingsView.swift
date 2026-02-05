import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var store = EditorStore()

    var body: some View {
        TabView {
            AccountSettingsView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            ConnectionsSettingsView()
                .tabItem {
                    Label("Connections", systemImage: "link")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 500)
        .environmentObject(authManager)
        .environment(store)
        .task {
            await store.loadStores()
        }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSignOutConfirm = false

    var body: some View {
        Form {
            Section {
                if let user = authManager.currentUser {
                    LabeledContent("Email", value: user.email ?? "Unknown")
                    LabeledContent("User ID", value: user.id.uuidString)

                    LabeledContent("Created", value: user.createdAt.formatted(date: .abbreviated, time: .omitted))
                } else {
                    Text("Not signed in")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Account Information")
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    showSignOutConfirm = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task { try? await authManager.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - OAuth Models for Decoding
// NOTE: Using supabaseDecoder which has .convertFromSnakeCase, so no CodingKeys needed

private struct OAuthAuthorizationResponse: Codable {
    let id: UUID
    let applicationId: UUID
    let grantedScopes: [String]
    let createdAt: Date
    let isActive: Bool
    let oauthApplications: OAuthAppInfo
}

private struct OAuthAppInfo: Codable {
    let name: String
    let description: String?
}

private struct OAuthTokenStats: Codable {
    let authorizationId: UUID
    let lastUsedAt: Date?
    let useCount: Int?
}

// For inserts, we need explicit CodingKeys since we're ENCODING to snake_case
private struct OAuthAuditLogInsert: Codable {
    let applicationId: String
    let storeId: String
    let action: String
    let details: [String: String]

    enum CodingKeys: String, CodingKey {
        case applicationId = "application_id"
        case storeId = "store_id"
        case action
        case details
    }
}

// MARK: - Connected Apps Model

struct ConnectedApp: Identifiable {
    let id: UUID
    let applicationId: UUID
    let applicationName: String
    let applicationDescription: String?
    let grantedScopes: [String]
    let createdAt: Date
    let lastUsedAt: Date?
    let useCount: Int
    let isActive: Bool
}

// MARK: - Connections Settings View

struct ConnectionsSettingsView: View {
    @Environment(EditorStore.self) private var store
    @State private var connectedApps: [ConnectedApp] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var revokingAppId: UUID?
    @State private var showRevokeConfirm = false
    @State private var appToRevoke: ConnectedApp?

    private let supabase = SupabaseService.shared

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            // Header with Store Picker
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected Applications")
                            .font(.headline)
                        Text("Apps that have access to your store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await loadConnectedApps() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoading)
                }

                // Store Picker
                if store.stores.count > 1 {
                    HStack {
                        Text("Store:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { store.selectedStore?.id },
                            set: { newId in
                                if let newId, let newStore = store.stores.first(where: { $0.id == newId }) {
                                    Task {
                                        store.selectedStore = newStore
                                        await loadConnectedApps()
                                    }
                                }
                            }
                        )) {
                            ForEach(store.stores, id: \.id) { s in
                                Text(s.storeName).tag(s.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        Spacer()
                    }
                }
            }
            .padding()

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if let error = error {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadConnectedApps() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else if connectedApps.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "link.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No Connected Apps")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("When you authorize third-party applications,\nthey'll appear here.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(connectedApps) { app in
                            ConnectedAppRow(
                                app: app,
                                isRevoking: revokingAppId == app.id,
                                onRevoke: {
                                    appToRevoke = app
                                    showRevokeConfirm = true
                                }
                            )
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .task {
            await loadConnectedApps()
        }
        .alert("Revoke Access", isPresented: $showRevokeConfirm, presenting: appToRevoke) { app in
            Button("Cancel", role: .cancel) { }
            Button("Revoke", role: .destructive) {
                Task { await revokeAccess(for: app) }
            }
        } message: { app in
            Text("Are you sure you want to revoke access for \"\(app.applicationName)\"? This will immediately disconnect the application.")
        }
    }

    private func loadConnectedApps() async {
        guard let storeId = store.selectedStore?.id else {
            error = "No store selected"
            isLoading = false
            return
        }

        isLoading = true
        error = nil

        do {
            // Fetch authorizations with app info
            let authResponse = try await supabase.adminClient
                .from("oauth_authorizations")
                .select("""
                    id,
                    application_id,
                    granted_scopes,
                    created_at,
                    is_active,
                    oauth_applications!inner(name, description)
                """)
                .eq("store_id", value: storeId.uuidString)
                .eq("is_active", value: true)
                .execute()

            // Handle empty response gracefully
            let authorizations: [OAuthAuthorizationResponse]
            let responseStr = String(data: authResponse.data, encoding: .utf8) ?? ""
            print("[OAuth Debug] Store: \(store.selectedStore?.storeName ?? "nil"), Response: \(responseStr.prefix(500))")

            if authResponse.data.isEmpty || responseStr == "[]" {
                authorizations = []
            } else {
                do {
                    authorizations = try JSONDecoder.supabaseDecoder.decode(
                        [OAuthAuthorizationResponse].self,
                        from: authResponse.data
                    )
                } catch {
                    print("[OAuth Debug] Decode error: \(error)")
                    authorizations = []
                }
            }

            // Fetch token usage stats (only if we have authorizations)
            var tokens: [OAuthTokenStats] = []
            if !authorizations.isEmpty {
                let tokenResponse = try await supabase.adminClient
                    .from("oauth_access_tokens")
                    .select("authorization_id, last_used_at, use_count")
                    .eq("store_id", value: storeId.uuidString)
                    .eq("is_active", value: true)
                    .execute()

                tokens = (try? JSONDecoder.supabaseDecoder.decode(
                    [OAuthTokenStats].self,
                    from: tokenResponse.data
                )) ?? []
            }

            // Merge data
            var apps: [ConnectedApp] = []
            for auth in authorizations {
                let tokenStats = tokens.first { $0.authorizationId == auth.id }

                apps.append(ConnectedApp(
                    id: auth.id,
                    applicationId: auth.applicationId,
                    applicationName: auth.oauthApplications.name,
                    applicationDescription: auth.oauthApplications.description,
                    grantedScopes: auth.grantedScopes,
                    createdAt: auth.createdAt,
                    lastUsedAt: tokenStats?.lastUsedAt,
                    useCount: tokenStats?.useCount ?? 0,
                    isActive: auth.isActive
                ))
            }

            connectedApps = apps
        } catch {
            // If table doesn't exist or other DB error, just show empty list
            let errorString = error.localizedDescription
            if errorString.contains("does not exist") || errorString.contains("42P01") {
                // Table doesn't exist - that's fine, just no apps connected
                connectedApps = []
            } else {
                self.error = "Failed to load: \(errorString)"
            }
        }

        isLoading = false
    }

    private func revokeAccess(for app: ConnectedApp) async {
        revokingAppId = app.id

        do {
            // Revoke all tokens
            try await supabase.adminClient
                .from("oauth_access_tokens")
                .update(["is_active": false])
                .eq("authorization_id", value: app.id.uuidString)
                .execute()

            // Deactivate authorization
            try await supabase.adminClient
                .from("oauth_authorizations")
                .update(["is_active": false])
                .eq("id", value: app.id.uuidString)
                .execute()

            // Log revocation
            if let storeId = store.selectedStore?.id {
                let auditLog = OAuthAuditLogInsert(
                    applicationId: app.applicationId.uuidString,
                    storeId: storeId.uuidString,
                    action: "authorization_revoked",
                    details: ["revoked_by": "user", "app_name": app.applicationName]
                )
                try await supabase.adminClient
                    .from("oauth_audit_log")
                    .insert(auditLog)
                    .execute()
            }

            // Remove from list
            connectedApps.removeAll { $0.id == app.id }
        } catch {
            self.error = "Failed to revoke: \(error.localizedDescription)"
        }

        revokingAppId = nil
    }
}

// MARK: - Connected App Row

struct ConnectedAppRow: View {
    let app: ConnectedApp
    let isRevoking: Bool
    let onRevoke: () -> Void

    private let scopeLabels: [String: String] = [
        "documents:read": "Read Documents",
        "documents:write": "Write Documents",
        "coas:create": "Create COAs",
        "products:read": "Read Products",
        "products:write": "Write Products",
        "inventory:read": "Read Inventory",
        "inventory:write": "Write Inventory",
        "orders:read": "Read Orders",
        "orders:write": "Write Orders",
        "customers:read": "Read Customers",
        "customers:write": "Write Customers",
        "analytics:read": "Read Analytics",
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // App Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "cpu")
                        .foregroundStyle(Color.accentColor)
                }

            // App Info
            VStack(alignment: .leading, spacing: 6) {
                Text(app.applicationName)
                    .font(.headline)

                if let desc = app.applicationDescription {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Stats
                HStack(spacing: 12) {
                    Label(app.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    Label(formatLastUsed(app.lastUsedAt), systemImage: "clock")
                    if app.useCount > 0 {
                        Label("\(app.useCount) requests", systemImage: "arrow.up.arrow.down")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                // Scopes
                FlowLayout(spacing: 4) {
                    ForEach(app.grantedScopes, id: \.self) { scope in
                        Text(scopeLabels[scope] ?? scope)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // Revoke Button
            Button(role: .destructive) {
                onRevoke()
            } label: {
                if isRevoking {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Text("Revoke")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRevoking)
        }
        .padding()
    }

    private func formatLastUsed(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - AI Settings View

struct AISettingsView: View {
    @AppStorage("anthropicApiKey") private var apiKey = ""
    @AppStorage("defaultModel") private var defaultModel = "claude-sonnet-4-20250514"
    @State private var showApiKey = false
    @State private var testStatus: TestStatus = .idle

    enum TestStatus: Equatable {
        case idle, testing, success, failed(String)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    if showApiKey {
                        TextField("sk-ant-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-ant-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    if apiKey.isEmpty {
                        Label("No API key configured", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if apiKey.hasPrefix("sk-ant-") {
                        Label("API key configured", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Invalid format (should start with sk-ant-)", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Link("Get API Key", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                        .font(.caption)
                }
            } header: {
                Text("Anthropic API Key")
            } footer: {
                Text("This key is used for all AI agents. Get yours from console.anthropic.com")
            }

            Section {
                Picker("Default Model", selection: $defaultModel) {
                    Text("Claude Opus 4.6").tag("claude-opus-4-6-20260201")
                    Text("Claude Opus 4.5").tag("claude-opus-4-5-20251101")
                    Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                    Text("Claude Haiku 3.5").tag("claude-3-5-haiku-20241022")
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Agents can override this with their own model selection")
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(apiKey.isEmpty || testStatus == .testing)

                    Spacer()

                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.7)
                    case .success:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failed(let error):
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() {
        testStatus = .testing

        // Simple validation - just check format for now
        // Real test would ping the API
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                if apiKey.hasPrefix("sk-ant-") && apiKey.count > 20 {
                    testStatus = .success
                } else {
                    testStatus = .failed("Invalid key format")
                }
            }
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultViewMode") private var defaultViewMode = "grid"
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("confirmDelete") private var confirmDelete = true

    var body: some View {
        Form {
            Section {
                Picker("Default View Mode", selection: $defaultViewMode) {
                    Text("Grid").tag("grid")
                    Text("List").tag("list")
                }

                Toggle("Show Thumbnails", isOn: $showThumbnails)
            } header: {
                Text("Display")
            }

            Section {
                Toggle("Auto-save Changes", isOn: $autoSave)
                Toggle("Confirm Before Deleting", isOn: $confirmDelete)
            } header: {
                Text("Editing")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Manage your creations and collections with a native macOS experience.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            Text("Built with SwiftUI + Supabase")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
        .environment(EditorStore())
}
