import SwiftUI

// MARK: - Editor UI Components
// Extracted from EditorView.swift following Apple engineering standards
// Contains: Small reusable UI components for editor views
// File size: ~50 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Creation List Item

struct CreationListItem: View {
    let creation: Creation
    let isSelected: Bool
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: creation.creationType.icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 16)

            Text(creation.name)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(creation.status == .published ? DesignSystem.Colors.green : DesignSystem.Colors.orange)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
