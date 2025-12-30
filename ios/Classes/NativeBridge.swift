import Foundation

/// Flutter Native Bridge - Registration Helper for iOS
///
/// Use this class to register your Swift/Objective-C classes with Flutter.
///
/// Usage in AppDelegate:
/// ```swift
/// override func application(
///     _ application: UIApplication,
///     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
/// ) -> Bool {
///     GeneratedPluginRegistrant.register(with: self)
///     FlutterNativeBridge.register(self)
///     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
/// }
/// ```
@objc public class FlutterNativeBridge: NSObject {

    /// Register an object with auto-detected class name.
    /// The object's methods marked with @objc will be callable from Flutter.
    ///
    /// - Parameter object: The object to register
    @objc public static func register(_ object: AnyObject) {
        FlutterNativeBridgePlugin.registerObject(object)
    }

    /// Register an object with a custom name.
    /// Use this to avoid name conflicts.
    ///
    /// - Parameters:
    ///   - name: Custom name for the object
    ///   - object: The object to register
    @objc public static func register(name: String, object: AnyObject) {
        FlutterNativeBridgePlugin.registerObject(name: name, object: object)
    }

    /// Register multiple objects at once.
    ///
    /// - Parameter objects: Objects to register
    @objc public static func registerObjects(_ objects: [AnyObject]) {
        for object in objects {
            FlutterNativeBridgePlugin.registerObject(object)
        }
    }

    /// Unregister an object by name.
    ///
    /// - Parameter name: Name of the object to unregister
    @objc public static func unregister(name: String) {
        FlutterNativeBridgePlugin.unregisterObject(name: name)
    }

    /// Check if a name is already registered.
    ///
    /// - Parameter name: Name to check
    /// - Returns: true if registered
    @objc public static func isRegistered(name: String) -> Bool {
        return FlutterNativeBridgePlugin.isRegistered(name: name)
    }
}

// MARK: - Protocol for Native Bridge Classes

/// Protocol for classes that expose methods to Flutter.
/// Conforming classes should mark methods with @objc.
///
/// Example:
/// ```swift
/// class DeviceService: NSObject, NativeBridgeClass {
///     @objc func getModel() -> String {
///         return UIDevice.current.model
///     }
/// }
/// ```
@objc public protocol NativeBridgeClass: AnyObject {
    // Marker protocol - implement @objc methods to expose them
}

// MARK: - Stream Support

/// Protocol for emitting stream events to Flutter.
/// Used with methods that need to send continuous data updates.
///
/// Example:
/// ```swift
/// class SensorService: NSObject {
///     @objc func accelerometerUpdates(_ sink: StreamSink) {
///         // Start sensor updates
///         motionManager.startAccelerometerUpdates(to: .main) { data, error in
///             if let error = error {
///                 sink.error(code: "SENSOR_ERROR", message: error.localizedDescription, details: nil)
///                 return
///             }
///             if let data = data {
///                 sink.success(["x": data.acceleration.x, "y": data.acceleration.y])
///             }
///         }
///     }
/// }
/// ```
@objc public protocol StreamSink: AnyObject {
    /// Send a success event to Flutter
    func success(_ event: Any?)

    /// Send an error event to Flutter
    func error(code: String, message: String?, details: Any?)

    /// Signal that the stream has ended
    func endOfStream()
}

/// Marker protocol for stream methods.
/// Conform to this protocol in classes that have stream methods.
///
/// Note: In Swift/iOS, stream methods are identified by having a StreamSink parameter.
/// Unlike Android, there's no annotation - just use @objc and accept StreamSink.
@objc public protocol NativeStreamClass: AnyObject {
    // Marker protocol - implement @objc methods with StreamSink parameter
}
