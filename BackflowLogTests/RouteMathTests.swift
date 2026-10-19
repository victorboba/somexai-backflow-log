import XCTest
@testable import BackflowLog

final class RouteMathTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let now = Date()

    private func assembly(_ type: AssemblyType = .rp, months: Int = 12,
                          serial: String = "A1", siteID: UUID = UUID()) -> Assembly {
        let a = Assembly(siteID: siteID, type: type, serial: serial, location: "Boiler room")
        a.testFrequencyMonths = months
        return a
    }

    private func test(_ assembly: Assembly, monthsAgo: Int, passed: Bool = true) -> BackflowTest {
        let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now)!
        let t = BackflowTest(assembly: assembly, date: date)
        t.passed = passed
        return t
    }

    // MARK: Due dates

    /// An assembly nobody has tested has no due date. Guessing one from the install date would
    /// put fictional work on the route.
    func testANeverTestedAssemblyHasNoDueDate() {
        let a = assembly()
        XCTAssertNil(RouteMath.dueDate(a, tests: [], calendar: calendar))
        XCTAssertEqual(RouteMath.status(a, tests: [], now: now, calendar: calendar), .neverTested)
    }

    func testTheDueDateIsTheLastTestPlusTheInterval() {
        let a = assembly(months: 12)
        let due = RouteMath.dueDate(a, tests: [test(a, monthsAgo: 12)], calendar: calendar)
        XCTAssertNotNil(due)
        XCTAssertEqual(RouteMath.daysUntilDue(a, tests: [test(a, monthsAgo: 12)], now: now, calendar: calendar), 0)
    }

    func testAShorterIntervalBringsTheDueDateForward() {
        let a = assembly(months: 6)
        let days = RouteMath.daysUntilDue(a, tests: [test(a, monthsAgo: 12)], now: now, calendar: calendar)
        XCTAssertNotNil(days)
        XCTAssertLessThan(days ?? 0, 0)
    }

    /// Only the most recent test counts, even when an older one is listed first.
    func testTheLatestTestWins() {
        let a = assembly()
        let tests = [test(a, monthsAgo: 24), test(a, monthsAgo: 2)]
        let days = RouteMath.daysUntilDue(a, tests: tests, now: now, calendar: calendar)
        XCTAssertGreaterThan(days ?? 0, 250)
    }

    func testStatusMovesFromScheduledToDueSoonToOverdue() {
        let a = assembly()
        XCTAssertEqual(RouteMath.status(a, tests: [test(a, monthsAgo: 1)], now: now, calendar: calendar), .scheduled)
        XCTAssertEqual(RouteMath.status(a, tests: [test(a, monthsAgo: 11)], now: now, calendar: calendar), .dueSoon)
        XCTAssertEqual(RouteMath.status(a, tests: [test(a, monthsAgo: 14)], now: now, calendar: calendar), .overdue)
    }

    // MARK: The route

    func testTheRouteJoinsCustomerSiteAndAssembly() {
        let customer = Customer(name: "Bergen Schools")
        let site = Site(customerID: customer.id, name: "Oak Street", address: "14 Oak Street")
        let a = assembly(siteID: site.id)
        let route = RouteMath.route(assemblies: [a], sites: [site], customers: [customer],
                                    tests: [test(a, monthsAgo: 2)], now: now, calendar: calendar)
        XCTAssertEqual(route.first?.customerName, "Bergen Schools")
        XCTAssertEqual(route.first?.siteName, "Oak Street")
        XCTAssertTrue(route.first?.assemblyName.contains("RP") ?? false)
    }

    func testTheRoutePutsNeverTestedAndOverdueFirst() {
        let site = Site(customerID: UUID())
        let never = assembly(serial: "NEVER", siteID: site.id)
        let overdue = assembly(serial: "OVER", siteID: site.id)
        let soon = assembly(serial: "SOON", siteID: site.id)
        let fine = assembly(serial: "FINE", siteID: site.id)
        let tests = [test(overdue, monthsAgo: 20), test(soon, monthsAgo: 11), test(fine, monthsAgo: 1)]
        let route = RouteMath.route(assemblies: [fine, soon, overdue, never], sites: [site],
                                    customers: [], tests: tests, now: now, calendar: calendar)
        XCTAssertEqual(route.map(\.assemblyName).map { $0.components(separatedBy: "#").last ?? "" },
                       ["NEVER", "OVER", "SOON", "FINE"])
    }

    func testArchivedAssembliesLeaveTheRoute() {
        let site = Site(customerID: UUID())
        let live = assembly(serial: "LIVE", siteID: site.id)
        let gone = assembly(serial: "GONE", siteID: site.id)
        gone.archived = true
        let route = RouteMath.route(assemblies: [live, gone], sites: [site], customers: [],
                                    tests: [], now: now, calendar: calendar)
        XCTAssertEqual(route.count, 1)
    }

    func testNeedingWorkExcludesThingsComfortablyInTheFuture() {
        let site = Site(customerID: UUID())
        let overdue = assembly(serial: "OVER", siteID: site.id)
        let fine = assembly(serial: "FINE", siteID: site.id)
        let tests = [test(overdue, monthsAgo: 20), test(fine, monthsAgo: 1)]
        let route = RouteMath.route(assemblies: [overdue, fine], sites: [site], customers: [],
                                    tests: tests, now: now, calendar: calendar)
        XCTAssertEqual(RouteMath.needingWork(route).count, 1)
    }

    /// Anything already due belongs in one bucket at the top, whatever month its date falls in.
    func testGroupingPutsEverythingAlreadyDueInOneBucket() {
        let site = Site(customerID: UUID())
        let overdue = assembly(serial: "OVER", siteID: site.id)
        let never = assembly(serial: "NEVER", siteID: site.id)
        let later = assembly(serial: "LATER", siteID: site.id)
        let tests = [test(overdue, monthsAgo: 20), test(later, monthsAgo: 1)]
        let route = RouteMath.route(assemblies: [overdue, never, later], sites: [site], customers: [],
                                    tests: tests, now: now, calendar: calendar)
        let groups = RouteMath.byMonth(route, calendar: calendar)
        XCTAssertEqual(groups.first?.title, "Due now")
        XCTAssertEqual(groups.first?.entries.count, 2)
    }

    // MARK: Readings

    func testEachTypeAsksForItsOwnBoxes() {
        XCTAssertEqual(AssemblyType.rp.fields, [.checkOne, .checkTwo, .relief])
        XCTAssertEqual(AssemblyType.dc.fields, [.checkOne, .checkTwo])
        XCTAssertEqual(AssemblyType.pvb.fields, [.airInlet, .checkValve])
    }

    func testAReadingOnTheMinimumMeetsIt() {
        XCTAssertTrue(RouteMath.meetsMinimum(.relief, value: 2.0, minimums: [.relief: 2.0]))
        XCTAssertFalse(RouteMath.meetsMinimum(.relief, value: 1.9, minimums: [.relief: 2.0]))
    }

    func testTheTestersOwnMinimumOverridesTheSuggestedOne() {
        XCTAssertTrue(RouteMath.meetsMinimum(.checkOne, value: 1.2, minimums: [:]))
        XCTAssertFalse(RouteMath.meetsMinimum(.checkOne, value: 1.2, minimums: [.checkOne: 1.5]))
    }

    func testShortReadingsOnlyLookAtFieldsThisTypeHas() {
        let readings: [ReadingField: Double] = [.checkOne: 0.5, .airInlet: 0.1]
        let short = RouteMath.shortReadings(readings, type: .dc, minimums: [:])
        XCTAssertEqual(short, [.checkOne])
    }

    func testMissingReadingsListsEmptyBoxesInFormOrder() {
        let readings: [ReadingField: Double] = [.checkTwo: 3.0]
        XCTAssertEqual(RouteMath.missingReadings(readings, type: .rp), [.checkOne, .relief])
    }

    func testAFullSetOfReadingsIsNotMissingAnything() {
        let readings: [ReadingField: Double] = [.checkOne: 5, .checkTwo: 3, .relief: 2.6]
        XCTAssertTrue(RouteMath.missingReadings(readings, type: .rp).isEmpty)
    }

    // MARK: Encoding

    func testReadingsSurviveEncoding() {
        let assembly = self.assembly()
        let t = BackflowTest(assembly: assembly)
        t.initialReadings = [.checkOne: 5.2, .relief: 2.6]
        XCTAssertEqual(t.initialReadings[.checkOne], 5.2)
        XCTAssertEqual(t.initialReadings[.relief], 2.6)
        XCTAssertNil(t.initialReadings[.checkTwo])
    }

    func testAnEmptyReadingSetEncodesToNothing() {
        let t = BackflowTest(assembly: assembly())
        t.finalReadings = [:]
        XCTAssertTrue(t.finalReadingsEncoded.isEmpty)
        XCTAssertFalse(t.hasRepair)
    }

    /// The assembly details are snapshotted, so replacing the unit does not rewrite a report
    /// that was filed against the old one.
    func testATestKeepsTheAssemblyItWasTakenOn() {
        let a = assembly(serial: "OLD")
        let t = BackflowTest(assembly: a)
        a.serial = "NEW"
        XCTAssertEqual(t.serial, "OLD")
    }

    // MARK: Gauge and counts

    func testAnExpiredGaugeCalibrationIsFlagged() {
        let tester = Tester(name: "J. Ferreira")
        tester.gaugeCalibratedOn = calendar.date(byAdding: .month, value: -13, to: now)
        tester.gaugeCalibrationMonths = 12
        XCTAssertTrue(RouteMath.gaugeOutOfCalibration(tester, now: now))
        tester.gaugeCalibratedOn = calendar.date(byAdding: .month, value: -2, to: now)
        XCTAssertFalse(RouteMath.gaugeOutOfCalibration(tester, now: now))
    }

    func testNoGaugeDateIsNotReportedAsExpired() {
        XCTAssertFalse(RouteMath.gaugeOutOfCalibration(Tester(name: "J"), now: now))
        XCTAssertFalse(RouteMath.gaugeOutOfCalibration(nil, now: now))
    }

    func testPassRateCountsOnlyPasses() {
        let a = assembly()
        let tests = [test(a, monthsAgo: 1), test(a, monthsAgo: 2, passed: false),
                     test(a, monthsAgo: 3), test(a, monthsAgo: 4)]
        XCTAssertEqual(RouteMath.passRate(tests), 0.75, accuracy: 0.0001)
        XCTAssertEqual(RouteMath.passRate([]), 0)
    }

    func testDateRangeIncludesBothEndDays() {
        let a = assembly()
        let tests = [test(a, monthsAgo: 0), test(a, monthsAgo: 2), test(a, monthsAgo: 5)]
        let start = calendar.date(byAdding: .month, value: -2, to: now)!
        XCTAssertEqual(RouteMath.tests(tests, from: start, to: now, calendar: calendar).count, 2)
    }
}
