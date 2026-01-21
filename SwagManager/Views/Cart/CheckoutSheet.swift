//
//  CheckoutSheet.swift
//  SwagManager (macOS)
//
//  Checkout sheet with liquid glass design - ported from iOS Whale app
//  Properly tracks location/register to prevent lost orders
//

import SwiftUI

struct CheckoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    let cart: ServerCart
    let queueEntry: QueueEntry
    let store: EditorStore
    let sessionInfo: SessionInfo
    let onComplete: () -> Void

    @State private var paymentMethod: PaymentMethod = .cash
    @State private var cashTendered: String = ""
    @State private var invoiceEmail: String = ""
    @State private var invoiceDueDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var completedOrder: SaleCompletion?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Group {
            if showSuccess {
                successView
            } else if isProcessing {
                processingView
            } else {
                checkoutContent
            }
        }
        .alert("Payment Error", isPresented: $showError) {
            Button("OK") {
                isProcessing = false
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Checkout Content

    private var checkoutContent: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Payment method selector
            paymentMethodPicker

            Divider()

            // Payment-specific inputs
            ScrollView {
                VStack(spacing: 20) {
                    switch paymentMethod {
                    case .cash:
                        cashInputSection
                    case .card:
                        cardSection
                    case .invoice:
                        invoiceSection
                    default:
                        EmptyView()
                    }

                    // Order summary
                    orderSummary
                }
                .padding()
            }

            Divider()

            // Process button
            processButton
        }
        .frame(width: 460, height: 560)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Checkout")
                .font(.headline)

            Spacer()

            Button {
                onComplete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Payment Method Picker

    private var paymentMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Method")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Payment Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }

    // MARK: - Cash Input

    private var cashInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cash Tendered")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("$0.00", text: $cashTendered)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            // Suggested amounts
            HStack(spacing: 8) {
                ForEach(suggestedCashAmounts, id: \.self) { amount in
                    Button("$\(Int(amount))") {
                        cashTendered = String(format: "%.2f", amount)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Change due
            if let cashAmount = Decimal(string: cashTendered), cashAmount > 0 {
                let change = cashAmount - cart.totals.total
                if change >= 0 {
                    HStack {
                        Text("Change Due:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatCurrency(change))
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var suggestedCashAmounts: [Double] {
        let total = NSDecimalNumber(decimal: cart.totals.total).doubleValue
        let base = ceil(total / 10) * 10
        return [base, base + 10, base + 20]
    }

    // MARK: - Card Section

    private var cardSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Card payments require terminal integration")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Use cash or invoice for desktop processing")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    // MARK: - Invoice Section

    private var invoiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Customer Email")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField("email@example.com", text: $invoiceEmail)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Due Date")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                DatePicker("Due Date", selection: $invoiceDueDate, displayedComponents: .date)
                    .labelsHidden()
            }

            Text("A payment link will be sent to the customer's email")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Order Summary

    private var orderSummary: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(cart.totals.subtotal))
            }

            if cart.totals.discountAmount > 0 {
                HStack {
                    Text("Discount")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("-\(formatCurrency(cart.totals.discountAmount))")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Text("Tax (\(formatPercent(cart.totals.taxRate)))")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(cart.totals.taxAmount))
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(cart.totals.total))
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Process Button

    private var processButton: some View {
        SlideToPayButton(
            text: actionButtonText,
            icon: actionButtonIcon,
            isEnabled: canProcess,
            onComplete: {
                Task {
                    await processPayment()
                }
            }
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var actionButtonText: String {
        switch paymentMethod {
        case .card: return "Slide to Pay \(formatCurrency(cart.totals.total))"
        case .cash: return "Slide to Complete"
        case .invoice: return "Slide to Send Invoice"
        default: return "Complete Payment"
        }
    }

    private var actionButtonIcon: String {
        switch paymentMethod {
        case .card: return "creditcard"
        case .cash: return "dollarsign.circle"
        case .invoice: return "paperplane"
        default: return "checkmark"
        }
    }

    private var canProcess: Bool {
        switch paymentMethod {
        case .cash:
            guard let amount = Decimal(string: cashTendered) else { return false }
            return amount >= cart.totals.total
        case .card:
            return false // Not supported on desktop yet
        case .invoice:
            return !invoiceEmail.isEmpty && invoiceEmail.contains("@")
        default:
            return false
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Processing \(paymentMethod.rawValue) Payment")
                .font(.headline)

            Text(formatCurrency(cart.totals.total))
                .font(.title)
                .fontWeight(.bold)

            if paymentMethod == .invoice {
                Text("Sending invoice to \(invoiceEmail)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 460, height: 560)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: paymentMethod == .invoice ? "paperplane.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(paymentMethod == .invoice ? "Invoice Sent" : "Payment Successful")
                .font(.title)
                .fontWeight(.bold)

            if let completion = completedOrder {
                Text("Order #\(completion.orderNumber)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(formatCurrency(cart.totals.total))
                .font(.title2)

            if paymentMethod == .invoice {
                Text("Payment link sent to \(invoiceEmail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if paymentMethod == .cash, let amount = Decimal(string: cashTendered) {
                let change = amount - cart.totals.total
                if change > 0 {
                    Text("Change: \(formatCurrency(change))")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            VStack(spacing: 8) {
                Text("Location: \(store.selectedStore?.storeName ?? "Unknown")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let registerId = sessionInfo.registerId {
                    Text("Register: \(registerId.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(width: 460, height: 560)
    }

    // MARK: - Payment Processing

    private func processPayment() async {
        isProcessing = true
        errorMessage = nil

        do {
            switch paymentMethod {
            case .cash:
                guard let cashAmount = Decimal(string: cashTendered) else {
                    errorMessage = "Invalid cash amount"
                    showError = true
                    isProcessing = false
                    return
                }

                guard cashAmount >= cart.totals.total else {
                    errorMessage = "Insufficient cash: need \(formatCurrency(cart.totals.total))"
                    showError = false
                    isProcessing = false
                    return
                }

                NSLog("[Checkout] Processing cash payment - location: \(sessionInfo.locationId), register: \(sessionInfo.registerId?.uuidString ?? "nil")")

                let completion = try await PaymentService.shared.processCashPayment(
                    sessionInfo: sessionInfo,
                    cart: cart,
                    cashTendered: cashAmount,
                    customerName: queueEntry.customerFirstName.map { "\($0) \(queueEntry.customerLastName ?? "")" }
                )

                completedOrder = completion
                isProcessing = false
                showSuccess = true

            case .card:
                errorMessage = "Card payments require terminal integration (not available on desktop)"
                showError = true
                isProcessing = false

            case .invoice:
                guard !invoiceEmail.isEmpty, invoiceEmail.contains("@") else {
                    errorMessage = "Valid email required for invoice"
                    showError = true
                    isProcessing = false
                    return
                }

                let completion = try await PaymentService.shared.processInvoicePayment(
                    sessionInfo: sessionInfo,
                    cart: cart,
                    customerEmail: invoiceEmail,
                    customerName: queueEntry.customerFirstName.map { "\($0) \(queueEntry.customerLastName ?? "")" },
                    dueDate: invoiceDueDate
                )

                completedOrder = completion
                isProcessing = false
                showSuccess = true

            case .split:
                errorMessage = "Split payments not yet supported on desktop"
                showError = true
                isProcessing = false
            }
        } catch {
            NSLog("[Checkout] ❌ Payment failed: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
        }
    }

    // MARK: - Formatters

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    private func formatPercent(_ rate: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: rate)) ?? "0%"
    }
}
