import Foundation

// MARK: - Centralized Formatters (Performance Optimized)

/// Shared formatters for dates, times, currency, and other common formats
/// Formatters are expensive to create, so we create them once and reuse
enum Formatters {

    // MARK: - Date & Time Formatters

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let calendar = Calendar.current

    // MARK: - Currency Formatters

    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    static let currencyNoDecimals: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    // MARK: - Number Formatters

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    // MARK: - Convenience Methods

    static func formatTime(_ date: Date) -> String {
        time.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        self.date.string(from: date)
    }

    static func formatDateTime(_ date: Date) -> String {
        dateTime.string(from: date)
    }

    static func formatRelative(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Smart date header formatting (Today, Yesterday, weekday, or date)
    static func formatDateHeader(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return weekdayFormatter.string(from: date)
        } else {
            return formatDate(date)
        }
    }

    /// Format currency from Double
    static func formatCurrency(_ amount: Double) -> String {
        currency.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    /// Format currency from Decimal
    static func formatCurrency(_ amount: Decimal) -> String {
        currency.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    /// Format price without decimals (e.g. "$10" instead of "$10.00")
    static func formatCurrencyWhole(_ amount: Double) -> String {
        currencyNoDecimals.string(from: NSNumber(value: amount)) ?? "$0"
    }

    /// Format number with commas
    static func formatNumber(_ number: Int) -> String {
        decimal.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Format decimal number
    static func formatDecimal(_ number: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: number)) ?? String(format: "%.\(decimals)f", number)
    }

    /// Format percentage (0.75 -> "75%")
    static func formatPercent(_ value: Double) -> String {
        percent.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    /// Format file size (bytes to KB/MB/GB)
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Format duration (seconds to "1:23:45" or "2:30")
    static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Format phone number (US format)
    static func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if cleaned.count == 10 {
            let areaCode = cleaned.prefix(3)
            let prefix = cleaned.dropFirst(3).prefix(3)
            let suffix = cleaned.dropFirst(6)
            return "(\(areaCode)) \(prefix)-\(suffix)"
        }
        return phone
    }
}

// MARK: - Message Grouping Utilities

extension Formatters {
    /// Group messages by date
    static func groupMessagesByDate<T>(_ messages: [T], dateExtractor: (T) -> Date?) -> [MessageGroup<T>] {
        var groups: [MessageGroup<T>] = []

        for message in messages {
            guard let createdAt = dateExtractor(message) else { continue }
            let dayStart = calendar.startOfDay(for: createdAt)

            if let lastGroupIndex = groups.indices.last,
               calendar.isDate(groups[lastGroupIndex].date, inSameDayAs: dayStart) {
                groups[lastGroupIndex].items.append(message)
            } else {
                groups.append(MessageGroup(date: dayStart, items: [message]))
            }
        }

        return groups
    }
}

// MARK: - Message Group Model

struct MessageGroup<T>: Identifiable {
    let date: Date
    var items: [T]

    var id: String {
        Formatters.iso8601.string(from: date)
    }

    var dateHeader: String {
        Formatters.formatDateHeader(date)
    }
}
