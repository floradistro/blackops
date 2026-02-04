import SwiftUI

// MARK: - Shared Detail Components
// Reusable components for detail views

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
