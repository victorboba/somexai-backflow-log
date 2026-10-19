import SwiftUI
import SwiftData

/// The form on the truck. Only the boxes this assembly's report has, with the tester's own
/// minimums flagged while they are still standing at the valve.
struct TestEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Customer.createdAt) private var customers: [Customer]
    @Query(sort: \Tester.createdAt) private var testers: [Tester]

    let assembly: Assembly
    let test: BackflowTest?

    @State private var date = Date.now
    @State private var reason: TestReason = .annual
    @State private var initial: [ReadingField: String] = [:]
    @State private var final: [ReadingField: String] = [:]
    @State private var needsRepair = false
    @State private var repairsMade = ""
    @State private var passed = true
    @State private var linePressure = ""
    @State private var notes = ""
    @State private var exportFile: ExportFile?
    @FocusState private var keypadUp: Bool

    private var tester: Tester? { testers.first }
    private var minimums: [ReadingField: Double] {
        var result: [ReadingField: Double] = [:]
        for field in ReadingField.allCases {
            let stored = UserDefaults.standard.double(forKey: field.storageKey)
            result[field] = stored > 0 ? stored : field.suggestedMinimum
        }
        return result
    }
    private var initialValues: [ReadingField: Double] { parse(initial) }
    private var missing: [ReadingField] {
        RouteMath.missingReadings(initialValues, type: assembly.type)
    }
    private var short: [ReadingField] {
        RouteMath.shortReadings(initialValues, type: assembly.type, minimums: minimums)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Assembly", value: assembly.displayName)
                    LabeledContent("Type", value: assembly.type.longName)
                    LabeledContent("Where", value: assembly.displayLocation)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Reason", selection: $reason) {
                        ForEach(TestReason.allCases) { Text($0.name).tag($0) }
                    }
                }

                Section {
                    ForEach(assembly.type.fields) { field in
                        ReadingField_View(field: field,
                                          minimum: minimums[field] ?? field.suggestedMinimum,
                                          text: binding(for: field, in: $initial),
                                          keypadUp: $keypadUp)
                    }
                    LabeledContent("Line pressure") {
                        HStack {
                            TextField("0", text: $linePressure)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .focused($keypadUp)
                            Text("psi").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Initial test")
                } footer: {
                    if !missing.isEmpty {
                        Text("Still to record: \(missing.map(\.name).joined(separator: ", ")). A report with an empty box comes back.")
                    } else if !short.isEmpty {
                        Text("\(short.count == 1 ? "One reading is" : "\(short.count) readings are") below your minimum.")
                    }
                }

                Section {
                    Toggle("Repaired and retested", isOn: $needsRepair)
                    if needsRepair {
                        TextField("What you did", text: $repairsMade, axis: .vertical).lineLimit(1...4)
                        ForEach(assembly.type.fields) { field in
                            ReadingField_View(field: field,
                                              minimum: minimums[field] ?? field.suggestedMinimum,
                                              text: binding(for: field, in: $final),
                                              keypadUp: $keypadUp)
                        }
                    }
                } header: {
                    Text("Repairs")
                }

                Section {
                    Picker("Result", selection: $passed) {
                        Text("Passed").tag(true)
                        Text("Failed").tag(false)
                    }
                    .pickerStyle(.segmented)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(1...4)
                } header: {
                    Text("Your call")
                } footer: {
                    Text("You decide this, not the app. The minimums above are the ones you set in Settings, shown so you can check your work.")
                }

                if let test {
                    Section {
                        Button {
                            exportFile = try? ExportFile(url: ReportExporter.export(test, minimums: minimums))
                        } label: { Label("Report PDF", systemImage: "doc.richtext") }
                        Button("Delete This Test", role: .destructive) {
                            context.delete(test)
                            dismiss()
                        }
                    }
                }

                Section {
                    Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(test == nil ? "New Test" : "Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!missing.isEmpty)
                }
                // The number pad has no return key, and a gloved hand needs a way off it.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { keypadUp = false }
                }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .onAppear(perform: load)
        }
    }

    private func binding(for field: ReadingField, in source: Binding<[ReadingField: String]>) -> Binding<String> {
        Binding(get: { source.wrappedValue[field] ?? "" },
                set: { source.wrappedValue[field] = $0 })
    }

    private func parse(_ source: [ReadingField: String]) -> [ReadingField: Double] {
        var result: [ReadingField: Double] = [:]
        for (field, text) in source {
            if let value = Double(text.replacingOccurrences(of: ",", with: ".")) { result[field] = value }
        }
        return result
    }

    private func load() {
        guard let test else { return }
        date = test.date
        reason = test.reason
        initial = test.initialReadings.mapValues(Formatters.psi)
        final = test.finalReadings.mapValues(Formatters.psi)
        needsRepair = test.hasRepair
        repairsMade = test.repairsMade
        passed = test.passed
        linePressure = test.linePressure
        notes = test.notes
    }

    private func save() {
        let site = sites.first { $0.id == assembly.siteID }
        let customer = site.flatMap { s in customers.first { $0.id == s.customerID } }

        let target = test ?? BackflowTest(assembly: assembly, date: date)
        target.date = date
        target.reason = reason
        target.initialReadings = initialValues
        target.finalReadings = needsRepair ? parse(final) : [:]
        target.repairsMade = needsRepair ? repairsMade.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        target.passed = passed
        target.linePressure = linePressure.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.siteName = site?.displayName ?? ""
        target.siteAddress = site?.address ?? ""
        target.customerName = customer?.displayName ?? ""
        target.testerName = tester?.displayName ?? ""
        target.certificationNumber = tester?.certificationNumber ?? ""
        target.gaugeSerial = tester?.gaugeSerial ?? ""
        target.gaugeCalibratedOn = tester?.gaugeCalibratedOn
        if test == nil { context.insert(target) }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
