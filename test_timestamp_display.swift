// Test timestamp parsing - paste this in Xcode playground to debug

import Foundation

// Simulate what the RPC returns
let timestampString = "2026-01-22T17:34:29.551-05:00"

// Try parsing with ISO8601DateFormatter
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

if let date = formatter.date(from: timestampString) {
    print("✅ Parsed date: \(date)")

    // Display with DateFormatter (what iOS uses)
    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium
    displayFormatter.timeStyle = .short
    print("📅 Formatted: \(displayFormatter.string(from: date))")

    // Check timezone
    print("🌍 Timezone: \(TimeZone.current.identifier)")
    print("🕐 Current time: \(Date())")
} else {
    print("❌ Failed to parse")
}
