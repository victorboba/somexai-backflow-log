import XCTest
import PDFKit
@testable import BackflowLog

final class ExportTests: XCTestCase {
    private let minimums: [ReadingField: Double] = [.checkOne: 1.0, .checkTwo: 1.0, .relief: 2.0]

    private func sample(passed: Bool = true, repaired: Bool = false) -> BackflowTest {
        let assembly = Assembly(siteID: UUID(), type: .rp, serial: "A44821", location: "Boiler room, north wall")
        assembly.size = "1in"
        assembly.make = "Watts"
        assembly.model = "909"
        let test = BackflowTest(assembly: assembly, date: Date())
        test.customerName = "Bergen Township Schools"
        test.siteName = "Oak Street Elementary"
        test.siteAddress = "14 Oak Street, Bergen"
        test.initialReadings = [.checkOne: 5.2, .checkTwo: 3.1, .relief: 2.6]
        test.linePressure = "68"
        test.passed = passed
        test.testerName = "J. Ferreira"
        test.certificationNumber = "BT-44219"
        test.gaugeSerial = "MW-208814"
        test.gaugeCalibratedOn = Date()
        if repaired {
            test.repairsMade = "Cleaned and reseated the first check."
            test.finalReadings = [.checkOne: 4.8, .checkTwo: 3.0, .relief: 2.4]
        }
        return test
    }

    /// PDFDocument wraps text at the column width, so every phrase must be compared with whitespace collapsed.
    private func text(of url: URL) throws -> String {
        let document = try XCTUnwrap(PDFDocument(url: url))
        let raw = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: " ")
        return raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: The report

    func testTheReportCarriesLocationAssemblyAndTester() throws {
        let url = try ReportExporter.export(sample(), minimums: minimums)
        let body = try text(of: url)
        XCTAssertTrue(body.contains("Backflow Prevention Assembly Test Report"))
        XCTAssertTrue(body.contains("Bergen Township Schools"))
        XCTAssertTrue(body.contains("Oak Street Elementary"))
        XCTAssertTrue(body.contains("A44821"))
        XCTAssertTrue(body.contains("BT-44219"))
        XCTAssertTrue(body.contains("MW-208814"))
        try? FileManager.default.removeItem(at: url)
    }

    func testTheResultIsStatedPlainly() throws {
        let pass = try ReportExporter.export(sample(passed: true), minimums: minimums)
        XCTAssertTrue(try text(of: pass).contains("Result: PASSED"))
        let fail = try ReportExporter.export(sample(passed: false), minimums: minimums)
        XCTAssertTrue(try text(of: fail).contains("Result: FAILED"))
        try? FileManager.default.removeItem(at: pass)
        try? FileManager.default.removeItem(at: fail)
    }

    /// The report shows the minimum each reading was judged against, so a reviewer can check the
    /// tester's work rather than taking the pass on trust.
    func testEveryReadingPrintsWithTheMinimumUsed() throws {
        let url = try ReportExporter.export(sample(), minimums: minimums)
        let body = try text(of: url)
        XCTAssertTrue(body.contains("Minimum used"))
        XCTAssertTrue(body.contains("Relief valve opened at"))
        XCTAssertTrue(body.contains("2.6 psid"))
        try? FileManager.default.removeItem(at: url)
    }

    func testAnRPReportDoesNotAskForVacuumBreakerBoxes() throws {
        let url = try ReportExporter.export(sample(), minimums: minimums)
        let body = try text(of: url)
        XCTAssertTrue(body.contains("Check valve 1"))
        XCTAssertFalse(body.contains("Air inlet"))
        try? FileManager.default.removeItem(at: url)
    }

    func testARepairedTestShowsBothSetsOfReadings() throws {
        let url = try ReportExporter.export(sample(repaired: true), minimums: minimums)
        let body = try text(of: url)
        XCTAssertTrue(body.contains("Initial test"))
        XCTAssertTrue(body.contains("Final test after repair"))
        XCTAssertTrue(body.contains("Cleaned and reseated"))
        try? FileManager.default.removeItem(at: url)
    }

    func testAnUnrecordedReadingSaysSoRatherThanShowingZero() throws {
        let test = sample()
        test.initialReadings = [.checkOne: 5.2]
        let url = try ReportExporter.export(test, minimums: minimums)
        let body = try text(of: url)
        XCTAssertTrue(body.contains("not recorded"))
        try? FileManager.default.removeItem(at: url)
    }

    func testTheReportSaysTheTesterMadeTheCall() throws {
        let url = try ReportExporter.export(sample(), minimums: minimums)
        let body = try text(of: url)
        XCTAssertTrue(body.contains("You take the readings"))
        XCTAssertTrue(body.contains("not an approved form"))
        try? FileManager.default.removeItem(at: url)
    }

    func testTheReportAlwaysCarriesASignatureLine() throws {
        let url = try ReportExporter.export(sample(), minimums: minimums)
        XCTAssertTrue(try text(of: url).contains("Tester signature"))
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: CSV

    func testTestsCSVHasOneRowPerTestPlusTheHeader() {
        let csv = CSVExporter.testsCSV([sample(), sample(passed: false)])
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(lines[0]), CSVExporter.testHeader)
        XCTAssertEqual(csv.components(separatedBy: "\"pass\"").count - 1, 1)
        XCTAssertEqual(csv.components(separatedBy: "\"fail\"").count - 1, 1)
    }

    func testCSVSpellsOutTheReadingsRatherThanTheEncodedString() {
        let csv = CSVExporter.testsCSV([sample()])
        XCTAssertTrue(csv.contains("Relief valve opened at 2.6 psid"))
        XCTAssertFalse(csv.contains("relief:2.6"))
    }

    func testCSVQuotesEscapeEmbeddedQuotes() {
        let test = sample()
        test.customerName = "The \"Old\" Mill"
        XCTAssertTrue(CSVExporter.testsCSV([test]).contains("\"The \"\"Old\"\" Mill\""))
    }

    // MARK: Formatting

    func testDueReadsForwardsAndBackwards() {
        XCTAssertEqual(Formatters.due(0), "due today")
        XCTAssertEqual(Formatters.due(1), "due in 1 day")
        XCTAssertEqual(Formatters.due(45), "due in 45 days")
        XCTAssertEqual(Formatters.due(120), "due in 4 mo")
        XCTAssertEqual(Formatters.due(-12), "overdue by 12 days")
    }

    func testPsiTrimsTrailingZeros() {
        XCTAssertEqual(Formatters.psi(2), "2")
        XCTAssertEqual(Formatters.psi(2.6), "2.6")
    }
}
