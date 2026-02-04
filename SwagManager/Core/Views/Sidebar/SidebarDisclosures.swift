import SwiftUI
import SwiftData

// MARK: - Shared Components
// Components used by both sidebar and detail list views

// MARK: - Order Status Badge

struct OrderStatusBadge: View {
    let status: String

    var color: Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "confirmed", "preparing": return .blue
        case "ready", "ready_to_ship", "packed": return .green
        case "delivered", "completed": return .gray
        case "cancelled": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
