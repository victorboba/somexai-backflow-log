import Foundation

enum Formatters {
    static let date: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    static let dateTime: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()
    static let monthYear: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    static let short: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    static let fileStamp: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    /// "5.2" / "12", trimming trailing zeros. Gauge readings are read to one decimal.
    static func psi(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    /// "overdue by 12 days" / "due in 3 mo", long units as the owner asked.
    static func due(_ days: Int) -> String {
        if days < 0 { return "overdue by \(span(-days))" }
        if days == 0 { return "due today" }
        return "due in \(span(days))"
    }

    static func span(_ days: Int) -> String {
        if days < 60 { return days == 1 ? "1 day" : "\(days) days" }
        let months = days / 30
        if months < 12 { return "\(months) mo" }
        let years = months / 12, rest = months % 12
        return rest == 0 ? "\(years) yr" : "\(years) yr \(rest) mo"
    }
}
