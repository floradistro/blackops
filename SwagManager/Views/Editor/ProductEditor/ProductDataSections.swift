import SwiftUI

// MARK: - Product Data Sections
// Extracted from ProductEditorComponents.swift following Apple engineering standards
// Contains: CustomFieldsSection and ProductPricingSection
// File size: ~205 lines (under Apple's 300 line "excellent" threshold)

struct CustomFieldsSection: View {
    let schemas: [FieldSchema]
    let fieldValues: [String: AnyCodable]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Custom Fields")

            VStack(alignment: .leading, spacing: 18) {
                ForEach(schemas, id: \.id) { schema in
                    // Only show fields that have actual values
                    let fieldsWithValues = schema.fields.filter { hasFieldValue($0) }

                    if !fieldsWithValues.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(schema.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.3)

                            VStack(spacing: 8) {
                                ForEach(fieldsWithValues, id: \.fieldId) { field in
                                    HStack(spacing: 12) {
                                        Text(field.displayLabel)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .leading)
                                            .font(.system(size: 12))
                                        Text(getFieldValue(field))
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func hasFieldValue(_ field: FieldDefinition) -> Bool {
        guard let fieldKey = field.key,
              let fieldValues = fieldValues else {
            return false
        }
        return fieldValues[fieldKey] != nil
    }

    private func getFieldValue(_ field: FieldDefinition) -> String {
        // Try to get actual value from product's custom_fields
        if let fieldKey = field.key,
           let fieldValues = fieldValues,
           let actualValue = fieldValues[fieldKey] {
            return "\(actualValue.value)"
        }

        // Fall back to default value from schema if no actual value exists
        if let defaultValue = field.defaultValue {
            return "\(defaultValue.value)"
        }

        return "-"
    }
}

// MARK: - Pricing Schemas Section

struct ProductPricingSection: View {
    let pricingData: AnyCodable
    let schemaName: String?

    var body: some View {
        let tiers = extractTiers()

        if !tiers.isEmpty {
            let title = schemaName.map { "\($0) Pricing" } ?? "Pricing Tiers"
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: title)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(tiers.enumerated()), id: \.offset) { index, tierDict in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(extractLabel(from: tierDict))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)

                                if let qty = extractQuantity(from: tierDict) {
                                    let unit = tierDict["unit"] as? String ?? "units"
                                    Text("(\(formatQuantity(qty)) \(unit))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(extractPrice(from: tierDict))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.green)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.surfaceTertiary)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Materials.thin)

                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func extractTiers() -> [[String: Any]] {
        // Case 1: pricing_data is an array of tiers
        if let tiersArray = pricingData.value as? [[String: Any]] {
            return tiersArray
        }

        // Case 2: pricing_data is an object with a "tiers" property
        if let pricingObject = pricingData.value as? [String: Any],
           let tiersArray = pricingObject["tiers"] as? [[String: Any]] {
            return tiersArray
        }

        return []
    }

    private func extractLabel(from dict: [String: Any]) -> String {
        if let label = dict["label"] as? String {
            return label
        }
        if let id = dict["id"] as? String {
            return id
        }
        return "Tier"
    }

    private func extractQuantity(from dict: [String: Any]) -> Double? {
        if let qty = dict["quantity"] as? Double {
            return qty
        }
        if let qty = dict["quantity"] as? Int {
            return Double(qty)
        }
        return nil
    }

    private func extractPrice(from dict: [String: Any]) -> String {
        // Try default_price first (various types for PostgreSQL numeric compatibility)
        if let price = dict["default_price"] as? Double {
            return String(format: "$%.2f", price)
        }
        if let price = dict["default_price"] as? Decimal {
            return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
        if let price = dict["default_price"] as? Int {
            return String(format: "$%.2f", Double(price))
        }
        if let priceStr = dict["default_price"] as? String, let price = Double(priceStr) {
            return String(format: "$%.2f", price)
        }

        // Try price field
        if let price = dict["price"] as? Double {
            return String(format: "$%.2f", price)
        }
        if let price = dict["price"] as? Decimal {
            return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
        if let price = dict["price"] as? Int {
            return String(format: "$%.2f", Double(price))
        }
        if let priceStr = dict["price"] as? String, let price = Double(priceStr) {
            return String(format: "$%.2f", price)
        }

        return "-"
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", qty)
        } else {
            return String(format: "%.1f", qty)
        }
    }
}
