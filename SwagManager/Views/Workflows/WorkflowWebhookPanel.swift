import SwiftUI

// MARK: - Workflow Webhook Panel
// Right panel: create, list, delete webhook endpoints

struct WorkflowWebhookPanel: View {
    let workflowId: String
    let storeId: UUID?
    let onDismiss: () -> Void

    @Environment(\.workflowService) private var service

    @State private var webhooks: [WebhookEndpoint] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newSlug = ""
    @State private var isCreating = false
    @State private var copiedId: String?
    @State private var testStatus: [String: TestResult] = [:]

    enum TestResult {
        case loading
        case success(Int)
        case error(String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Inline controls
            HStack(spacing: DS.Spacing.sm) {
                Text("\(webhooks.count) endpoints")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)

                Spacer()

                Button { showCreate.toggle() } label: {
                    Image(systemName: "plus")
                        .font(DesignSystem.font(10, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(9, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            // Create form
            if showCreate {
                VStack(spacing: DS.Spacing.sm) {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.monoCaption)
                        .padding(DS.Spacing.sm)
                        .glassBackground(cornerRadius: DS.Radius.sm)

                    TextField("Slug (URL path)", text: $newSlug)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.monoCaption)
                        .padding(DS.Spacing.sm)
                        .glassBackground(cornerRadius: DS.Radius.sm)

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            showCreate = false
                            newName = ""
                            newSlug = ""
                        }
                        .font(DS.Typography.buttonSmall)

                        Button("Create") { createWebhook() }
                            .font(DS.Typography.buttonSmall)
                            .disabled(newName.isEmpty || newSlug.isEmpty || isCreating)
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surfaceElevated.opacity(0.5))

                Divider().opacity(0.3)
            }

            // List
            if isLoading {
                Spacer()
                ProgressView().scaleEffect(0.7)
                Spacer()
            } else if webhooks.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Webhooks", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Create a webhook endpoint to trigger this workflow via HTTP.")
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xs) {
                        ForEach(webhooks) { webhook in
                            webhookRow(webhook)
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
        }
        .background(DS.Colors.surfaceTertiary)
        .task {
            webhooks = await service.listWebhooks(workflowId: workflowId, storeId: storeId)
            isLoading = false
        }
    }

    private func webhookRow(_ webhook: WebhookEndpoint) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Circle()
                    .fill(webhook.isActive ? DS.Colors.success : DS.Colors.textQuaternary)
                    .frame(width: 6, height: 6)

                Text(webhook.name)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                // Test webhook
                Button {
                    testWebhook(webhook)
                } label: {
                    Group {
                        switch testStatus[webhook.id] {
                        case .loading:
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 12, height: 12)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(DesignSystem.font(9))
                                .foregroundStyle(DS.Colors.success)
                        case .error:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(DesignSystem.font(9))
                                .foregroundStyle(DS.Colors.error)
                        case .none:
                            Image(systemName: "bolt.horizontal.fill")
                                .font(DesignSystem.font(9))
                                .foregroundStyle(DS.Colors.cyan)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(testHelpText(for: webhook.id))
                .disabled(webhook.url == nil || (testStatus[webhook.id]?.isLoading ?? false))

                // Copy URL
                Button {
                    if let url = webhook.url {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                        copiedId = webhook.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedId = nil }
                    }
                } label: {
                    Image(systemName: copiedId == webhook.id ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(DesignSystem.font(9))
                        .foregroundStyle(copiedId == webhook.id ? DS.Colors.success : DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                // Delete
                Button {
                    Task {
                        if await service.deleteWebhook(webhookId: webhook.id, storeId: storeId) {
                            webhooks.removeAll { $0.id == webhook.id }
                        }
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(DesignSystem.font(9))
                        .foregroundStyle(DS.Colors.error)
                }
                .buttonStyle(.plain)
            }

            // URL
            if let url = webhook.url {
                Text(url)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Text("slug: /\(webhook.slug)")
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textQuaternary)

            // Test result feedback
            if let status = testStatus[webhook.id] {
                HStack(spacing: DS.Spacing.xxs) {
                    switch status {
                    case .loading:
                        ProgressView().scaleEffect(0.4)
                            .frame(width: 10, height: 10)
                        Text("Sending test...")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                    case .success(let code):
                        Image(systemName: "checkmark.diamond.fill")
                            .font(DesignSystem.font(8))
                            .foregroundStyle(DS.Colors.success)
                        Text("Test OK (\(code))")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.success)
                    case .error(let msg):
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(DesignSystem.font(8))
                            .foregroundStyle(DS.Colors.error)
                        Text(msg)
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.error)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(DS.Spacing.sm)
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }

    private func testWebhook(_ webhook: WebhookEndpoint) {
        guard let urlString = webhook.url, let url = URL(string: urlString) else { return }
        testStatus[webhook.id] = .loading

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let payload: [String: Any] = [
                    "test": true,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                request.timeoutInterval = 10

                let (_, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                if (200...299).contains(statusCode) {
                    testStatus[webhook.id] = .success(statusCode)
                } else {
                    testStatus[webhook.id] = .error("HTTP \(statusCode)")
                }
            } catch {
                testStatus[webhook.id] = .error(error.localizedDescription)
            }

            // Auto-clear after 4 seconds
            try? await Task.sleep(for: .seconds(4))
            testStatus.removeValue(forKey: webhook.id)
        }
    }

    private func testHelpText(for webhookId: String) -> String {
        switch testStatus[webhookId] {
        case .success(let code): return "Test passed (HTTP \(code))"
        case .error(let msg): return "Test failed: \(msg)"
        case .loading: return "Testing..."
        case .none: return "Send test payload"
        }
    }

    private func createWebhook() {
        isCreating = true
        Task {
            if let wh = await service.createWebhook(workflowId: workflowId, name: newName, slug: newSlug, storeId: storeId) {
                webhooks.insert(wh, at: 0)
                showCreate = false
                newName = ""
                newSlug = ""
            }
            isCreating = false
        }
    }
}
