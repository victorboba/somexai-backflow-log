import Foundation
import SwiftData

#if DEBUG
/// A working tester's book: a dozen customers, a spread of assemblies, and a route with real
/// overdue work on it, because a sample where nothing is due demonstrates nothing.
enum SampleData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current

        let tester = Tester(name: "J. Ferreira")
        tester.company = "Ferreira Backflow & Irrigation"
        tester.phone = "(919) 555-0114"
        tester.certificationNumber = "BT-44219"
        tester.gaugeMake = "Midwest 845-5"
        tester.gaugeSerial = "MW-208814"
        tester.gaugeCalibratedOn = calendar.date(byAdding: .month, value: -7, to: .now)
        tester.gaugeCalibrationMonths = 12
        context.insert(tester)

        // (customer, site, address, [(type, serial, size, location, months since last test)])
        let seeds: [(String, String, String, [(AssemblyType, String, String, String, Int?)])] = [
            ("Bergen Township Schools", "Oak Street Elementary", "14 Oak Street, Bergen", [
                (.rp, "A44821", "1in", "Boiler room, north wall", 14),
                (.dc, "B10233", "2in", "Irrigation, by the ball field", 13),
            ]),
            ("Riverside Apartments", "Building A", "88 River Road, Bergen", [
                (.rp, "C88120", "2in", "Mechanical room, behind the pump", 11),
                (.pvb, "D22104", "3/4in", "Irrigation box, front lawn", 9),
            ]),
            ("Bergen Family Dental", "Main office", "402 Center Street", [
                (.rp, "E55901", "3/4in", "Utility closet by the compressor", 6),
            ]),
            ("Northside Car Wash", "Wash bay", "1200 Industrial Drive", [
                (.rp, "F71440", "1 1/2in", "Above the bay door, ladder needed", 15),
                (.dc, "G33218", "1in", "Water softener feed", 4),
            ]),
            ("Marsh Hardware", "Store", "9 Market Square", [
                (.dc, "H90014", "3/4in", "Basement, left of the stairs", 8),
            ]),
            ("Greenfield HOA", "Clubhouse", "5 Greenfield Way", [
                (.pvb, "J12005", "1in", "Pool equipment pad", 10),
                (.svb, "K40118", "3/4in", "Irrigation, east side", nil),
            ]),
            ("Cedar Lane Church", "Sanctuary", "77 Cedar Lane", [
                (.rp, "L66220", "2in", "Fire line room", 2),
            ]),
            ("Bergen Brewing", "Taproom", "310 Mill Street", [
                (.rp, "M18877", "1 1/2in", "Behind the grain silo", 12),
                (.rp, "N29004", "3/4in", "Glycol loop, upstairs", nil),
            ]),
        ]

        var generator = SystemRandomNumberGenerator()

        for seed in seeds {
            let customer = Customer(name: seed.0)
            customer.phone = "(919) 555-0\(Int.random(in: 100...199, using: &generator))"
            context.insert(customer)

            let site = Site(customerID: customer.id, name: seed.1, address: seed.2)
            site.accessNotes = ["Key at the front desk", "Gate code 4412", "Call ahead, dog on site", ""]
                .randomElement(using: &generator) ?? ""
            context.insert(site)

            for spec in seed.3 {
                let assembly = Assembly(siteID: site.id, type: spec.0, serial: spec.1, location: spec.3)
                assembly.size = spec.2
                assembly.make = ["Watts", "Febco", "Wilkins", "Conbraco"].randomElement(using: &generator) ?? "Watts"
                assembly.model = ["909", "825Y", "375", "40-200"].randomElement(using: &generator) ?? "909"
                assembly.waterPurveyor = "Bergen Water Authority"
                assembly.testFrequencyMonths = 12
                context.insert(assembly)

                // Some assemblies have a history; the nil ones have never been tested, which is
                // its own line on the route.
                guard let monthsAgo = spec.4 else { continue }
                for yearsBack in 0..<2 {
                    guard let date = calendar.date(byAdding: .month, value: -(monthsAgo + yearsBack * 12), to: .now),
                          date <= .now else { continue }
                    let test = BackflowTest(assembly: assembly, date: date)
                    let failed = yearsBack == 0 && Int.random(in: 0...5, using: &generator) == 0
                    var readings: [ReadingField: Double] = [:]
                    for field in spec.0.fields {
                        let base = field.suggestedMinimum
                        readings[field] = failed && field == spec.0.fields.first
                            ? (base - Double.random(in: 0.2...0.8, using: &generator)).rounded(to: 1)
                            : (base + Double.random(in: 0.6...4.0, using: &generator)).rounded(to: 1)
                    }
                    test.initialReadings = readings
                    test.passed = !failed
                    if failed {
                        test.repairsMade = "Cleaned and reseated the first check. Retested."
                        var fixed = readings
                        for field in spec.0.fields {
                            fixed[field] = (field.suggestedMinimum + Double.random(in: 0.8...3.0, using: &generator)).rounded(to: 1)
                        }
                        test.finalReadings = fixed
                        test.passed = true
                    }
                    test.linePressure = "\(Int.random(in: 55...85, using: &generator))"
                    test.siteName = site.displayName
                    test.siteAddress = site.address
                    test.customerName = customer.displayName
                    test.testerName = tester.displayName
                    test.certificationNumber = tester.certificationNumber
                    test.gaugeSerial = tester.gaugeSerial
                    test.gaugeCalibratedOn = tester.gaugeCalibratedOn
                    context.insert(test)
                }
            }
        }
        try? context.save()
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
#endif
