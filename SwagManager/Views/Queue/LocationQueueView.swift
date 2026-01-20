//
//  LocationQueueView.swift
//  SwagManager
//
//  Customer queue view for a location with realtime updates.
//  Displays all customers in queue and allows queue management.
//

import SwiftUI

struct LocationQueueView: View {
    let locationId: UUID
    @StateObject private var queueStore: LocationQueueStore
    @State private var queueUpdateCounter = 0

    init(locationId: UUID) {
        self.locationId = locationId
        _queueStore = StateObject(wrappedValue: LocationQueueStore.shared(for: locationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            queueHeader

            Divider()

            // Queue list
            if queueStore.isLoading && queueStore.queue.isEmpty {
                loadingView
            } else if queueStore.queue.isEmpty {
                emptyView
            } else {
                queueList
            }
        }
        .task(id: locationId) {
            await queueStore.loadQueue()
            queueStore.subscribeToRealtime()
        }
        .onDisappear {
            queueStore.unsubscribeFromRealtime()
        }
        .onReceive(NotificationCenter.default.publisher(for: .queueDidChange)) { notification in
            if let notificationLocationId = notification.object as? UUID,
               notificationLocationId == locationId {
                queueUpdateCounter += 1
            }
        }
    }

    // MARK: - Header

    private var queueHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Customer Queue")
                        .font(.headline)

                    // Connection indicator
                    connectionIndicator
                }

                HStack(spacing: 6) {
                    Text("\(queueStore.count) customer\(queueStore.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let lastUpdated = queueStore.lastUpdated {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timeAgo(from: lastUpdated))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Clear queue button
            if !queueStore.isEmpty {
                Button(action: {
                    Task {
                        await queueStore.clearQueue()
                    }
                }) {
                    Label("Clear All", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }

            // Refresh button
            Button(action: {
                Task {
                    await queueStore.refresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(queueStore.isLoading)
        }
        .padding()
    }

    // MARK: - Connection Indicator

    @ViewBuilder
    private var connectionIndicator: some View {
        switch queueStore.connectionState {
        case .connected:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        case .connecting:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 6, height: 6)
                Text("Connecting")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        case .disconnected, .error:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Auto-refresh")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Helper Functions

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 5 {
            return "just now"
        } else if seconds < 60 {
            return "\(Int(seconds))s ago"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        }
    }

    // MARK: - Queue List

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(queueStore.queue.enumerated()), id: \.element.id) { index, entry in
                    QueueEntryRow(
                        entry: entry,
                        position: index + 1,
                        isSelected: queueStore.selectedCartId == entry.cartId,
                        onSelect: {
                            queueStore.selectCart(entry.cartId)
                        },
                        onRemove: {
                            Task {
                                await queueStore.removeFromQueue(cartId: entry.cartId)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding()
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: queueStore.queue.map(\.id))
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No customers in queue")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Customers will appear here when added to the queue")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading queue...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Queue Entry Row

struct QueueEntryRow: View {
    let entry: QueueEntry
    let position: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Position badge
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(position)")
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .white : .primary)
            }

            // Customer info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.customerName)
                        .font(.headline)
                    if entry.customerId == nil {
                        Text("Guest")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let phone = entry.customerPhone {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "cart.fill")
                        .font(.caption2)
                    Text("\(entry.cartItemCount) items")
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                    Text("$\(entry.cartTotal as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Remove from queue")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - Preview

#Preview {
    LocationQueueView(locationId: UUID())
        .frame(width: 400, height: 600)
}
