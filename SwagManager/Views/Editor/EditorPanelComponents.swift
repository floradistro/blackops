import SwiftUI

// MARK: - Editor Panel Components
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~180 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Details Panel

struct DetailsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: creation.creationType.icon)
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                        Text(creation.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Text(creation.description ?? "No description")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatBox(title: "Views", value: "\(creation.viewCount ?? 0)", icon: "eye")
                    StatBox(title: "Installs", value: "\(creation.installCount ?? 0)", icon: "arrow.down.circle")
                    StatBox(title: "Version", value: creation.version ?? "1.0.0", icon: "tag")
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)

                    MetaRow(label: "ID", value: creation.id.uuidString)
                    MetaRow(label: "Slug", value: creation.slug)
                    MetaRow(label: "Type", value: creation.creationType.displayName)
                    MetaRow(label: "Status", value: creation.status?.displayName ?? "Draft")
                    MetaRow(label: "Visibility", value: creation.visibility ?? "private")

                    if let url = creation.deployedUrl {
                        MetaRow(label: "URL", value: url)
                    }

                    if let created = creation.createdAt {
                        MetaRow(label: "Created", value: created.formatted())
                    }
                }
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Metadata Row

struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 13))
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    @State private var selectedStatus: CreationStatus = .draft
    @State private var isPublic: Bool = false
    @State private var selectedVisibility: String = "private"

    var body: some View {
        Form {
            Section("Visibility") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(CreationStatus.allCases, id: \.self) { status in
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(status.displayName)
                        }
                        .tag(status)
                    }
                }
                .onChange(of: selectedStatus) { _, newStatus in
                    Task {
                        await store.updateCreationSettings(id: creation.id, status: newStatus)
                    }
                }

                Toggle("Public", isOn: $isPublic)
                    .onChange(of: isPublic) { _, newValue in
                        Task {
                            await store.updateCreationSettings(id: creation.id, isPublic: newValue)
                        }
                    }

                Picker("Visibility", selection: $selectedVisibility) {
                    Text("Private").tag("private")
                    Text("Public").tag("public")
                    Text("Unlisted").tag("unlisted")
                }
                .onChange(of: selectedVisibility) { _, newValue in
                    Task {
                        await store.updateCreationSettings(id: creation.id, visibility: newValue)
                    }
                }
            }

            Section("Deployment") {
                if let url = creation.deployedUrl {
                    LabeledContent("URL", value: url)
                }
                if let repo = creation.githubRepo {
                    LabeledContent("GitHub", value: repo)
                }
            }

            Section("Info") {
                LabeledContent("ID", value: creation.id.uuidString)
                LabeledContent("Type", value: creation.creationType.displayName)
                if let created = creation.createdAt {
                    LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
        }
        .onChange(of: creation.id) { _, _ in
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
        }
    }
}
