//
//  LabelPrinterSettings.swift
//  SwagManager (macOS)
//
//  Label printer settings - ported from iOS Whale app.
//  Manages printer selection, auto-print preferences, and label position.
//

import Foundation
import AppKit
import Combine

// MARK: - Label Printer Settings

@MainActor
final class LabelPrinterSettings: ObservableObject {
    static let shared = LabelPrinterSettings()

    @Published var isAutoPrintEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isAutoPrintEnabled, forKey: "labelAutoPrintEnabled") }
    }

    @Published var printerName: String? = nil {
        didSet { UserDefaults.standard.set(printerName, forKey: "labelPrinterName") }
    }

    @Published var startPosition: Int = 0 {
        didSet { UserDefaults.standard.set(startPosition, forKey: "labelStartPosition") }
    }

    // Selected register for this POS session
    @Published var selectedRegisterId: UUID? = nil {
        didSet {
            if let id = selectedRegisterId {
                UserDefaults.standard.set(id.uuidString, forKey: "posSelectedRegisterId")
            } else {
                UserDefaults.standard.removeObject(forKey: "posSelectedRegisterId")
            }
        }
    }

    @Published var selectedRegisterName: String? = nil {
        didSet { UserDefaults.standard.set(selectedRegisterName, forKey: "posSelectedRegisterName") }
    }

    var isReadyToAutoPrint: Bool {
        isAutoPrintEnabled && printerName != nil
    }

    var isPrinterConfigured: Bool {
        printerName != nil
    }

    var autoPrintEnabled: Bool {
        isAutoPrintEnabled
    }

    private init() {
        // Load from UserDefaults
        self.isAutoPrintEnabled = UserDefaults.standard.bool(forKey: "labelAutoPrintEnabled")
        self.printerName = UserDefaults.standard.string(forKey: "labelPrinterName")
        self.startPosition = UserDefaults.standard.integer(forKey: "labelStartPosition")

        if let registerIdString = UserDefaults.standard.string(forKey: "posSelectedRegisterId") {
            self.selectedRegisterId = UUID(uuidString: registerIdString)
        }
        self.selectedRegisterName = UserDefaults.standard.string(forKey: "posSelectedRegisterName")
    }

    func selectRegister(_ register: Register) {
        selectedRegisterId = register.id
        selectedRegisterName = register.displayName
    }

    func clearRegister() {
        selectedRegisterId = nil
        selectedRegisterName = nil
    }
}
