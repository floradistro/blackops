import SwiftUI

// MARK: - Editor Welcome & Small Panel Components
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~242 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Welcome View

struct WelcomeView: View {
    @ObservedObject var store: EditorStore
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Welcome card
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.accent.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.selectedStore?.storeName ?? "Swag Manager")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("Ready to build")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                // Stats
                if !store.products.isEmpty || !store.categories.isEmpty || !store.creations.isEmpty {
                    HStack(spacing: 0) {
                        statItem(value: store.products.count, label: "Products", color: DesignSystem.Colors.green)
                        Rectangle().fill(DesignSystem.Colors.border).frame(width: 1, height: 40)
                        statItem(value: store.categories.count, label: "Categories", color: DesignSystem.Colors.yellow)
                        Rectangle().fill(DesignSystem.Colors.border).frame(width: 1, height: 40)
                        statItem(value: store.creations.count, label: "Creations", color: DesignSystem.Colors.cyan)
                    }
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Quick actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        QuickActionButton(icon: "plus", label: "New Creation", shortcut: "⌘N") {
                            store.showNewCreationSheet = true
                        }
                        QuickActionButton(icon: "folder.badge.plus", label: "New Collection", shortcut: "⌘⇧N") {
                            store.showNewCollectionSheet = true
                        }
                    }
                }
            }
            .padding(32)
            .background(DesignSystem.Colors.surfaceTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .frame(maxWidth: 440)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            // Keyboard hints
            HStack(spacing: 32) {
                keyboardHint(keys: ["⌘", "N"], action: "New")
                keyboardHint(keys: ["⌘", "F"], action: "Search")
                keyboardHint(keys: ["⌘", "\\"], action: "Sidebar")
            }
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(DesignSystem.Animation.slow.delay(0.1)) {
                appeared = true
            }
        }
    }

    private func statItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func keyboardHint(keys: [String], action: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            Text(action)
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovering = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(shortcut)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isHovering ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovering ? DesignSystem.Colors.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Code Editor Panel

struct CodeEditorPanel: View {
    @Binding var code: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("React Code")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(code.count) characters")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceTertiary)

            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(height: 1)

            // Editor
            TextEditor(text: $code)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Colors.surfaceElevated)
        }
    }
}

// MARK: - Empty Editor State

struct EmptyEditorView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Selection")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Select a creation from the sidebar")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
