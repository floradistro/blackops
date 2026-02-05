// Extracted from SupabaseService.swift following Apple engineering standards
// Refactored - methods split into focused extensions
// File size: ~20 lines (under Apple's 300 line "excellent" threshold)

import Foundation
import Supabase

// NOT @MainActor — network I/O + JSON decoding must run off main thread
final class ProductSchemaService: @unchecked Sendable {
    internal let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // Methods extracted to extensions:
    // - ProductSchemaService+Products.swift: Product CRUD operations
    // - ProductSchemaService+FieldSchemas.swift: Field schema operations
    // - ProductSchemaService+PricingSchemas.swift: Pricing schema operations
    // - ProductSchemaService+CategoryAssignments.swift: Category schema assignments
}
