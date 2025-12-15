import Flutter
import UIKit
import flutter_native_bridge

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register native services with Flutter Native Bridge
        FlutterNativeBridge.register(DeviceService())
        FlutterNativeBridge.register(BatteryService())

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
