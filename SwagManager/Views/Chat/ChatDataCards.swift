import SwiftUI

// MARK: - Chat Data Cards for Rich AI Responses

// MARK: - Product Card

struct ProductDataCard: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            // Image
            if let imageUrl = product.featuredImage, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.white.opacity(0.1)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "leaf")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if let sku = product.sku {
                    Text(sku)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    Text(product.displayPrice)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)

                    Text(product.stockStatusLabel)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(product.stockStatusColor.opacity(0.2))
                        .foregroundStyle(product.stockStatusColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Quick actions
            VStack(spacing: 6) {
                Button {
                    // View product
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    // Edit product
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Order Card

struct OrderDataCard: View {
    let orderNumber: String
    let status: String
    let total: Double
    let itemCount: Int
    let date: Date

    var statusColor: Color {
        switch status.lowercased() {
        case "completed": return .green
        case "processing": return .blue
        case "pending": return .orange
        case "cancelled": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "bag.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(statusColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(orderNumber)")
                        .font(.system(size: 13, weight: .semibold))

                    Text(status.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", total))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(formatDate(date))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Quick actions
            Button {
                // View order
            } label: {
                Text("View")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Inventory Alert Card

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

// MARK: - Sales Summary Card

struct SalesSummaryCard: View {
    let period: String
    let revenue: Double
    let orders: Int
    let growth: Double?
    let topCategory: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(period)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if let growth = growth {
                    HStack(spacing: 2) {
                        Image(systemName: growth >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.1f%%", abs(growth)))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(growth >= 0 ? .green : .red)
                }
            }

            // Main stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revenue")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(String(format: "$%.2f", revenue))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Orders")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("\(orders)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }

                Spacer()
            }

            // Top category
            if let category = topCategory {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text("Top: \(category)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.green.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Action Card (for AI-suggested actions)

struct ActionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonLabel: String
    let buttonColor: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(buttonColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(buttonColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))

                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Action button
            Button(action: action) {
                Text(buttonLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(buttonColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(buttonColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let stats: [(label: String, value: String, icon: String, color: Color)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                HStack(spacing: 6) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(stat.color)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(stat.value)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text(stat.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(stat.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if index < stats.count - 1 {
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Chart Card (Placeholder for charts)

struct ChartPlaceholderCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Placeholder bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let height = CGFloat.random(in: 20...60)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 24, height: height)
                }
            }
            .frame(height: 60)

            // Labels
            HStack {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
