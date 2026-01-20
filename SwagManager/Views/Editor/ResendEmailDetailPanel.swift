import SwiftUI
import WebKit

// MARK: - Resend Email Detail Panel
// Following Apple engineering standards

struct ResendEmailDetailPanel: View {
    let email: ResendEmail
    @ObservedObject var store: EditorStore

    @State private var selectedTab: EmailTab = .details

    enum EmailTab: String, CaseIterable {
        case details = "Details"
        case raw = "Raw"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar

            // Content based on selected tab
            TabView(selection: $selectedTab) {
                detailsTab.tag(EmailTab.details)
                rawTab.tag(EmailTab.raw)
            }
            .tabViewStyle(.automatic)
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(EmailTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Refresh button
            Button(action: {
                Task {
                    await store.loadEmails()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Details Tab

    @ViewBuilder
    private var detailsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                headerSection

                Divider()

                // Status & Basic Info
                statusSection

                Divider()

                // Recipients
                recipientsSection

                Divider()

                // Metadata
                if email.metadata != nil {
                    metadataSection
                    Divider()
                }

                // Linked Order
                if let orderId = email.orderId {
                    linkedOrderSection(orderId)
                    Divider()
                }

                // Error (if any)
                if let error = email.errorMessage {
                    errorSection(error)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    // MARK: - Raw Tab

    @ViewBuilder
    private var rawTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Email Object")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let jsonData = try? JSONEncoder().encode(email),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    Text(jsonString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(DesignSystem.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(email.displaySubject)
                        .font(.system(size: 20, weight: .semibold))

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        StatusBadge(text: email.statusLabel, color: email.statusColor)

                        if email.hasError {
                            StatusBadge(text: "Error", color: .red)
                        }

                        if email.orderId != nil {
                            StatusBadge(text: "Order", color: .orange)
                        }
                    }
                }
            }

            if let resendId = email.resendEmailId {
                Text("ID: \(resendId)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Status")

            EmailInfoRow(label: "Status", value: email.statusLabel, color: email.statusColor)
            EmailInfoRow(label: "Type", value: email.emailType.capitalized)

            if let createdAt = email.createdAt {
                EmailInfoRow(label: "Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let sentAt = email.sentAt {
                EmailInfoRow(label: "Sent", value: sentAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let resendId = email.resendEmailId {
                EmailInfoRow(label: "Resend ID", value: resendId)
            }
        }
    }

    // MARK: - Recipients Section

    @ViewBuilder
    private var recipientsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Recipients")

            EmailInfoRow(label: "From", value: "\(email.fromName) <\(email.fromEmail)>")
            EmailInfoRow(label: "To", value: email.displayTo)

            if let replyTo = email.replyTo {
                EmailInfoRow(label: "Reply-To", value: replyTo)
            }
        }
    }

    // MARK: - Metadata Section

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Metadata")

            if let metadata = email.metadata {
                Text(String(describing: metadata))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Linked Order Section

    @ViewBuilder
    private func linkedOrderSection(_ orderId: UUID) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Linked Order")

            Button(action: {
                // Find and open order
                if let order = store.orders.first(where: { $0.id == orderId }) {
                    store.openOrder(order)
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)

                    Text("Open Order")
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)

                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)

                Text("Error")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
            }

            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
    }
}

// MARK: - Email Info Row

struct EmailInfoRow: View {
    let label: String
    let value: String
    var color: Color? = nil

    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(color ?? .primary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - HTML Preview

struct HTMLPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Prevent navigation - just display HTML
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
