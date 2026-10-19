import Foundation
import SwiftData

enum TestReason: String, Codable, CaseIterable, Identifiable {
    case annual, newInstall, afterRepair, replacement
    var id: String { rawValue }

    var name: String {
        switch self {
        case .annual: return "Annual test"
        case .newInstall: return "New installation"
        case .afterRepair: return "Retest after repair"
        case .replacement: return "Replacement"
        }
    }
}

/// One test, and the report that comes off it. The assembly's details are snapshotted because a
/// report filed last March has to keep saying what was on the wall last March, even after the
/// assembly is replaced.
@Model
final class BackflowTest {
    var id: UUID = UUID()
    var assemblyID: UUID = UUID()
    var date: Date = Date()
    var reasonRaw: String = TestReason.annual.rawValue

    // Snapshot of the assembly as tested.
    var assemblyName: String = ""
    var assemblyTypeRaw: String = AssemblyType.rp.rawValue
    var serial: String = ""
    var make: String = ""
    var model: String = ""
    var size: String = ""
    var location: String = ""
    var siteName: String = ""
    var siteAddress: String = ""
    var customerName: String = ""

    /// "checkOne:5.2|checkTwo:3.1|relief:2.6" — the readings, in one CloudKit-safe string.
    var initialReadingsEncoded: String = ""
    /// The readings after repair, when there was one.
    var finalReadingsEncoded: String = ""
    var repairsMade: String = ""
    /// The tester's own call. The app shows the minimums they configured but never decides this.
    var passed: Bool = true
    var linePressure: String = ""
    var notes: String = ""

    // Snapshot of who tested and with what, both of which the report has to carry.
    var testerName: String = ""
    var certificationNumber: String = ""
    var gaugeSerial: String = ""
    var gaugeCalibratedOn: Date?

    var createdAt: Date = Date()

    init(assembly: Assembly, date: Date = .now) {
        self.id = UUID()
        self.assemblyID = assembly.id
        self.date = date
        self.assemblyName = assembly.displayName
        self.assemblyTypeRaw = assembly.typeRaw
        self.serial = assembly.serial
        self.make = assembly.make
        self.model = assembly.model
        self.size = assembly.size
        self.location = assembly.location
        self.createdAt = .now
    }
}

extension BackflowTest {
    var reason: TestReason {
        get { TestReason(rawValue: reasonRaw) ?? .annual }
        set { reasonRaw = newValue.rawValue }
    }

    var assemblyType: AssemblyType { AssemblyType(rawValue: assemblyTypeRaw) ?? .rp }

    var initialReadings: [ReadingField: Double] {
        get { BackflowTest.decode(initialReadingsEncoded) }
        set { initialReadingsEncoded = BackflowTest.encode(newValue) }
    }

    var finalReadings: [ReadingField: Double] {
        get { BackflowTest.decode(finalReadingsEncoded) }
        set { finalReadingsEncoded = BackflowTest.encode(newValue) }
    }

    var hasRepair: Bool { !finalReadingsEncoded.isEmpty || !repairsMade.isEmpty }

    static func encode(_ readings: [ReadingField: Double]) -> String {
        ReadingField.allCases
            .compactMap { field in readings[field].map { "\(field.rawValue):\($0)" } }
            .joined(separator: "|")
    }

    static func decode(_ encoded: String) -> [ReadingField: Double] {
        var result: [ReadingField: Double] = [:]
        for part in encoded.split(separator: "|") {
            let pieces = part.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2,
                  let field = ReadingField(rawValue: String(pieces[0])),
                  let value = Double(pieces[1]) else { continue }
            result[field] = value
        }
        return result
    }
}

/// The tester and their gauge. One per install; it stamps every report.
@Model
final class Tester {
    var id: UUID = UUID()
    var name: String = ""
    var company: String = ""
    var phone: String = ""
    var certificationNumber: String = ""
    var certificationExpires: Date?
    var gaugeMake: String = ""
    var gaugeSerial: String = ""
    /// Gauges must be calibrated, usually yearly, and an out-of-calibration gauge voids the test.
    var gaugeCalibratedOn: Date?
    var gaugeCalibrationMonths: Int = 12
    var createdAt: Date = Date()

    init(name: String = "") {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}

extension Tester {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tester" : trimmed
    }

    var gaugeDueOn: Date? {
        guard let gaugeCalibratedOn else { return nil }
        return Calendar.current.date(byAdding: .month, value: gaugeCalibrationMonths, to: gaugeCalibratedOn)
    }
}
