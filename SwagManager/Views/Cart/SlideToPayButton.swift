//
//  SlideToPayButton.swift
//  SwagManager (macOS)
//
//  Slide-to-pay button with shimmer effect - ported from iOS Whale app
//  macOS-native with mouse/trackpad gesture support
//

import SwiftUI

struct SlideToPayButton: View {
    let text: String
    let icon: String
    let isEnabled: Bool
    let onComplete: () -> Void

    // Layout constants
    private let trackHeight: CGFloat = 62
    private let thumbDiameter: CGFloat = 52
    private let trackPadding: CGFloat = 5
    private let completionThreshold: CGFloat = 0.80

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false
    @State private var shimmerPhase: CGFloat = 0
    @GestureState private var isDragging = false

    // Success green
    private let successGreen = Color(red: 52/255, green: 199/255, blue: 89/255)

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let maxOffset = trackWidth - thumbDiameter - (trackPadding * 2)
            let progress = maxOffset > 0 ? min(max(dragOffset / maxOffset, 0), 1.0) : 0

            ZStack(alignment: .leading) {
                // Shimmer text - centered in track
                ShimmerText(text: text, phase: shimmerPhase)
                    .opacity(1.0 - Double(progress) * 2.0)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, thumbDiameter + trackPadding + 8)

                // Liquid glass thumb with icon
                ZStack {
                    Image(systemName: isCompleted ? "checkmark" : icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isCompleted ? successGreen : .white.opacity(0.9))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: thumbDiameter, height: thumbDiameter)
                .glassEffect(.regular.interactive(), in: .circle)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .padding(.leading, trackPadding)
                .offset(x: dragOffset)
                .scaleEffect(isDragging ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            guard isEnabled && !isCompleted else { return }
                            dragOffset = max(0, min(value.translation.width, maxOffset))
                        }
                        .onEnded { _ in
                            guard isEnabled && !isCompleted else { return }
                            let finalProgress = maxOffset > 0 ? dragOffset / maxOffset : 0

                            if finalProgress >= completionThreshold {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = maxOffset
                                    isCompleted = true
                                }
                                onComplete()
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .frame(height: trackHeight)
            .glassEffect(.regular, in: .capsule)
            .opacity(isEnabled ? 1.0 : 0.5)
            .allowsHitTesting(isEnabled && !isCompleted)
        }
        .frame(height: trackHeight)
        .onAppear {
            // Shimmer animation - continuous sweep
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.0
            }
        }
        .onChange(of: text) { _, _ in
            if !isCompleted {
                withAnimation(.spring(response: 0.3)) {
                    dragOffset = 0
                }
            }
        }
    }
}

// MARK: - Shimmer Text (macOS-compatible)

private struct ShimmerText: View {
    let text: String
    let phase: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .white.opacity(0.3),
                        .white.opacity(0.7),
                        .white.opacity(1.0),
                        .white.opacity(0.7),
                        .white.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black, .black, .black, .clear],
                            startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                            endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                        )
                    )
            )
    }
}
