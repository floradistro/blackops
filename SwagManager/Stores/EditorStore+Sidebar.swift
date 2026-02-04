import SwiftUI

// MARK: - EditorStore Extension: Sidebar Management
// Methods for managing sidebar sections, groups, and smart auto-collapse

extension EditorStore {
    // MARK: - Collapse All Sections

    /// Collapses all sidebar sections and groups
    func collapseAllSections() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Collapse all section groups
            workspaceGroupCollapsed = true
            contentGroupCollapsed = true
            operationsGroupCollapsed = true
            infrastructureGroupCollapsed = true

            // Collapse all individual sections
            sidebarCatalogExpanded = false
            sidebarCreationsExpanded = false
            sidebarChatExpanded = false
            sidebarCRMExpanded = false
            sidebarLocationsExpanded = false
            sidebarQueuesExpanded = false
            sidebarBrowserExpanded = false
            sidebarEmailsExpanded = false
            sidebarOrdersExpanded = false
            sidebarCustomersExpanded = false

            // Collapse campaign subsections
            sidebarEmailCampaignsExpanded = false
            sidebarMetaCampaignsExpanded = false
            sidebarSMSCampaignsExpanded = false
        }
    }

    // MARK: - Smart Auto-Collapse

    /// Tracks number of expanded sections
    var expandedSectionsCount: Int {
        var count = 0
        if sidebarCatalogExpanded { count += 1 }
        if sidebarCreationsExpanded { count += 1 }
        if sidebarChatExpanded { count += 1 }
        if sidebarCRMExpanded { count += 1 }
        if sidebarLocationsExpanded { count += 1 }
        if sidebarQueuesExpanded { count += 1 }
        if sidebarBrowserExpanded { count += 1 }
        if sidebarEmailsExpanded { count += 1 }
        return count
    }

    /// Auto-collapses less important sections when too many are expanded
    /// Strategy: Keep Workspace and newest expanded section, collapse others
    func autoCollapseIfNeeded(justExpanded: SidebarSection? = nil) {
        guard expandedSectionsCount > 2 else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            // Never auto-collapse Workspace sections (Queues, Locations)
            let workspaceSections: [SidebarSection] = [.queues, .locations]

            // Collapse sections except workspace and the one just expanded
            if justExpanded != .catalogs && !workspaceSections.contains(.catalogs) {
                sidebarCatalogExpanded = false
            }
            if justExpanded != .creations && !workspaceSections.contains(.creations) {
                sidebarCreationsExpanded = false
            }
            if justExpanded != .communications && !workspaceSections.contains(.communications) {
                sidebarChatExpanded = false
            }
            if justExpanded != .crm && !workspaceSections.contains(.crm) {
                sidebarCRMExpanded = false
            }
            if justExpanded != .browser && !workspaceSections.contains(.browser) {
                sidebarBrowserExpanded = false
            }
            if justExpanded != .emails && !workspaceSections.contains(.emails) {
                sidebarEmailsExpanded = false
            }
        }
    }

    // MARK: - Expand with Smart Collapse

    /// Expands a section and triggers auto-collapse if needed
    func expandSection(_ section: SidebarSection) {
        switch section {
        case .catalogs:
            sidebarCatalogExpanded = true
        case .creations:
            sidebarCreationsExpanded = true
        case .communications:
            sidebarChatExpanded = true
        case .crm:
            sidebarCRMExpanded = true
        case .locations:
            sidebarLocationsExpanded = true
        case .queues:
            sidebarQueuesExpanded = true
        case .browser:
            sidebarBrowserExpanded = true
        case .emails:
            sidebarEmailsExpanded = true
        case .orders:
            sidebarOrdersExpanded = true
        case .customers:
            sidebarCustomersExpanded = true
        }

        autoCollapseIfNeeded(justExpanded: section)
    }
}

// MARK: - Sidebar Section Enum

enum SidebarSection {
    case catalogs
    case creations
    case communications
    case crm
    case locations
    case queues
    case browser
    case emails
    case orders
    case customers
}
