import Foundation

/// The route and the readings, with no SwiftData dependency so it can be tested directly.
/// Nothing here decides whether a test passed: it compares readings against the minimums the
/// tester configured and leaves the call to them.
enum RouteMath {

    // MARK: When a thing is due

    enum DueStatus: String {
        case overdue, dueSoon, scheduled, neverTested

        var name: String {
            switch self {
            case .overdue: return "Overdue"
            case .dueSoon: return "Due soon"
            case .scheduled: return "Scheduled"
            case .neverTested: return "Never tested"
            }
        }

        var symbol: String {
            switch self {
            case .overdue: return "exclamationmark.octagon.fill"
            case .dueSoon: return "exclamationmark.triangle.fill"
            case .scheduled: return "calendar"
            case .neverTested: return "questionmark.circle.fill"
            }
        }
    }

    /// How far ahead an assembly counts as due soon. A tester books work a couple of months out.
    static let dueSoonDays = 60

    /// The last test on an assembly, which is what the next due date hangs off.
    static func lastTest(_ tests: [BackflowTest], for assemblyID: UUID) -> BackflowTest? {
        tests.filter { $0.assemblyID == assemblyID }.max { $0.date < $1.date }
    }

    /// Nil when the assembly has never been tested: there is nothing to count from, and guessing
    /// a due date from the install date would put fictional work on the route.
    static func dueDate(_ assembly: Assembly, tests: [BackflowTest], calendar: Calendar = .current) -> Date? {
        guard let last = lastTest(tests, for: assembly.id) else { return nil }
        return calendar.date(byAdding: .month, value: max(1, assembly.testFrequencyMonths),
                             to: calendar.startOfDay(for: last.date))
    }

    static func daysUntilDue(_ assembly: Assembly, tests: [BackflowTest],
                             now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let due = dueDate(assembly, tests: tests, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: due)).day
    }

    static func status(_ assembly: Assembly, tests: [BackflowTest],
                       now: Date = .now, calendar: Calendar = .current) -> DueStatus {
        guard let days = daysUntilDue(assembly, tests: tests, now: now, calendar: calendar) else {
            return .neverTested
        }
        if days < 0 { return .overdue }
        return days <= dueSoonDays ? .dueSoon : .scheduled
    }

    // MARK: The route

    struct RouteEntry: Identifiable, Equatable {
        let assemblyID: UUID
        let assemblyName: String
        let siteName: String
        let customerName: String
        let location: String
        let status: DueStatus
        let dueDate: Date?
        let daysUntilDue: Int?
        var id: UUID { assemblyID }
    }

    /// Everything worth driving to, most urgent first: never-tested and overdue at the top, then
    /// due soonest. Assemblies with a date far out are still listed so a tester can plan a month.
    static func route(assemblies: [Assembly], sites: [Site], customers: [Customer],
                      tests: [BackflowTest], now: Date = .now, calendar: Calendar = .current) -> [RouteEntry] {
        let siteByID = Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) })
        let customerByID = Dictionary(uniqueKeysWithValues: customers.map { ($0.id, $0) })

        return assemblies
            .filter { !$0.archived }
            .map { assembly -> RouteEntry in
                let site = siteByID[assembly.siteID]
                let customer = site.flatMap { customerByID[$0.customerID] }
                return RouteEntry(assemblyID: assembly.id,
                                  assemblyName: assembly.displayName,
                                  siteName: site?.displayName ?? "Site",
                                  customerName: customer?.displayName ?? "Customer",
                                  location: assembly.displayLocation,
                                  status: status(assembly, tests: tests, now: now, calendar: calendar),
                                  dueDate: dueDate(assembly, tests: tests, calendar: calendar),
                                  daysUntilDue: daysUntilDue(assembly, tests: tests, now: now, calendar: calendar))
            }
            .sorted { a, b in
                if urgency(a.status) != urgency(b.status) { return urgency(a.status) < urgency(b.status) }
                switch (a.daysUntilDue, b.daysUntilDue) {
                case let (x?, y?) where x != y: return x < y
                case (nil, _?): return true
                case (_?, nil): return false
                default: return a.customerName < b.customerName
                }
            }
    }

    private static func urgency(_ status: DueStatus) -> Int {
        switch status {
        case .neverTested: return 0
        case .overdue: return 1
        case .dueSoon: return 2
        case .scheduled: return 3
        }
    }

    static func needingWork(_ route: [RouteEntry]) -> [RouteEntry] {
        route.filter { $0.status == .overdue || $0.status == .dueSoon || $0.status == .neverTested }
    }

    /// The route grouped by the month it falls in, for planning a few months ahead. Anything
    /// already due lands in the first group whatever its date says.
    struct MonthGroup: Identifiable, Equatable {
        let month: Date?
        let entries: [RouteEntry]
        var id: String { month.map(Formatters.monthYear.string(from:)) ?? "now" }
        var title: String { month.map(Formatters.monthYear.string(from:)) ?? "Due now" }
    }

    static func byMonth(_ route: [RouteEntry], calendar: Calendar = .current) -> [MonthGroup] {
        let now = route.filter { $0.status == .overdue || $0.status == .neverTested }
        var groups: [MonthGroup] = now.isEmpty ? [] : [MonthGroup(month: nil, entries: now)]

        let rest = route.filter { $0.status != .overdue && $0.status != .neverTested }
        let grouped = Dictionary(grouping: rest) { entry -> Date in
            guard let due = entry.dueDate else { return .distantFuture }
            return calendar.date(from: calendar.dateComponents([.year, .month], from: due)) ?? due
        }
        for month in grouped.keys.sorted() {
            groups.append(MonthGroup(month: month, entries: grouped[month] ?? []))
        }
        return groups
    }

    // MARK: Readings

    /// Whether one reading clears the minimum the tester configured. Advisory only: the pass or
    /// fail on the report is the tester's own call, and the app never overrides it.
    static func meetsMinimum(_ field: ReadingField, value: Double, minimums: [ReadingField: Double]) -> Bool {
        value >= (minimums[field] ?? field.suggestedMinimum)
    }

    /// Readings that fall short, so the form can flag them while the tester is still on site.
    static func shortReadings(_ readings: [ReadingField: Double], type: AssemblyType,
                              minimums: [ReadingField: Double]) -> [ReadingField] {
        type.fields.filter { field in
            guard let value = readings[field] else { return false }
            return !meetsMinimum(field, value: value, minimums: minimums)
        }
    }

    /// A report with a box left empty is a report that comes back. Missing fields, in form order.
    static func missingReadings(_ readings: [ReadingField: Double], type: AssemblyType) -> [ReadingField] {
        type.fields.filter { readings[$0] == nil }
    }

    // MARK: Counting

    static func tests(_ tests: [BackflowTest], from start: Date, to end: Date,
                      calendar: Calendar = .current) -> [BackflowTest] {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        return tests.filter { $0.date >= lower && $0.date < upper }
    }

    static func passRate(_ tests: [BackflowTest]) -> Double {
        guard !tests.isEmpty else { return 0 }
        return Double(tests.filter(\.passed).count) / Double(tests.count)
    }

    /// True when the gauge's calibration has run out, which voids every test taken with it.
    static func gaugeOutOfCalibration(_ tester: Tester?, now: Date = .now) -> Bool {
        guard let due = tester?.gaugeDueOn else { return false }
        return due < now
    }
}
