import SwiftUI

// MARK: - Inventory Alert Card
// Extracted from ChatDataCards.swift following Apple engineering standards
// File size: ~97 lines (under Apple's 300 line "excellent" threshold)

struct InventoryAlertCard: View {
    let productName: String
    let sku: String
    let currentStock: Int
    let minimumStock: Int
    let severity: AlertSeverity

    enum AlertSeverity {
        case critical, low, warning

        var color: Color {
            switch self {
            case .critical: return .red
            case .low: return .orange
            case .warning: return .yellow
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .low: return "exclamationmark.triangle"
            case .warning: return "exclamationmark.circle"
            }
        }

        var label: String {
            switch self {
            case .critical: return "Critical"
            case .low: return "Low"
            case .warning: return "Warning"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Severity icon
            ZStack {
                Circle()
                    .fill(severity.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: severity.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(severity.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(productName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(sku)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Stock levels
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(currentStock)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(severity.color)
                    Text("/ \(minimumStock)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Text(severity.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(severity.color)
            }

            // Action
            Button {
                // Create PO
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Create Purchase Order")
        }
        .padding(10)
        .background(severity.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(severity.color.opacity(0.2), lineWidth: 1)
        )
    }
}
