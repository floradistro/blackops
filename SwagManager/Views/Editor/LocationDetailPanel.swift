import SwiftUI

// MARK: - Location Detail Panel
// Minimal, monochromatic theme with smooth Apple-style animations

struct LocationDetailPanel: View {
    let location: Location
    @ObservedObject var store: EditorStore

    @State private var isAppearing = false

    var locationOrders: [Order] {
        store.ordersForLocation(location.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Inline toolbar
            PanelToolbar(
                title: location.name,
                icon: "mappin.and.ellipse",
                subtitle: location.isActive == true ? "Active" : "Inactive"
            ) {
                ToolbarButton(icon: "square.and.pencil", action: { /* Edit */ })
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 48, height: 48)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.primary.opacity(0.6))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.9))

                            if let city = location.city, let state = location.state {
                                Text("\(city), \(state)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }
                        }

                        Spacer()

                        // Active status
                        if location.isActive == true {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.primary.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .modifier(PulseModifier())
                                Text("Active")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.primary.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(20)
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 8)

                    Divider()
                        .padding(.vertical, 8)

                    // Contact Info
                    if location.address != nil || location.phone != nil || location.email != nil {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Contact")
                            VStack(alignment: .leading, spacing: 8) {
                                if let address = location.address {
                                    MinimalContactRow(icon: "location", value: address)
                                }
                                if let phone = location.phone {
                                    MinimalContactRow(icon: "phone", value: phone)
                                }
                                if let email = location.email {
                                    MinimalContactRow(icon: "envelope", value: email)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 6)

                        Divider()
                            .padding(.vertical, 8)
                    }

                    // Orders at this location
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            SectionHeader(title: "Orders")
                            Spacer()
                            Text("\(locationOrders.count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .padding(.trailing, 20)
                        }

                        if locationOrders.isEmpty {
                            Text("No orders at this location")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(40)
                        } else {
                            LazyVStack(spacing: 1) {
                                ForEach(locationOrders) { order in
                                    LocationOrderRow(order: order) {
                                        store.openOrder(order)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 4)

                    Spacer(minLength: 40)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                isAppearing = true
            }
        }
        .onChange(of: location.id) { _, _ in
            isAppearing = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Supporting Views

private struct MinimalContactRow: View {
    let icon: String
    let value: String

    @State private var isCopied = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.4))
                .frame(width: 16)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.7))
                .textSelection(.enabled)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { isCopied = false }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(isCopied ? 0.6 : 0.25))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Location Order Row with Hover

private struct LocationOrderRow: View {
    let order: Order
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))

                    Text(order.statusLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }

                Spacer()

                Text(order.displayTotal)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.7))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.5 : 0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(isPressed ? 0.06 : isHovered ? 0.04 : 0.02))
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
    }
}
