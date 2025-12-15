import Foundation
import UIKit

/// Example battery service for iOS.
/// Methods marked with @objc are automatically exposed to Flutter.
class BatteryService: NSObject {

    override init() {
        super.init()
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    @objc func getBatteryLevel() -> Int {
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            return -1 // Unknown
        }
        return Int(level * 100)
    }

    @objc func isCharging() -> Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    @objc func getBatteryState() -> String {
        switch UIDevice.current.batteryState {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }
}
