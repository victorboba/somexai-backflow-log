import SwiftUI
import SwiftData

@main
struct BackflowLog: App {
    @State private var entitlements = EntitlementStore()
    private let container: ModelContainer

    init() {
        let schema = Schema([Customer.self, Site.self, Assembly.self, BackflowTest.self, Tester.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            try? container.mainContext.delete(model: BackflowTest.self)
            try? container.mainContext.delete(model: Assembly.self)
            try? container.mainContext.delete(model: Site.self)
            try? container.mainContext.delete(model: Customer.self)
            try? container.mainContext.delete(model: Tester.self)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
        }
        .modelContainer(container)
    }
}
