import AppIntents
import Foundation

/// "Start a test in Backflow Log" from Siri, Spotlight or Shortcuts.
struct StartTestIntent: AppIntent {
    static var title: LocalizedStringResource = "Open the Route"
    static var description = IntentDescription("Opens Backflow Log on today's route.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.startTest"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct BackflowLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTestIntent(),
            phrases: ["Open the route in \(.applicationName)", "Show my route in \(.applicationName)"],
            shortTitle: "Open the Route",
            systemImageName: "list.clipboard.fill"
        )
    }
}
