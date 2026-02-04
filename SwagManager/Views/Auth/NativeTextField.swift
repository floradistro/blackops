import SwiftUI
import AppKit

struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.backgroundColor = NSColor.controlBackgroundColor
        textField.textColor = NSColor.labelColor
        textField.font = NSFont.systemFont(ofSize: 13)

        // Force enable input
        textField.isEnabled = true
        textField.isEditable = true
        textField.isSelectable = true

        // Try to become first responder after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
            }
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeTextField

        init(_ parent: NativeTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit()
        }
    }
}

struct NativeSecureField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void

    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = NSSecureTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.backgroundColor = NSColor.controlBackgroundColor
        textField.textColor = NSColor.labelColor
        textField.font = NSFont.systemFont(ofSize: 13)

        // Force enable input
        textField.isEnabled = true
        textField.isEditable = true
        textField.isSelectable = true

        return textField
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeSecureField

        init(_ parent: NativeSecureField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSSecureTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit()
        }
    }
}
