//
//  FloatingCartDock.swift
//  SwagManager (macOS)
//
//  Ported from iOS Whale app - floating cart with customer info
//

import SwiftUI

struct FloatingCartDock: View {
    @ObservedObject var cartStore: CartStore
    let customerName: String
    let onCheckout: () -> Void
    let onClose: () -> Void

    private var cart: ServerCart? { cartStore.cart }
    private var hasItems: Bool { cart?.items.isEmpty == false }
    private var itemCount: Int { cart?.itemCount ?? 0 }

    var body: some View {
        floatingCartPill
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }

    // MARK: - Floating Cart Pill

    private var floatingCartPill: some View {
        HStack(spacing: 12) {
            // Customer avatar
            Menu {
                Section {
                    Text(customerName)
                }

                Button(role: .destructive) {
                    Task {
                        await cartStore.clearCart()
                    }
                } label: {
                    Label("Clear Cart", systemImage: "trash")
                }

                Button(role: .destructive) {
                    onClose()
                } label: {
                    Label("Remove Customer", systemImage: "person.badge.minus")
                }
            } label: {
                Text(customerInitials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.accentColor))
            }
            .menuStyle(.borderlessButton)

            if hasItems {
                // Item count badge
                Text("\(itemCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.2)))

                Spacer()

                // Total
                if let totals = cart?.totals {
                    Text(formatCurrency(totals.total))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Checkout button
                Button {
                    onCheckout()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Pay")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // No items
                Text("Add items")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 500)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }

    // MARK: - Helpers

    private var customerInitials: String {
        let parts = customerName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(customerName.prefix(2)).uppercased()
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}
