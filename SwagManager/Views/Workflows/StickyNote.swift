import SwiftUI

// MARK: - Sticky Note Data Model
// Draggable text notes for the workflow canvas (inspired by n8n sticky notes)

struct StickyNoteData: Identifiable, Codable, Equatable {
    let id: String
    var text: String
    var color: StickyColor
    var position: CGPoint
    var width: CGFloat

    enum StickyColor: String, Codable, CaseIterable {
        case yellow, blue, green, pink, purple

        var background: Color {
            switch self {
            case .yellow: return Color(red: 0.98, green: 0.92, blue: 0.55).opacity(0.18)
            case .blue:   return Color(red: 0.55, green: 0.78, blue: 0.98).opacity(0.18)
            case .green:  return Color(red: 0.55, green: 0.90, blue: 0.62).opacity(0.18)
            case .pink:   return Color(red: 0.98, green: 0.58, blue: 0.72).opacity(0.18)
            case .purple: return Color(red: 0.75, green: 0.60, blue: 0.98).opacity(0.18)
            }
        }

        var border: Color {
            switch self {
            case .yellow: return Color(red: 0.92, green: 0.82, blue: 0.30).opacity(0.45)
            case .blue:   return Color(red: 0.40, green: 0.65, blue: 0.95).opacity(0.45)
            case .green:  return Color(red: 0.35, green: 0.78, blue: 0.45).opacity(0.45)
            case .pink:   return Color(red: 0.95, green: 0.45, blue: 0.62).opacity(0.45)
            case .purple: return Color(red: 0.65, green: 0.48, blue: 0.92).opacity(0.45)
            }
        }

        var dotColor: Color {
            switch self {
            case .yellow: return Color(red: 0.92, green: 0.82, blue: 0.30)
            case .blue:   return Color(red: 0.40, green: 0.65, blue: 0.95)
            case .green:  return Color(red: 0.35, green: 0.78, blue: 0.45)
            case .pink:   return Color(red: 0.95, green: 0.45, blue: 0.62)
            case .purple: return Color(red: 0.65, green: 0.48, blue: 0.92)
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        text: String = "",
        color: StickyColor = .yellow,
        position: CGPoint = .zero,
        width: CGFloat = 200
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.position = position
        self.width = width
    }

    // Codable support for CGPoint
    enum CodingKeys: String, CodingKey {
        case id, text, color, positionX, positionY, width
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        color = try container.decode(StickyColor.self, forKey: .color)
        let x = try container.decode(CGFloat.self, forKey: .positionX)
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
        width = try container.decode(CGFloat.self, forKey: .width)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(color, forKey: .color)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(width, forKey: .width)
    }
}

// MARK: - Sticky Note View

struct StickyNoteView: View {
    @Binding var note: StickyNoteData
    let isSelected: Bool
    let zoom: CGFloat
    let onDelete: () -> Void

    // Drag state
    @State private var dragStartPosition: CGPoint?

    // Resize state
    @State private var resizeStartWidth: CGFloat?
    @State private var isResizing = false

    // Hover state
    @State private var isHovered = false

    // Stable rotation per instance (seeded from id hash)
    private var rotation: Double {
        let hash = note.id.hashValue
        let normalized = Double(abs(hash) % 200) / 100.0 - 1.0 // range -1...+1
        return normalized
    }

    private let minWidth: CGFloat = 120
    private let maxWidth: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color picker toolbar (visible when selected)
            if isSelected {
                colorPicker
                    .padding(.bottom, DS.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Note body
            noteBody
        }
        .rotationEffect(.degrees(rotation))
        .shadow(
            color: Color.black.opacity(isSelected ? 0.25 : 0.15),
            radius: isSelected ? 8 : 4,
            y: 2
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Menu("Change Color") {
                ForEach(StickyNoteData.StickyColor.allCases, id: \.self) { color in
                    Button {
                        note.color = color
                    } label: {
                        Label(color.rawValue.capitalized, systemImage: note.color == color ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .animation(DS.Animation.fast, value: isSelected)
    }

    // MARK: - Note Body

    private var noteBody: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Text editor area
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if note.text.isEmpty {
                        Text("Add a note...")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.sm)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $note.text)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .padding(.horizontal, DS.Spacing.xxs)
                        .padding(.vertical, DS.Spacing.xs)
                        .frame(minHeight: 40)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(width: note.width, alignment: .leading)
            .background(note.color.background, in: noteShape)
            .background(.ultraThinMaterial, in: noteShape)
            .overlay {
                noteShape
                    .strokeBorder(
                        isSelected ? DS.Colors.accent : note.color.border,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }

            // Resize handle
            resizeHandle
        }
        .gesture(dragGesture)
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(StickyNoteData.StickyColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.dotColor)
                    .frame(width: 12, height: 12)
                    .overlay {
                        if note.color == color {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .scaleEffect(note.color == color ? 1.2 : 1.0)
                    .onTapGesture {
                        withAnimation(DS.Animation.fast) {
                            note.color = color
                        }
                    }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right")
            .font(DesignSystem.font(8, weight: .bold))
            .foregroundStyle(DS.Colors.textQuaternary)
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .opacity(isHovered || isSelected ? 1 : 0)
            .gesture(resizeGesture)
            .padding(DS.Spacing.xs)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isResizing else { return }
                if dragStartPosition == nil {
                    dragStartPosition = note.position
                }
                let start = dragStartPosition!
                note.position = CGPoint(
                    x: start.x + value.translation.width / zoom,
                    y: start.y + value.translation.height / zoom
                )
            }
            .onEnded { _ in
                dragStartPosition = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isResizing = true
                if resizeStartWidth == nil {
                    resizeStartWidth = note.width
                }
                let startWidth = resizeStartWidth!
                let delta = value.translation.width / zoom
                note.width = max(minWidth, min(maxWidth, startWidth + delta))
            }
            .onEnded { _ in
                resizeStartWidth = nil
                isResizing = false
            }
    }

    // MARK: - Shape

    private var noteShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.sm)
    }
}

// MARK: - Preview

#Preview("Sticky Notes") {
    ZStack {
        Color.black.opacity(0.85).ignoresSafeArea()

        HStack(spacing: 40) {
            StickyNoteView(
                note: .constant(StickyNoteData(
                    text: "Remember to connect the webhook trigger to the email step",
                    color: .yellow,
                    position: .zero,
                    width: 200
                )),
                isSelected: true,
                zoom: 1.0,
                onDelete: {}
            )

            StickyNoteView(
                note: .constant(StickyNoteData(
                    text: "TODO: Add error handling for failed API calls",
                    color: .blue,
                    position: .zero,
                    width: 180
                )),
                isSelected: false,
                zoom: 1.0,
                onDelete: {}
            )

            StickyNoteView(
                note: .constant(StickyNoteData(
                    text: "",
                    color: .green,
                    position: .zero,
                    width: 160
                )),
                isSelected: false,
                zoom: 1.0,
                onDelete: {}
            )

            StickyNoteView(
                note: .constant(StickyNoteData(
                    text: "Approved by team lead",
                    color: .pink,
                    position: .zero,
                    width: 150
                )),
                isSelected: false,
                zoom: 1.0,
                onDelete: {}
            )

            StickyNoteView(
                note: .constant(StickyNoteData(
                    text: "v2 refactor",
                    color: .purple,
                    position: .zero,
                    width: 130
                )),
                isSelected: false,
                zoom: 1.0,
                onDelete: {}
            )
        }
        .padding(40)
    }
    .frame(width: 1000, height: 400)
}
