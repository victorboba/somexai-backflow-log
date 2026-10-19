import SwiftUI
import SwiftData

/// Everything filed, newest first, plus the exports.
struct TestListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Customer.createdAt) private var customers: [Customer]
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Assembly.createdAt) private var assemblies: [Assembly]
    @Query(sort: \BackflowTest.date, order: .reverse) private var tests: [BackflowTest]

    @State private var editing: BackflowTest?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var minimums: [ReadingField: Double] {
        var result: [ReadingField: Double] = [:]
        for field in ReadingField.allCases {
            let stored = UserDefaults.standard.double(forKey: field.storageKey)
            result[field] = stored > 0 ? stored : field.suggestedMinimum
        }
        return result
    }

    private var months: [(start: Date, tests: [BackflowTest])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: tests) { test in
            calendar.date(from: calendar.dateComponents([.year, .month], from: test.date)) ?? test.date
        }
        return grouped.keys.sorted(by: >).map { (start: $0, tests: (grouped[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tests.isEmpty {
                    ContentUnavailableView("No tests filed", systemImage: "doc.text",
                                           description: Text("Run a test from the Route screen and it lands here."))
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                StatBlock(value: "\(tests.count)", label: "tests")
                                StatBlock(value: "\(thisYear.count)", label: "this year")
                                StatBlock(value: Formatters.psi(RouteMath.passRate(tests) * 100) + "%", label: "passed")
                            }
                        }
                        ForEach(months, id: \.start) { month in
                            Section(Formatters.monthYear.string(from: month.start)) {
                                ForEach(month.tests) { test in
                                    Button { editing = test } label: { TestRow(test: test) }
                                        .buttonStyle(.plain)
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                exportFile = try? ExportFile(url: ReportExporter.export(test, minimums: minimums))
                                            } label: { Label("Report", systemImage: "doc.richtext") }
                                            .tint(.accentColor)
                                        }
                                }
                            }
                        }
                        exportSection
                        Section { Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary) }
                    }
                    .maxContentWidth(700)
                }
            }
            .navigationTitle("Tests")
            .sheet(item: $editing) { test in
                if let assembly = assemblies.first(where: { $0.id == test.assemblyID }) {
                    TestEditorView(assembly: assembly, test: test)
                }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private var thisYear: [BackflowTest] {
        let year = Calendar.current.component(.year, from: .now)
        return tests.filter { Calendar.current.component(.year, from: $0.date) == year }
    }

    private var exportSection: some View {
        Section {
            Button {
                export { try CSVExporter.write(CSVExporter.testsCSV(tests), suffix: "tests") }
            } label: { Label("Every test CSV", systemImage: "tablecells") }
            Button {
                let route = RouteMath.route(assemblies: assemblies, sites: sites,
                                            customers: customers, tests: tests)
                export { try CSVExporter.write(CSVExporter.routeCSV(route), suffix: "route") }
            } label: { Label("Route CSV", systemImage: "tablecells") }
        } header: {
            Text("Export")
        } footer: {
            Text("Each test also has its own report PDF: swipe a row, or open it and tap Report PDF.")
        }
    }

    private func export(_ make: () throws -> URL) {
        do { exportFile = ExportFile(url: try make()) } catch { exportError = error.localizedDescription }
    }
}
