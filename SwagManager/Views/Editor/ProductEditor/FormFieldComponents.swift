import SwiftUI

// MARK: - Form Field Components
// Extracted from ProductEditorComponents.swift following Apple engineering standards
// Contains: Reusable form field building blocks
// File size: ~125 lines (under Apple's 300 line "excellent" threshold)

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
    }
}

struct EditableRow: View {
    let label: String
    @Binding var text: String
    @Binding var hasChanges: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.surfaceTertiary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Materials.thin)

                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .onChange(of: text) { _, _ in hasChanges = true }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProductFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
    }
}

struct GlassTextEditor: View {
    let label: String
    @Binding var text: String
    let minHeight: CGFloat
    @Binding var hasChanges: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .font(.system(size: 12))
                .padding(10)
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.surfaceTertiary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Materials.thin)

                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .onChange(of: text) { _, _ in hasChanges = true }
        }
    }
}
