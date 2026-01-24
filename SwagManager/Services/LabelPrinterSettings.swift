//
//  LabelPrinterSettings.swift
//  SwagManager (macOS)
//
//  Label printer settings - stores register/printer preferences.
//

import Foundation

// MARK: - Label Printer Settings

final class LabelPrinterSettings {
    static let shared = LabelPrinterSettings()

    var isAutoPrintEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "labelAutoPrintEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "labelAutoPrintEnabled") }
    }

    var printerName: String? {
        get { UserDefaults.standard.string(forKey: "labelPrinterName") }
        set { UserDefaults.standard.set(newValue, forKey: "labelPrinterName") }
    }

    var startPosition: Int {
        get { UserDefaults.standard.integer(forKey: "labelStartPosition") }
        set { UserDefaults.standard.set(newValue, forKey: "labelStartPosition") }
    }

    var selectedRegisterId: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: "posSelectedRegisterId") else { return nil }
            return UUID(uuidString: str)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: "posSelectedRegisterId")
            } else {
                UserDefaults.standard.removeObject(forKey: "posSelectedRegisterId")
            }
        }
    }

    var selectedRegisterName: String? {
        get { UserDefaults.standard.string(forKey: "posSelectedRegisterName") }
        set { UserDefaults.standard.set(newValue, forKey: "posSelectedRegisterName") }
    }

    var isPrinterConfigured: Bool {
        printerName != nil
    }

    var isReadyToAutoPrint: Bool {
        isAutoPrintEnabled && printerName != nil
    }

    private init() {}

    func selectRegister(_ register: Register) {
        selectedRegisterId = register.id
        selectedRegisterName = register.displayName
    }

    func clearRegister() {
        selectedRegisterId = nil
        selectedRegisterName = nil
    }
}
