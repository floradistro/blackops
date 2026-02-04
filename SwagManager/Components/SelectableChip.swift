import SwiftUI

// MARK: - FlowLayout
// A simple flow layout that wraps content

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        let maxX = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxX && currentX > 0 {
                // Wrap to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}

// MARK: - Selectable Chip Component
// Reusable chip for multi-select scenarios
// Replaces 6+ duplicate chip implementations

struct SelectableChip<T: Hashable>: View {
    let item: T
    let label: String
    let isSelected: Bool
    let color: Color
    let onToggle: (T) -> Void

    init(
        item: T,
        label: String,
        isSelected: Bool,
        color: Color = .blue,
        onToggle: @escaping (T) -> Void
    ) {
        self.item = item
        self.label = label
        self.isSelected = isSelected
        self.color = color
        self.onToggle = onToggle
    }

    var body: some View {
        Button {
            onToggle(item)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.15) : Color.primary.opacity(0.05))
            .foregroundStyle(isSelected ? color : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Convenience Initializers

extension SelectableChip where T == String {
    /// String chip with auto-formatting (underscores to spaces, capitalized)
    init(
        _ value: String,
        isSelected: Bool,
        color: Color = .blue,
        formatLabel: Bool = true,
        onToggle: @escaping (String) -> Void
    ) {
        self.item = value
        self.label = formatLabel
            ? value.replacingOccurrences(of: "_", with: " ").capitalized
            : value
        self.isSelected = isSelected
        self.color = color
        self.onToggle = onToggle
    }
}

extension SelectableChip where T == Int {
    /// Day of week chip (0 = Sun, 1 = Mon, etc.)
    init(
        dayIndex: Int,
        isSelected: Bool,
        color: Color = .cyan,
        onToggle: @escaping (Int) -> Void
    ) {
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        self.item = dayIndex
        self.label = weekdays[dayIndex]
        self.isSelected = isSelected
        self.color = color
        self.onToggle = onToggle
    }
}

// MARK: - Location Chip

extension SelectableChip where T == UUID {
    /// Location chip using Location model
    init(
        location: Location,
        isSelected: Bool,
        color: Color = .indigo,
        onToggle: @escaping (UUID) -> Void
    ) {
        self.item = location.id
        self.label = location.name
        self.isSelected = isSelected
        self.color = color
        self.onToggle = onToggle
    }
}

// MARK: - Chip Group

/// A flow layout group of selectable chips
struct ChipGroup<T: Hashable>: View {
    let items: [T]
    let selectedItems: Set<T>
    let color: Color
    let labelProvider: (T) -> String
    let onToggle: (T) -> Void

    init(
        items: [T],
        selectedItems: Set<T>,
        color: Color = .blue,
        labelProvider: @escaping (T) -> String,
        onToggle: @escaping (T) -> Void
    ) {
        self.items = items
        self.selectedItems = selectedItems
        self.color = color
        self.labelProvider = labelProvider
        self.onToggle = onToggle
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                SelectableChip(
                    item: item,
                    label: labelProvider(item),
                    isSelected: selectedItems.contains(item),
                    color: color,
                    onToggle: onToggle
                )
            }
        }
    }
}

// MARK: - String Chip Group

extension ChipGroup where T == String {
    init(
        items: [String],
        selectedItems: Set<String>,
        color: Color = .blue,
        formatLabels: Bool = true,
        onToggle: @escaping (String) -> Void
    ) {
        self.items = items
        self.selectedItems = selectedItems
        self.color = color
        self.labelProvider = { value in
            formatLabels
                ? value.replacingOccurrences(of: "_", with: " ").capitalized
                : value
        }
        self.onToggle = onToggle
    }
}

// MARK: - Monochrome Option Selector
// Single-select chip group with minimal styling (no color)

struct MonoOptionSelector<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let labelProvider: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(labelProvider(option))
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selection == option ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                        .foregroundStyle(selection == option ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension MonoOptionSelector where T == String {
    init(options: [String], selection: Binding<String>) {
        self.options = options
        self._selection = selection
        self.labelProvider = { $0 }
    }
}

extension MonoOptionSelector where T == Int {
    init(options: [Int], selection: Binding<Int>, labels: [Int: String]) {
        self.options = options
        self._selection = selection
        self.labelProvider = { labels[$0] ?? "\($0)" }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        Text("String Chips")
            .font(.headline)

        ChipGroup(
            items: ["vip", "gold", "silver", "standard"],
            selectedItems: ["vip", "gold"],
            color: .purple
        ) { item in
            print("Toggled: \(item)")
        }

        Text("Day Chips")
            .font(.headline)

        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { day in
                SelectableChip(
                    dayIndex: day,
                    isSelected: [1, 2, 3, 4, 5].contains(day),
                    color: .cyan
                ) { _ in }
            }
        }
    }
    .padding()
}
