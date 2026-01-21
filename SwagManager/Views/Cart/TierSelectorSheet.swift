//
//  TierSelectorSheet.swift
//  SwagManager (macOS)
//
//  Ported from iOS Whale app - exact styling and behavior
//

import SwiftUI

struct TierSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let product: Product
    let pricingSchemas: [PricingSchema]
    let onSelectTier: (PricingTier) -> Void

    @State private var selectedVariantId: UUID? = nil
    @State private var variantTiers: [PricingTier] = []
    @Namespace private var animation

    private var variants: [ProductVariant] { [] } // TODO: Add variants support
    private var hasVariants: Bool { !variants.isEmpty }

    private var selectedVariant: ProductVariant? {
        guard let id = selectedVariantId else { return nil }
        return variants.first { $0.id == id }
    }

    private var currentTiers: [PricingTier] {
        let tiers = selectedVariant != nil ? variantTiers : allTiers
        return tiers.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }

    private var allTiers: [PricingTier] {
        // Use embedded pricing schema from product (loaded via PostgREST join)
        if let schema = product.pricingSchema {
            NSLog("[TierSelector] ✅ Found \(schema.tiers.count) tiers for product '\(product.name)' in embedded schema '\(schema.name)'")
            for tier in schema.tiers {
                NSLog("[TierSelector]    - Tier: id=\(tier.id), label=\(tier.label), qty=\(tier.quantity), unit=\(tier.unit), price=\(tier.defaultPrice)")
            }
            return schema.tiers
        }

        // Fallback: Look up schema from store's pricing schemas array
        guard let schemaId = product.pricingSchemaId else {
            NSLog("[TierSelector] ⚠️ Product '\(product.name)' has no pricingSchemaId and no embedded schema")
            return []
        }

        guard let schema = pricingSchemas.first(where: { $0.id == schemaId }) else {
            NSLog("[TierSelector] ⚠️ No schema found for product '\(product.name)' with schemaId: \(schemaId)")
            NSLog("[TierSelector] Available schemas: \(pricingSchemas.map { "\($0.name) (\($0.id))" }.joined(separator: ", "))")
            return []
        }

        NSLog("[TierSelector] ✅ Found \(schema.tiers.count) tiers for product '\(product.name)' in schema '\(schema.name)'")
        for tier in schema.tiers {
            NSLog("[TierSelector]    - Tier: id=\(tier.id), label=\(tier.label), qty=\(tier.quantity), unit=\(tier.unit), price=\(tier.defaultPrice)")
        }
        return schema.tiers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - compact
            HStack {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // SKU row
                    if let sku = product.sku {
                        HStack {
                            Text(sku)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    // Variants (if any)
                    if hasVariants {
                        variantPicker
                    }

                    // Tiers
                    tiersSection
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 340, height: currentTiers.isEmpty ? 180 : min(400, CGFloat(currentTiers.count) * 48 + 120))
        .onAppear {
            NSLog("[TierSelector] Sheet opened for product: \(product.name), tiers: \(currentTiers.count)")
        }
    }

    // MARK: - Variant Picker

    private var variantPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                variantChip(name: "Base", isSelected: selectedVariantId == nil) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedVariantId = nil
                        variantTiers = []
                    }
                }

                ForEach(variants) { variant in
                    variantChip(name: variant.variantName, isSelected: selectedVariantId == variant.id) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedVariantId = variant.id
                            variantTiers = variant.pricingTiers
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func variantChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tiers Section

    private var tiersSection: some View {
        VStack(spacing: 6) {
            if currentTiers.isEmpty {
                // No tiers message
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No pricing tiers available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(currentTiers, id: \.id) { tier in
                    tierButton(tier)
                }
            }
        }
    }

    private func tierButton(_ tier: PricingTier) -> some View {
        Button {
            if let variant = selectedVariant {
                // TODO: Handle variant-specific callback
                onSelectTier(tier)
            } else {
                onSelectTier(tier)
            }
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(formatQuantity(tier.quantity)) \(tier.unit)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatCurrency(tier.defaultPrice))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(qty))"
        }
        return String(format: "%.1f", qty)
    }
}

// MARK: - ProductVariant Stub (TODO: Add full variant support)

struct ProductVariant: Identifiable {
    let id: UUID
    let variantName: String
    let pricingTiers: [PricingTier]
}
