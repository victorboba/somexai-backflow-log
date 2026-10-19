import SwiftUI
import SwiftData

struct CustomerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let customer: Customer?
    @State private var name = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Business or owner name", text: $name)
                    TextField("Contact", text: $contactName)
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextField("Anything useful", text: $notes, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle(customer == nil ? "New Customer" : "Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let customer else { return }
                name = customer.name; contactName = customer.contactName
                phone = customer.phone; email = customer.email; notes = customer.notes
            }
        }
    }

    private func save() {
        let target = customer ?? Customer()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.contactName = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        target.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if customer == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}

struct SiteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let site: Site?
    let customer: Customer

    @State private var name = ""
    @State private var address = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var accessNotes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Site") {
                    TextField("Name, e.g. North warehouse", text: $name)
                    TextField("Address", text: $address, axis: .vertical).lineLimit(1...3)
                }
                Section("On site") {
                    TextField("Contact", text: $contactName)
                    TextField("Phone", text: $contactPhone).keyboardType(.phonePad)
                }
                Section {
                    TextField("Gate code, where the key is, dogs", text: $accessNotes, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text("Getting in")
                } footer: {
                    Text("Worth filling in. It is the difference between one trip and two.")
                }
            }
            .navigationTitle(site == nil ? "New Site" : "Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  && address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let site else { return }
                name = site.name; address = site.address
                contactName = site.contactName; contactPhone = site.contactPhone
                accessNotes = site.accessNotes
            }
        }
    }

    private func save() {
        let target = site ?? Site(customerID: customer.id)
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        target.contactName = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.contactPhone = contactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        target.accessNotes = accessNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if site == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}

struct AssemblyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let assembly: Assembly?
    let site: Site

    @State private var type: AssemblyType = .rp
    @State private var serial = ""
    @State private var make = ""
    @State private var model = ""
    @State private var size = ""
    @State private var location = ""
    @State private var hazard = ""
    @State private var waterPurveyor = ""
    @State private var permitNumber = ""
    @State private var frequency = 12
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(AssemblyType.allCases) { candidate in
                            Text("\(candidate.name) — \(candidate.longName)").tag(candidate)
                        }
                    }
                } header: {
                    Text("Assembly")
                } footer: {
                    Text("The type decides which boxes the test form shows: \(type.fields.map(\.name).joined(separator: ", ")).")
                }

                Section("Nameplate") {
                    TextField("Serial number", text: $serial)
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    TextField("Size, e.g. 1in", text: $size)
                }

                Section {
                    TextField("Where it is, e.g. north wall, in the pit", text: $location, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Hazard, e.g. irrigation with fertiliser", text: $hazard)
                } header: {
                    Text("On the property")
                }

                Section {
                    Picker("Test every", selection: $frequency) {
                        ForEach([3, 6, 12, 24], id: \.self) { months in
                            Text(months == 12 ? "12 months (annual)" : "\(months) months").tag(months)
                        }
                    }
                    TextField("Water purveyor", text: $waterPurveyor)
                    TextField("Permit or purveyor number", text: $permitNumber)
                } header: {
                    Text("Filing")
                } footer: {
                    Text("The due date on the route is the last test plus this interval.")
                }

                Section("Notes") {
                    TextField("Anything useful", text: $notes, axis: .vertical).lineLimit(1...4)
                }

                if assembly != nil {
                    Section {
                        Button("Remove This Assembly", role: .destructive) {
                            assembly?.archived = true
                            try? context.save()
                            dismiss()
                        }
                    } footer: {
                        Text("Removing keeps every test you filed against it.")
                    }
                }
            }
            .navigationTitle(assembly == nil ? "New Assembly" : "Assembly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                guard let assembly else { return }
                type = assembly.type; serial = assembly.serial; make = assembly.make
                model = assembly.model; size = assembly.size; location = assembly.location
                hazard = assembly.hazard; waterPurveyor = assembly.waterPurveyor
                permitNumber = assembly.permitNumber; frequency = assembly.testFrequencyMonths
                notes = assembly.notes
            }
        }
    }

    private func save() {
        let target = assembly ?? Assembly(siteID: site.id)
        target.type = type
        target.serial = serial.trimmingCharacters(in: .whitespacesAndNewlines)
        target.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        target.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        target.size = size.trimmingCharacters(in: .whitespacesAndNewlines)
        target.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        target.hazard = hazard.trimmingCharacters(in: .whitespacesAndNewlines)
        target.waterPurveyor = waterPurveyor.trimmingCharacters(in: .whitespacesAndNewlines)
        target.permitNumber = permitNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.testFrequencyMonths = frequency
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if assembly == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}
