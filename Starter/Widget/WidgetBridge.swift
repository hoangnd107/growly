import Foundation
import WidgetKit

@objc public class WidgetBridge: NSObject {
    @objc public static func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
