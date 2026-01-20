//
//  LocationQueueDebugView.swift
//  SwagManager
//
//  Standalone queue view for testing and debugging.
//  Access via menu or toolbar button to see queue for any location.
//

import SwiftUI

struct LocationQueueDebugView: View {
    @StateObject private var store: EditorStore
    @State private var selectedLocationId: UUID?

    init(store: EditorStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Location picker sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Location")
                    .font(.headline)
                    .padding()

                Divider()

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.locations) { location in
                            Button {
                                selectedLocationId = location.id
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.purple)
                                    Text(location.name)
                                        .font(.body)
                                    Spacer()
                                    if location.isActive == true {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedLocationId == location.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if store.locations.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "mappin.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No locations found")
                                    .font(.headline)
                                Text("Select a store first")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        }
                    }
                    .padding(8)
                }
            }
            .frame(width: 250)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Queue view
            if let locationId = selectedLocationId {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customer Queue")
                                .font(.title2.bold())
                            if let location = store.locations.first(where: { $0.id == locationId }) {
                                Text(location.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    // Queue
                    LocationQueueView(locationId: locationId)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a location")
                        .font(.headline)
                    Text("Choose a location from the list to view its customer queue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Preview
#Preview {
    LocationQueueDebugView(store: EditorStore())
}
