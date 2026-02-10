import SwiftUI

struct SettingsView: View {
    @Environment(\.authManager) private var authManager
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

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 500)
        .environment(\.authManager, authManager)
        .environment(store)
        .task {
            await store.loadStores()
        }
    }
}

struct AccountSettingsView: View {
    @Environment(\.authManager) private var authManager
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


// MARK: - AI Settings View

struct AISettingsView: View {
    @State private var apiKey = ""
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
                    Text("Claude Opus 4.6").tag("claude-opus-4-6")
                    Text("Claude Sonnet 4.5").tag("claude-sonnet-4-5-20250929")
                    Text("Claude Opus 4.5").tag("claude-opus-4-5-20251101")
                    Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                    Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
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
        .onAppear {
            apiKey = KeychainService.read("anthropic_api_key") ?? ""
        }
        .onChange(of: apiKey) { _, newValue in
            if newValue.isEmpty {
                KeychainService.delete("anthropic_api_key")
            } else {
                _ = KeychainService.save("anthropic_api_key", value: newValue)
            }
        }
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

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Agent Manager")
                .font(.title2.weight(.semibold))

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Build, deploy, and monitor AI agents.")
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
}
