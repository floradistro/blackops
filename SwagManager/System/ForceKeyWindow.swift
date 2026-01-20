import AppKit

class ForceKeyWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeKey() {
        print("✅ ForceKeyWindow became key window")
        super.becomeKey()
    }

    override func resignKey() {
        print("⚠️ ForceKeyWindow resigned key")
        super.resignKey()
    }
}
