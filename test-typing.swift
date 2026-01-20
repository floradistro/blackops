#!/usr/bin/swift

import SwiftUI
import AppKit

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            TestView()
                .frame(width: 400, height: 300)
        }
    }
}

struct TestView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Test Login")
                .font(.title)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            Button("Login") {
                print("Email: \(email), Password: \(password)")
            }
            .buttonStyle(.borderedProminent)

            Text("Email: \(email)")
                .font(.caption)
            Text("Password: \(password.isEmpty ? "empty" : "has \(password.count) chars")")
                .font(.caption)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
