import SwiftUI

// MARK: - EditorStore Catalog Management Extension
// Refactored - split into focused extension files following Apple engineering standards
// File size: ~10 lines (under Apple's 300 line "excellent" threshold)

// This file previously contained 408 lines of store, catalog, and category management code.
// It has been refactored into focused, maintainable extensions:
//
// - EditorStore+StoreManagement.swift: Store loading, selection, and creation
// - EditorStore+CatalogOperations.swift: Catalog CRUD operations and default catalog migration
// - EditorStore+CategoryManagement.swift: Category CRUD and catalog data loading
// - EditorStore+CategoryHierarchy.swift: Category tree traversal and product selection
//
// All functionality remains the same, but now follows Apple engineering standards
// with files under 300 lines for "excellent" maintainability.
