import SwiftUI

// MARK: - Canvas Search Overlay

struct CanvasSearchOverlay: View {
    @Binding var isPresented: Bool
    let nodes: [GraphNode]
    let nodePositions: [String: CGPoint]
    let onNavigateToNode: (String) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var currentMatchIndex = 0
    @FocusState private var isSearchFocused: Bool

    // MARK: - Filtered Matches

    private var matches: [GraphNode] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return nodes.filter {
            $0.id.lowercased().contains(q) ||
            $0.type.lowercased().contains(q) ||
            $0.displayName.lowercased().contains(q) ||
            $0.stepConfig?["tool_name"]?.stringValue?.lowercased().contains(q) == true
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(DesignSystem.font(12))
                .foregroundStyle(DS.Colors.textTertiary)

            TextField("Find node...", text: $query)
                .textFieldStyle(.plain)
                .font(DS.Typography.monoCaption)
                .focused($isSearchFocused)
                .onSubmit { navigateToNext() }

            if !matches.isEmpty {
                Text("\(currentMatchIndex + 1)/\(matches.count)")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .monospacedDigit()

                Button { navigateToPrevious() } label: {
                    Image(systemName: "chevron.up")
                        .font(DesignSystem.font(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)

                Button { navigateToNext() } label: {
                    Image(systemName: "chevron.down")
                        .font(DesignSystem.font(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)
            }

            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.font(10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(width: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: query) { _, _ in
            currentMatchIndex = 0
            navigateToCurrentMatch()
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.return) {
            navigateToNext()
            return .handled
        }
    }

    // MARK: - Navigation

    private func navigateToNext() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matches.count
        navigateToCurrentMatch()
    }

    private func navigateToPrevious() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        navigateToCurrentMatch()
    }

    private func navigateToCurrentMatch() {
        guard let match = matches[safe: currentMatchIndex] else { return }
        onNavigateToNode(match.id)
    }
}

// MARK: - Safe Collection Subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
