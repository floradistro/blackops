import SwiftUI

@main
struct TestTextFieldApp: App {
    var body: some Scene {
        WindowGroup {
            TestTextFieldView()
        }
    }
}

struct TestTextFieldView: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Simple TextField Test")
                .font(.title)

            TextField("Type here", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            Text("You typed: \(text)")
                .font(.caption)

            Button("Clear") {
                text = ""
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
