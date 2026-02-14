import SwiftUI

// MARK: - Cron Description Helper

private func cronDescription(_ cron: String) -> String? {
    let trimmed = cron.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    let parts = trimmed.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 5 else { return nil }

    let (minute, hour, dom, month, dow) = (parts[0], parts[1], parts[2], parts[3], parts[4])

    // Every minute
    if minute == "*" && hour == "*" && dom == "*" && month == "*" && dow == "*" {
        return "Every minute"
    }

    // Every N minutes: */N * * * *
    if minute.hasPrefix("*/"), let n = Int(minute.dropFirst(2)),
       hour == "*" && dom == "*" && month == "*" && dow == "*" {
        return n == 1 ? "Every minute" : "Every \(n) minutes"
    }

    // Every N hours: 0 */N * * *
    if minute == "0", hour.hasPrefix("*/"), let n = Int(hour.dropFirst(2)),
       dom == "*" && month == "*" && dow == "*" {
        return n == 1 ? "Every hour" : "Every \(n) hours"
    }

    // Every hour: 0 * * * *
    if minute == "0" && hour == "*" && dom == "*" && month == "*" && dow == "*" {
        return "Every hour"
    }

    // Specific minute every hour: N * * * *
    if let m = Int(minute), hour == "*" && dom == "*" && month == "*" && dow == "*" {
        return "Every hour at minute \(m)"
    }

    // Daily at specific time: M H * * *
    if let m = Int(minute), let h = Int(hour), dom == "*" && month == "*" && dow == "*" {
        return "Every day at \(formatTime(h, m))"
    }

    // Weekdays: M H * * 1-5
    if let m = Int(minute), let h = Int(hour), dom == "*" && month == "*" && dow == "1-5" {
        return "Weekdays at \(formatTime(h, m))"
    }

    // Weekly on specific day: M H * * D
    if let m = Int(minute), let h = Int(hour), dom == "*" && month == "*" {
        if let dayName = dowName(dow) {
            return "\(dayName) at \(formatTime(h, m))"
        }
    }

    // Monthly: M H D * *
    if let m = Int(minute), let h = Int(hour), let d = Int(dom), month == "*" && dow == "*" {
        return "Monthly on day \(d) at \(formatTime(h, m))"
    }

    return nil
}

private func formatTime(_ hour: Int, _ minute: Int) -> String {
    let period = hour >= 12 ? "PM" : "AM"
    let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    return minute == 0
        ? "\(displayHour):00 \(period)"
        : String(format: "%d:%02d %@", displayHour, minute, period)
}

private func dowName(_ dow: String) -> String? {
    switch dow {
    case "0", "7": return "Every Sunday"
    case "1": return "Every Monday"
    case "2": return "Every Tuesday"
    case "3": return "Every Wednesday"
    case "4": return "Every Thursday"
    case "5": return "Every Friday"
    case "6": return "Every Saturday"
    case "1-5": return "Weekdays"
    case "0,6", "6,0": return "Weekends"
    default: return nil
    }
}

// MARK: - Backoff Strategy

private enum BackoffStrategy: String, CaseIterable, Identifiable {
    case fixed = "fixed"
    case exponential = "exponential"
    case linear = "linear"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: return "Fixed"
        case .exponential: return "Exponential"
        case .linear: return "Linear"
        }
    }

    var description: String {
        switch self {
        case .fixed: return "Same delay between each retry"
        case .exponential: return "Delay doubles after each retry"
        case .linear: return "Delay increases by base amount each retry"
        }
    }
}

// MARK: - Environment Variable Row

private struct EnvVar: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

// MARK: - Workflow Settings Sheet

struct WorkflowSettingsSheet: View {
    let workflow: Workflow
    let storeId: UUID?
    let onSaved: () -> Void
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.workflowService) private var service

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    // Existing fields
    @State private var cronExpression: String
    @State private var maxConcurrentRuns: String
    @State private var maxRunDuration: String
    @State private var errorWebhookUrl: String
    @State private var errorEmail: String
    @State private var circuitBreakerThreshold: String

    // New fields
    @State private var backoffStrategy: BackoffStrategy
    @State private var baseDelay: String
    @State private var maxRetries: String
    @State private var envVars: [EnvVar]

    @State private var isSaving = false

    init(workflow: Workflow, storeId: UUID?, onSaved: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.workflow = workflow
        self.storeId = storeId
        self.onSaved = onSaved
        self.onDismiss = onDismiss
        _cronExpression = State(initialValue: workflow.cronExpression ?? "")
        _maxConcurrentRuns = State(initialValue: workflow.maxConcurrentRuns.map(String.init) ?? "")
        _maxRunDuration = State(initialValue: workflow.maxRunDurationSeconds.map(String.init) ?? "")
        _errorWebhookUrl = State(initialValue: workflow.errorWebhookUrl ?? "")
        _errorEmail = State(initialValue: workflow.errorEmail ?? "")
        _circuitBreakerThreshold = State(initialValue: workflow.circuitBreakerThreshold.map(String.init) ?? "")
        _backoffStrategy = State(initialValue: .fixed)
        _baseDelay = State(initialValue: "")
        _maxRetries = State(initialValue: "")
        _envVars = State(initialValue: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workflow Settings")
                    .font(DS.Typography.headline)
                Spacer()
                Button { close() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    // Schedule
                    scheduleSection

                    // Execution
                    settingsSection("EXECUTION") {
                        settingsField("Max Concurrent Runs", placeholder: "1", text: $maxConcurrentRuns)
                        settingsField("Max Run Duration (seconds)", placeholder: "3600", text: $maxRunDuration)
                    }

                    // Retry Backoff
                    retrySection

                    // Environment Variables
                    envVarsSection

                    // Error Handling
                    settingsSection("ERROR HANDLING") {
                        settingsField("Error Webhook URL", placeholder: "https://...", text: $errorWebhookUrl)
                        settingsField("Error Notification Email", placeholder: "team@example.com", text: $errorEmail)
                    }

                    // Circuit Breaker
                    settingsSection("CIRCUIT BREAKER") {
                        settingsField("Failure Threshold", placeholder: "5", text: $circuitBreakerThreshold)
                        Text("Number of consecutive failures before pausing the workflow.")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textQuaternary)
                    }
                }
                .padding(DS.Spacing.lg)
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { close() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isSaving)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(minWidth: 320, idealWidth: 420, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        settingsSection("SCHEDULE") {
            settingsField("Cron Expression", placeholder: "0 */5 * * *", text: $cronExpression)

            // Human-readable description
            if let desc = cronDescription(cronExpression) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(DesignSystem.font(10, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                    Text(desc)
                        .font(DS.Typography.monoCaption)
                        .foregroundStyle(DS.Colors.accent)
                }
                .padding(.vertical, DS.Spacing.xxs)
            } else if !cronExpression.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "questionmark.diamond")
                        .font(DesignSystem.font(10, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Custom schedule: \(cronExpression)")
                        .font(DS.Typography.monoCaption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.vertical, DS.Spacing.xxs)
            } else {
                Text("Leave empty for no schedule. Uses standard cron syntax.")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
            }

            // Preset buttons
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Presets")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)

                HStack(spacing: DS.Spacing.xs) {
                    cronPreset("Every 5 min", cron: "*/5 * * * *")
                    cronPreset("Hourly", cron: "0 * * * *")
                    cronPreset("Midnight", cron: "0 0 * * *")
                    cronPreset("Mon 9 AM", cron: "0 9 * * 1")
                }
            }
        }
    }

    private func cronPreset(_ label: String, cron: String) -> some View {
        Button {
            cronExpression = cron
        } label: {
            Text(label)
                .font(DS.Typography.buttonSmall)
                .foregroundStyle(cronExpression == cron ? DS.Colors.accent : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(
                    cronExpression == cron
                        ? DS.Colors.accent.opacity(0.12)
                        : DS.Colors.surfaceTertiary,
                    in: RoundedRectangle(cornerRadius: DS.Radius.xs)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Retry Backoff Section

    private var retrySection: some View {
        settingsSection("RETRY STRATEGY") {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Backoff type picker
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Backoff Type")
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Picker("", selection: $backoffStrategy) {
                        ForEach(BackoffStrategy.allCases) { strategy in
                            Text(strategy.label).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(backoffStrategy.description)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)

                // Delay preview
                if let delay = Int(baseDelay), delay > 0 {
                    retryPreview(delay: delay)
                }

                HStack(spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Base Delay (sec)")
                            .font(DS.Typography.caption1)
                            .foregroundStyle(DS.Colors.textSecondary)
                        TextField("5", text: $baseDelay)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.monoCaption)
                            .padding(DS.Spacing.sm)
                            .glassBackground(cornerRadius: DS.Radius.sm)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Max Retries")
                            .font(DS.Typography.caption1)
                            .foregroundStyle(DS.Colors.textSecondary)
                        TextField("3", text: $maxRetries)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.monoCaption)
                            .padding(DS.Spacing.sm)
                            .glassBackground(cornerRadius: DS.Radius.sm)
                    }
                }
            }
        }
    }

    private func retryPreview(delay: Int) -> some View {
        let retryCount = Int(maxRetries) ?? 3
        let attempts = min(retryCount, 5)

        return HStack(spacing: DS.Spacing.xs) {
            ForEach(0..<attempts, id: \.self) { i in
                if i > 0 {
                    Image(systemName: "arrow.right")
                        .font(DesignSystem.font(8, weight: .regular))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                let d = retryDelay(base: delay, attempt: i, strategy: backoffStrategy)
                Text("\(d)s")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DS.Colors.surfaceTertiary, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    private func retryDelay(base: Int, attempt: Int, strategy: BackoffStrategy) -> Int {
        switch strategy {
        case .fixed:
            return base
        case .exponential:
            return base * Int(pow(2.0, Double(attempt)))
        case .linear:
            return base * (attempt + 1)
        }
    }

    // MARK: - Environment Variables Section

    private var envVarsSection: some View {
        settingsSection("ENVIRONMENT VARIABLES") {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Key-value pairs passed to all workflow steps at runtime.")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)

                ForEach($envVars) { $envVar in
                    HStack(spacing: DS.Spacing.sm) {
                        TextField("KEY", text: $envVar.key)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.monoCaption)
                            .textCase(.uppercase)
                            .padding(DS.Spacing.sm)
                            .glassBackground(cornerRadius: DS.Radius.sm)
                            .frame(maxWidth: 160)

                        TextField("value", text: $envVar.value)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.monoCaption)
                            .padding(DS.Spacing.sm)
                            .glassBackground(cornerRadius: DS.Radius.sm)

                        Button {
                            envVars.removeAll { $0.id == envVar.id }
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(DesignSystem.font(9, weight: .regular))
                                .foregroundStyle(DS.Colors.error)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    envVars.append(EnvVar(key: "", value: ""))
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(DesignSystem.font(10, weight: .medium))
                        Text("Add Variable")
                            .font(DS.Typography.buttonSmall)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.surfaceTertiary, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Components

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.monoHeader)
                .foregroundStyle(DS.Colors.textTertiary)
            content()
        }
    }

    private func settingsField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(DS.Typography.monoCaption)
                .padding(DS.Spacing.sm)
                .glassBackground(cornerRadius: DS.Radius.sm)
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        Task {
            var updates: [String: Any] = [:]

            if !cronExpression.isEmpty {
                _ = await service.setSchedule(workflowId: workflow.id, cronExpression: cronExpression, storeId: storeId)
            }

            if let val = Int(maxConcurrentRuns) { updates["max_concurrent_runs"] = val }
            if let val = Int(maxRunDuration) { updates["max_run_duration_seconds"] = val }
            if !errorWebhookUrl.isEmpty { updates["on_error_webhook_url"] = errorWebhookUrl }
            if !errorEmail.isEmpty { updates["on_error_email"] = errorEmail }
            if let val = Int(circuitBreakerThreshold) { updates["circuit_breaker_threshold"] = val }

            // Retry strategy
            updates["retry_backoff"] = backoffStrategy.rawValue
            if let val = Int(baseDelay), val > 0 {
                updates["retry_base_delay_seconds"] = val
            }
            if let val = Int(maxRetries), val > 0 {
                updates["max_retries"] = val
            }

            // Environment variables — only save non-empty pairs
            let filteredVars = envVars.filter { !$0.key.isEmpty }
            if !filteredVars.isEmpty {
                var dict: [String: String] = [:]
                for v in filteredVars {
                    dict[v.key] = v.value
                }
                updates["environment_variables"] = dict
            }

            if !updates.isEmpty {
                _ = await service.updateWorkflow(id: workflow.id, updates: updates, storeId: storeId)
            }

            onSaved()
            close()
        }
    }
}
