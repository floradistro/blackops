import SwiftUI

// MARK: - Editor Panel Components
// Optimized with smooth Apple-style animations
// Minimal monochromatic theme

// MARK: - Details Panel

struct DetailsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    @State private var isAppearing = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: creation.creationType.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Color.primary.opacity(0.5))
                        Text(creation.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.9))
                    }
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 8)

                    Text(creation.description ?? "No description")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 6)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .padding(.vertical, 8)

                // Stats
                HStack(spacing: 1) {
                    StatBox(title: "Views", value: "\(creation.viewCount ?? 0)", icon: "eye")
                    StatBox(title: "Installs", value: "\(creation.installCount ?? 0)", icon: "arrow.down.circle")
                    StatBox(title: "Version", value: creation.version ?? "1.0.0", icon: "tag")
                }
                .padding(.horizontal, 20)
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 4)

                Divider()
                    .padding(.vertical, 12)

                // Metadata
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Details")

                    VStack(spacing: 6) {
                        MetaRow(label: "ID", value: String(creation.id.uuidString.prefix(8)) + "...")
                        MetaRow(label: "Slug", value: creation.slug)
                        MetaRow(label: "Type", value: creation.creationType.displayName)
                        MetaRow(label: "Status", value: creation.status?.displayName ?? "Draft")
                        MetaRow(label: "Visibility", value: creation.visibility ?? "private")

                        if let url = creation.deployedUrl {
                            MetaRow(label: "URL", value: url)
                        }

                        if let created = creation.createdAt {
                            MetaRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 4)

                Spacer(minLength: 40)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                isAppearing = true
            }
        }
        .onChange(of: creation.id) { _, _ in
            isAppearing = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Stat Box (Minimal)

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.4))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(isHovered ? 0.05 : 0.03))
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Metadata Row (Minimal)

struct MetaRow: View {
    let label: String
    let value: String

    @State private var isCopied = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.8))
                .textSelection(.enabled)
                .lineLimit(1)
            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { isCopied = false }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(isCopied ? 0.6 : 0.25))
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Settings Panel (Minimal)

struct SettingsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    @State private var selectedStatus: CreationStatus = .draft
    @State private var isPublic: Bool = false
    @State private var selectedVisibility: String = "private"
    @State private var isAppearing = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Status Section
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Status")
                    VStack(spacing: 8) {
                        // Status Picker - Minimal buttons
                        HStack(spacing: 6) {
                            ForEach(CreationStatus.allCases, id: \.self) { status in
                                MinimalStatusButton(
                                    title: status.displayName,
                                    isSelected: selectedStatus == status,
                                    action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            selectedStatus = status
                                        }
                                        Task {
                                            await store.updateCreationSettings(id: creation.id, status: status)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 8)

                Divider()
                    .padding(.vertical, 12)

                // Visibility Section
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Visibility")
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            MinimalStatusButton(
                                title: "Private",
                                isSelected: selectedVisibility == "private",
                                action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        selectedVisibility = "private"
                                    }
                                    Task {
                                        await store.updateCreationSettings(id: creation.id, visibility: "private")
                                    }
                                }
                            )
                            MinimalStatusButton(
                                title: "Unlisted",
                                isSelected: selectedVisibility == "unlisted",
                                action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        selectedVisibility = "unlisted"
                                    }
                                    Task {
                                        await store.updateCreationSettings(id: creation.id, visibility: "unlisted")
                                    }
                                }
                            )
                            MinimalStatusButton(
                                title: "Public",
                                isSelected: selectedVisibility == "public",
                                action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        selectedVisibility = "public"
                                    }
                                    Task {
                                        await store.updateCreationSettings(id: creation.id, visibility: "public")
                                    }
                                }
                            )
                        }

                        // Public Toggle
                        HStack {
                            Text("Public Access")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.primary.opacity(0.6))
                            Spacer()
                            Toggle("", isOn: $isPublic)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .onChange(of: isPublic) { _, newValue in
                                    Task {
                                        await store.updateCreationSettings(id: creation.id, isPublic: newValue)
                                    }
                                }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 6)

                Divider()
                    .padding(.vertical, 12)

                // Deployment Section
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Deployment")
                    VStack(spacing: 6) {
                        if let url = creation.deployedUrl {
                            MetaRow(label: "URL", value: url)
                        }
                        if let repo = creation.githubRepo {
                            MetaRow(label: "GitHub", value: repo)
                        }
                        if creation.deployedUrl == nil && creation.githubRepo == nil {
                            Text("Not deployed")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 4)

                Divider()
                    .padding(.vertical, 12)

                // Info Section
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Info")
                    VStack(spacing: 6) {
                        MetaRow(label: "ID", value: String(creation.id.uuidString.prefix(8)) + "...")
                        MetaRow(label: "Type", value: creation.creationType.displayName)
                        if let created = creation.createdAt {
                            MetaRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 4)

                Spacer(minLength: 40)
            }
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .onAppear {
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                isAppearing = true
            }
        }
        .onChange(of: creation.id) { _, _ in
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
            isAppearing = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Minimal Status Button

private struct MinimalStatusButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                .foregroundStyle(Color.primary.opacity(isSelected ? 0.8 : 0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(
                            isPressed ? 0.1 :
                            isSelected ? 0.08 :
                            isHovered ? 0.05 : 0.03
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(isSelected ? 0.12 : 0), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
    }
}
