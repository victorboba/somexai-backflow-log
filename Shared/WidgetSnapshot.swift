import Foundation

struct WidgetSnapshot: Codable {
    var overdueCount: Int = 0
    var dueSoonCount: Int = 0
    var neverTestedCount: Int = 0
    var nextName: String = ""
    var nextDays: Int?
    var gaugeOutOfCalibration: Bool = false
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(overdueCount: 4, dueSoonCount: 11, neverTestedCount: 2,
                                            nextName: "RP 1in #A44821", nextDays: 6,
                                            gaugeOutOfCalibration: false)
}
