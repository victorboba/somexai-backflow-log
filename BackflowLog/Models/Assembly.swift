import Foundation
import SwiftData

/// The assembly types a tester meets, and the readings each one's report asks for. The fields
/// differ by type, which is why the test form is built from this rather than hard-coded.
enum AssemblyType: String, Codable, CaseIterable, Identifiable {
    case rp, rpda, dc, dcda, pvb, svb
    var id: String { rawValue }

    var name: String {
        switch self {
        case .rp: return "RP"
        case .rpda: return "RPDA"
        case .dc: return "DC"
        case .dcda: return "DCDA"
        case .pvb: return "PVB"
        case .svb: return "SVB"
        }
    }

    var longName: String {
        switch self {
        case .rp: return "Reduced pressure principle"
        case .rpda: return "Reduced pressure detector"
        case .dc: return "Double check valve"
        case .dcda: return "Double check detector"
        case .pvb: return "Pressure vacuum breaker"
        case .svb: return "Spill-resistant vacuum breaker"
        }
    }

    /// The readings this type's report has a box for, in the order the tester takes them.
    var fields: [ReadingField] {
        switch self {
        case .rp, .rpda:
            return [.checkOne, .checkTwo, .relief]
        case .dc, .dcda:
            return [.checkOne, .checkTwo]
        case .pvb, .svb:
            return [.airInlet, .checkValve]
        }
    }

    var symbol: String {
        switch self {
        case .rp, .rpda: return "arrow.triangle.branch"
        case .dc, .dcda: return "circle.grid.2x1.fill"
        case .pvb, .svb: return "arrow.up.to.line"
        }
    }
}

/// One box on the test report.
enum ReadingField: String, Codable, CaseIterable, Identifiable {
    case checkOne, checkTwo, relief, airInlet, checkValve
    var id: String { rawValue }

    var name: String {
        switch self {
        case .checkOne: return "Check valve 1"
        case .checkTwo: return "Check valve 2"
        case .relief: return "Relief valve opened at"
        case .airInlet: return "Air inlet opened at"
        case .checkValve: return "Check valve"
        }
    }

    var unit: String { self == .relief || self == .airInlet ? "psid" : "psid" }

    /// The figure most training programmes teach, offered as a starting default. The tester
    /// confirms or changes it in Settings, because the number that counts is the one their own
    /// purveyor and certification body use.
    var suggestedMinimum: Double {
        switch self {
        case .checkOne, .checkTwo, .checkValve: return 1.0
        case .relief: return 2.0
        case .airInlet: return 1.0
        }
    }

    var storageKey: String { "minimum.\(rawValue)" }
}

/// One device in the ground. The tester's route is a list of these with annual due dates.
@Model
final class Assembly {
    var id: UUID = UUID()
    var siteID: UUID = UUID()
    var typeRaw: String = AssemblyType.rp.rawValue
    var serial: String = ""
    var make: String = ""
    var model: String = ""
    var size: String = ""
    /// Where on the property it is, which is the difference between a ten-minute job and an hour.
    var location: String = ""
    var hazard: String = ""
    var waterPurveyor: String = ""
    var permitNumber: String = ""
    var installedOn: Date?
    /// Most jurisdictions require annual testing; some want it more often on high hazard.
    var testFrequencyMonths: Int = 12
    var archived: Bool = false
    var notes: String = ""
    var createdAt: Date = Date()

    init(siteID: UUID, type: AssemblyType = .rp, serial: String = "", location: String = "") {
        self.id = UUID()
        self.siteID = siteID
        self.typeRaw = type.rawValue
        self.serial = serial
        self.location = location
        self.createdAt = .now
    }
}

extension Assembly {
    var type: AssemblyType {
        get { AssemblyType(rawValue: typeRaw) ?? .rp }
        set { typeRaw = newValue.rawValue }
    }

    /// "RP 3/4in #A44821" — how a tester recognises one on a list.
    var displayName: String {
        var parts = [type.name]
        if !size.isEmpty { parts.append(size) }
        let serial = self.serial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !serial.isEmpty { parts.append("#\(serial)") }
        return parts.joined(separator: " ")
    }

    var displayLocation: String {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Location not recorded" : trimmed
    }
}

/// A property. One customer can have many; one site can have many assemblies.
@Model
final class Site {
    var id: UUID = UUID()
    var customerID: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var contactName: String = ""
    var contactPhone: String = ""
    var accessNotes: String = ""
    var archived: Bool = false
    var createdAt: Date = Date()

    init(customerID: UUID, name: String = "", address: String = "") {
        self.id = UUID()
        self.customerID = customerID
        self.name = name
        self.address = address
        self.createdAt = .now
    }
}

extension Site {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let address = self.address.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? "Site" : address
    }
}

@Model
final class Customer {
    var id: UUID = UUID()
    var name: String = ""
    var contactName: String = ""
    var phone: String = ""
    var email: String = ""
    var notes: String = ""
    var archived: Bool = false
    var createdAt: Date = Date()

    init(name: String = "") {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}

extension Customer {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Customer" : trimmed
    }
}
