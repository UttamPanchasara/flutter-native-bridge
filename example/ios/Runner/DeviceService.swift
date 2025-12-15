import Foundation
import UIKit

/// Example service class for iOS.
/// Methods marked with @objc are automatically exposed to Flutter.
class DeviceService: NSObject {

    @objc func getDeviceModel() -> String {
        return UIDevice.current.model
    }

    @objc func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    @objc func getDeviceName() -> String {
        return UIDevice.current.name
    }

    // This method is NOT exposed (no @objc)
    func internalMethod() -> String {
        return "Not accessible from Flutter"
    }
}
