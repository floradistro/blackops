import SwiftUI

// MARK: - Toolbar State
// Shared observable for cross-view toolbar communication
// Child views write state, AppleContentView reads it for toolbar items

@MainActor
@Observable
class ToolbarState {
    // Agent selection & config visibility
    var selectedAgentId: UUID?
    var showConfig: Bool = false

    // Agent config state
    var agentHasChanges: Bool = false
    var agentIsSaving: Bool = false
    var saveAction: (() async -> Void)?
    var discardAction: (() -> Void)?

    // Telemetry state
    var telemetryTimeRange: TelemetryService.TimeRange = .lastHour
    var telemetryRefreshAction: (() async -> Void)?
    var telemetryIsLive: Bool = false
    var telemetryStoreId: UUID?

    func reset() {
        // Keep selectedAgentId and showConfig — persistent UI state
        agentHasChanges = false
        agentIsSaving = false
        saveAction = nil
        discardAction = nil
        telemetryRefreshAction = nil
        telemetryIsLive = false
    }
}

// MARK: - Environment Support

private struct ToolbarStateKey: EnvironmentKey {
    static var defaultValue: ToolbarState {
        MainActor.assumeIsolated {
            _sharedDefault
        }
    }
    @MainActor private static let _sharedDefault = ToolbarState()
}

extension EnvironmentValues {
    var toolbarState: ToolbarState {
        get { self[ToolbarStateKey.self] }
        set { self[ToolbarStateKey.self] = newValue }
    }
}
