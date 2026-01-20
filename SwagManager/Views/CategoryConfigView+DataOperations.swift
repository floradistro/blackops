import SwiftUI

// MARK: - CategoryConfigView Data Operations Extension
// Extracted from CategoryConfigView.swift following Apple engineering standards
// File size: ~80 lines (under Apple's 300 line "excellent" threshold)

extension CategoryConfigView {
    // MARK: - Data Loading

    internal func loadData() async {
        isLoading = true
        error = nil
        let catalogId = category.catalogId ?? store.selectedCatalog?.id

        do {
            async let f1 = SupabaseService.shared.fetchFieldSchemasForCategory(categoryId: category.id)
            async let f2 = SupabaseService.shared.fetchPricingSchemasForCategory(categoryId: category.id)
            async let f3 = SupabaseService.shared.fetchAvailableFieldSchemas(catalogId: catalogId ?? UUID(), categoryName: category.name)
            async let f4 = SupabaseService.shared.fetchAvailablePricingSchemas(catalogId: catalogId ?? UUID(), categoryName: category.name)

            let (assigned1, assigned2, avail1, avail2) = try await (f1, f2, f3, f4)

            await MainActor.run {
                assignedFieldSchemas = assigned1
                assignedPricingSchemas = assigned2
                availableFieldSchemas = avail1
                availablePricingSchemas = avail2
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Toggle Operations

    internal func toggleFieldSchema(_ schema: FieldSchema) async {
        do {
            if assignedFieldSchemas.contains(where: { $0.id == schema.id }) {
                try await SupabaseService.shared.removeFieldSchemaFromCategory(categoryId: category.id, fieldSchemaId: schema.id)
            } else {
                try await SupabaseService.shared.assignFieldSchemaToCategory(categoryId: category.id, fieldSchemaId: schema.id)
            }
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    internal func togglePricingSchema(_ schema: PricingSchema) async {
        do {
            if assignedPricingSchemas.contains(where: { $0.id == schema.id }) {
                try await SupabaseService.shared.removePricingSchemaFromCategory(categoryId: category.id, pricingSchemaId: schema.id)
            } else {
                try await SupabaseService.shared.assignPricingSchemaToCategory(categoryId: category.id, pricingSchemaId: schema.id)
            }
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete Operations

    internal func deleteFieldSchema(_ schema: FieldSchema) async {
        do {
            try await SupabaseService.shared.deleteFieldSchema(schemaId: schema.id)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    internal func deletePricingSchema(_ schema: PricingSchema) async {
        do {
            try await SupabaseService.shared.deletePricingSchema(schemaId: schema.id)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
