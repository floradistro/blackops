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

    // Workflow state (populated by WorkflowCanvas, consumed by WorkflowMenuCommands)
    var activeWorkflowName: String?
    var workflowRunAction: (() -> Void)?
    var workflowPublishAction: (() -> Void)?
    var workflowFitViewAction: (() -> Void)?
    var workflowSettingsAction: (() -> Void)?
    var workflowVersionsAction: (() -> Void)?
    var workflowWebhooksAction: (() -> Void)?
    var workflowDLQAction: (() -> Void)?
    var workflowMetricsAction: (() -> Void)?
    var workflowRunHistoryAction: (() -> Void)?
    var workflowExportAction: (() -> Void)?
    var workflowAddStepAction: ((String) -> Void)?

    func reset() {
        // Keep selectedAgentId and showConfig — persistent UI state
        agentHasChanges = false
        agentIsSaving = false
        saveAction = nil
        discardAction = nil
        telemetryRefreshAction = nil
        telemetryIsLive = false
        resetWorkflow()
    }

    func resetWorkflow() {
        activeWorkflowName = nil
        workflowRunAction = nil
        workflowPublishAction = nil
        workflowFitViewAction = nil
        workflowSettingsAction = nil
        workflowVersionsAction = nil
        workflowWebhooksAction = nil
        workflowDLQAction = nil
        workflowMetricsAction = nil
        workflowRunHistoryAction = nil
        workflowExportAction = nil
        workflowAddStepAction = nil
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
