import SwiftUI

// MARK: - Execution History View
// Searchable, filterable list of all tool executions

struct ExecutionHistoryView: View {
    let serverName: String? // Filter by specific server, or nil for all
    @StateObject private var viewModel: ExecutionHistoryViewModel
    @State private var searchText = ""
    @State private var selectedExecution: ExecutionDetail?
    @State private var showDetailSheet = false

    init(serverName: String? = nil) {
        self.serverName = serverName
        _viewModel = StateObject(wrappedValue: ExecutionHistoryViewModel(serverName: serverName))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with filters
            headerSection

            Divider()

            // Execution list
            if viewModel.isLoading {
                ProgressView("Loading executions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.executions.isEmpty {
                emptyState
            } else {
                executionList
            }
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
        .sheet(isPresented: $showDetailSheet) {
            if let execution = selectedExecution {
                ExecutionDetailView(execution: execution)
            }
        }
        .task {
            await viewModel.loadExecutions()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Execution History")
                        .font(.system(size: 20, weight: .semibold))

                    Text("\(viewModel.executions.count) executions")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Refresh") {
                    Task { await viewModel.loadExecutions() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Search and filters
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))

                    TextField("Search by tool name...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 6)
                .background(VisualEffectBackground(material: .sidebar))
                .cornerRadius(6)

                Picker("Status", selection: $viewModel.statusFilter) {
                    Text("All").tag(StatusFilter.all)
                    Text("Success").tag(StatusFilter.success)
                    Text("Failed").tag(StatusFilter.failed)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Picker("Time", selection: $viewModel.timeFilter) {
                    Text("Last Hour").tag(TimeFilter.lastHour)
                    Text("Last 24h").tag(TimeFilter.last24Hours)
                    Text("Last 7d").tag(TimeFilter.last7Days)
                    Text("All Time").tag(TimeFilter.all)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // MARK: - Execution List

    @ViewBuilder
    private var executionList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredExecutions) { execution in
                    ExecutionRow(execution: execution)
                        .onTapGesture {
                            selectedExecution = execution
                            showDetailSheet = true
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Executions Found")
                .font(.system(size: 16, weight: .semibold))

            Text("Tool executions will appear here")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtering

    private var filteredExecutions: [ExecutionDetail] {
        viewModel.executions.filter { execution in
            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                if !execution.toolName.lowercased().contains(searchLower) {
                    return false
                }
            }
            return true
        }
    }
}

// MARK: - Execution Row

struct ExecutionRow: View {
    let execution: ExecutionDetail

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status indicator
            Image(systemName: execution.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(execution.success ? .green : .red)

            // Tool name
            VStack(alignment: .leading, spacing: 2) {
                Text(execution.toolName)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))

                if let error = execution.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            .frame(width: 250, alignment: .leading)

            // Timestamp
            Text(execution.createdAt, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            // Duration
            if let duration = execution.executionTimeMs {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(duration)ms")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(duration < 1000 ? .secondary : Color.orange)
                .frame(width: 80, alignment: .trailing)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(VisualEffectBackground(material: .sidebar))
        .contentShape(Rectangle())
    }
}

// MARK: - View Model

@MainActor
class ExecutionHistoryViewModel: ObservableObject {
    @Published var executions: [ExecutionDetail] = []
    @Published var isLoading = false
    @Published var statusFilter: StatusFilter = .all
    @Published var timeFilter: TimeFilter = .last24Hours

    private let supabase = SupabaseService.shared
    let serverName: String? // Filter by specific server, or nil for all

    init(serverName: String? = nil) {
        self.serverName = serverName
    }

    func loadExecutions() async {
        isLoading = true

        do {
            // Build base query
            var query = supabase.client
                .from("lisa_tool_execution_log")
                .select("id, tool_name, result_status, execution_time_ms, error_message, error_code, request, response, user_id, store_id, created_at")

            // Filter by server name if specified
            if let serverName = serverName {
                query = query.eq("tool_name", value: serverName)
            }

            // Apply time filter
            if timeFilter != .all {
                let startDate = Calendar.current.date(
                    byAdding: .hour,
                    value: -timeFilter.hours,
                    to: Date()
                )!
                query = query.gte("created_at", value: ISO8601DateFormatter().string(from: startDate))
            }

            // Apply status filter
            if statusFilter != .all {
                query = query.eq("result_status", value: statusFilter == .success ? "success" : "error")
            }

            let response = try await query
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .data

            let decoder = JSONDecoder.supabaseDecoder
            executions = try decoder.decode([ExecutionDetail].self, from: response)

            NSLog("[ExecutionHistory] Loaded \(executions.count) executions")
        } catch {
            NSLog("[ExecutionHistory] Error loading: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Filters

enum StatusFilter {
    case all
    case success
    case failed
}

enum TimeFilter {
    case lastHour
    case last24Hours
    case last7Days
    case all

    var hours: Int {
        switch self {
        case .lastHour: return 1
        case .last24Hours: return 24
        case .last7Days: return 24 * 7
        case .all: return 0
        }
    }
}
