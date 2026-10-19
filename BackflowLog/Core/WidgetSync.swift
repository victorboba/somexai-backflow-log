import Foundation
import WidgetKit

enum WidgetSync {
    static func update(_ snapshot: WidgetSnapshot) {
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
