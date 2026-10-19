import SwiftUI
import SwiftData

/// Home: the route. What is overdue, what is due next, grouped by the month it falls in, so a
/// tester can plan a week of driving in one screen.
struct RouteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Customer.createdAt) private var customers: [Customer]
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Assembly.createdAt) private var assemblies: [Assembly]
    @Query(sort: \BackflowTest.date, order: .reverse) private var tests: [BackflowTest]
    @Query(sort: \Tester.createdAt) private var testers: [Tester]

    @State private var showingSettings = false
    @State private var startingTest: Assembly?

    private var tester: Tester? { testers.first }
    private var route: [RouteMath.RouteEntry] {
        RouteMath.route(assemblies: assemblies, sites: sites, customers: customers, tests: tests)
    }
    private var needing: [RouteMath.RouteEntry] { RouteMath.needingWork(route) }

    var body: some View {
        NavigationStack {
            Group {
                if assemblies.filter({ !$0.archived }).isEmpty {
                    ContentUnavailableView {
                        Label("No assemblies yet", systemImage: "gauge.with.needle")
                    } description: {
                        Text("Add a customer, a site and the assemblies on it. The route builds itself from their test dates.")
                    } actions: {
                        NavigationLink("Add a Customer") { CustomerListView() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        summarySection
                        if RouteMath.gaugeOutOfCalibration(tester) { gaugeSection }
                        ForEach(RouteMath.byMonth(route)) { group in
                            Section(group.title) {
                                ForEach(group.entries) { entry in
                                    Button {
                                        startingTest = assemblies.first { $0.id == entry.assemblyID }
                                    } label: {
                                        RouteRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Section { Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary) }
                    }
                    .maxContentWidth(700)
                }
            }
            .navigationTitle("Route")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                    NavigationLink { HowToView() } label: { Image(systemName: "questionmark.circle") }
                        .accessibilityLabel("How do I use this app")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $startingTest) { assembly in
                TestEditorView(assembly: assembly, test: nil)
            }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), customers.isEmpty {
                SampleData.insert(into: context)
            }
            #endif
        }
        .onChange(of: tests.count, initial: true) { sync() }
        .onChange(of: assemblies.count) { sync() }
        .onChange(of: testers.count) { sync() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            WidgetSnapshot.defaults.removeObject(forKey: StartTestIntent.pendingKey)
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                StatBlock(value: "\(route.filter { $0.status == .overdue }.count)", label: "overdue",
                          tint: route.contains { $0.status == .overdue } ? .red : .primary)
                StatBlock(value: "\(route.filter { $0.status == .dueSoon }.count)", label: "due soon")
                StatBlock(value: "\(route.filter { $0.status == .neverTested }.count)", label: "never tested")
            }
            if needing.isEmpty {
                Label("Nothing is due in the next \(RouteMath.dueSoonDays) days.", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("\(assemblies.filter { !$0.archived }.count) assemblies across \(customers.filter { !$0.archived }.count) customers")
        }
    }

    private var gaugeSection: some View {
        Section {
            Label("Your gauge calibration has run out", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            Text("A test taken with an out-of-calibration gauge is not valid. Get it calibrated and update the date in Settings before testing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sync() {
        var snapshot = WidgetSnapshot()
        snapshot.overdueCount = route.filter { $0.status == .overdue }.count
        snapshot.dueSoonCount = route.filter { $0.status == .dueSoon }.count
        snapshot.neverTestedCount = route.filter { $0.status == .neverTested }.count
        if let next = needing.first {
            snapshot.nextName = "\(next.customerName) · \(next.assemblyName)"
            snapshot.nextDays = next.daysUntilDue
        }
        snapshot.gaugeOutOfCalibration = RouteMath.gaugeOutOfCalibration(tester)
        WidgetSync.update(snapshot)
    }
}
