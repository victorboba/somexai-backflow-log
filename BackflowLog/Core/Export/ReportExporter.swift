import UIKit

/// One test report, laid out the way the paper forms are: who and where at the top, then the
/// assembly, then the readings, then the signature block. The tester sends this to the purveyor.
enum ReportExporter {
    static func export(_ test: BackflowTest, minimums: [ReadingField: Double]) throws -> URL {
        let footer = "\(AppConfig.appName) · \(test.customerName) · \(Formatters.date.string(from: test.date))"

        return try PDFCanvas.render(footer: footer) { page in
            page.title("Backflow Prevention Assembly Test Report")
            page.subtitle("\(test.reason.name) · \(Formatters.date.string(from: test.date))")
            page.subtitle(test.passed ? "Result: PASSED" : "Result: FAILED")

            page.heading("Location")
            page.keyValues([
                ("Customer", test.customerName),
                ("Site", test.siteName),
                ("Address", test.siteAddress),
                ("Assembly location", test.location),
            ])

            page.heading("Assembly")
            page.keyValues([
                ("Type", "\(test.assemblyType.name) — \(test.assemblyType.longName)"),
                ("Make and model", [test.make, test.model].filter { !$0.isEmpty }.joined(separator: " ")),
                ("Size", test.size),
                ("Serial number", test.serial),
                ("Line pressure", test.linePressure),
            ])

            readingTable(page, title: "Initial test",
                         readings: test.initialReadings, type: test.assemblyType, minimums: minimums)

            if test.hasRepair {
                page.heading("Repairs")
                page.paragraph(test.repairsMade.isEmpty ? "Repairs made; see the final readings." : test.repairsMade)
                if !test.finalReadingsEncoded.isEmpty {
                    readingTable(page, title: "Final test after repair",
                                 readings: test.finalReadings, type: test.assemblyType, minimums: minimums)
                }
            }

            if !test.notes.isEmpty {
                page.heading("Notes")
                page.paragraph(test.notes)
            }

            page.heading("Tester")
            page.keyValues([
                ("Name", test.testerName),
                ("Certification number", test.certificationNumber),
                ("Gauge serial", test.gaugeSerial),
                ("Gauge calibrated", test.gaugeCalibratedOn.map(Formatters.date.string(from:)) ?? "not recorded"),
            ])
            page.spacer(16)
            page.keyValues([
                ("Tester signature", "______________________________________      Date: ______________"),
            ])

            page.heading("About this report")
            page.paragraph(AppConfig.disclaimer, color: .darkGray)
        }
    }

    private static func readingTable(_ page: PDFCanvas, title: String,
                                     readings: [ReadingField: Double], type: AssemblyType,
                                     minimums: [ReadingField: Double]) {
        page.heading(title)
        let rows = type.fields.map { field -> [String] in
            let minimum = minimums[field] ?? field.suggestedMinimum
            guard let value = readings[field] else {
                return [field.name, "not recorded", "\(Formatters.psi(minimum)) \(field.unit)", "—"]
            }
            let meets = RouteMath.meetsMinimum(field, value: value, minimums: minimums)
            return [field.name,
                    "\(Formatters.psi(value)) \(field.unit)",
                    "\(Formatters.psi(minimum)) \(field.unit)",
                    meets ? "Met" : "Below"]
        }
        page.table(headers: ["Reading", "Recorded", "Minimum used", "Against minimum"],
                   widths: [0.36, 0.22, 0.22, 0.20],
                   rows: rows)
    }
}

enum CSVExporter {
    static let testHeader = "date,customer,site,address,assembly,type,serial,size,location,reason,passed,initial_readings,final_readings,repairs,tester,certification,gauge_serial,notes"
    static let routeHeader = "customer,site,address,assembly,type,serial,location,status,due_date,days_until_due"

    static func testsCSV(_ tests: [BackflowTest]) -> String {
        var lines = [testHeader]
        for test in tests.sorted(by: { $0.date < $1.date }) {
            let fields = [
                Formatters.fileStamp.string(from: test.date),
                test.customerName, test.siteName, test.siteAddress,
                test.assemblyName, test.assemblyType.name, test.serial, test.size, test.location,
                test.reason.name,
                test.passed ? "pass" : "fail",
                readable(test.initialReadings, type: test.assemblyType),
                readable(test.finalReadings, type: test.assemblyType),
                test.repairsMade.replacingOccurrences(of: "\n", with: " "),
                test.testerName, test.certificationNumber, test.gaugeSerial,
                test.notes.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func routeCSV(_ route: [RouteMath.RouteEntry]) -> String {
        var lines = [routeHeader]
        for entry in route {
            let fields = [
                entry.customerName, entry.siteName, "", entry.assemblyName, "", "",
                entry.location, entry.status.name,
                entry.dueDate.map(Formatters.fileStamp.string(from:)) ?? "",
                entry.daysUntilDue.map(String.init) ?? "",
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// "Check valve 1 5.2 psid; Relief valve opened at 2.6 psid"
    private static func readable(_ readings: [ReadingField: Double], type: AssemblyType) -> String {
        type.fields.compactMap { field in
            readings[field].map { "\(field.name) \(Formatters.psi($0)) \(field.unit)" }
        }.joined(separator: "; ")
    }

    static func write(_ text: String, suffix: String) throws -> URL {
        let url = ExportFile.temporaryURL(suffix: suffix, extension: "csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(suffix: String, extension ext: String) -> URL {
        let stamp = Formatters.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(suffix)-\(stamp)")
            .appendingPathExtension(ext)
    }
}
