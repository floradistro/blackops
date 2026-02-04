//
//  POSSettingsView.swift
//  SwagManager (macOS)
//
//  POS settings panel for register/printer configuration.
//  Appears as a popover from the toolbar settings button.
//

import SwiftUI
import AppKit

struct POSSettingsView: View {
    var store: EditorStore
    let locationId: UUID

    @State private var isAutoPrintEnabled = false
    @State private var printerName: String? = nil
    @State private var startPosition = 0
    @State private var selectedRegisterId: UUID? = nil

    @State private var registers: [Register] = []
    @State private var isLoadingRegisters = false
    @State private var showPrinterPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("POS Settings")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Register Section
                    registerSection

                    Divider()

                    // Printer Section
                    printerSection

                    Divider()

                    // Label Position Section
                    labelPositionSection
                }
                .padding()
            }
        }
        .frame(width: 340, height: 500)
        .onAppear {
            // Load current settings
            let settings = LabelPrinterSettings.shared
            isAutoPrintEnabled = settings.isAutoPrintEnabled
            printerName = settings.printerName
            startPosition = settings.startPosition
            selectedRegisterId = settings.selectedRegisterId

            // Load registers
            Task {
                await loadRegisters()
            }
        }
    }

    // MARK: - Register Section

    private var registerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Register", systemImage: "desktopcomputer")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                if isLoadingRegisters {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading registers...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } else if registers.isEmpty {
                    Text("No registers found for this location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(registers) { register in
                        RegisterRow(
                            register: register,
                            isSelected: selectedRegisterId == register.id,
                            onSelect: {
                                selectedRegisterId = register.id
                                LabelPrinterSettings.shared.selectRegister(register)
                            }
                        )
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    // MARK: - Printer Section

    private var printerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Label Printer", systemImage: "printer.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // Printer selection button
                Button {
                    showPrinterPicker = true
                } label: {
                    HStack {
                        Image(systemName: printerName != nil ? "printer.fill" : "printer")
                            .foregroundColor(printerName != nil ? .accentColor : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Printer")
                                .font(.system(size: 13, weight: .medium))
                            if let name = printerName {
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)

                // Auto-print toggle
                HStack {
                    Image(systemName: isAutoPrintEnabled ? "bolt.fill" : "bolt")
                        .foregroundColor(isAutoPrintEnabled ? .yellow : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Print Labels")
                            .font(.system(size: 13, weight: .medium))
                        Text("Print after each sale")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isAutoPrintEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: isAutoPrintEnabled) { _, newValue in
                            LabelPrinterSettings.shared.isAutoPrintEnabled = newValue
                        }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                )

                // Status indicator
                if printerName != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Printer Ready")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
        }
        .popover(isPresented: $showPrinterPicker) {
            PrinterPickerView(onSelect: { name in
                printerName = name
                LabelPrinterSettings.shared.printerName = name
                showPrinterPicker = false
            })
        }
    }

    // MARK: - Label Position Section

    private var labelPositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Label Start Position", systemImage: "rectangle.grid.2x2")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                HStack {
                    Text("Position \(startPosition + 1)")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("Avery 5163 - 2x4\" - 10 per sheet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 5 rows x 2 cols grid
                HStack(spacing: 16) {
                    // Sheet preview
                    VStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { col in
                                    let position = row * 2 + col
                                    let isSelected = startPosition == position

                                    Button {
                                        startPosition = position
                                        LabelPrinterSettings.shared.startPosition = position
                                    } label: {
                                        Text("\(position + 1)")
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .frame(width: 28, height: 18)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Position")
                            .font(.caption.weight(.medium))
                        Text("Labels print starting from this position on the sheet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    // MARK: - Helpers

    private func loadRegisters() async {
        isLoadingRegisters = true

        do {
            // Only select the columns we need to avoid decode errors from extra DB columns
            let response: [Register] = try await SupabaseService.shared.client
                .from("pos_registers")
                .select("id, location_id, store_id, register_number, register_name, status, device_id, device_name, device_type, allow_cash, allow_card, allow_refunds, allow_voids, require_manager_approval, hardware_model, created_at, updated_at")
                .eq("location_id", value: locationId.uuidString.lowercased())
                .eq("status", value: "active")
                .order("register_name")
                .execute()
                .value

            registers = response
            isLoadingRegisters = false
        } catch {
            isLoadingRegisters = false
        }
    }
}

// MARK: - Register Row

struct RegisterRow: View {
    let register: Register
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(register.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text("Register #\(register.registerNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Printer Picker View

struct PrinterPickerView: View {
    let onSelect: (String) -> Void

    @State private var printers: [String] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Select Printer")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading printers...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if printers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "printer.dotmatrix")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No printers found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Make sure a printer is connected and available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(printers, id: \.self) { printer in
                    Button {
                        onSelect(printer)
                    } label: {
                        HStack {
                            Image(systemName: "printer.fill")
                                .foregroundColor(.accentColor)
                            Text(printer)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 280, height: 300)
        .task {
            loadPrinters()
        }
    }

    private func loadPrinters() {
        isLoading = true
        printers = NSPrinter.printerNames
        isLoading = false
    }
}
