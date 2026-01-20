import SwiftUI
import Supabase
import Realtime

// MARK: - EditorStore Realtime Sync Extension
// Extracted from EditorView.swift following Apple engineering standards
// Refactored - split into focused extension files
// File size: ~10 lines (under Apple's 300 line "excellent" threshold)

// This file previously contained 457 lines of realtime subscription and creation management code.
// It has been refactored into focused, maintainable extensions:
//
// - EditorStore+RealtimeSubscriptions.swift: Channel setup and subscription management
// - EditorStore+RealtimeHandlers.swift: Event handlers for all realtime database changes
// - EditorStore+CreationManagement.swift: Creation CRUD operations and selection management
//
// All functionality remains the same, but now follows Apple engineering standards
// with files under 300 lines for "excellent" maintainability.
