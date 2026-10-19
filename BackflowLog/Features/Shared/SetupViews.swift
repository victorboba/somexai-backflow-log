import SwiftUI
import SwiftData

/// Who you are and what you tested with. Both print on every report, and an out-of-calibration
/// gauge voids the tests taken with it, so the date is tracked properly.
struct TesterEditorView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tester.createdAt) private var testers: [Tester]

    @State private var name = ""
    @State private var company = ""
    @State private var phone = ""
    @State private var certificationNumber = ""
    @State private var hasCertExpiry = false
    @State private var certificationExpires = Date.now
    @State private var gaugeMake = ""
    @State private var gaugeSerial = ""
    @State private var hasCalibration = true
    @State private var gaugeCalibratedOn = Date.now
    @State private var calibrationMonths = 12

    private var tester: Tester? { testers.first }

    var body: some View {
        Form {
            Section("You") {
                TextField("Your name", text: $name)
                TextField("Company", text: $company)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
            }
            Section {
                TextField("Certification number", text: $certificationNumber)
                Toggle("Certification expires", isOn: $hasCertExpiry)
                if hasCertExpiry {
                    DatePicker("Expires", selection: $certificationExpires, displayedComponents: .date)
                }
            } header: {
                Text("Certification")
            }
            Section {
                TextField("Gauge make", text: $gaugeMake)
                TextField("Gauge serial", text: $gaugeSerial)
                Toggle("Track calibration", isOn: $hasCalibration)
                if hasCalibration {
                    DatePicker("Calibrated on", selection: $gaugeCalibratedOn, displayedComponents: .date)
                    Picker("Calibrate every", selection: $calibrationMonths) {
                        ForEach([6, 12, 24], id: \.self) { Text("\($0) months").tag($0) }
                    }
                    if let due = tester?.gaugeDueOn {
                        LabeledContent("Next due", value: Formatters.date.string(from: due))
                            .foregroundStyle(due < .now ? .red : .primary)
                    }
                }
            } header: {
                Text("Gauge")
            } footer: {
                Text("A test taken with an out-of-calibration gauge is not valid, so the Route screen warns you when it has run out.")
            }
        }
        .navigationTitle("You and your gauge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    private func load() {
        guard let tester else { return }
        name = tester.name; company = tester.company; phone = tester.phone
        certificationNumber = tester.certificationNumber
        hasCertExpiry = tester.certificationExpires != nil
        certificationExpires = tester.certificationExpires ?? .now
        gaugeMake = tester.gaugeMake; gaugeSerial = tester.gaugeSerial
        hasCalibration = tester.gaugeCalibratedOn != nil
        gaugeCalibratedOn = tester.gaugeCalibratedOn ?? .now
        calibrationMonths = tester.gaugeCalibrationMonths
    }

    private func save() {
        let target = tester ?? Tester()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        target.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        target.certificationNumber = certificationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.certificationExpires = hasCertExpiry ? certificationExpires : nil
        target.gaugeMake = gaugeMake.trimmingCharacters(in: .whitespacesAndNewlines)
        target.gaugeSerial = gaugeSerial.trimmingCharacters(in: .whitespacesAndNewlines)
        target.gaugeCalibratedOn = hasCalibration ? gaugeCalibratedOn : nil
        target.gaugeCalibrationMonths = calibrationMonths
        if tester == nil { context.insert(target) }
        try? context.save()
    }
}

/// The figures the form checks readings against. Offered as the numbers most training programmes
/// teach, and editable because the ones that count are the tester's own.
struct MinimumsView: View {
    @State private var values: [ReadingField: String] = [:]

    var body: some View {
        Form {
            Section {
                ForEach(ReadingField.allCases) { field in
                    LabeledContent(field.name) {
                        HStack {
                            TextField(Formatters.psi(field.suggestedMinimum),
                                      text: Binding(get: { values[field] ?? "" },
                                                    set: { values[field] = $0; store(field, $0) }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(field.unit).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Minimums")
            } footer: {
                Text("A reading below one of these is flagged on the form while you are still on site. You still decide whether the assembly passed; the app never does.")
            }
            Section {
                Button("Reset to the common figures") {
                    for field in ReadingField.allCases {
                        UserDefaults.standard.removeObject(forKey: field.storageKey)
                        values[field] = Formatters.psi(field.suggestedMinimum)
                    }
                }
            }
        }
        .navigationTitle("Pass minimums")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for field in ReadingField.allCases {
                let stored = UserDefaults.standard.double(forKey: field.storageKey)
                values[field] = Formatters.psi(stored > 0 ? stored : field.suggestedMinimum)
            }
        }
    }

    private func store(_ field: ReadingField, _ text: String) {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        UserDefaults.standard.set(value, forKey: field.storageKey)
    }
}
