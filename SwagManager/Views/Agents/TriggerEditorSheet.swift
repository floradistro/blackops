import SwiftUI

// MARK: - Trigger Editor Sheet

struct TriggerEditorSheet: View {
    @Environment(\.editorStore) private var store
    let trigger: UserTrigger?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedToolId: UUID?
    @State private var triggerType: UserTrigger.TriggerType = .event
    @State private var eventTable = ""
    @State private var eventOperation: UserTrigger.EventOperation = .INSERT
    @State private var cronExpression = ""
    @State private var conditionSql = ""
    @State private var maxRetries = 3
    @State private var retryDelaySeconds = 60
    @State private var cooldownSeconds: Int? = nil
    @State private var maxExecutionsPerHour: Int? = nil
    @State private var isActive = true
    @State private var isSaving = false

    private let availableTables = [
        ("orders", "Customer orders"),
        ("order_items", "Line items in orders"),
        ("customers", "Customer profiles"),
        ("customer_loyalty", "Loyalty points & tiers"),
        ("inventory", "Stock levels by location"),
        ("locations", "Store locations"),
        ("carts", "Active shopping carts"),
        ("cart_items", "Items in carts")
    ]

    private var isValid: Bool {
        !name.isEmpty && selectedToolId != nil && (triggerType != .event || !eventTable.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - Anthropic style
            HStack {
                Text(trigger == nil ? "NEW" : "EDIT")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("Trigger")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                Spacer()
                Button("Close") { dismiss() }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BASIC INFO")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Trigger name", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(.body, weight: .medium))
                                .padding(8)
                                .background(Color.primary.opacity(0.03))

                            TextField("Description (optional)", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(.caption))
                                .lineLimit(2...4)
                                .padding(8)
                                .background(Color.primary.opacity(0.03))
                        }
                    }

                    Divider()

                    // Tool Selection Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TOOL")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        if store.userTools.isEmpty {
                            Text("Create a tool first")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        } else {
                            Picker("Tool", selection: $selectedToolId) {
                                Text("select...").tag(nil as UUID?)
                                ForEach(store.userTools) { tool in
                                    Text(tool.displayName.isEmpty ? tool.name : tool.displayName)
                                        .tag(tool.id as UUID?)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    Divider()

                    // Trigger Type Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TYPE")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        // Trigger type buttons - minimal
                        HStack(spacing: 6) {
                            ForEach(UserTrigger.TriggerType.allCases, id: \.self) { type in
                                Button {
                                    triggerType = type
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: type.icon)
                                            .font(.caption)
                                            .foregroundStyle(triggerType == type ? .primary : .secondary)
                                        Text(type.displayName.uppercased())
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(triggerType == type ? .primary : .tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(triggerType == type ? Color.primary.opacity(0.08) : Color.primary.opacity(0.02))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Trigger-specific configuration
                        if triggerType == .event {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("table")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    Picker("Table", selection: $eventTable) {
                                        Text("select...").tag("")
                                        ForEach(availableTables, id: \.0) { table in
                                            Text(table.0).tag(table.0)
                                        }
                                    }
                                    .labelsHidden()
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("operation")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    HStack(spacing: 4) {
                                        ForEach(UserTrigger.EventOperation.allCases, id: \.self) { op in
                                            Button {
                                                eventOperation = op
                                            } label: {
                                                Text(op.displayName.uppercased())
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(eventOperation == op ? .primary : .tertiary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 6)
                                                    .background(eventOperation == op ? Color.primary.opacity(0.08) : Color.primary.opacity(0.02))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                Text("Fires on row changes. Tool receives row data.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        } else if triggerType == .schedule {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("cron expression")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    TextField("0 9 * * *", text: $cronExpression)
                                        .textFieldStyle(.plain)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(8)
                                        .background(Color.primary.opacity(0.03))
                                }

                                Text("Example: '0 9 * * *' = daily at 9am")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        } else if triggerType == .condition {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("condition sql")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    TextField("SELECT COUNT(*) > 10 FROM ...", text: $conditionSql, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .lineLimit(3...6)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .background(Color.primary.opacity(0.03))
                                }

                                Text("Fires when SQL returns true. Checked periodically.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        }
                    }

                    Divider()

                    // Retry Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RETRY")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("max retries")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Stepper("\(maxRetries)", value: $maxRetries, in: 0...10)
                                    .frame(width: 90)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("delay (s)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Stepper("\(retryDelaySeconds)", value: $retryDelaySeconds, in: 10...3600, step: 10)
                                    .frame(width: 90)
                            }
                        }

                        Text("Exponential backoff applied")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    Divider()

                    // Status Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("STATUS")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Toggle("", isOn: $isActive)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }

                        Text(isActive ? "Active - will fire on events" : "Inactive - configuration preserved")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if isSaving {
                    Text("saving...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button(trigger == nil ? "Create" : "Save") {
                    Task { await saveTrigger() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isValid || isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 600)
        .onAppear { loadTrigger() }
    }

    private func loadTrigger() {
        guard let trigger = trigger else { return }
        name = trigger.name
        description = trigger.description ?? ""
        selectedToolId = trigger.toolId
        triggerType = trigger.triggerType
        eventTable = trigger.eventTable ?? ""
        eventOperation = trigger.eventOperation ?? .INSERT
        cronExpression = trigger.cronExpression ?? ""
        conditionSql = trigger.conditionSql ?? ""
        maxRetries = trigger.maxRetries
        retryDelaySeconds = trigger.retryDelaySeconds
        cooldownSeconds = trigger.cooldownSeconds
        maxExecutionsPerHour = trigger.maxExecutionsPerHour
        isActive = trigger.isActive
    }

    private func saveTrigger() async {
        guard let storeId = store.selectedStore?.id,
              let toolId = selectedToolId else { return }
        isSaving = true

        var newTrigger = trigger ?? UserTrigger(storeId: storeId, toolId: toolId)
        newTrigger.name = name
        newTrigger.description = description.isEmpty ? nil : description
        newTrigger.toolId = toolId
        newTrigger.triggerType = triggerType
        newTrigger.eventTable = triggerType == .event ? eventTable : nil
        newTrigger.eventOperation = triggerType == .event ? eventOperation : nil
        newTrigger.cronExpression = triggerType == .schedule ? cronExpression : nil
        newTrigger.conditionSql = triggerType == .condition ? conditionSql : nil
        newTrigger.maxRetries = maxRetries
        newTrigger.retryDelaySeconds = retryDelaySeconds
        newTrigger.cooldownSeconds = cooldownSeconds
        newTrigger.maxExecutionsPerHour = maxExecutionsPerHour
        newTrigger.isActive = isActive

        if trigger == nil {
            _ = await store.createUserTrigger(newTrigger)
        } else {
            _ = await store.updateUserTrigger(newTrigger)
        }

        isSaving = false
        dismiss()
    }
}
