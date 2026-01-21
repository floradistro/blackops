import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        TabView {
            AccountSettingsView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
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
        .frame(width: 500, height: 400)
        .environmentObject(authManager)
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
}
