import SwiftUI
import SwiftData

/// Customer, then site, then assembly. The hierarchy a tester's book is already in.
struct CustomerListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Customer.createdAt) private var customers: [Customer]
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Assembly.createdAt) private var assemblies: [Assembly]

    @State private var creating = false
    @State private var editing: Customer?

    private var live: [Customer] { customers.filter { !$0.archived } }

    var body: some View {
        Group {
            if live.isEmpty {
                ContentUnavailableView {
                    Label("No customers", systemImage: "building.2")
                } description: {
                    Text("A customer, then their sites, then the assemblies on each one.")
                } actions: {
                    Button("Add a Customer") { creating = true }.buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(live) { customer in
                        NavigationLink {
                            SiteListView(customer: customer)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(customer.displayName).font(.body.weight(.semibold))
                                Text(summary(customer)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { editing = customer } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.accentColor)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { live[index].archived = true }
                        try? context.save()
                    }
                }
                .maxContentWidth()
            }
        }
        .navigationTitle("Customers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a customer")
            }
        }
        .sheet(isPresented: $creating) { CustomerEditorView(customer: nil) }
        .sheet(item: $editing) { CustomerEditorView(customer: $0) }
    }

    private func summary(_ customer: Customer) -> String {
        let mySites = sites.filter { $0.customerID == customer.id && !$0.archived }
        let siteIDs = Set(mySites.map(\.id))
        let count = assemblies.filter { siteIDs.contains($0.siteID) && !$0.archived }.count
        return "\(mySites.count) site\(mySites.count == 1 ? "" : "s") · \(count) assembl\(count == 1 ? "y" : "ies")"
    }
}

struct SiteListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Assembly.createdAt) private var assemblies: [Assembly]

    let customer: Customer
    @State private var creating = false
    @State private var editing: Site?

    private var mine: [Site] { sites.filter { $0.customerID == customer.id && !$0.archived } }

    var body: some View {
        Group {
            if mine.isEmpty {
                ContentUnavailableView {
                    Label("No sites", systemImage: "mappin.and.ellipse")
                } description: {
                    Text("The properties you look after for \(customer.displayName).")
                } actions: {
                    Button("Add a Site") { creating = true }.buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(mine) { site in
                        NavigationLink {
                            AssemblyListView(site: site)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.displayName).font(.body.weight(.semibold))
                                if !site.address.isEmpty {
                                    Text(site.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Text("\(assemblies.filter { $0.siteID == site.id && !$0.archived }.count) assemblies")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { editing = site } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.accentColor)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { mine[index].archived = true }
                        try? context.save()
                    }
                }
                .maxContentWidth()
            }
        }
        .navigationTitle(customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a site")
            }
        }
        .sheet(isPresented: $creating) { SiteEditorView(site: nil, customer: customer) }
        .sheet(item: $editing) { SiteEditorView(site: $0, customer: customer) }
    }
}

struct AssemblyListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Assembly.createdAt) private var assemblies: [Assembly]
    @Query(sort: \BackflowTest.date, order: .reverse) private var tests: [BackflowTest]

    let site: Site
    @State private var creating = false
    @State private var editing: Assembly?
    @State private var testing: Assembly?

    private var mine: [Assembly] { assemblies.filter { $0.siteID == site.id && !$0.archived } }

    var body: some View {
        Group {
            if mine.isEmpty {
                ContentUnavailableView {
                    Label("No assemblies", systemImage: "gauge.with.needle")
                } description: {
                    Text("Every backflow preventer on this property.")
                } actions: {
                    Button("Add an Assembly") { creating = true }.buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(mine) { assembly in
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assembly.displayName).font(.body.weight(.semibold))
                                Text(assembly.displayLocation).font(.caption).foregroundStyle(.secondary)
                                let status = RouteMath.status(assembly, tests: tests)
                                Label(statusText(assembly, status), systemImage: status.symbol)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(status.tint)
                            }
                            .padding(.vertical, 2)
                            Button { testing = assembly } label: {
                                Label("Start Test", systemImage: "square.and.pencil").fontWeight(.semibold)
                            }
                            Button { editing = assembly } label: {
                                Label("Edit assembly", systemImage: "pencil")
                            }
                            .foregroundStyle(.secondary)
                            ForEach(tests.filter { $0.assemblyID == assembly.id }.prefix(3)) { test in
                                TestRow(test: test)
                            }
                        }
                    }
                }
                .maxContentWidth()
            }
        }
        .navigationTitle(site.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add an assembly")
            }
        }
        .sheet(isPresented: $creating) { AssemblyEditorView(assembly: nil, site: site) }
        .sheet(item: $editing) { AssemblyEditorView(assembly: $0, site: site) }
        .sheet(item: $testing) { TestEditorView(assembly: $0, test: nil) }
    }

    private func statusText(_ assembly: Assembly, _ status: RouteMath.DueStatus) -> String {
        guard let days = RouteMath.daysUntilDue(assembly, tests: tests) else { return "Never tested" }
        return Formatters.due(days).prefix(1).uppercased() + Formatters.due(days).dropFirst()
    }
}
