import Flutter
import UIKit

/// Flutter Native Bridge Plugin for iOS
///
/// Bridges Flutter and native iOS code using Objective-C runtime.
/// Use @objc to expose methods to Flutter.
public class FlutterNativeBridgePlugin: NSObject, FlutterPlugin {

    private static var registeredObjects: [String: AnyObject] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_native_bridge",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterNativeBridgePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Registration Methods (Called from FlutterNativeBridge helper)

    static func registerObject(name: String, object: AnyObject) {
        registeredObjects[name] = object
    }

    static func registerObject(_ object: AnyObject) {
        let name = String(describing: type(of: object))
            .components(separatedBy: ".").last ?? String(describing: type(of: object))
        registeredObjects[name] = object
    }

    static func unregisterObject(name: String) {
        registeredObjects.removeValue(forKey: name)
    }

    static func isRegistered(name: String) -> Bool {
        return registeredObjects[name] != nil
    }

    // MARK: - Method Call Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Discovery methods
        switch call.method {
        case "_getRegisteredClasses":
            result(Array(FlutterNativeBridgePlugin.registeredObjects.keys))
            return

        case "_getMethods":
            guard let className = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "Class name required", details: nil))
                return
            }
            guard let target = FlutterNativeBridgePlugin.registeredObjects[className] else {
                result(FlutterError(code: "NOT_FOUND", message: "Class '\(className)' not registered", details: nil))
                return
            }
            result(getExposedMethods(target: target))
            return

        case "_discover":
            var discovery: [String: [String]] = [:]
            for (name, obj) in FlutterNativeBridgePlugin.registeredObjects {
                discovery[name] = getExposedMethods(target: obj)
            }
            result(discovery)
            return

        default:
            break
        }

        // Regular method calls (ClassName.methodName)
        let parts = call.method.components(separatedBy: ".")
        guard parts.count == 2 else {
            result(FlutterError(code: "INVALID_FORMAT", message: "Method must be 'ClassName.methodName'", details: nil))
            return
        }

        let className = parts[0]
        let methodName = parts[1]

        guard let target = FlutterNativeBridgePlugin.registeredObjects[className] else {
            result(FlutterError(code: "NOT_FOUND", message: "Class '\(className)' not registered", details: nil))
            return
        }

        // Find and call the method
        let returnValue = invokeMethod(target: target, methodName: methodName, arguments: call.arguments)

        if let error = returnValue as? FlutterError {
            result(error)
        } else {
            result(returnValue)
        }
    }

    // MARK: - Method Invocation

    private func invokeMethod(target: AnyObject, methodName: String, arguments: Any?) -> Any? {
        // Try to find a matching selector
        let selectors = buildSelectors(methodName: methodName, arguments: arguments)

        for selector in selectors {
            if target.responds(to: selector) {
                return performSelector(target: target, selector: selector, arguments: arguments)
            }
        }

        return FlutterError(
            code: "NOT_FOUND",
            message: "Method '\(methodName)' not found. Make sure it's marked with @objc",
            details: nil
        )
    }

    private func buildSelectors(methodName: String, arguments: Any?) -> [Selector] {
        var selectors: [Selector] = []

        if arguments == nil {
            // No arguments
            selectors.append(Selector(methodName))
        } else if let dict = arguments as? [String: Any] {
            // Dictionary arguments - try with parameter names
            let keys = dict.keys.sorted()
            if keys.count == 1 {
                selectors.append(Selector("\(methodName)With\(keys[0].capitalized):"))
                selectors.append(Selector("\(methodName):"))
            } else {
                // Multiple parameters
                var selectorName = methodName
                for (i, key) in keys.enumerated() {
                    if i == 0 {
                        selectorName += "With\(key.capitalized):"
                    } else {
                        selectorName += "\(key):"
                    }
                }
                selectors.append(Selector(selectorName))
                selectors.append(Selector("\(methodName):"))
            }
        } else {
            // Single argument
            selectors.append(Selector("\(methodName):"))
            selectors.append(Selector("\(methodName)With:"))
        }

        return selectors
    }

    private func performSelector(target: AnyObject, selector: Selector, arguments: Any?) -> Any? {
        if arguments == nil {
            let result = target.perform(selector)
            return unwrapResult(result?.takeUnretainedValue())
        }

        // Handle dictionary with single value
        if let dict = arguments as? [String: Any], dict.count == 1, let value = dict.values.first {
            let result = target.perform(selector, with: value)
            return unwrapResult(result?.takeUnretainedValue())
        }

        // Pass arguments directly
        let result = target.perform(selector, with: arguments)
        return unwrapResult(result?.takeUnretainedValue())
    }

    private func unwrapResult(_ value: Any?) -> Any? {
        guard let value = value else { return nil }

        // Convert NSNumber to appropriate Swift types
        if let number = value as? NSNumber {
            let type = String(cString: number.objCType)
            switch type {
            case "c", "B": return number.boolValue
            case "i", "s", "l", "q": return number.intValue
            case "f", "d": return number.doubleValue
            default: return number
            }
        }

        return value
    }

    // MARK: - Method Discovery

    private func getExposedMethods(target: AnyObject) -> [String] {
        var methods: Set<String> = []

        var methodCount: UInt32 = 0
        guard let methodList = class_copyMethodList(type(of: target), &methodCount) else {
            return []
        }

        for i in 0..<Int(methodCount) {
            let method = methodList[i]
            let selector = method_getName(method)
            var name = NSStringFromSelector(selector)

            // Filter out system methods
            if name.hasPrefix("_") || name.hasPrefix(".") { continue }
            if name.contains("init") || name.contains("dealloc") { continue }
            if name.contains(".cxx") { continue }

            // Extract method name (before first colon)
            if let colonIndex = name.firstIndex(of: ":") {
                name = String(name[..<colonIndex])
            }

            // Remove "With" suffix if present
            if name.hasSuffix("With") {
                name = String(name.dropLast(4))
            }

            // Only include user-defined methods
            if !name.isEmpty && name.first?.isLowercase == true {
                methods.insert(name)
            }
        }

        free(methodList)
        return Array(methods).sorted()
    }
}
