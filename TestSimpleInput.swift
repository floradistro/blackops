import SwiftUI
import AppKit

@main
struct TestSimpleInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Test Input"
        window.center()

        let contentView = NSHostingView(rootView: TestView())
        window.contentView = contentView

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}

struct TestView: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Type something:")
                .font(.title)

            TextField("Type here", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            Text("You typed: \(text)")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
